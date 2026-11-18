#!/bin/sh
set -eu
# Access-controlled STAFF-ONLY 3D HYTOPIA preview.
# NO auth bypass for the separate real child-facing product.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -s /home/jumperkids-native-dev/client-dist/index.html
test -s /home/gyeol/Caddyfile
test -x /home/gyeol/runtime/caddy/caddy
test "$(curl -ksS --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1:18837/)" = 200
test "$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' http://127.0.0.1:18838/)" = 200
"$D" -H "$S" run --rm -i --network host \
 --cap-drop ALL --security-opt no-new-privileges \
 -v /home:/home:rw \
 python:3.11-alpine python - <<'PY'
from pathlib import Path
import os,fcntl,shutil,subprocess,secrets
root=Path('/home/jumperkids-native-dev')
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
snippet=root/'Caddyfile.staff3d'
line='import /home/jumperkids-native-dev/Caddyfile.staff3d'
lock=Path('/home/jumper/deploy/.caddy.lock')
password_path=root/'staff-preview-password.txt'
if not all(p.is_file() for p in [main,caddy,root/'client-dist/index.html']):
    raise RuntimeError('JK3D_REQUIRED_FILES_MISSING')
# Generate and retain strong staff-only HTTP Basic password server-side.
if not password_path.exists():
    password_path.write_text(secrets.token_urlsafe(25))
    os.chmod(password_path,0o600)
password=password_path.read_text().strip()
if len(password)<25:raise RuntimeError('JK3D_PASSWORD_WEAK')
hashed=subprocess.run([str(caddy),'hash-password','--plaintext',password],
    stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
if hashed.returncode:
    raise RuntimeError('JK3D_PASSWORD_HASH_FAILED')
pw_hash=hashed.stdout.decode().strip()
if not pw_hash or '\n' in pw_hash:raise RuntimeError('JK3D_INVALID_PASSWORD_HASH')
site='''# STAFF ONLY: separate HYTOPIA backend and sanitized client.
# All routes require strong server-side BasicAuth, no public guest access.
jumperkids3d.suaveforge.com {
    encode gzip zstd
    basic_auth {
        staff '''+pw_hash+'''
    }
    @client {
        path / /index.html /assets/* /jk-client.js /jk-client.css
    }
    handle @client {
        reverse_proxy 127.0.0.1:18838
    }
    handle {
        reverse_proxy https://127.0.0.1:18837 {
            transport http {
                tls_insecure_skip_verify
            }
        }
    }
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
    old=main.read_bytes()
    prior=snippet.read_text() if snippet.exists() else None
    if old.count(line.encode())>1:raise RuntimeError('JK3D_CADDY_IMPORT_DUPLICATE')
    candidate=old if line.encode() in old else old.rstrip()+b'\n\n'+line.encode()+b'\n'
    # Reuse hash only when password unchanged; hash itself gets a new salt.
    snippet.write_text(site)
    temp=main.parent/'.Caddyfile.jumperkids3d.candidate'
    temp.write_bytes(candidate)
    shutil.copymode(main,temp)
    valid=subprocess.run([str(caddy),'adapt','--config',str(temp),'--adapter','caddyfile'],
        stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=40)
    if valid.returncode:
        temp.unlink(missing_ok=True)
        if prior is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior)
        raise RuntimeError('JK3D_CADDY_VALIDATION_FAILED:'+valid.stderr.decode(errors='replace')[-600:])
    if old!=candidate:os.replace(temp,main)
    else:temp.unlink(missing_ok=True)
    cmd=[str(caddy),'reload','--config',str(main),'--adapter','caddyfile']
    reload=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
    if reload.returncode:
        if old!=candidate:
            backup=main.parent/'.Caddyfile.jumperkids3d.rollback'
            backup.write_bytes(old)
            shutil.copymode(main,backup)
            os.replace(backup,main)
        if prior is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior)
        subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
        raise RuntimeError('JK3D_CADDY_RELOAD_FAILED_ROLLED_BACK')
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
index=root/'client-dist/index.html'
html=index.read_text()
old_expr="u.searchParams.set('join',location.hostname+':18837');"
new_expr="u.searchParams.set('join',location.hostname==='jumperkids3d.suaveforge.com'?location.hostname:location.hostname+':18837');"
if old_expr in html:
    html=html.replace(old_expr,new_expr)
    index.write_text(html)
if new_expr not in index.read_text():
    raise RuntimeError('JK3D_JOIN_ENDPOINT_NOT_PATCHED')
print('JK3D_GUARDED_CADDY=RELOADED')
print('JK3D_CLIENT_PUBLIC_JOIN=OWN_AUTHENTICATED_HOST')
print('JK3D_ORIGINAL_JUMPER_CADDY_SITE=UNMODIFIED')
# Never emit staff credentials into workflow logs; provide staff access through secure server-side credential provisioning.
print('JK3D_STAFF_USERNAME=staff')
print('JK3D_STAFF_PASSWORD=NOT_LOGGED_ROTATION_REQUIRED_FOR_PREVIOUS_EXPOSURE')
PY
