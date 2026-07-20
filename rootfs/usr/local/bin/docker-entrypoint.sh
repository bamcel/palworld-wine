#!/usr/bin/env bash
set -euo pipefail

: "${PUID:=99}"
: "${PGID:=100}"

if ! getent group "${PGID}" >/dev/null 2>&1; then
  groupadd --gid "${PGID}" palworld
fi

if ! getent passwd "${PUID}" >/dev/null 2>&1; then
  useradd -K UID_MIN=0 --uid "${PUID}" --gid "${PGID}" --home-dir /palworld --shell /bin/bash palworld
fi

mkdir -p "${SERVER_DIR}" "${STEAMCMD_DIR}" "${BACKUP_DIR}" "${WINEPREFIX}" "${XDG_CACHE_HOME}" "${XDG_RUNTIME_DIR}"
chmod 0700 "${XDG_RUNTIME_DIR}"
chown "${PUID}:${PGID}" "${XDG_RUNTIME_DIR}"

chown_if_writable() {
  local path="${1:?path required}"

  if [ ! -w "${path}" ]; then
    echo "Skipping ownership update for read-only path: ${path}"
    return
  fi

  local owner
  owner="$(stat -c '%u:%g' "${path}")"
  if [ "${owner}" = "${PUID}:${PGID}" ]; then
    return
  fi

  chown -R "${PUID}:${PGID}" "${path}"
}

if [ "${SKIP_CHOWN:-false}" != "true" ]; then
  chown_if_writable /palworld
  chown_if_writable /steamcmd
  chown_if_writable /backups
fi

if [ "${XVFB_LOG_STDOUT:-false}" = "true" ]; then
  Xvfb "${DISPLAY}" -screen 0 1024x768x16 -nolisten tcp &
else
  Xvfb "${DISPLAY}" -screen 0 1024x768x16 -nolisten tcp >/tmp/xvfb.log 2>&1 &
fi

exec gosu "${PUID}:${PGID}" /usr/local/bin/start-palworld.sh "$@"
