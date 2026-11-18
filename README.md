# JumperKids — Public Preview Deployment

This PUBLIC repository contains only a safe, standalone playflow preview. The authoritative game source, guardian identity and all unshipped game content stay in the PRIVATE `suaveforge/jumperkids` repository.

## Current preview

- `index.html`: zero-tracking, no-login, no-backend, standalone child-friendly playflow demo (egg, three strawberries, bunny bakery, home and factual local-only parent preview).
- The current preview is a **2.5D storyboard**, **not** the HYTOPIA 3D production game.
- No accounts, payments, child personal data, remote APIs, cookies, location tracking, analytics or live game services.

## Planned deployment rule

Public repo may contain only non-sensitive **rendered deploy artifacts**, public Pages workflow and documentation. Never commit API tokens, actual `.env`, auth secrets, DB credentials, private code, children's data or internal server address.

Open the static preview from GitHub Pages once enabled via Settings > Pages > Build and deployment > Source = GitHub Actions.
