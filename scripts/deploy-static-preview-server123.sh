#!/bin/sh
set -eu
# JUMPER KIDS *public preview only* — not a child-facing production runtime.
# Runs on the SAME server123 runner architecture as Jumper, in a separate dir,
# container, and loopback port. Original /home/jumper is NEVER modified.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
ROOT=/home/jumperkids-preview
NAME=sf-jumperkids-preview
PORT=18836
IMAGE=python:3.11-alpine

test -x "$D"
test -s "$PWD/demo/index.html"
test -s "$PWD/ops/index.html"
cmp -s "$PWD/demo/index.html" "$PWD/ops/index.html"
# The no-login, no-API artifact must be identical to the public deploy artifact.
# Any intended future change must be reviewed and published to the public repo first.
if "$D" -H "$S" inspect "$NAME" >/dev/null 2>&1; then
  project=$("$D" -H "$S" inspect --format '{{ index .Config.Labels "com.suaveforge.project" }}' "$NAME")
  test "$project" = jumperkids-preview || { echo JUMPERKIDS_CONTAINER_NAME_CONFLICT; exit 1; }
fi

# A Docker-owned dedicated directory. We never touch original Jumper assets.
"$D" -H "$S" run --rm -i --network none --read-only \
  --cap-drop ALL --security-opt no-new-privileges \
  -v "$PWD/demo:/source:ro" -v "$ROOT:/dest:rw" \
  "$IMAGE" python - <<'PY'
from pathlib import Path
import hashlib, os, shutil, time
source=Path('/source/index.html')
dest=Path('/dest/web')
backups=Path('/dest/backups')
dest.mkdir(parents=True,exist_ok=True)
backups.mkdir(parents=True,exist_ok=True)
body=source.read_bytes()
if len(body)>150_000 or b'<html' not in body or b'<script' not in body:
    raise RuntimeError('JUMPERKIDS_PREVIEW_UNEXPECTED_CONTENT')
target=dest/'index.html'
if target.exists() and target.read_bytes()!=body:
    backup=backups/('index.before-'+str(int(time.time()))+'.html')
    shutil.copy2(target,backup)
    os.chmod(backup,0o600)
tmp=dest/'.index.html.new'
tmp.write_bytes(body)
os.chmod(tmp,0o644)
os.replace(tmp,target)
print('JUMPERKIDS_PREVIEW_SHA256='+hashlib.sha256(body).hexdigest())
print('JUMPERKIDS_PUBLIC_ARTIFACT=SYNCED')
PY

if ! "$D" -H "$S" inspect "$NAME" >/dev/null 2>&1; then
  "$D" -H "$S" run -d --name "$NAME" --restart unless-stopped \
    --label com.suaveforge.project=jumperkids-preview \
    --network bridge --memory 128m --pids-limit 90 \
    --cap-drop ALL --security-opt no-new-privileges \
    --read-only --tmpfs /tmp:rw,nosuid,noexec,size=16m \
    --user 65534:65534 \
    -p 127.0.0.1:"$PORT":8080 \
    -v "$ROOT/web:/www:ro" -w /www \
    "$IMAGE" python -m http.server 8080 --bind 0.0.0.0 >/dev/null
fi
test "$("$D" -H "$S" inspect --format '{{.State.Running}}' "$NAME")" = true
ok=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  status=$(curl -sS --max-time 5 -o /tmp/jumperkids-preview-response -w '%{http_code}' http://127.0.0.1:"$PORT"/ || true)
  if test "$status" = 200 && grep -q '꿈꾸는 마을' /tmp/jumperkids-preview-response; then ok=1; break; fi
  sleep 1
done
test "$ok" = 1 || { echo JUMPERKIDS_LOCAL_HTTP_CHECK_FAILED; exit 1; }
echo JUMPERKIDS_PRIVATE_DOCKER_LOOPBACK=HTTP_200
echo JUMPERKIDS_ORIGINAL_JUMPER_UNTOUCHED=YES
