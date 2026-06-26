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

mkdir -p "${SERVER_DIR}" "${STEAMCMD_DIR}" "${MODS_DIR}" "${BACKUP_DIR}" "${WINEPREFIX}" "${XDG_CACHE_HOME}"

chown_if_writable() {
  local path="${1:?path required}"

  if [ -w "${path}" ]; then
    chown -R "${PUID}:${PGID}" "${path}"
  else
    echo "Skipping ownership update for read-only path: ${path}"
  fi
}

if [ "${SKIP_CHOWN:-false}" != "true" ]; then
  chown_if_writable /palworld
  chown_if_writable /steamcmd
  chown_if_writable /backups
  chown_if_writable "${MODS_DIR}"
fi

if [ "${XVFB_LOG_STDOUT:-false}" = "true" ]; then
  Xvfb "${DISPLAY}" -screen 0 1024x768x16 -nolisten tcp &
else
  Xvfb "${DISPLAY}" -screen 0 1024x768x16 -nolisten tcp >/tmp/xvfb.log 2>&1 &
fi

exec gosu "${PUID}:${PGID}" /usr/local/bin/start-palworld.sh "$@"
