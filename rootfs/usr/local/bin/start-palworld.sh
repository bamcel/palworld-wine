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
PAL_EXE="${PAL_EXE:-}"

mkdir -p "${SERVER_DIR}" "${STEAMCMD_DIR}" "${BACKUP_DIR}"

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

WINETRICKS_MARKER="${WINEPREFIX}/.vcrun2022-installed"

if is_true "${WINETRICKS_ON_BOOT}"; then
  if [ ! -f "${WINETRICKS_MARKER}" ] || is_true "${FORCE_WINETRICKS:-false}"; then
    log "Installing/updating Visual C++ runtime with winetricks"
    winetricks --optout -f -q vcrun2022
    wineserver -w
    date -u +%Y-%m-%dT%H:%M:%SZ > "${WINETRICKS_MARKER}"
  else
    log "Visual C++ runtime already installed; set FORCE_WINETRICKS=true to reinstall"
  fi
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

if [ -z "${PAL_EXE}" ]; then
  for candidate in \
    "${SERVER_DIR}/PalServer.exe" \
    "${PAL_WIN64_DIR}/PalServer-Win64-Test-Cmd.exe" \
    "${PAL_WIN64_DIR}/PalServer-Win64-Shipping-Cmd.exe" \
    "${PAL_WIN64_DIR}/PalServer-Win64-Shipping.exe"
  do
    if [ -f "${candidate}" ]; then
      PAL_EXE="${candidate}"
      break
    fi
  done
fi

if [ -z "${PAL_EXE}" ] || [ ! -f "${PAL_EXE}" ]; then
  echo "Palworld server executable not found."
  echo "Checked:"
  echo "  ${SERVER_DIR}/PalServer.exe"
  echo "  ${PAL_WIN64_DIR}/PalServer-Win64-Test-Cmd.exe"
  echo "  ${PAL_WIN64_DIR}/PalServer-Win64-Shipping-Cmd.exe"
  echo "  ${PAL_WIN64_DIR}/PalServer-Win64-Shipping.exe"
  echo
  echo "Installed files under ${SERVER_DIR}:"
  find "${SERVER_DIR}" -maxdepth 4 -type f \( -iname 'PalServer*.exe' -o -iname 'Pal*.exe' \) -print | sort || true
  echo
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

container_hostname="$(cat /etc/hostname 2>/dev/null || true)"
container_ip=""
if [ -n "${container_hostname}" ]; then
  while read -r hosts_ip hosts_name _; do
    if [ "${hosts_name}" = "${container_hostname}" ]; then
      container_ip="${hosts_ip}"
      break
    fi
  done < /etc/hosts
fi

log "Starting Palworld server"
if [ -n "${container_ip}" ]; then
  log "Container IP: ${container_ip}:${PORT:-8211} -- if using Docker port mapping (e.g. Unraid bridge networking), connect using this host's IP address on port ${PORT:-8211} instead."
fi
printf '%q ' "${start_args[@]}"
printf '\n'
exec "${start_args[@]}"
