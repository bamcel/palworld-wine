# Palworld WINE Server Container

A Palworld dedicated server image that runs the Windows server under WINE so you can use Windows-only Palworld mod loaders and mods. This project is based on the approach from [`ripps818/palworld-wine`](https://github.com/ripps818/palworld-wine), with a cleaner Unraid/GitHub publishing layout.

## Features

- Windows SteamCMD and Palworld server running under WINE.
- Persistent `/palworld`, `/steamcmd`, `/mods`, and `/backups` mounts.
- Unraid-friendly `PUID` / `PGID` ownership.
- Boot-time install/update with optional Steam validation.
- Common mod overlay folders for UE4SS, Win64 files, and pak mods.
- Scheduled backups with `supercronic`.
- GitHub Actions workflow for publishing to GitHub Container Registry.

## Quick Start

Copy `.env.example` to `.env`, edit values, then start the server:

```bash
docker compose up -d
```

The first boot can take a while because the image initializes WINE, installs the Visual C++ runtime, downloads Windows SteamCMD, and installs the Palworld dedicated server.

## Volumes

| Container path | Purpose |
| --- | --- |
| `/palworld` | WINE prefix and installed Palworld server |
| `/steamcmd` | Windows SteamCMD files |
| `/mods` | Read-only mod staging folder |
| `/backups` | Scheduled backup output |

## Mod Layout

Place mods on the host under `./mods` using one or more of these folders:

```text
mods/
  win64/              # copied into Pal/Binaries/Win64
    xinput1_3.dll
    UE4SS-settings.ini
    Mods/
  paks/               # copied into Pal/Content/Paks/~mods
    ExampleMod.pak
  server-overlay/     # copied into the Palworld server root
    Pal/
```

This keeps downloaded mod files outside the image and makes them easy to update on Unraid.

## Environment

| Variable | Default | Notes |
| --- | --- | --- |
| `PUID` / `PGID` | `99` / `100` | Unraid `nobody:users` defaults |
| `TZ` | `UTC` | Container timezone |
| `UPDATE_ON_BOOT` | `true` | Install/update Palworld on startup |
| `VALIDATE_ON_UPDATE` | `true` | Run Steam validation during update |
| `WINETRICKS_ON_BOOT` | `true` | Install/update `vcrun2022` |
| `PORT` | `8211` | Palworld game UDP port |
| `QUERY_PORT` | `27015` | Steam query UDP port |
| `MULTITHREADING` | `true` | Adds Palworld dedicated-server threading flags |
| `COMMUNITY` | `false` | Adds `EpicApp=PalServer` |
| `EXTRA_ARGS` | empty | Extra PalServer command-line args |
| `MODS_ENABLED` | `true` | Enables mod handling |
| `MOD_OVERLAY_ON_BOOT` | `true` | Copies `/mods` overlays before startup |
| `BACKUP_ENABLED` | `true` | Starts scheduled backups |
| `BACKUP_CRON` | `0 */6 * * *` | Backup schedule |
| `DELETE_OLD_BACKUPS` | `false` | Delete old `palworld-*.tgz` backups |
| `OLD_BACKUP_DAYS` | `30` | Retention age when deletion is enabled |

Palworld world settings are still managed in the normal game file under:

```text
/palworld/server/Pal/Saved/Config/WindowsServer/PalWorldSettings.ini
```

## Unraid

Use the files in `compose_files/` with the Unraid Compose Manager plugin:

```yaml
image: ghcr.io/bamcel/palworld-wine:latest
```

Suggested Unraid paths:

```text
/mnt/user/game_server/palworld/game    -> /palworld
/mnt/user/game_server/palworld/mods    -> /mods
/mnt/user/game_server/palworld/backups -> /backups
/mnt/user/game_server/steamcmd         -> /steamcmd
```

Copy `compose_files/.env.example` to `compose_files/.env` before starting the Unraid stack.

You can also add this as a classic Unraid Docker template by adding this template URL:

```text
https://raw.githubusercontent.com/bamcel/palworld-wine/main/templates/palworld-wine.xml
```

## Attribution

This image is derived from the WINE-based Palworld container pattern in [`ripps818/palworld-wine`](https://github.com/ripps818/palworld-wine). See `NOTICE` for attribution notes.
