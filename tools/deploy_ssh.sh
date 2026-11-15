#!/usr/bin/env bash
# Inputs are validated before interpolation into the remote shell command.
set -euo pipefail
umask 077
revision=${1:?revision required}
image_id=${2:?image ID required}
version=${3:?version required}
root=${VPS_DEPLOY_PATH:?Set VPS_DEPLOY_PATH explicitly after preparing the VPS}
[[ $root =~ ^/[a-zA-Z0-9_/-]+$ && $root != / && $root != *..* && $root != *//* && $root != */ ]] || exit 2
[[ $revision =~ ^[a-f0-9]{40}$ && $image_id =~ ^sha256:[a-f0-9]{64}$ && $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
[[ ${VPS_HOST:-} =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ && ${VPS_USER:-} =~ ^[a-z_][a-z0-9_-]*$ ]] || exit 2
[[ ${VPS_PORT:-} =~ ^[0-9]{1,5}$ ]] && ((10#$VPS_PORT > 0 && 10#$VPS_PORT < 65536)) || exit 2
[[ -n ${VPS_KNOWN_HOSTS:-} && -n ${VPS_SSH_KEY:-} ]] || { printf '%s\n' 'Pinned VPS_KNOWN_HOSTS and VPS_SSH_KEY are required.' >&2; exit 2; }
keydir=$(mktemp -d "${RUNNER_TEMP:?}/muse-deploy-XXXXXXXX")
trap 'rm -f "$keydir/key" "$keydir/known_hosts"; rmdir "$keydir"' EXIT
printf '%s\n' "$VPS_SSH_KEY" > "$keydir/key"
printf '%s\n' "$VPS_KNOWN_HOSTS" > "$keydir/known_hosts"
unset VPS_SSH_KEY VPS_KNOWN_HOSTS
options=(-i "$keydir/key" -p "$VPS_PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$keydir/known_hosts" -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o LogLevel=ERROR)
target="$VPS_USER@$VPS_HOST"
# Preflight does not create directories or run Docker. The operator owns bootstrap.
ssh "${options[@]}" "$target" "python3 - '$root'" < tools/deploy_preflight.py
# A unique immutable revision directory; existing release directories fail closed.
ssh "${options[@]}" "$target" "umask 077; mkdir '$root/incoming/$revision'"
# Stream fixed filenames through stdin: no scp/rsync remote quoting ambiguity.
for pair in 'deploy-image.tar:image.tar' 'deploy/compose.production.yml:compose.yml' 'tools/deploy_remote.py:deploy_remote.py'; do
  local_file=${pair%%:*}
  remote_file=${pair#*:}
  ssh "${options[@]}" "$target" "umask 077; cat > '$root/incoming/$revision/$remote_file'" < "$local_file"
done
ssh "${options[@]}" "$target" "python3 '$root/incoming/$revision/deploy_remote.py' '$root' '$revision' '$image_id' '$version'"
