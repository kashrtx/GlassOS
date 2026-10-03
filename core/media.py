"""
GlassOS media services, exposed to QML as ``Visualizer``.

The Media Player plays files with Qt Multimedia (FFmpeg backend in Qt 6.5+:
MP4/MKV/WebM/AVI/MOV, MP3/FLAC/OGG/WAV/AAC/M4A/OPUS…). This module adds a
real-time spectrum analyzer for the equalizer visual:

* Qt >= 6.8 exposes decoded PCM through ``QAudioBufferOutput``; we keep only
  the newest buffer and analyze at most 30 times per second on the GUI thread
  (an FFT of 2048 samples takes well under a millisecond with numpy).
* Without numpy a pure-Python Goertzel filter bank (24 bands) is used.
* If the Qt version can't tap audio at all, ``realSpectrum`` stays False and
  the QML visual animates a tasteful synthetic spectrum instead.
"""

from __future__ import annotations

import array
import math
import time
from typing import List, Optional

from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot

from . import log as _log

log = _log.get("media")

try:  # optional, much faster spectrum
    import numpy as _np
except ImportError:  # pragma: no cover - environment dependent
    _np = None

BANDS = 48
MIN_HZ, MAX_HZ = 40.0, 16000.0
FFT_SIZE = 2048


def band_edges(n: int = BANDS, lo: float = MIN_HZ, hi: float = MAX_HZ) -> List[float]:
    """Logarithmically spaced band edges (n + 1 values)."""
    return [lo * (hi / lo) ** (i / n) for i in range(n + 1)]


def to_mono_floats(raw: bytes, sample_format: str, channels: int) -> List[float]:
    """Decode interleaved PCM to a mono list of floats in [-1, 1]."""
    if sample_format == "float":
        data = array.array("f")
        scale = 1.0
    elif sample_format == "int16":
        data, scale = array.array("h"), 1 / 32768.0
    elif sample_format == "int32":
        data, scale = array.array("i"), 1 / 2147483648.0
    elif sample_format == "uint8":
        data, scale = array.array("B"), 1 / 128.0
    else:
        return []
    usable = len(raw) - len(raw) % data.itemsize
    data.frombytes(raw[:usable])
    channels = max(1, channels)
    if sample_format == "uint8":
        values = [(v - 128) * scale for v in data]
    else:
        values = [v * scale for v in data] if scale != 1.0 else list(data)
    if channels == 1:
        return values
    frames = len(values) // channels
    return [sum(values[i * channels:(i + 1) * channels]) / channels for i in range(frames)]


def spectrum(samples, sample_rate: int, bands: int = BANDS) -> List[float]:
    """Band magnitudes normalized to 0..1 (roughly -60 dB .. 0 dB)."""
    if not samples or sample_rate <= 0:
        return [0.0] * bands
    edges = band_edges(bands, MIN_HZ, min(MAX_HZ, sample_rate / 2 * 0.95))
    if _np is not None:
        x = _np.asarray(samples[-FFT_SIZE:], dtype=_np.float32)
        if x.size < 64:
            return [0.0] * bands
        x = x * _np.hanning(x.size)
        mag = _np.abs(_np.fft.rfft(x)) / (x.size / 2)
        freqs = _np.fft.rfftfreq(x.size, 1.0 / sample_rate)
        out = []
        for i in range(bands):
            sel = mag[(freqs >= edges[i]) & (freqs < edges[i + 1])]
            v = float(sel.max()) if sel.size else 0.0
            out.append(v)
    else:  # Goertzel filter bank on fewer samples / bands, then stretch to `bands`
        x = samples[-512:]
        n = len(x)
        if n < 64:
            return [0.0] * bands
        window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)) for i in range(n)]
        xs = [a * w for a, w in zip(x, window)]
        coarse_edges = band_edges(24, MIN_HZ, min(MAX_HZ, sample_rate / 2 * 0.95))
        coarse = []
        for i in range(24):
            f = math.sqrt(coarse_edges[i] * coarse_edges[i + 1])
            k = 2 * math.cos(2 * math.pi * f / sample_rate)
            s1 = s2 = 0.0
            for v in xs:
                s1, s2 = v + k * s1 - s2, s1
            coarse.append(math.sqrt(max(0.0, s1 * s1 + s2 * s2 - k * s1 * s2)) / (n / 2))
        out = [coarse[min(23, int(i * 24 / bands))] for i in range(bands)]
    # magnitude -> 0..1 on a dB scale; tilt so treble isn't visually starved
    result = []
    for i, v in enumerate(out):
        db = 20 * math.log10(max(v, 1e-6)) + 6 * (i / bands)
        result.append(max(0.0, min(1.0, (db + 60) / 60)))
    return result


