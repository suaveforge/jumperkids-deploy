#!/bin/sh
set -eu
# Publish the already-tested standalone *visual preview* to the existing 3D
# hostname ONLY. No login, no child identity, no PII/payment/chat.
# No modification to public 2.5D, adult JUMPER, or native game API/WSS.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
HOMEFILE=/home/jumperkids-visual-candidate/web/index.html
MAIN=/home/gyeol/Caddyfile
CADDY=/home/gyeol/runtime/caddy/caddy
SITE=/home/jumperkids-native-dev/Caddyfile.staff3d
test -s "$HOMEFILE"
test -s "$MAIN"
test -s "$SITE"
test -x "$CADDY"
test "$(curl -fsS --max-time 12 -o /tmp/jk-visual-preflight -w '%{http_code}' http://127.0.0.1:18845/)" = 200
grep -q '꿈꾸는 마을' /tmp/jk-visual-preflight
test "$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' http://127.0.0.1:18845/main.js)" = 200
test "$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' http://127.0.0.1:18845/style.css)" = 200
"$D" -H "$S" run --rm -i --network host \
  --cap-drop ALL --security-opt no-new-privileges \
  -v /home:/home:rw python:3.11-alpine python - <<'PY'
from pathlib import Path
import fcntl,os,shutil,subprocess
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
site=Path('/home/jumperkids-native-dev/Caddyfile.staff3d')
lock=Path('/home/jumper/deploy/.caddy.lock')
backup=Path('/home/jumperkids-native-dev/Caddyfile.staff3d.rollback-visual')
line='import /home/jumperkids-native-dev/Caddyfile.staff3d'
site_text='''# JUMPER KIDS 3D visual TECHNICAL PREVIEW. No child login/data/payment.
# Dedicated Three.js frontend 18845. Native HYTOPIA API remains separate.
jumperkids3d.suaveforge.com {
    encode gzip zstd
    reverse_proxy 127.0.0.1:18845
    header {
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        Cache-Control "no-store"
        X-Robots-Tag "noindex, nofollow"
        Cross-Origin-Resource-Policy "same-origin"
    }
}
'''
fd=os.open(lock,os.O_CREAT|os.O_RDWR,0o600)
fcntl.flock(fd,fcntl.LOCK_EX)
try:
    old=site.read_bytes()
    current=main.read_bytes()
    if b'jumperkids3d.suaveforge.com {' not in old:
        raise RuntimeError('JK_VISUAL_REFUSE_OVERWRITE_UNRELATED_SITE')
    count=sum(1 for r in current.decode(errors='replace').splitlines() if r.strip()==line)
    if count!=1:
        raise RuntimeError('JK_VISUAL_CADDY_IMPORT_MUST_BE_EXACTLY_ONE')
    if not backup.exists():
        backup.write_bytes(old)
        os.chmod(backup,0o600)
    candidate=site.with_suffix('.visual-candidate')
    candidate.write_text(site_text)
    os.replace(candidate,site)
    check=subprocess.run([str(caddy),'adapt','--config',str(main),'--adapter','caddyfile'],
        stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=40)
    if check.returncode:
        site.write_bytes(old)
        raise RuntimeError('JK_VISUAL_CADDY_VALIDATE_FAILED: '+check.stderr.decode(errors='replace')[-450:])
    cmd=[str(caddy),'reload','--config',str(main),'--adapter','caddyfile']
    result=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=50)
    if result.returncode:
        site.write_bytes(old)
        subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=35)
        raise RuntimeError('JK_VISUAL_CADDY_RELOAD_FAILED_ROLLED_BACK')
    # Validate actual public TLS+HTTP from inside the host Caddy network.
    host='jumperkids3d.suaveforge.com'
    # Alpine python image has no curl. Request local Caddy over verified TLS
    # with the correct SNI and Host header, without weakening verification.
    import ssl,socket
    try:
        ctx=ssl.create_default_context()
        with socket.create_connection(('127.0.0.1',443),timeout=12) as raw:
            with ctx.wrap_socket(raw,server_hostname=host) as conn:
                conn.sendall(('GET / HTTP/1.1\\r\\nHost: '+host+'\\r\\nConnection: close\\r\\n\\r\\n').encode())
                chunks=[]
                while True:
                    part=conn.recv(32768)
                    if not part:break
                    chunks.append(part)
                response=b''.join(chunks)
    except Exception as exc:
        response=b''
        print('JK_VISUAL_HTTPS_VERIFY_ERROR='+type(exc).__name__)
    if not response.startswith(b'HTTP/1.1 200') or b'<canvas id="game"' not in response or b'<title>' not in response:
        site.write_bytes(old)
        subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=35)
        raise RuntimeError('JK_VISUAL_HTTPS_SMOKE_FAILED_ROLLED_BACK')
    print('JK_VISUAL_PUBLIC_3D_CADDY_SWITCH=PASS')
    print('JK_VISUAL_CADDY_ROLLBACK_SNAPSHOT=STORED_PRIVATE')
    print('JK_VISUAL_ORIGINAL_ADULT_AND_KIDS_2D=CONFIG_UNCHANGED')
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
PY
host=jumperkids3d.suaveforge.com
test "$(curl -sS --max-time 14 -o /tmp/jk-visual-home -w '%{http_code}' "https://$host/")" = 200
grep -q '꿈꾸는 마을' /tmp/jk-visual-home
test "$(curl -sS --max-time 14 -o /dev/null -w '%{http_code}' "https://$host/main.js")" = 200
test "$(curl -sS --max-time 14 -o /dev/null -w '%{http_code}' "https://$host/style.css")" = 200
test "$(curl -ksS --max-time 12 -o /dev/null -w '%{http_code}' https://127.0.0.1:18773/)" = 200
test "$(curl -sS --max-time 12 -o /dev/null -w '%{http_code}' http://127.0.0.1:18836/)" = 200
test "$(curl -ksS --max-time 12 -o /dev/null -w '%{http_code}' https://127.0.0.1:18837/)" = 200
echo JK_VISUAL_PUBLIC_GAME_HTML_JS_CSS_HTTPS=200
echo JK_VISUAL_OLD_JUMPER_KIDS_2D_NATIVE_API=UNAFFECTED
