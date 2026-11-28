# JumperKids — PUBLIC server123 deployment repository

## Current ingress (2026-11-28)

All three existing JumperKids HTTPS hostnames use Nginx on standard port 443. No DNS change or port suffix is needed. The former Caddy routes were removed and the legacy deployment entrypoints no longer edit the gateway. The historical deployment notes below describe earlier architecture, not current operational instructions. Use `scripts/verify-nginx-server123.sh main|visual|api` after application deployment.

**Deliberate architecture:** `suaveforge/jumperkids` is PRIVATE source; `suaveforge/jumperkids-deploy` is PUBLIC deployment scripts plus a deliberately public **standalone 2.5D preview artifact**. The playable 3D art-preview source is in the PRIVATE repository and its reviewed browser bundle is deployed from server123.

## Live preview deployment

- Intended hostname: **https://jumperkids.suaveforge.com**
- Hosting stack: **server123 + isolated Docker + existing shared Caddy HTTPS + Spaceship DNS**, same hosting method as the original Jumper but in a separate container, project directory, port and Caddy site block.
- First complete workflow: [JumperKids preview deployment](https://github.com/suaveforge/jumperkids/actions/runs/44231669989) — **SUCCESS**.
- Server-side verified: static container HTTP 200, Spaceship DNS API record write HTTP 204 and readback verified, shared Caddy reloaded, HTTPS 200 for `jumperkids.suaveforge.com` using local domain resolution.
- **Important:** Public DNS propagation / independent browser rendering / browser-trusted TLS status may not yet have been confirmed outside the server. HTTPS link can fail until DNS propagates.
- This is **NOT** a running HYTOPIA 3D game. It is the interaction walkthrough: egg → three strawberries → bakery → home → a local observation report. No personal data, guardian identities, payments, analytics, remote APIs, cookies or database.

## Deployment files

- `index.html`: published public-only static HTML/JS preview; SHA256 expected `18ca1b55eadd570cea0fa18c39d61180314e6fc5d8b808c7112e26e434046d55`.
- `scripts/deploy-static-preview-server123.sh`: safe update and local Docker HTTP check in `/home/jumperkids-preview` only.
- `scripts/configure-spaceship-dns-server123.sh`: uses **pre-existing server-side** Spaceship secret file, adds only the `jumperkids` A record, refuses to overwrite conflict, verifies DNS API response.
- `scripts/configure-caddy-server123.sh`: adds an independent `jumperkids.suaveforge.com` site to the server's Caddy, validates and rolls back on failure; original Jumper site config is not modified.
- Workflow lives in **PRIVATE** `suaveforge/jumperkids/.github/workflows/deploy-preview-server123.yml` using the same private organization self-hosted runner that original Jumper uses. This PUBLIC repository intentionally has **no server credentials** and does not run public self-hosted Actions.

## Security and release boundaries

1. **Never** commit tokens, keys, passwords, private source, `.env` values, child data, Guardian identity information, or internal host details to this public repo. Only reviewed static artifacts / public deploy scripts.
2. Source and runtime are independent of original `suaveforge/jumper`; do not replace the original Jumper container, Caddy site, keys or databases.
3. The new 3D central-plaza **preview** is publicly viewable, but **child-facing production MMO** needs verified guardian identity/consent, persistent backend state, server-authoritative movement, device performance, accessibility and child-safety review.
4. Rollback: a pre-deploy HTML backup is retained under the isolated project's server-side backups directory. The Caddy script restores its prior config on validation/reload failure.
5. For later feature previews update the PRIVATE source demo and the PUBLIC `index.html` artifact to byte-identical content before dispatching the PRIVATE deploy workflow. This deliberate parity gate prevents accidentally publishing private source.

**Legacy GitHub Pages workflow has been deleted.** This project uses the same Spaceship/Caddy/server123 delivery pipeline as Jumper.

## Current JumperKids 3D technical play preview — NO LOGIN

**Live:** https://jumperkids3d.suaveforge.com — active Three.js art-first 3D dream-village build on server123, promoted using **`scripts/deploy-visual-3d-caddy-server123.sh`**. Source is PRIVATE `suaveforge/jumperkids/visual/`, built by `.github/workflows/build-visual-candidate.yml` on loopback `127.0.0.1:18845` and promoted by `.github/workflows/deploy-visual-3d-public.yml`. HTTPS, client JS/CSS and adult Jumper isolation verified in [successful deployment run 44265103784](https://github.com/suaveforge/jumperkids/actions/runs/44265103784). Rollback Caddy site snapshot is saved privately on server123.

**Real user-facing mechanics in this technical preview:** move a rounded chibi avatar by WASD/arrows or mobile touch joystick, reach and interact with a 3D flower egg, watch the rounded mint dragon hatch and physically follow, pick three separate 3D strawberry bushes, visit the bunny bakery and finish at the cottage. Actions are currently LOCAL to the browser, not authoritative multi-user play. No username, password, parent or child account, PII, payment or chat. Do not claim educational MMO, persistent state or child-safety completion.

**Back-end:** `api-jumperkids3d.suaveforge.com` is a separate legacy HYTOPIA 3D technical server and is *not yet connected* to the new Three.js play preview. The adult Jumper and earlier `jumperkids.suaveforge.com` 2.5D preview are independent and unchanged.

**Current approved verification command:** `bash scripts/verify-nginx-server123.sh visual`, run after the private build and browser QA. The older `scripts/promote-artstudio-server123.sh` and `scripts/configure-open-3d-caddy-server123.sh` are obsolete and MUST NOT be run; their corresponding deployment workflows have been removed to prevent rollback to rejected demo scenes. This PUBLIC repository must not receive private source code, credentials, child data, or secret tokens.

**Verification and known limits:** [real public desktop and mobile full five-stage journey run 44267742649](https://github.com/suaveforge/jumperkids/actions/runs/44267742649) **SUCCESS**: actual joystick/keyboard play, egg hatching, 3 unique berries, real 3D bakery cake, 3D house decoration and ending all passed. Screenshots artifact ID `14410742736`. This is mobile Chromium emulation, not real phone hardware. Guardian consent, durable sessions, parent observations, real MMO packet sync and proper educational content are incomplete. This is a zero-login technical preview, not a completed children-facing product.

