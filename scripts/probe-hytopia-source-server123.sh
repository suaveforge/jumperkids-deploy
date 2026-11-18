#!/bin/sh
set -eu
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
SRC=/home/jumper-eval/hytopia/source
test -d "$SRC" || { echo JK_ENGINE_SOURCE_NOT_FOUND; exit 1; }
"$D" -H "$S" run --rm -i --network none --read-only \
 --cap-drop ALL --security-opt no-new-privileges \
 -v "$SRC:/src:ro" python:3.11-alpine python - <<'PY'
from pathlib import Path
import json,os,hashlib
root=Path('/src')
print('JK_ENGINE_ROOT=EXISTS')
paths=[
 'server/package.json','server/src/playground.ts','server/src/playground.mjs',
 'server/src/jumper-world.mjs','server/src/index.ts',
 'server/tsconfig.json','client/package.json','client/dist/index.html',
 'assets/release/maps/boilerplate-small.json',
 'LICENSE','LICENSE.md','server/LICENSE','client/LICENSE',
]
for name in paths:
  p=root/name
  print('JK_ENGINE_FILE='+name+' '+('EXISTS' if p.is_file() else 'MISSING')+' SIZE='+str(p.stat().st_size if p.is_file() else 0))
for name in ('server/package.json','client/package.json'):
  p=root/name
  if not p.exists():continue
  try:
    obj=json.loads(p.read_text())
    print('JK_PACKAGE='+name+' NAME='+str(obj.get('name','?'))+' TYPE='+str(obj.get('type','?')))
    print('JK_PACKAGE_SCRIPTS='+json.dumps(sorted((obj.get('scripts') or {}).keys())))
    print('JK_PACKAGE_DEPS='+json.dumps(sorted((obj.get('dependencies') or {}).keys())[:40]))
  except Exception as e:
    print('JK_PACKAGE_READ_ERROR='+name+':'+type(e).__name__)
for name in ('server/src/jumper-world.mjs','server/src/playground.mjs','server/src/playground.ts'):
  p=root/name
  if p.exists():
    txt=p.read_text(errors='replace')
    print('JK_ENTRY='+name+' LINES='+str(txt.count('\n')+1)+' HAS_AUTHHUB='+str('authhub' in txt.lower())+' HAS_PAYHUB='+str('payhub' in txt.lower())+' HAS_GAME='+str('startServer' in txt or 'jumper-world' in txt))
for name in ('client/dist','server/node_modules','client/node_modules','assets/release'):
  p=root/name
  print('JK_ENGINE_DIR='+name+' PRESENT='+str(p.is_dir()))
# Do not list or read environment secrets, user profiles or operational databases.
print('JK_ENGINE_AUDIT=READ_ONLY')
PY
