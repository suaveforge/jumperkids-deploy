#!/bin/sh
set -eu
# Dedicated HTTPS route via the same shared server123 Caddy as original Jumper.
# No modifications to Jumper's own Caddy snippet, containers, DB or game code.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -x "$D"
test -s /home/gyeol/Caddyfile
test -x /home/gyeol/runtime/caddy/caddy
"$D" -H "$S" run --rm -i --network host \
  --cap-drop ALL --security-opt no-new-privileges \
  -v /home:/home:rw \
  python:3.11-alpine python - <<'PY'
from pathlib import Path
import fcntl,os,shutil,subprocess
root=Path('/home/jumperkids-preview')
(root/'deploy').mkdir(parents=True,exist_ok=True)
(root/'backups').mkdir(parents=True,exist_ok=True)
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
snippet=root/'deploy/Caddyfile.jumperkids'
line='import /home/jumperkids-preview/deploy/Caddyfile.jumperkids'
# Reuse the SAME Caddy edit lock used by Jumper deployment scripts.
lock=Path('/home/jumper/deploy/.caddy.lock')
if not (main.is_file() and caddy.is_file()):
    raise RuntimeError('JUMPERKIDS_SHARED_CADDY_MISSING')
site='''# JUMPER KIDS static non-production preview only.
# No child accounts, no payments, no HYTOPIA backend.
jumperkids.suaveforge.com {
    encode gzip zstd
    reverse_proxy 127.0.0.1:18836
    header {
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        X-Robots-Tag "noindex, nofollow"
        Cache-Control "no-store"
        Content-Security-Policy "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    }
}
'''
fd=os.open(lock,os.O_CREAT|os.O_RDWR,0o600)
fcntl.flock(fd,fcntl.LOCK_EX)
try:
    previous=main.read_bytes()
    prior_snippet=snippet.read_text() if snippet.exists() else None
    if previous.count(line.encode())>1:
        raise RuntimeError('JUMPERKIDS_IMPORT_DUPLICATE_CONFLICT')
    candidate=(previous if line.encode() in previous else previous.rstrip()+b'\n\n'+line.encode()+b'\n')
    if previous==candidate and prior_snippet==site:
        print('JUMPERKIDS_CADDY=ALREADY_CONFIGURED')
        raise SystemExit(0)
    snippet.write_text(site)
    temp=main.parent/'.Caddyfile.jumperkids.candidate'
    temp.write_bytes(candidate)
    shutil.copymode(main,temp)
    adapt=subprocess.run([str(caddy),'adapt','--config',str(temp),'--adapter','caddyfile'],
                          stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=40)
    if adapt.returncode:
        temp.unlink(missing_ok=True)
        if prior_snippet is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior_snippet)
        raise RuntimeError('JUMPERKIDS_CADDY_ADAPT_FAILED: '+adapt.stderr.decode(errors='replace')[-600:])
    if previous!=candidate:
        backup=root/'backups/Caddyfile.before-jumperkids'
        if not backup.exists():
            backup.write_bytes(previous)
            os.chmod(backup,0o600)
        os.replace(temp,main)
    else:
        temp.unlink(missing_ok=True)
    cmd=[str(caddy),'reload','--config',str(main),'--adapter','caddyfile']
    reload=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
    if reload.returncode:
        if previous!=candidate:
            restore=main.parent/'.Caddyfile.jumperkids.rollback'
            restore.write_bytes(previous)
            shutil.copymode(main,restore)
            os.replace(restore,main)
        if prior_snippet is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior_snippet)
        subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40)
        raise RuntimeError('JUMPERKIDS_CADDY_RELOAD_FAILED_ROLLED_BACK: '+reload.stderr.decode(errors='replace')[-600:])
    print('JUMPERKIDS_CADDY=RELOADED')
    print('JUMPERKIDS_ORIGINAL_CADDY_SNIPPET=UNMODIFIED')
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
PY
