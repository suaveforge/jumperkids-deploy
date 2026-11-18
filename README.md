# JumperKids — PUBLIC server123 deployment repository

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

## Current 3D art-preview deployed on Spaceship — NO LOGIN

**https://jumperkids3d.suaveforge.com** now hosts the NEW art-first, custom-built **Three.js 3D egg-hatching and mint baby-dragon following preview**, not the rejected old HYTOPIA voxel test world.

- First core story: pastel toy village central plaza → move or press **알 깨우기** → 3D egg hatches, star particles and short original chime → cute rounded dragon appears and follows the avatar. PC WASD/mouse click, mobile touch joystick and large action button. No account required.
- Source: PRIVATE `suaveforge/jumperkids/studio/`. Built offline on server123 using real model assets and KTX2 decoder, staged in dedicated Docker `sf-jumperkids-artstudio` at loopback `127.0.0.1:18846`.
- Real desktop/mobile Chromium test of egg hatch and companion following [run 44248041085](https://github.com/suaveforge/jumperkids/actions/runs/44248041085) PASS after correcting poor first assets, buried ground mesh and portrait camera clipping. Actual rendered screenshot artifacts attached to that run.
- Current public-site Caddy promotion with backup and rollback via [successful GitHub Actions run 44249439740](https://github.com/suaveforge/jumperkids/actions/runs/44249439740). HTTPS root, JS, CSS, GLB and Basis WASM HTTP 200; original Jumper and independent 2.5D Kids preview unaffected. Exact public deployment script: `scripts/promote-artstudio-server123.sh`.
- Separate `api-jumperkids3d.suaveforge.com` remains the **independent legacy HYTOPIA MMO sandbox API**, online and healthy, but **not yet connected to the new Three.js art-first preview**. Do not claim real multiplayer, secure parental accounts or persistent educational progress.
- The old `scripts/configure-open-3d-caddy-server123.sh` was for the rejected voxel test and must NOT be re-run, because it would revert the new art-first frontend. The current intended site update path is ONLY `scripts/promote-artstudio-server123.sh` after private visual/functional QA.
- This public site is a **zero-login technical play preview** without PII, advertising, payment or chat. It is not the complete child-safe educational MMO. Legal parental consent, verified auth, persistent observations, pet inventory and polished bakery/house/berry interactions remain to be built.

The sibling **https://jumperkids.suaveforge.com** still serves the earlier independent 2.5D walkthrough. Both hostnames use server123/Caddy/Spaceship, not GitHub Pages.
