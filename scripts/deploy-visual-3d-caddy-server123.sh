#!/bin/sh
set -eu
# Backward-compatible entrypoint; old gateway configuration is retired.
exec sh "$(dirname "$0")/verify-nginx-server123.sh" visual
