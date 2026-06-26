#!/usr/bin/env bash
set -euo pipefail

: "${PUID:=99}"
: "${PGID:=100}"

if ! getent group "${PGID}" >/dev/null 2>&1; then
  groupadd --gid "${PGID}" palworld
fi

if ! getent passwd "${PUID}" >/dev/null 2>&1; then
  useradd --uid "${PUID}" --gid "${PGID}" --home-dir /palworld --shell /bin/bash palworld
fi

mkdir -p "${SERVER_DIR}" "${STEAMCMD_DIR}" "${MODS_DIR}" "${BACKUP_DIR}" "${WINEPREFIX}" "${XDG_CACHE_HOME}"

if [ "${SKIP_CHOWN:-false}" != "true" ]; then
  chown -R "${PUID}:${PGID}" /palworld /steamcmd /mods /backups
fi

Xvfb "${DISPLAY}" -screen 0 1024x768x16 -nolisten tcp &

exec gosu "${PUID}:${PGID}" /usr/local/bin/start-palworld.sh "$@"
