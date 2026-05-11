# SnorlaxBot

SnorlaxBot is a single-file Bash FileBot manager with setup, configuration, qBittorrent integration (native or Docker), transmission-cli testing, and maintenance diagnostics.

## Install

```bash
curl -fsS https://raw.githubusercontent.com/alittler/snorlaxbot/main/install.sh | bash
```

## Run

```bash
/bin/bash ./snorlaxbot.sh
```

## qBittorrent completion automation

Use this hook in qBittorrent (generated dynamically in app summaries):

```bash
/bin/bash "<resolved-script-path>/snorlaxbot.sh" --auto-filebot "%L" "%N" "%F"
```

## Non-interactive auto mode

```bash
/bin/bash ./snorlaxbot.sh --auto-filebot "%L" "%N" "%F"
```
