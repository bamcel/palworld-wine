#!/usr/bin/env bash
set -euo pipefail

: "${SERVER_DIR:=/palworld/server}"
: "${BACKUP_DIR:=/backups}"
: "${OLD_BACKUP_DAYS:=30}"
: "${DELETE_OLD_BACKUPS:=false}"

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_file="${BACKUP_DIR}/palworld-${timestamp}.tgz"

mkdir -p "${BACKUP_DIR}"

paths=()
[ -d "${SERVER_DIR}/Pal/Saved" ] && paths+=("${SERVER_DIR}/Pal/Saved")
[ -d "${SERVER_DIR}/Pal/Binaries/Win64/Mods" ] && paths+=("${SERVER_DIR}/Pal/Binaries/Win64/Mods")
[ -d "${SERVER_DIR}/Pal/Content/Paks/~mods" ] && paths+=("${SERVER_DIR}/Pal/Content/Paks/~mods")

if [ "${#paths[@]}" -eq 0 ]; then
  echo "No Palworld save or mod directories found to back up."
  exit 0
fi

tar -czf "${backup_file}" "${paths[@]}"
echo "Created backup: ${backup_file}"

case "${DELETE_OLD_BACKUPS}" in
  true|TRUE|True|1|yes|YES|Yes)
    find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'palworld-*.tgz' -mtime "+${OLD_BACKUP_DAYS}" -delete
    ;;
esac
