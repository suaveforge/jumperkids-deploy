#!/bin/sh
set -eu
# Split 3D frontend from HYTOPIA API/WSS, like the original Jumper deployment.
# No login. Technical-only preview, no child PII, payments, chat or accounts.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -s /home/gyeol/Caddyfile
test -x /home/gyeol/runtime/caddy/caddy
test -s /home/jumperkids-native-dev/client-dist/index.html
test "$(curl -ksS --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1:18837/)" = 200
"$D" -H "$S" run --rm -i --network host \
 --cap-drop ALL --security-opt no-new-privileges \
 -v /home:/home:rw python:3.11-alpine python - <<'PY'
from pathlib import Path
import os,fcntl,subprocess,shutil,re
root=Path('/home/jumperkids-native-dev')
main=Path('/home/gyeol/Caddyfile')
caddy=Path('/home/gyeol/runtime/caddy/caddy')
snippet=root/'Caddyfile.staff3d-api'
line='import /home/jumperkids-native-dev/Caddyfile.staff3d-api'
lock=Path('/home/jumper/deploy/.caddy.lock')
web=root/'client-dist/index.html'
api_host='api-jumperkids3d.suaveforge.com'
site='''# JUMPER KIDS independent 3D world API and websocket, not the HTML frontend.
api-jumperkids3d.suaveforge.com {
    encode gzip zstd
    header {
        >Access-Control-Allow-Origin "https://jumperkids3d.suaveforge.com"
        Access-Control-Allow-Methods "GET, POST, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With"
        Vary "Origin"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "no-referrer"
        Cache-Control "no-store"
        X-Robots-Tag "noindex, nofollow"
    }
    @preflight method OPTIONS
    handle @preflight {
        respond "" 204
    }
    handle {
        reverse_proxy https://127.0.0.1:18837 {
            transport http {
                tls_insecure_skip_verify
            }
        }
    }
}
'''
if not (main.exists() and caddy.exists() and web.exists()):
    raise RuntimeError('JK3D_API_RUNTIME_MISSING')
prior_html=web.read_text()
# The old frontend sends the root server-info fetch to the static client site,
# resulting in HTML instead of {"status":"OK"}. Always repair persisted stale
# ?join= values from earlier visits, not just first clean navigation.
new_js="""<script>
(function(){
 const u=new URL(location.href), current=u.searchParams.get('join');
 const desired=location.hostname==='jumperkids3d.suaveforge.com'
    ?'api-jumperkids3d.suaveforge.com' : location.hostname+':18837';
 if(current!==desired){u.searchParams.set('join',desired);history.replaceState(history.state,'',u.toString());}
})();
</script>"""
old_match=re.search(r'(?s)<script>\s*if \(!new URLSearchParams\(location.search\).has\(\'join\'\)\).*?</script>',prior_html)
if old_match:
    candidate_html=prior_html[:old_match.start()]+new_js+prior_html[old_match.end():]
elif api_host in prior_html and "current!==desired" in prior_html:
    candidate_html=prior_html
else:
    raise RuntimeError('JK3D_CLIENT_BOOTSTRAP_UNKNOWN_REFUSE_PATCH')
for forbidden in ('api-jumper.suaveforge.com','hubs-client','payhub','authhub'):
    if forbidden in candidate_html.lower():raise RuntimeError('JK3D_ADULT_SERVICE_LEAK')
fd=os.open(lock,os.O_CREAT|os.O_RDWR,0o600)
fcntl.flock(fd,fcntl.LOCK_EX)
try:
    previous=main.read_bytes()
    prior_snippet=snippet.read_text() if snippet.exists() else None
    if previous.count(line.encode())>1:
        raise RuntimeError('JK3D_API_IMPORT_DUPLICATE')
    new_config=previous if line.encode() in previous else previous.rstrip()+b'\n\n'+line.encode()+b'\n'
    snippet.write_text(site)
    candidate=main.parent/'.Caddyfile.jk3d-api.candidate'
    candidate.write_bytes(new_config)
    shutil.copymode(main,candidate)
    check=subprocess.run([str(caddy),'adapt','--config',str(candidate),'--adapter','caddyfile'],
                         stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=40)
    if check.returncode:
        candidate.unlink(missing_ok=True)
        if prior_snippet is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior_snippet)
        raise RuntimeError('JK3D_API_CADDY_INVALID:'+check.stderr.decode(errors='replace')[-600:])
    if candidate.read_bytes()!=previous:os.replace(candidate,main)
    else:candidate.unlink(missing_ok=True)
    cmd=[str(caddy),'reload','--config',str(main),'--adapter','caddyfile']
    result=subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,timeout=60)
    if result.returncode:
        if new_config!=previous:
            restore=main.parent/'.Caddyfile.jk3d-api.rollback'
            restore.write_bytes(previous)
            shutil.copymode(main,restore)
            os.replace(restore,main)
        if prior_snippet is None:snippet.unlink(missing_ok=True)
        else:snippet.write_text(prior_snippet)
        subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=40)
        raise RuntimeError('JK3D_API_RELOAD_FAILED_ROLLED_BACK')
    if candidate_html!=prior_html:
        staged=web.with_suffix('.jk3d-new')
        staged.write_text(candidate_html)
        os.replace(staged,web)
finally:
    fcntl.flock(fd,fcntl.LOCK_UN)
    os.close(fd)
print('JK3D_FRONTEND_DEFAULT_JOIN=api-jumperkids3d.suaveforge.com')
print('JK3D_API_CADDY=RELOADED')
print('JK3D_ORIGINAL_JUMPER_SERVICE=UNTOUCHED')
PY
