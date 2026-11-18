# JumperKids — Public Preview Deployment

This PUBLIC repository contains only a safe, standalone playflow preview. The authoritative game source, guardian identity and all unshipped game content stay in the PRIVATE `suaveforge/jumperkids` repository.

## Current preview

- `index.html`: zero-tracking, no-login, no-backend, standalone child-friendly playflow demo (egg, three strawberries, bunny bakery, home and factual local-only parent preview).
- The current preview is a **2.5D storyboard**, **not** the HYTOPIA 3D production game.
- No accounts, payments, child personal data, remote APIs, cookies, location tracking, analytics or live game services.

## Planned deployment rule

Public repo may contain only non-sensitive **rendered deploy artifacts**, public Pages workflow and documentation. Never commit API tokens, actual `.env`, auth secrets, DB credentials, private code, children's data or internal server address.

Open the static preview from GitHub Pages once enabled via Settings > Pages > Build and deployment > Source = GitHub Actions.

## Play now / hosting status (2026-11-18)

- **HTML preview (third-party, not verified on a physical browser):** [Open playable preview](https://htmlpreview.github.io/?https://github.com/suaveforge/jumperkids-deploy/blob/main/index.html). The static HTML/JS is byte-identical to the private repository's tested `demo/index.html` (Git blob `165ab7918d7a6756f18413f99dcc3f228a4267fa`).
- **GitHub Pages deployment workflow configured:** `.github/workflows/pages.yml` (run [44227807565](https://github.com/suaveforge/jumperkids-deploy/actions/runs/44227807565)). It currently fails at `Configure Pages` with a 404 because this new repository does not yet have Pages enabled. It is not a game-script failure.
- **One-time setup for canonical Pages URL:** Repository `Settings > Pages > Build and deployment > Source` → `GitHub Actions`, then re-run `Publish JumperKids standalone preview` from Actions. Do not put secrets or private source in this public repo.
- **Important distinction:** This is only an interaction prototype. Real HYTOPIA 3D engine, authoritative state, guardian authentication, private DB and full child-facing deployment remain unbuilt/unverified.
