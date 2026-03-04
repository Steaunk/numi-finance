import hashlib
import json
from pathlib import Path

ICON_MAPPINGS = [
    {"key": "moomoo", "keywords": ["moomoo"]},
    {"key": "ibkr", "keywords": ["ibkr", "interactive brokers"]},
    {"key": "dbs", "keywords": ["\u661f\u5c55", "dbs"]},
    {"key": "uob", "keywords": ["united overseas", "uob"]},
    {"key": "icbc", "keywords": ["icbc", "\u5de5\u5546\u94f6\u884c"]},
    {"key": "boc", "keywords": ["\u4e2d\u56fd\u94f6\u884c", "bank of china", "boc"]},
    {"key": "cmb", "keywords": ["\u62db\u5546\u94f6\u884c", "\u62db\u5546", "cmb"]},
    {"key": "okx", "keywords": ["okx", "okex"]},
    {"key": "bond", "keywords": ["sgs", "bond", "treasury"]},
    {"key": "crypto", "keywords": ["crypto", "bitcoin", "btc", "eth"]},
    {"key": "cash", "keywords": ["cash"]},
    {"key": "lend", "keywords": ["lend", "receivable", "owe", "\u501f\u51fa", "\u5e94\u6536"]},
    {"key": "house", "keywords": ["house", "rent", "mortgage", "\u623f"]},
    {"key": "weixin", "keywords": ["weixin", "wechat", "\u5fae\u4fe1"]},
    {"key": "alipay", "keywords": ["alipay", "\u652f\u4ed8\u5b9d"]},
    {"key": "tax", "keywords": ["tax", "cpf", "\u7a0e"]},
    {"key": "debt", "keywords": ["debt", "loan", "borrow", "\u501f\u5165", "\u8d37\u6b3e", "\u6b20\u6b3e"]},
]

_icons_dir = Path(__file__).parent / "static_icons"
_cache = None  # (version, icons_list)


def load_icons():
    """Read SVG files and combine with mappings. Cached after first call."""
    global _cache
    if _cache is not None:
        return _cache

    icons = []
    for mapping in ICON_MAPPINGS:
        svg_path = _icons_dir / f"{mapping['key']}.svg"
        svg_content = svg_path.read_text() if svg_path.exists() else ""
        icons.append({
            "key": mapping["key"],
            "keywords": mapping["keywords"],
            "svg": svg_content,
        })

    version = hashlib.md5(
        json.dumps(icons, sort_keys=True).encode()
    ).hexdigest()[:8]

    _cache = (version, icons)
    return _cache


def get_version():
    version, _ = load_icons()
    return version


def get_icons():
    _, icons = load_icons()
    return icons
