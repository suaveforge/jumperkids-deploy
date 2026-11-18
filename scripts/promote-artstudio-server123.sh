#!/bin/sh
set -eu
# Promote visually-accepted, no-account kids 3D ART PREVIEW only.
# A human must inspect real desktop/mobile before invoking this script.
# Original Jumper, its Caddy snippet and the separate HYTOPIA API host are untouched.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
ROOT=/home/jumperkids-artstudio
test -s "$ROOT/dist/index.html"
test -s "$ROOT/dist/game.js"
test -s "$ROOT/dist/assets/pink-bunny.glb"
test -s /home/jumperkids-native-dev/Caddyfile.staff3d
test -s /home/gyeol/Caddyfile
test -x /home/gyeol/runtime/caddy/caddy
test "$(curl -sS --max-time 9 -o /dev/null -w '%{http_code}' http://127.0.0.1:18846/)" = 200
"$D" -H "$S" run --rm -i --network host \
  --cap-drop ALL --security-opt no-new-privileges \
  -v /home:/home:rw python:3.11-alpine python - <<'PY'
from pathlib import Path
import os,fcntl,subprocess,urllib.request,time
root=Path('/home/jumperkids-artstudio')
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
snippet=Path('/home/jumperkids-native-dev/Caddyfile.staff3d')
lock=Path('/home/jumper/deploy/.caddy.lock')
line='import /home/jumperkids-native-dev/Caddyfile.staff3d'
bak=root/'backups'
bak.mkdir(parents=True,exist_ok=True)
new='''# JUMPERKIDS art-first egg hatch / dragon follow TECHNICAL PREVIEW
# No login; no child data, accounts, chat, payments or persistence.
# Separate real HYTOPIA API remains at api-jumperkids3d.suaveforge.com.
jumperkids3d.suaveforge.com {
    encode gzip zstd
    reverse_proxy 127.0.0.1:18846
    header {
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        Cache-Control "no-store"
        X-Robots-Tag "noindex, nofollow"
    }
}
'''
fd=os.open(lock,os.O_CREAT|os.O_RDWR,0o600)
fcntl.flock(fd,fcntl.LOCK_EX)
try:
    old_main=main.read_text()
    old_site=snippet.read_text()
    if sum(1 for row in old_main.splitlines() if row.strip()==line)!=1:
        raise RuntimeError('JK_ART_PRODUCTION_CADDY_IMPORT_UNEXPECTED')
    if 'jumperkids3d.suaveforge.com {' not in old_site or 'basic_auth' in old_site:
        raise RuntimeError('JK_ART_REFUSE_UNKNOWN_OR_AUTH_SITE')
    b=bak/'Caddyfile.staff3d.before-art-studio'
    if not b.exists():
        b.write_text(old_site)
        os.chmod(b,0o600)
    snippet.write_text(new)
    def rollback(message):
        snippet.write_text(old_site)
        subprocess.run([str(caddy),'reload','--config',str(main),'--adapter','caddyfile'],
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=35)
        raise RuntimeError(message)
    c=subprocess.run([str(caddy),'adapt','--config',str(main),'--adapter','caddyfile'],
                     stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=45)
    if c.returncode:rollback('JK_ART_CADDY_ADAPT_FAIL '+c.stderr.decode(errors='replace')[-450:])
    c=subprocess.run([str(caddy),'reload','--config',str(main),'--adapter','caddyfile'],
                     stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=55)
    if c.returncode:rollback('JK_ART_CADDY_RELOAD_FAIL')
    time.sleep(1)
    try:
        with urllib.request.urlopen('https://jumperkids3d.suaveforge.com/',timeout=20) as f:
            body=f.read(16384)
            if f.status!=200 or '<title>꿈꾸는 마을 · 마법의 알</title>'.encode() not in body:
                raise RuntimeError('JK_ART_PUBLIC_HTML_MISMATCH')
        with urllib.request.urlopen('https://jumperkids3d.suaveforge.com/game.js',timeout=15) as f:
            if f.status!=200 or len(f.read(1024))<500:raise RuntimeError('JK_ART_JS_INVALID')
        with urllib.request.urlopen('https://jumperkids3d.suaveforge.com/assets/pink-bunny.glb',timeout=15) as f:
            if f.status!=200 or f.read(4)!=b'glTF':raise RuntimeError('JK_ART_GLB_INVALID')
    except Exception as e:
        rollback('JK_ART_PUBLIC_SMOKE_FAILED '+str(e)[:200])
    print('JK_ART_3D_PUBLIC_HTTPS=200')
    print('JK_ART_3D_STATIC_ASSETS=PASS')
    print('JK_ART_ORIGINAL_JUMPER_SNIPPET=UNTOUCHED')
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
PY
test "$(curl -ksS --max-time 12 -o /dev/null -w '%{http_code}' https://127.0.0.1:18773/)" = 200
test "$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' http://127.0.0.1:18836/)" = 200
test "$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' https://jumperkids3d.suaveforge.com/)" = 200
echo JK_ART_3D_PUBLIC_PREVIEW_PROMOTION_SUCCESS
