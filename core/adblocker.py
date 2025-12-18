"""
GlassOS AdBlocker - URL Request Interceptor for AeroBrowser
Blocks ads, trackers, and malware domains using pattern matching.
"""

import re
from pathlib import Path
from typing import Set, List
from PySide6.QtCore import QObject, Slot, Signal, Property, QUrl
from PySide6.QtWebEngineCore import (
    QWebEngineUrlRequestInterceptor,
    QWebEngineUrlRequestInfo,
    QWebEngineProfile
)


class AdBlocker(QWebEngineUrlRequestInterceptor):
    """URL request interceptor that blocks ads and trackers."""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._enabled = True
        self._blocked_count = 0
        self._blocked_domains: Set[str] = set()
        self._blocked_patterns: List[re.Pattern] = []
        self._whitelist: Set[str] = set()
        self._domain_cache: dict = {}  # Cache for fast repeated lookups
        
        # Load default block lists
        self._load_default_blocklist()
    
    def _load_default_blocklist(self):
        """Load default ad and tracker domains to block."""
        # Common ad networks and trackers
        ad_domains = [
            # Major ad networks
            "doubleclick.net",
            "googlesyndication.com",
            "googleadservices.com",
            "google-analytics.com",
            "googletagmanager.com",
            "googletagservices.com",
            "adservice.google.com",
            "pagead2.googlesyndication.com",
            "adsense.google.com",
            
            # Facebook/Meta trackers
            "facebook.net",
            "fbcdn.net",
            "connect.facebook.net",
            "pixel.facebook.com",
            
            # Ad exchanges
            "adsrvr.org",
            "adnxs.com",
            "criteo.com",
            "criteo.net",
            "outbrain.com",
            "taboola.com",
            "revcontent.com",
            "mgid.com",
            "zergnet.com",
            
            # Tracking/Analytics
            "hotjar.com",
            "fullstory.com",
            "mouseflow.com",
            "crazyegg.com",
            "quantserve.com",
            "scorecardresearch.com",
            "chartbeat.com",
            "segment.io",
            "segment.com",
            "mixpanel.com",
            "amplitude.com",
            "heapanalytics.com",
            "mxpnl.com",
            
            # Common ad servers
            "adroll.com",
            "adform.net",
            "adzerk.net",
            "advertising.com",
            "rubiconproject.com",
            "pubmatic.com",
            "openx.net",
            "indexexchange.com",
            "casalemedia.com",
            "contextweb.com",
            "bidswitch.net",
            
            # Popups and overlays
            "popads.net",
            "popcash.net",
            "propellerads.com",
            "exoclick.com",
            "juicyads.com",
            "trafficjunky.com",
            
            # Mobile ad networks
            "appsflyer.com",
            "adjust.com",
            "branch.io",
            "kochava.com",
            "singular.net",
            
            # Social widgets (optional tracking)
            "addthis.com",
            "sharethis.com",
            "addtoany.com",
            
            # Malware/Scam domains
            "clickbooth.com",
            "intellitxt.com",
            "vibrantmedia.com",
            
            # Video ads
            "innovid.com",
            "spotxchange.com",
            "teads.tv",
            "tremorhub.com",
            
            # Native ads
            "nativo.com",
            "sharethrough.com",
            "triplelift.com",
            
            # Retargeting
            "perfectaudience.com",
            "adacado.com",
            "retargeter.com",
            
            # Data brokers
            "bluekai.com",
            "exelator.com",
            "liveramp.com",
            "lotame.com",
            "acxiom.com",
            
            # Amazon ads
            "amazon-adsystem.com",
            "assoc-amazon.com",
            
            # Twitter/X ads
            "ads-twitter.com",
            "analytics.twitter.com",
            
            # Microsoft ads
            "bat.bing.com",
            "ads.microsoft.com",
            
            # Other trackers
            "omtrdc.net",
            "demdex.net",
            "everesttech.net",
            "2o7.net",
            "imrworldwide.com",
            "moatads.com",
            "doubleverify.com",
            "ias.com",
        ]
        
        self._blocked_domains = set(ad_domains)
        
        # URL patterns to block (regex)
        patterns = [
            r'/ads/',
            r'/ad/',
            r'/adv/',
            r'/advertisement/',
            r'/banner/',
            r'/banners/',
            r'/sponsor/',
            r'/tracking/',
            r'/tracker/',
            r'/pixel/',
            r'/analytics\.js',
            r'/gtag/',
            r'/gtm\.js',
            r'\.gif\?.*(?:track|click|imp)',
            r'[?&]ad[_-]?id=',
            r'[?&]campaign[_-]?id=',
            r'[?&]click[_-]?id=',
            r'/doubleclick/',
            r'/pagead/',
            r'/adserver/',
            r'/adserv/',
            r'popup',
            r'popunder',
        ]
        
        self._blocked_patterns = [re.compile(p, re.IGNORECASE) for p in patterns]
    
    def interceptRequest(self, info: QWebEngineUrlRequestInfo):
        """Intercept and potentially block a URL request."""
        if not self._enabled:
            return
        
        url = info.requestUrl()
        host = url.host().lower()
        
        # Fast path: Check domain cache first
        if host in self._domain_cache:
            if self._domain_cache[host]:
                info.block(True)
                self._blocked_count += 1
            return
        
        # Check whitelist first (quick rejection)
        for domain in self._whitelist:
            if domain in host:
                self._domain_cache[host] = False
                return
        
        # Efficient domain check using suffix matching
        should_block = False
        
        # Split host into parts for suffix checking
        # e.g., "ads.doubleclick.net" -> check "doubleclick.net", then "net"
        parts = host.split('.')
        for i in range(len(parts)):
            suffix = '.'.join(parts[i:])
            if suffix in self._blocked_domains:
                should_block = True
                break
        
        # Check URL patterns only if not already blocked (lazy evaluation)
        if not should_block:
            url_string = url.toString().lower()
            for pattern in self._blocked_patterns:
                if pattern.search(url_string):
                    should_block = True
                    break
        
        # Block third-party tracking pixels (only for images, cheap check)
        if not should_block:
            resource_type = info.resourceType()
            if resource_type == QWebEngineUrlRequestInfo.ResourceTypeImage:
                url_string = url.toString().lower() if 'url_string' not in dir() else url_string
                if any(x in url_string for x in ('track', 'pixel', 'beacon', '1x1')):
                    should_block = True
        
        # Cache the result for this host
        self._domain_cache[host] = should_block
        
        if should_block:
            info.block(True)
            self._blocked_count += 1
    
    @property
    def enabled(self) -> bool:
        return self._enabled
    
    @enabled.setter
    def enabled(self, value: bool):
        self._enabled = value
    
    @property
    def blocked_count(self) -> int:
        return self._blocked_count
    
    def reset_count(self):
        self._blocked_count = 0
    
    def add_to_whitelist(self, domain: str):
        """Add a domain to the whitelist."""
        self._whitelist.add(domain.lower())
    
    def remove_from_whitelist(self, domain: str):
        """Remove a domain from the whitelist."""
        self._whitelist.discard(domain.lower())
    
    def add_blocked_domain(self, domain: str):
        """Add a custom domain to block."""
        self._blocked_domains.add(domain.lower())
    
    def remove_blocked_domain(self, domain: str):
        """Remove a domain from the blocklist."""
        self._blocked_domains.discard(domain.lower())


