# JumperKids — PUBLIC server123 deployment repository

**Deliberate architecture:** `suaveforge/jumperkids` is PRIVATE source; `suaveforge/jumperkids-deploy` is PUBLIC deployment scripts and a deliberately public **standalone 2.5D preview artifact only**.

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
3. Release **real 3D** only after a dedicated HYTOPIA engine/server build, actual browser rendering, verified identity/parental consent and persistence, device testing and child-safety review.
4. Rollback: a pre-deploy HTML backup is retained under the isolated project's server-side backups directory. The Caddy script restores its prior config on validation/reload failure.
5. For later feature previews update the PRIVATE source demo and the PUBLIC `index.html` artifact to byte-identical content before dispatching the PRIVATE deploy workflow. This deliberate parity gate prevents accidentally publishing private source.

**Legacy GitHub Pages workflow has been deleted.** This project uses the same Spaceship/Caddy/server123 delivery pipeline as Jumper.

## HYTOPIA 3D technical preview — NO LOGIN

- **Open technical preview:** https://jumperkids3d.suaveforge.com — no username, password or BasicAuth. The old credential file and BasicAuth deployment workflow were deleted. [Verified open HTTPS deployment](https://github.com/suaveforge/jumperkids/actions/runs/44240220215).
- **World API + WebSocket:** `api-jumperkids3d.suaveforge.com`, separate from the HTML frontend as in the original Jumper system. API status JSON, .ktx2 and .glb assets, TLS and the single CORS origin passed [API deployment validation](https://github.com/suaveforge/jumperkids/actions/runs/44241235055).
- The actual Chromium test verifies the WebGL canvas, kids HUD, WSS packets and 200 responses for atlas/model files. **It still fails at the KTX2 texture loader**, despite successful downloads: [browser log and screenshot](https://github.com/suaveforge/jumperkids/actions/runs/44241443403). The visual quality and mobile usability are **not accepted**.
- This is a no-account, no-PII, no-commerce, no-public-chat **technical sandbox**, not a complete or safe child-facing release; the real guardian-only entrypoint remains fail-closed. The main https://jumperkids.suaveforge.com continues serving the existing 2.5D preview.
- Live deployment scripts are `scripts/configure-open-3d-caddy-server123.sh`, `scripts/configure-native-api-dns-server123.sh` and `scripts/configure-native-api-caddy-server123.sh`. **Do not restore the deleted BasicAuth script**. This PUBLIC repo contains no credentials or private app source.

