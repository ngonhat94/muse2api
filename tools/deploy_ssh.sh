#!/usr/bin/env bash
# Inputs are validated before interpolation into the remote shell command.
# Never trace credentials, including when invoked with bash -x.
set +x
set -euo pipefail
umask 077
revision=${1:?revision required}
image_id=${2:?image ID required}
version=${3:?version required}
root=${VPS_DEPLOY_PATH:?Set VPS_DEPLOY_PATH explicitly after preparing the VPS}
[[ $root =~ ^/[a-zA-Z0-9_/-]+$ && $root != / && $root != *..* && $root != *//* && $root != */ ]] || exit 2
[[ $revision =~ ^[a-f0-9]{40}$ && $image_id =~ ^sha256:[a-f0-9]{64}$ && $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
fail() { printf '%s\n' "$1" >&2; exit 2; }
mode=${VPS_SSH_MODE:-key}
case "$mode" in
  key)
    [[ ${VPS_USER:-} =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'Invalid VPS_USER for key mode.'
    [[ -n ${VPS_SSH_KEY:-} ]] || fail 'VPS_SSH_KEY is required in key mode.'
    ;;
  instabox-token)
    # Lexical safety only, not a guessed provider token prefix/encoding contract.
    [[ ${VPS_USER:-} =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,255}$ ]] || fail 'Invalid VPS_USER token (1-256 safe SSH username characters required).'
    ;;
  *) fail 'VPS_SSH_MODE must be key or instabox-token.' ;;
esac
[[ ${VPS_HOST:-} =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || fail 'Invalid VPS_HOST.'
[[ ${VPS_PORT:-} =~ ^[0-9]{1,5}$ ]] && ((10#$VPS_PORT > 0 && 10#$VPS_PORT < 65536)) || fail 'Invalid VPS_PORT.'
[[ -n ${VPS_KNOWN_HOSTS:-} ]] || fail 'Pinned VPS_KNOWN_HOSTS is required.'
keydir=$(mktemp -d "${RUNNER_TEMP:?}/muse-deploy-XXXXXXXX")
trap 'rm -f "$keydir/key" "$keydir/known_hosts" "$keydir/config" "$keydir/stderr"; rmdir "$keydir"' EXIT
printf '%s\n' "$VPS_KNOWN_HOSTS" > "$keydir/known_hosts"
options=(-p "$VPS_PORT" -o BatchMode=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$keydir/known_hosts" -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o LogLevel=ERROR)
if [[ $mode == key ]]; then
  printf '%s\n' "$VPS_SSH_KEY" > "$keydir/key"
  options+=(-F /dev/null -i "$keydir/key" -o IdentitiesOnly=yes)
  target="$VPS_USER@$VPS_HOST"
else
  # Private config keeps the bearer token out of argv/process listings and traces.
  printf 'Host *\n  User %s\n' "$VPS_USER" > "$keydir/config"
  options+=(-F "$keydir/config" -o PubkeyAuthentication=no -o PasswordAuthentication=no -o KbdInteractiveAuthentication=no -o GSSAPIAuthentication=no -o HostbasedAuthentication=no)
  target=$VPS_HOST
fi
unset VPS_SSH_KEY VPS_KNOWN_HOSTS
run_ssh() {
  local status=0 line category=unclassified
  ssh "${options[@]}" "$target" "$@" 2> "$keydir/stderr" || status=$?
  # Neither SSH nor arbitrary remote stderr is safe to publish. Only recognize
  # our fixed remote command-stage diagnostics; never echo the original line.
  if (( status != 0 )); then
    while IFS= read -r line || [[ -n $line ]]; do
      # Classify only; paths, usernames, tokens and arbitrary messages stay private.
      # A category is evidence for investigation, not a root-cause assertion.
      if [[ $category == unclassified ]]; then
        case "$line" in
          *'Permission denied'*) category=permission-denied ;;
          *'No such file or directory'*) category=missing-path ;;
          *'No space left on device'*) category=disk-full ;;
          *'Disk quota exceeded'*) category=quota-exceeded ;;
          *'File too large'*) category=file-too-large ;;
          *'Illegal option'*|*'invalid option'*) category=shell-option ;;
          *'cannot overwrite existing file'*|*'File exists'*) category=target-exists ;;
          *'Read-only file system'*) category=read-only-filesystem ;;
          *'Connection reset'*) category=connection-reset ;;
          *'Broken pipe'*) category=broken-pipe ;;
          *'Connection timed out'*|*'Operation timed out'*) category=connection-timeout ;;
          *'Host key verification failed'*|*'REMOTE HOST IDENTIFICATION HAS CHANGED'*) category=host-key ;;
        esac
      fi
      for stage in image-load image-inspect docker-query legacy-restart-policy legacy-stop compose-stop compose-up; do
        case "$line" in
          "Deployment failed: $stage: timed out after 180s;"*)
            printf 'Deployment stage %s timed out after 180s; inspect VPS privately.\n' "$stage" >&2 ;;
          "Deployment failed: $stage: command failed;"*|"Deployment failed: $stage: command unavailable;"*)
            printf 'Deployment stage %s command failed; inspect VPS privately.\n' "$stage" >&2 ;;
        esac
      done
    done < "$keydir/stderr"
    printf 'SSH stage %s failed (exit %s); category=%s; stderr [REDACTED]. Check pinned SSH access and remote state privately.\n' "${ssh_stage:-unknown}" "$status" "$category" >&2
  fi
  return "$status"
}
# Preflight does not create directories or run Docker. The operator owns bootstrap.
ssh_stage=preflight
run_ssh "python3 - '$root'" < tools/deploy_preflight.py
# Independent attempts: --pull may produce a different image for the same SHA.
# Never reuse, remove or overwrite an interrupted or previously deployed upload.
attempt="$revision-$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
ssh_stage=allocate-upload
run_ssh "umask 077; mkdir '$root/incoming/$attempt'"
# Stream fixed filenames through stdin: no scp/rsync remote quoting ambiguity.
for pair in 'deploy-image.tar:image.tar' 'deploy/compose.production.yml:compose.yml' 'tools/deploy_remote.py:deploy_remote.py'; do
  local_file=${pair%%:*}
  remote_file=${pair#*:}
  ssh_stage="upload-$remote_file"
  run_ssh "umask 077; set -C; cat > '$root/incoming/$attempt/$remote_file'" < "$local_file"
done
ssh_stage=remote-deploy
run_ssh "python3 '$root/incoming/$attempt/deploy_remote.py' '$root' '$revision' '$image_id' '$version' '$attempt'"
