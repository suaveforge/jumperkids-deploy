#!/bin/sh
set -eu
# Preserve the native client join repair without modifying any gateway.
D=/home/ggul-docker/bin/docker
S=unix:///home/ggul-docker/run/docker.sock
test -s /home/jumperkids-native-dev/client-dist/index.html
test "$(curl -ksS --max-time 10 -o /dev/null -w '%{http_code}' https://127.0.0.1:18837/)" = 200
"$D" -H "$S" run --rm -i --network host --cap-drop ALL --security-opt no-new-privileges \
  -v /home/jumperkids-native-dev/client-dist:/client:rw python:3.11-alpine python - <<'PY'
from pathlib import Path
import os,re
web=Path('/client/index.html')
api_host='api-jumperkids3d.suaveforge.com'
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
if candidate_html!=prior_html:
    staged=web.with_suffix('.jk3d-new')
    staged.write_text(candidate_html)
    os.chmod(staged,web.stat().st_mode & 0o777)
    os.replace(staged,web)
print('JK3D_FRONTEND_DEFAULT_JOIN=api-jumperkids3d.suaveforge.com')
PY
exec sh "$(dirname "$0")/verify-nginx-server123.sh" api
