"""
Ad/tracker blocking engine for AeroBrowser (pure Python, unit-tested).

Understands the network-filter subset of the Adblock Plus syntax used by
EasyList / EasyPrivacy (the lists Brave and uBlock Origin start from):

  ||ads.example.com^             block a host and its subdomains
  ||example.com/banner/*.gif      host-anchored path pattern
  /adserver/*$third-party,script  options: (~)third-party, resource types, domain=
  @@||cdn.example.com^$script     exception (allow) rules
  ##.ad-banner                    generic element hiding (cosmetic CSS)

Rules using syntax we don't implement ($redirect, $csp, $removeparam, regex
rules, scriptlets...) are skipped rather than approximated, so the engine
never over-blocks. Matching uses a token index like uBlock Origin: each URL is
only tested against rules that share a token with it.

Top-level page loads are never blocked, and a site's own (first-party)
resources are only blocked by explicit list rules, never by built-in heuristics.
"""

from __future__ import annotations

import re
from functools import lru_cache
from typing import Dict, Iterable, List, Optional, Set

# A small built-in list so blocking works offline before the big lists arrive.
BLOCKED_DOMAINS = frozenset("""
doubleclick.net googlesyndication.com googleadservices.com google-analytics.com
googletagmanager.com googletagservices.com adservice.google.com pagead2.googlesyndication.com
adsrvr.org adnxs.com criteo.com criteo.net outbrain.com taboola.com revcontent.com mgid.com
zergnet.com hotjar.com fullstory.com mouseflow.com crazyegg.com quantserve.com
scorecardresearch.com chartbeat.com segment.io mixpanel.com heapanalytics.com mxpnl.com
adroll.com adform.net adzerk.net advertising.com rubiconproject.com pubmatic.com openx.net
indexexchange.com casalemedia.com contextweb.com bidswitch.net popads.net popcash.net
propellerads.com exoclick.com juicyads.com trafficjunky.com appsflyer.com kochava.com
addthis.com sharethis.com clickbooth.com intellitxt.com vibrantmedia.com innovid.com
spotxchange.com teads.tv tremorhub.com nativo.com sharethrough.com triplelift.com
perfectaudience.com bluekai.com exelator.com lotame.com amazon-adsystem.com
assoc-amazon.com ads-twitter.com analytics.twitter.com bat.bing.com omtrdc.net demdex.net
everesttech.net 2o7.net imrworldwide.com moatads.com doubleverify.com adsafeprotected.com
""".split())

_BUILTIN_PATHS = re.compile(
    r"(?:/(?:ads|adserver|adserv|adframe|advert|advertisement|banners?|sponsor(?:ed)?|pagead|"
    r"doubleclick)/)|(?:/(?:gtag/js|gtm\.js|analytics\.js|ga\.js|pixel(?:\.gif|\.png)?)(?:[?#]|$))"
    r"|(?:/popunder)",
    re.IGNORECASE,
)

TYPES = {"script", "image", "stylesheet", "xmlhttprequest", "subdocument", "media", "font",
         "object", "ping", "websocket", "other"}
_UNSUPPORTED = {"redirect", "redirect-rule", "csp", "removeparam", "rewrite", "replace", "header",
                "permissions", "urltransform", "popup", "popunder", "document", "doc", "elemhide", "ehide",
                "generichide", "ghide", "genericblock", "specifichide", "shide", "inline-script",
                "inline-font", "badfilter", "empty", "mp4", "cname", "denyallow", "to", "from", "method",
                "strict1p", "strict3p", "urlskip", "sitekey", "webrtc", "content", "jsinject", "frame"}

_TOKEN_RE = re.compile(r"[a-z0-9%]{3,}")
_SEPARATOR = r"(?:[^\w\-.%]|$)"


def registrable(host: str) -> str:
    """Very small eTLD+1 approximation (good enough for first/third-party checks)."""
    return _registrable(host.lower().strip("."))


@lru_cache(maxsize=8192)
def _registrable(host: str) -> str:
    parts = [p for p in host.split(".") if p]
    if len(parts) <= 2:
        return ".".join(parts)
    if len(parts[-1]) == 2 and parts[-2] in {"co", "com", "net", "org", "gov", "ac", "edu", "ne", "or"}:
        return ".".join(parts[-3:])
    return ".".join(parts[-2:])


def _host_suffixes(host: str) -> Iterable[str]:
    parts = host.split(".")
    for i in range(len(parts) - 1):
        yield ".".join(parts[i:])


def _domain_matches(host: str, domains: Iterable[str]) -> bool:
    return any(host == d or host.endswith("." + d) for d in domains)


