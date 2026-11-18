#!/bin/sh
set -eu
# Spaceship DNS API as originally used by JUMPER. This script edits ONLY
# the jumperkids A-record and refuses to change existing conflicting records.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -x "$D"
test -s /home/suaveforge/secrets/spaceship.env || { echo JUMPERKIDS3D_SPACESHIP_CREDENTIALS_MISSING; exit 1; }
"$D" -H "$S" run --rm -i --network host --read-only \
 --cap-drop ALL --security-opt no-new-privileges \
 -v /home/suaveforge/secrets/spaceship.env:/run/spaceship.env:ro \
 python:3.11-alpine python - <<'PY'
from pathlib import Path
import json,urllib.request,urllib.error
env={}
for line in Path('/run/spaceship.env').read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        k,v=line.split('=',1)
        env[k.strip()]=v.strip().strip('"').strip("'")
key,secret=env.get('SPACESHIP_API_KEY'),env.get('SPACESHIP_API_SECRET')
if not key or not secret:
    raise RuntimeError('JUMPERKIDS3D_SPACESHIP_CREDENTIALS_MISSING')
domain='suaveforge.com'
host='jumperkids3d'
base='https://spaceship.dev/api/v1/dns/records/'+domain
headers={'X-Api-Key':key,'X-Api-Secret':secret,'Accept':'application/json'}
def get_records():
    req=urllib.request.Request(base+'?take=500&skip=0',headers=headers)
    with urllib.request.urlopen(req,timeout=25) as stream:
        obj=json.load(stream)
    if isinstance(obj.get('items'),list):return obj['items']
    if isinstance(obj.get('records'),list):return obj['records']
    if isinstance(obj.get('data'),dict) and isinstance(obj['data'].get('items'),list):return obj['data']['items']
    raise RuntimeError('JUMPERKIDS3D_DNS_RESPONSE_UNEXPECTED')
def matches(item,name):
    found=str(item.get('name','')).strip('.').lower()
    return found in (name, name+'.'+domain)
all_records=get_records()
# Reuse the original Jumper's verified Spaceship A record target. No guessed IP.
jumper_a=[x for x in all_records if matches(x,'jumper') and str(x.get('type','')).upper()=='A']
targets={str(x.get('address','')) for x in jumper_a if x.get('address')}
if len(targets)!=1:
    raise RuntimeError('JUMPERKIDS3D_EXISTING_JUMPER_A_RECORD_AMBIGUOUS')
target=next(iter(targets))
records=[x for x in all_records if matches(x,host)]
if records:
    if len(records)!=1 or str(records[0].get('type','')).upper()!='A' or str(records[0].get('address',''))!=target:
        raise RuntimeError('JUMPERKIDS3D_DNS_CONFLICT_REFUSE_OVERWRITE')
    print('JUMPERKIDS3D_DNS_A_RECORD=ALREADY_SET')
else:
    payload=json.dumps({'force':False,'items':[{
      'type':'A','name':host,'address':target,'ttl':600
    }]}).encode('utf-8')
    req=urllib.request.Request(base,data=payload,
            headers={**headers,'Content-Type':'application/json'},method='PUT')
    with urllib.request.urlopen(req,timeout=30) as stream:
        print('JUMPERKIDS3D_DNS_WRITE_HTTP='+str(stream.status))
check=[x for x in get_records() if matches(x,host)]
if len(check)!=1 or str(check[0].get('type','')).upper()!='A' or str(check[0].get('address',''))!=target:
    raise RuntimeError('JUMPERKIDS3D_DNS_READBACK_FAILED')
print('JUMPERKIDS3D_DNS=VERIFIED')
print('JUMPERKIDS3D_HOST=jumperkids3d.suaveforge.com')
PY
