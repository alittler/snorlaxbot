# SnorlaxBot

SnorlaxBot is a single-file Bash app that wraps **FileBot AMC** in a FileBot Manager-style terminal UI.  It combines the restored FileBot Manager look-and-feel (with the Snorlax ASCII art header) with enhanced features for qBittorrent integration, Docker support, diagnostics, and automation.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/alittler/snorlaxbot/main/install.sh | sudo bash
```

Or clone and run directly:

```bash
git clone https://github.com/alittler/snorlaxbot.git
cd snorlaxbot
chmod +x snorlaxbot.sh
./snorlaxbot.sh
```

## Usage

```bash
snorlaxbot        # interactive menu
./snorlaxbot.sh   # same, run directly
```

## Menu overview

| Section | Options |
|---|---|
| **SETUP & CONFIGURATION** | Credentials [01], Directories [02], Processing defaults [03], AMC/Hook commands [04], Install deps [05], First-time discovery [06], qBittorrent detection [07], Install hook [08], Verify hook [09], Optimization [10] |
| **CORE PROCESSING** | Run Move Finished [11], Run Move Temp [12], Forced Run [13], Dry Run [14] |
| **SYSTEM & MAINTENANCE** | View logs [15], Search logs [16], Import reports [17], Scrub junk [18], Cleanup preview [19], Wipe history [20], Empty dirs [21], Disk checks [22], Duplicate detection [23], Storage summary [24], Plex test [25], Upgrade [26] |
| **ALERTS & TESTING** | Test notifications [27], Test cycle [28], Config backup [29], BBB via qBittorrent [30], BBB via transmission-cli [31], Integration summary [32] |

## Configuration

Settings are stored in `.env` next to the script (auto-created on first save, `chmod 600`):

```bash
FINISHED_DIR="/mnt/Media/Torrents/finished"
TEMP_DIR="/mnt/Media/Torrents/temp"
WATCH_DIR="/mnt/Media/Torrents/watch"
OUTPUT_BASE="/mnt/Media"
MOVIES_DIR="/mnt/Media/Movies"
SERIES_DIR="/mnt/TV_Shows/TV Shows"
PLEX_HOST="localhost"
PLEX_URL="http://localhost:32400/identity"
PLEX_TOKEN=""
GMAIL_USER=""
GMAIL_PASS=""
PUSHOVER_USER=""
PUSHOVER_TOKEN=""
QB_CONFIG_PATH="~/.config/qBittorrent/qBittorrent.conf"
QBITTORRENT_VARIANT=""
QBITTORRENT_MODE=""
QBITTORRENT_CONTAINER=""
CLEANUP_DAYS=7
```

## qBittorrent completion hook

In qBittorrent → Settings → Downloads → **Run external program on torrent completion**, enter exactly (generated and displayed in menu [04] and [08]):

```
/bin/bash "/path/to/snorlaxbot.sh" --auto-filebot "%L" "%N" "%F"
```

## Non-interactive auto mode

Called automatically by the completion hook to process a single completed torrent:

```bash
/bin/bash ./snorlaxbot.sh --auto-filebot "%L" "%N" "%F"
```

- `%L` — torrent label / save location
- `%N` — torrent name
- `%F` — content file path

The script resolves the best available path and runs FileBot AMC against it.

## Dependencies

Required: `filebot`, `java`  
Recommended: `curl`, `docker`, `docker-compose`  
Optional: `qbittorrent`, `qbittorrent-nox`, `transmission-cli`

Install on Debian/Ubuntu:

```bash
sudo apt-get install -y filebot default-jre curl docker.io docker-compose \
    qbittorrent qbittorrent-nox transmission-cli
```

Use menu option **[05] Install / Re-verify Dependencies** or **[26] SYSTEM UPGRADE** to install and verify from within the app.

## Logs

- `logs/snorlaxbot.log` — runtime log (timestamped)
- `logs/import-report.log` — FileBot run results (success/failure per path)