def _pattern_to_regex(p: str) -> str:
    out, i = [], 0
    if p.startswith("||"):
        out.append(r"^[a-z][a-z0-9+.\-]*://(?:[^/?#]*\.)?")
        i = 2
    elif p.startswith("|"):
        out.append("^")
        i = 1
    end_anchor = p.endswith("|") and len(p) > i
    body = p[i:-1] if end_anchor else p[i:]
    for ch in body:
        if ch == "*":
            out.append(".*")
        elif ch == "^":
            out.append(_SEPARATOR)
        else:
            out.append(re.escape(ch))
    if end_anchor:
        out.append("$")
    return "".join(out)


_HOST_ANCHOR = re.compile(r"^\|\|([a-z0-9.\-]+)(?=[\^/:?*|]|$)")
_EDGE = 4   # characters used for prefix/suffix keys


def _best_token(pattern: str) -> str:
    """Index key for a rule.

    * "w:<token>" - an alnum run that must appear as a whole URL token;
    * "p:<abcd>"  - a run open on its right (pattern edge): URL tokens starting with it;
    * "s:<abcd>"  - a run open on its left: URL tokens ending with it;
    * ""          - nothing usable (checked against every URL; kept rare).
    """
    best, best_key = "", ""
    for m in _TOKEN_RE.finditer(pattern):
        s, e = m.start(), m.end()
        before = pattern[s - 1] if s > 0 else ""
        after = pattern[e] if e < len(pattern) else ""
        left_open = before == "*" or (s == 0 and not pattern.startswith("|"))
        right_open = after == "*" or e == len(pattern)
        tok = m.group()
        if not left_open and not right_open:
            key, score = "w:" + tok, len(tok) + 100        # exact tokens are the best keys
        elif not left_open and len(tok) >= _EDGE:
            key, score = "p:" + tok[:_EDGE], len(tok)
        elif not right_open and len(tok) >= _EDGE:
            key, score = "s:" + tok[-_EDGE:], len(tok)
        else:
            continue
        if score > len(best):
            best, best_key = "x" * score, key
    return best_key


def _url_keys(url: str):
    keys = [""]
    for tok in _TOKEN_RE.findall(url):
        keys.append("w:" + tok)
        if len(tok) >= _EDGE:
            keys.append("p:" + tok[:_EDGE])
            keys.append("s:" + tok[-_EDGE:])
    return keys


class Rule:
    __slots__ = ("pattern", "_regex", "third_party", "types", "not_types", "domains", "not_domains")

    def __init__(self, pattern: str):
        self.pattern = pattern
        self._regex = None
        self.third_party: Optional[bool] = None
        self.types: Optional[Set[str]] = None
        self.not_types: Set[str] = set()
        self.domains: List[str] = []
        self.not_domains: List[str] = []

    @property
    def regex(self):
        if self._regex is None:  # compiled lazily: most rules are never tested
            self._regex = re.compile(_pattern_to_regex(self.pattern))
        return self._regex

    def matches(self, url: str, page_host: str, rtype: str, third_party: bool) -> bool:
        if self.third_party is not None and self.third_party != third_party:
            return False
        if self.types is not None and rtype not in self.types:
            return False
        if rtype in self.not_types:
            return False
        if self.domains and not _domain_matches(page_host, self.domains):
            return False
        if self.not_domains and _domain_matches(page_host, self.not_domains):
            return False
        return self.regex.search(url) is not None


