# SnorlaxBot

SnorlaxBot is a single-file Bash FileBot manager with setup, configuration, qBittorrent integration (native or Docker), transmission-cli testing, and maintenance diagnostics.

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