class AudioVisualizer(QObject):
    levelsChanged = Signal()
    stateChanged = Signal()

    def __init__(self, parent: Optional[QObject] = None):
        super().__init__(parent)
        self._levels = [0.0] * BANDS
        self._bass = 0.0
        self._pending = None          # newest (samples, rate) waiting for analysis
        self._real = False
        self._enabled = False
        self._last_data = 0.0
        self._outputs = []            # keep QAudioBufferOutput objects alive
        self._timer = QTimer(self)
        self._timer.setInterval(33)   # ~30 fps
        self._timer.timeout.connect(self._tick)

    # ------------------------------------------------------------ QML API
    @Slot(QObject, result=bool)
    def attach(self, player) -> bool:
        """Tap a QML MediaPlayer's decoded audio (Qt 6.8+). Returns True if possible."""
        try:
            from PySide6.QtMultimedia import QAudioBufferOutput
        except ImportError:
            log.info("QAudioBufferOutput unavailable (needs Qt 6.8+): using synthetic visualizer")
            return False
        if player is None or not hasattr(player, "setAudioBufferOutput"):
            return False
        try:
            out = QAudioBufferOutput(self)
            out.audioBufferReceived.connect(self._on_buffer)
            player.setAudioBufferOutput(out)
            self._outputs.append(out)
            return True
        except Exception as exc:
            log.warning("could not attach audio analyzer: %s", exc)
            return False

    @Slot(bool)
    def setEnabled(self, enabled: bool):
        self._enabled = bool(enabled)
        if self._enabled:
            self._timer.start()
        else:
            self._timer.stop()
            self._decay(reset=True)

    @Property("QVariantList", notify=levelsChanged)
    def levels(self) -> list:
        return self._levels

    @Property(float, notify=levelsChanged)
    def bass(self) -> float:
        return self._bass

    @Property(bool, notify=stateChanged)
    def realSpectrum(self) -> bool:
        return self._real

    @Property(int, constant=True)
    def bandCount(self) -> int:
        return BANDS

    # ------------------------------------------------------------ internals
    def _on_buffer(self, buf):
        if not self._enabled:
            return
        try:
            fmt = buf.format()
            sf = fmt.sampleFormat()
            name = getattr(sf, "name", str(sf)).lower()
            kind = ("float" if "float" in name else "int16" if "int16" in name else
                    "int32" if "int32" in name else "uint8" if "uint8" in name else "")
            raw = _buffer_bytes(buf)
            if not raw or not kind:
                return
            self._pending = (raw, kind, fmt.channelCount(), fmt.sampleRate())
            self._last_data = time.monotonic()
            if not self._real:
                self._real = True
                self.stateChanged.emit()
        except Exception as exc:  # never break playback because of the visual
            log.debug("audio buffer skipped: %s", exc)

    def _tick(self):
        pending, self._pending = self._pending, None
        if pending is None:
            if time.monotonic() - self._last_data > 0.3:
                self._decay()
            return
        raw, kind, channels, rate = pending
        itemsize = {"float": 4, "int16": 2, "int32": 4, "uint8": 1}[kind]
        raw = raw[-FFT_SIZE * max(1, channels) * itemsize:]   # only what the FFT needs
        try:
            mono = to_mono_floats(raw, kind, channels)
            target = spectrum(mono, rate)
        except Exception as exc:
            log.debug("spectrum failed: %s", exc)
            return
        # fast attack, slow release: lively but not jittery
        self._levels = [t if t > c else c * 0.82 + t * 0.18 for t, c in zip(target, self._levels)]
        self._bass = sum(self._levels[:6]) / 6
        self.levelsChanged.emit()

    def _decay(self, reset: bool = False):
        if reset:
            self._levels = [0.0] * BANDS
        elif max(self._levels) < 0.01:
            return
        else:
            self._levels = [v * 0.85 for v in self._levels]
        self._bass = sum(self._levels[:6]) / 6
        self.levelsChanged.emit()


def _buffer_bytes(buf) -> bytes:
    """Copy a QAudioBuffer's payload into bytes (PySide returns different wrappers per version)."""
    size = buf.byteCount()
    if size <= 0:
        return b""
    data = buf.constData() if hasattr(buf, "constData") else buf.data()
    if isinstance(data, (bytes, bytearray)):
        return bytes(data[:size])
    if isinstance(data, memoryview):
        return data.tobytes()[:size]
    try:  # shiboken VoidPtr without a known size
        import shiboken6
        return bytes(shiboken6.VoidPtr(data, size, False))
    except Exception:
        return bytes(memoryview(data))[:size]