class FilterEngine:
    def __init__(self):
        self.block_hosts: Set[str] = set()
        self.allow_hosts: Set[str] = set()
        self._block: Dict[str, List[Rule]] = {}
        self._allow: Dict[str, List[Rule]] = {}
        # host-anchored rules with options/paths, indexed by their host (suffix walk)
        self._block_by_host: Dict[str, List[Rule]] = {}
        self._allow_by_host: Dict[str, List[Rule]] = {}
        self.cosmetic: List[str] = []
        self.rule_count = 0
        self.skipped = 0

    # ------------------------------------------------------------ parsing
    def add_text(self, text: str) -> int:
        return sum(1 for line in text.splitlines() if self.add_rule(line))

    def add_rule(self, line: str) -> bool:
        line = line.strip()
        if not line or line.startswith(("!", "[")):
            return False
        if line.startswith("##"):
            sel = line[2:]
            bad = (":-abp", ":has(", ":xpath", ":style", ":remove", ":matches", "+js(", ":upward", ":watch")
            if sel and not any(t in sel for t in bad) and "{" not in sel:
                self.cosmetic.append(sel)
                return True
            return False
        if any(t in line for t in ("##", "#@#", "#?#", "#$#", "#%#")):
            return False  # domain-specific cosmetic filters / scriptlets: not supported
        allow = line.startswith("@@")
        if allow:
            line = line[2:]
        pattern, opts = line, ""
        dollar = line.rfind("$")
        if dollar > 0 and not (line.startswith("/") and line.endswith("/")):
            pattern, opts = line[:dollar], line[dollar + 1:]
        if pattern.startswith("/") and pattern.endswith("/") and len(pattern) > 2:
            self.skipped += 1
            return False  # regex rules: skipped (rare and expensive)
        rule = Rule(pattern.lower())
        if opts and not self._apply_options(rule, opts):
            self.skipped += 1
            return False
        plain_host = re.fullmatch(r"\|\|([a-z0-9.\-]+)\^?", rule.pattern)
        if plain_host and not opts:
            (self.allow_hosts if allow else self.block_hosts).add(plain_host.group(1))
        else:
            if not rule.pattern.strip("*|^") or len(rule.pattern.strip("*|^")) < 3:
                self.skipped += 1
                return False  # too generic to be safe
            anchor = _HOST_ANCHOR.match(rule.pattern)
            if anchor and "*" not in anchor.group(1) and "." in anchor.group(1):
                by_host = self._allow_by_host if allow else self._block_by_host
                by_host.setdefault(anchor.group(1), []).append(rule)
            else:
                bucket = self._allow if allow else self._block
                bucket.setdefault(_best_token(rule.pattern), []).append(rule)
        self.rule_count += 1
        return True

    @staticmethod
    def _apply_options(rule: Rule, opts: str) -> bool:
        types: Set[str] = set()
        for opt in opts.lower().split(","):
            opt = opt.strip()
            if not opt:
                continue
            neg = opt.startswith("~")
            name = opt[1:] if neg else opt
            key = name.split("=")[0]
            if key in _UNSUPPORTED:
                return False
            if name in ("match-case", "important", "all"):
                continue
            if name in ("third-party", "3p"):
                rule.third_party = not neg
            elif name in ("first-party", "1p"):
                rule.third_party = neg
            elif name in TYPES or name == "xhr":
                name = "xmlhttprequest" if name == "xhr" else name
                (rule.not_types.add(name) if neg else types.add(name))
            elif key == "domain":
                for d in name[7:].split("|"):
                    d = d.strip()
                    if d.startswith("~"):
                        rule.not_domains.append(d[1:])
                    elif d:
                        rule.domains.append(d)
            else:
                return False  # unknown option: don't guess
        if types:
            rule.types = types
        return True

    # ------------------------------------------------------------ matching
    @staticmethod
    def _hit(buckets: Dict[str, List[Rule]], by_host: Dict[str, List[Rule]], url: str, host: str,
             page_host: str, rtype: str, third: bool, keys) -> bool:
        if by_host:
            for suffix in _host_suffixes(host):
                for rule in by_host.get(suffix, ()):
                    if rule.matches(url, page_host, rtype, third):
                        return True
        if not buckets:
            return False
        seen = set()
        for key in keys:
            if key in seen:
                continue
            seen.add(key)
            for rule in buckets.get(key, ()):
                if rule.matches(url, page_host, rtype, third):
                    return True
        return False

    def match(self, url: str, host: str, page_host: str, rtype: str = "other") -> bool:
        """True if the request should be blocked."""
        url = url.lower()
        host = host.lower()
        page_host = (page_host or "").lower()
        third = bool(page_host) and registrable(host) != registrable(page_host)
        keys = _url_keys(url)
        blocked = any(s in self.block_hosts for s in _host_suffixes(host)) or \
            self._hit(self._block, self._block_by_host, url, host, page_host, rtype, third, keys)
        if not blocked:
            return False
        if any(s in self.allow_hosts for s in _host_suffixes(host)):
            return False
        return not self._hit(self._allow, self._allow_by_host, url, host, page_host, rtype, third, keys)

    def cosmetic_css(self, limit: int = 8000) -> str:
        """Generic element-hiding CSS, chunked so one bad selector can't void the rest."""
        sels = self.cosmetic[:limit]
        return "\n".join(",".join(sels[i:i + 100]) + "{display:none!important}" for i in range(0, len(sels), 100))


@lru_cache(maxsize=4096)
def domain_blocked(host: str) -> bool:
    return any(s in BLOCKED_DOMAINS for s in _host_suffixes(host.lower().strip(".")))


def should_block(url: str, host: str, first_party_host: str, is_main_frame: bool,
                 engine: Optional[FilterEngine] = None, rtype: str = "other") -> bool:
    """Decide whether a sub-resource request should be blocked. Never raises."""
    if is_main_frame or not host or not url:
        return False
    host = host.lower()
    try:
        if domain_blocked(host):
            return True
        if engine is not None and engine.match(url, host, first_party_host, rtype):
            return True
        if first_party_host and registrable(host) == registrable(first_party_host):
            return False  # built-in heuristics never break a site's own resources
        return bool(_BUILTIN_PATHS.search(url))
    except Exception:
        return False
