# Account Icons

SVG icons displayed in the Assets screen for each account.

## How it works

`AccountIconUtils.logoAssetPath()` matches account names by keyword to return the SVG asset path. The icon is rendered by `flutter_svg` inside a `CircleAvatar` at 20x20, tinted to match the theme via `ColorFilter.mode(iconColor, BlendMode.srcIn)`.

Unknown accounts fall back to showing the currency code as text.

## Icon sources

| File | Brand | Source |
|------|-------|--------|
| ibkr.svg | Interactive Brokers | [companieslogo.com](https://companieslogo.com/interactive-brokers/logo/) |
| moomoo.svg | Futu/Moomoo | [Futu CDN](https://cdn.futustatic.com/upload/403/logo-4698994ea47283fc21c85a87bb12c8d0.svg) (icon paths extracted) |
| dbs.svg | DBS Bank | [companieslogo.com](https://companieslogo.com/dbs/logo/) |
| uob.svg | UOB Bank | [companieslogo.com](https://companieslogo.com/uob/logo/) |
| icbc.svg | ICBC | [companieslogo.com](https://companieslogo.com/icbc/logo/) |
| boc.svg | Bank of China | [companieslogo.com](https://companieslogo.com/bank-of-china/logo/) |
| cmb.svg | China Merchants Bank | [Wikipedia](https://en.wikipedia.org/wiki/File:China_Merchants_Bank_logo.svg) (icon mark extracted) |
| okx.svg | OKX | [Simple Icons](https://simpleicons.org/?q=okx) |
| crypto.svg | Bitcoin/Crypto | [Simple Icons](https://simpleicons.org/?q=bitcoin) |
| cash.svg | Cash | [Lucide Icons](https://lucide.dev/icons/banknote) |
| bond.svg | Bond/Treasury | [Lucide Icons](https://lucide.dev/icons/file-badge) |

## Adding a new icon

1. Find or create an SVG icon. Preferred sources:
   - **Brand logos**: [companieslogo.com](https://companieslogo.com) (icon/symbol variant, not full logo)
   - **Generic concepts**: [Lucide Icons](https://lucide.dev) (24x24, monoline stroke style)
   - **Tech brands**: [Simple Icons](https://simpleicons.org) (24x24, single path)

2. Save the SVG to this directory (e.g., `newbrand.svg`).

3. Add a mapping in `lib/utils/account_icon_utils.dart`:
   ```dart
   (key: 'newbrand', keywords: ['newbrand', 'alternate name']),
   ```

4. Update this README table with the new icon source.

## Style notes

- All icons are rendered monochrome via `ColorFilter.mode(iconColor, BlendMode.srcIn)`, so original colors in the SVG don't matter at runtime.
- Icons display at 20x20 inside a 40x40 CircleAvatar.
- Both simple stroke-based icons (Lucide) and filled brand logos (companieslogo) work fine at this size.
