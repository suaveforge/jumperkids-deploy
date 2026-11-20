#!/bin/sh
set -eu
# W01 task 01/18 — FAIL-CLOSED safety interlock for the retired Art Studio
# PUBLIC promotion route. The historical version served six HYTOPIA HGAL
# GLBs to the shared Kids 3D domain and replaced its Caddy snippet, bypassing
# W01's seven-GLB public deny rules.
#
# Private Art Studio remains at 127.0.0.1:18846. The W01 approved W05-owned
# private builder is the ONLY supported path while PR #1/#3 await MAIN review.
# No public preview Art Studio promotion without NEW explicit MAIN approval,
# dedicated rights review and an independently reviewed replacement promoter.
#
# Intentionally no Docker, Caddy, DNS, filesystem, or public service mutations.
echo 'JK_W01_ARTSTUDIO_PUBLIC_PROMOTION_DENIED_PENDING_MAIN_APPROVAL' >&2
exit 78
