# Account Icons

SVG icons served via the `/api/account-icons/` endpoint. The Flutter app fetches and caches these on sync.

## How it works

`core/account_icons.py` defines `ICON_MAPPINGS` (key + keywords). At startup, Django reads SVGs from this directory, combines them with mappings, and computes an MD5 version hash. The app sends `?v=<cached_hash>` — if unchanged, the server returns `{"changed": false}` (zero transfer).

Icons are rendered at 20x20 inside a CircleAvatar, tinted monochrome via `ColorFilter.mode(iconColor, BlendMode.srcIn)`.

## Icon sources

| File | Brand | Source |
|------|-------|--------|
| ibkr.svg | Interactive Brokers | [companieslogo.com](https://companieslogo.com/interactive-brokers/logo/) |
| moomoo.svg | Futu/Moomoo | [Futu CDN](https://cdn.futustatic.com/upload/403/logo-4698994ea47283fc21c85a87bb12c8d0.svg) |
| dbs.svg | DBS Bank | [companieslogo.com](https://companieslogo.com/dbs/logo/) |
| uob.svg | UOB Bank | [companieslogo.com](https://companieslogo.com/uob/logo/) |
| icbc.svg | ICBC | [companieslogo.com](https://companieslogo.com/icbc/logo/) |
| boc.svg | Bank of China | [companieslogo.com](https://companieslogo.com/bank-of-china/logo/) |
| cmb.svg | China Merchants Bank | [Wikipedia](https://en.wikipedia.org/wiki/File:China_Merchants_Bank_logo.svg) |
| okx.svg | OKX | [Simple Icons](https://simpleicons.org/?q=okx) |
| crypto.svg | Bitcoin/Crypto | [Simple Icons](https://simpleicons.org/?q=bitcoin) |
| cash.svg | Cash | [Lucide Icons](https://lucide.dev/icons/banknote) |
| bond.svg | Bond/Treasury | [Lucide Icons](https://lucide.dev/icons/file-badge) |
| lend.svg | Lend/Receivable | [Lucide Icons](https://lucide.dev/icons/hand-coins) |
| house.svg | House/Rent | [Lucide Icons](https://lucide.dev/icons/house) |
| weixin.svg | WeChat/Weixin | [Simple Icons](https://simpleicons.org/?q=wechat) |
| alipay.svg | Alipay | [Simple Icons](https://simpleicons.org/?q=alipay) |
| tax.svg | Tax/CPF | [Lucide Icons](https://lucide.dev/icons/landmark) |
| debt.svg | Debt/Loan | [Lucide Icons](https://lucide.dev/icons/circle-dollar-sign) |

## Adding a new icon

1. Add SVG file to this directory (e.g., `newbrand.svg`)
2. Add mapping in `core/account_icons.py`
3. Deploy Django — version hash auto-updates, app picks up new icon on next sync
