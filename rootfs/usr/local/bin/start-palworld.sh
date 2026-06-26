#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '\033[0;32m%s\033[0m\n' "$*"
}

is_true() {
  case "${1:-}" in
    true|TRUE|True|1|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

wine_path() {
  local linux_path="${1:?path required}"
  printf 'Z:%s' "${linux_path//\//\\}"
}

STEAMCMD_EXE="${STEAMCMD_DIR}/steamcmd.exe"
PAL_WIN64_DIR="${SERVER_DIR}/Pal/Binaries/Win64"
PAL_EXE="${PAL_WIN64_DIR}/PalServer-Win64-Test-Cmd.exe"

mkdir -p "${SERVER_DIR}" "${STEAMCMD_DIR}" "${MODS_DIR}" "${BACKUP_DIR}"

if [ ! -d "${WINEPREFIX}/drive_c" ]; then
  log "Initializing WINE prefix at ${WINEPREFIX}"
  wineboot --init
  wineserver -w
fi

if [ ! -f "${STEAMCMD_EXE}" ]; then
  log "Downloading Windows SteamCMD"
  curl -fsSL "https://media.steampowered.com/installer/steamcmd.zip" -o "${STEAMCMD_DIR}/steamcmd.zip"
  unzip -o "${STEAMCMD_DIR}/steamcmd.zip" -d "${STEAMCMD_DIR}"
  rm -f "${STEAMCMD_DIR}/steamcmd.zip"
fi

if is_true "${WINETRICKS_ON_BOOT}"; then
  log "Installing/updating Visual C++ runtime with winetricks"
  winetricks --optout -f -q vcrun2022
  wineserver -w
fi

if is_true "${BACKUP_ENABLED}"; then
  log "Starting backup scheduler: ${BACKUP_CRON}"
  printf '%s /usr/local/bin/backup-palworld.sh\n' "${BACKUP_CRON}" > /tmp/palworld-cron
  supercronic -passthrough-logs /tmp/palworld-cron &
fi

if is_true "${UPDATE_ON_BOOT}"; then
  log "Installing/updating Palworld dedicated server"
  update_args=(
    wine "${STEAMCMD_EXE}"
    +force_install_dir "$(wine_path "${SERVER_DIR}")"
    +login anonymous
    +app_update "${STEAM_APP_ID}"
  )

  if is_true "${VALIDATE_ON_UPDATE}"; then
    update_args+=(validate)
  fi

  update_args+=(+quit)
  "${update_args[@]}"
  wineserver -w
fi

if is_true "${MODS_ENABLED}" && is_true "${MOD_OVERLAY_ON_BOOT}"; then
  log "Applying mod overlays from ${MODS_DIR}"
  mkdir -p "${PAL_WIN64_DIR}" "${SERVER_DIR}/Pal/Content/Paks/~mods"

  if [ -d "${MODS_DIR}/server-overlay" ]; then
    cp -a "${MODS_DIR}/server-overlay/." "${SERVER_DIR}/"
  fi

  if [ -d "${MODS_DIR}/win64" ]; then
    cp -a "${MODS_DIR}/win64/." "${PAL_WIN64_DIR}/"
  fi

  if [ -d "${MODS_DIR}/paks" ]; then
    cp -a "${MODS_DIR}/paks/." "${SERVER_DIR}/Pal/Content/Paks/~mods/"
  fi
fi

if [ ! -f "${PAL_EXE}" ]; then
  echo "Palworld server executable not found at ${PAL_EXE}."
  echo "Start with UPDATE_ON_BOOT=true so SteamCMD can install the server."
  exit 1
fi

start_args=(wine "${PAL_EXE}")

if is_true "${COMMUNITY}"; then
  start_args+=("EpicApp=PalServer")
fi

if [ -n "${PORT:-}" ]; then
  start_args+=("-port=${PORT}")
fi

if [ -n "${QUERY_PORT:-}" ]; then
  start_args+=("-queryport=${QUERY_PORT}")
fi

if is_true "${MULTITHREADING}"; then
  start_args+=("-useperfthreads" "-NoAsyncLoadingThread" "-UseMultithreadForDS")
fi

if [ -n "${EXTRA_ARGS:-}" ]; then
  read -r -a extra_args <<< "${EXTRA_ARGS}"
  start_args+=("${extra_args[@]}")
fi

log "Starting Palworld server"
printf '%q ' "${start_args[@]}"
printf '\n'
exec "${start_args[@]}"
