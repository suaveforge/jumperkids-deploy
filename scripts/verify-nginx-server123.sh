#!/bin/sh
set -eu
# Verify existing standard HTTPS endpoints without changing shared ingress.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
check(){
  url=$1
  expected=$2
  code=$(curl -sS --max-time 20 -D "$work/headers" -o "$work/body" -w '%{http_code}' "$url")
  test "$code" = "$expected"
  ! grep -Eiq '^via:.*caddy' "$work/headers"
  grep -Eiq '^server: nginx([ /]|[[:space:]]*$)' "$work/headers"
}
case "$1" in
  main)
    for p in / /games/ /asset-studio/ /story-arcade/; do check "https://jumperkids.suaveforge.com$p" 200; done
    ;;
  visual)
    for p in / /main.js /style.css; do check "https://jumperkids3d.suaveforge.com$p" 200; done
    check "https://jumperkids3d.suaveforge.com/art/" 404
    ;;
  api)
    check "https://api-jumperkids3d.suaveforge.com/" 200
    grep -Eq '"status"[[:space:]]*:[[:space:]]*"OK"' "$work/body"
    for p in /blocks/ /models/ /audio/ /textures/ /fonts/; do check "https://api-jumperkids3d.suaveforge.com$p" 404; done
    ;;
  *) echo 'usage: verify-nginx-server123.sh main|visual|api' >&2; exit 2;;
esac
echo "JUMPERKIDS_STANDARD_HTTPS_NGINX_VERIFIED $1"
