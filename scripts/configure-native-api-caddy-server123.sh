#!/bin/sh
set -eu
# Backward-compatible native client repair; never edits the old gateway.
exec sh "$(dirname "$0")/configure-native-api-client-server123.sh"
