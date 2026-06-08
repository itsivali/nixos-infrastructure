#!/usr/bin/env bash
set -euo pipefail

sudo nixos-rebuild switch --rollback

./scripts/notify.sh "🚨 rollback executed on prague"