class AdBlockerProvider(QObject):
    """QML-accessible provider for the ad blocker."""
    
    enabledChanged = Signal()
    blockedCountChanged = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self._ad_blocker = AdBlocker(self)
        self._profile = None
    
    def get_interceptor(self) -> AdBlocker:
        """Get the underlying interceptor."""
        return self._ad_blocker
    
    def install_on_profile(self, profile: QWebEngineProfile):
        """Install the ad blocker on a WebEngine profile."""
        self._profile = profile
        profile.setUrlRequestInterceptor(self._ad_blocker)
        print("🛡️ AdBlocker installed on WebEngine profile")
    
    @Property(bool, notify=enabledChanged)
    def enabled(self) -> bool:
        return self._ad_blocker.enabled
    
    @enabled.setter
    def enabled(self, value: bool):
        if self._ad_blocker.enabled != value:
            self._ad_blocker.enabled = value
            self.enabledChanged.emit()
            print(f"🛡️ AdBlocker {'enabled' if value else 'disabled'}")
    
    @Slot(bool)
    def setEnabled(self, value: bool):
        self.enabled = value
    
    @Slot(result=bool)
    def isEnabled(self) -> bool:
        return self._ad_blocker.enabled
    
    @Property(int, notify=blockedCountChanged)
    def blockedCount(self) -> int:
        return self._ad_blocker.blocked_count
    
    @Slot(result=int)
    def getBlockedCount(self) -> int:
        return self._ad_blocker.blocked_count
    
    @Slot()
    def resetCount(self):
        self._ad_blocker.reset_count()
        self.blockedCountChanged.emit()
    
    @Slot(str)
    def addToWhitelist(self, domain: str):
        self._ad_blocker.add_to_whitelist(domain)
        print(f"✅ Whitelisted: {domain}")
    
    @Slot(str)
    def removeFromWhitelist(self, domain: str):
        self._ad_blocker.remove_from_whitelist(domain)
        print(f"❌ Removed from whitelist: {domain}")
    
    @Slot(str)
    def addBlockedDomain(self, domain: str):
        self._ad_blocker.add_blocked_domain(domain)
        print(f"🚫 Added to blocklist: {domain}")
    
    @Slot(str)
    def removeBlockedDomain(self, domain: str):
        self._ad_blocker.remove_blocked_domain(domain)
        print(f"✅ Removed from blocklist: {domain}")
