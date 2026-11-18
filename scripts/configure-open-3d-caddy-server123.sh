#!/bin/sh
set -eu
# Public, NONPRODUCTION HYTOPIA tech preview: NO login, no child accounts,
# no persistent activity, no payment or chat. Existing JUMPER remains untouched.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -s /home/jumperkids-native-dev/client-dist/index.html
test -s /home/gyeol/Caddyfile
test -x /home/gyeol/runtime/caddy/caddy
test "$(curl -ksS --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1:18837/)" = 200
test "$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' http://127.0.0.1:18838/)" = 200
"$D" -H "$S" run --rm -i --network host \
  --cap-drop ALL --security-opt no-new-privileges \
  -v /home:/home:rw python:3.11-alpine python - <<'PY'
from pathlib import Path
import os, fcntl, shutil, subprocess
root=Path('/home/jumperkids-native-dev')
snippet=root/'Caddyfile.staff3d'
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
lock=Path('/home/jumper/deploy/.caddy.lock')
line='import /home/jumperkids-native-dev/Caddyfile.staff3d'
if not all(p.is_file() for p in (main,caddy,snippet,root/'client-dist/index.html')):
    raise RuntimeError('JK3D_REQUIRED_SITE_FILES_MISSING')
site='''# JUMPER KIDS unrestricted technical 3D preview (NOT a child-ready service).
# Independent client and anonymous in-memory 3D world with no PII/payment/chat.
jumperkids3d.suaveforge.com {
    encode gzip zstd
    @client {
        path / /index.html /assets/* /basis/* /images/* /jk-client.js /jk-client.css
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
    previous=main.read_bytes()
    prev_snippet=snippet.read_text()
    # Count exact import lines only: the API import shares this path prefix.
    import_count=sum(1 for row in previous.decode(errors='replace').splitlines() if row.strip()==line)
    if import_count>1:
        raise RuntimeError('JK3D_IMPORT_DUPLICATED_REFUSE_OVERWRITE')
    next_main=previous if import_count==1 else previous.rstrip()+b'\n\n'+line.encode()+b'\n'
    if 'jumperkids3d.suaveforge.com {' not in prev_snippet:
        raise RuntimeError('JK3D_REFUSE_OVERWRITE_UNRELATED_SITE')
    snippet.write_text(site)
    candidate=main.parent/'.Caddyfile.jk3d-open-check'
    candidate.write_bytes(next_main)
    shutil.copymode(main,candidate)
    check=subprocess.run([str(caddy),'adapt','--config',str(candidate),'--adapter','caddyfile'],
                         stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=40)
    if check.returncode:
        candidate.unlink(missing_ok=True)
        snippet.write_text(prev_snippet)
        raise RuntimeError('JK3D_OPEN_CADDY_VALIDATE_FAILED: '+check.stderr.decode(errors='replace')[-600:])
    if next_main!=previous:os.replace(candidate,main)
    else:candidate.unlink(missing_ok=True)
    command=[str(caddy),'reload','--config',str(main),'--adapter','caddyfile']
    reload=subprocess.run(command,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
    if reload.returncode:
        snippet.write_text(prev_snippet)
        if next_main!=previous:
            restore=main.parent/'.Caddyfile.jk3d-rollback'
            restore.write_bytes(previous)
            shutil.copymode(main,restore)
            os.replace(restore,main)
        subprocess.run(command,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40)
        raise RuntimeError('JK3D_OPEN_RELOAD_FAILED_ROLLED_BACK: '+reload.stderr.decode(errors='replace')[-600:])
    secret=root/'staff-preview-password.txt'
    if secret.exists():
        secret.unlink()
    if 'basic_auth' in snippet.read_text() or 'staff ' in snippet.read_text():
        raise RuntimeError('JK3D_BASIC_AUTH_NOT_REMOVED')
    print('JK3D_LOGIN_FORM=REMOVED')
    print('JK3D_PUBLIC_SITE=NO_AUTH')
    print('JK3D_ORIGINAL_JUMPER_SITE=UNMODIFIED')
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
PY
