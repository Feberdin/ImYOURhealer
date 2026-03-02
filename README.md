# ImYOURhealer

ImYOURhealer is a WoW TBC Classic addon that automates healer-focused party communication for dungeon runs, including run start/end flow, cooldown announcements, low-mana alerts, and optional PallyPower whisper coordination.

## Why This Addon
Healing in dungeons often means typing the same things over and over: greeting, cooldown calls, rerun questions, and mana status. ImYOURhealer automates that communication while keeping everything configurable in a compact in-game UI.

## Core Features
- One-time greeting when entering an instance run (no spam on wipe/reload)
- End-of-run detection by endboss kill, all bosses killed, or both
- End popup: ask if the group wants another run (yes/no follow-up messages)
- Heroic follow-up list with optional key ownership check
- Cooldown announcements with per-class/per-spell toggles
- Cooldown message suffix with current cooldown duration (for example `CD now: 5:00`)
- Out-of-range warning in combat with configurable delay
- Low-mana alerts with configurable threshold and message scope:
  - Any group
  - Instances only
- Optional extra low-mana hints:
  - Ask for Innervate if a druid is in group
  - Announce mana potion ready/cooldown state
- Auto `/thank` emote when Innervate is cast on you (target restored afterwards)
- PallyPower integration:
  - Whisper each group member their current assignment on instance start
  - Apply whisper requests (`pp ...`) directly to PallyPower
  - Group chat message when a player changes to a different blessing
  - `pp` whisper help supports German and English keywords
- Test mode (`/s` instead of `/p`) and dedicated test tab buttons
- DE/EN language switch
- Minimap button for quick access
- Persistent local addon log (`/imyh log show|clear`)

## UI Overview
The config window is organized into tabs:
- `General`: run flow, heroic checks, range/mana settings, message texts
- `Cooldowns`: global switch + class tabs + spell toggles
- `Tests`: all test buttons and utility toggles (test mode, minimap, debug, persistent log)

## Quick Start
1. Install and enable `ImYOURhealer`.
2. Log in and run `/imyh`.
3. Configure your texts and options.
4. Optional: use the `Tests` tab to verify behavior before running dungeons.

## Commands
- `/imyh` open config
- `/imyh test` send greeting test
- `/imyh testmode` toggle test mode (`/s` output)
- `/imyh lang de|en`
- `/imyh debug on|off`
- `/imyh minimap`
- `/imyh selftest`
- `/imyh keycheck on|off`
- `/imyh ids`
- `/imyh range on|off`
- `/imyh rangetime <1-30>`
- `/imyh cooldown on|off`
- `/imyh pally on|off`
- `/imyh mana on|off`
- `/imyh manathreshold <1-80>`
- `/imyh manascope group|instance`
- `/imyh log on|off|show|clear`

## PallyPower Whisper Examples
- `pp` -> returns usage/help text
- `pp wisdom`
- `pp might`
- `pp kings`
- `pp salv`
- `pp light`
- `pp sanc`

German aliases are also supported, for example:
- `pp weisheit`, `pp macht`, `pp koenige`, `pp erloesung`, `pp licht`, `pp schutz`

## Debug & Troubleshooting
- If no party message is sent, check whether test mode is enabled (`/s` output) or whether you are in a group.
- Low-mana auto alert requires being in a group (and optionally in an instance if `manascope` is set to `instance`).
- Enable debug output: `/imyh debug on`
- Show recent persistent logs: `/imyh log show`
- If a UI issue occurs, post the latest `UI error` / `ERROR` lines from chat/log.

## Data & Privacy
- Configuration is stored locally in `ImYOURhealerDB`.
- No external network communication is used.
- No secrets are required.

## License
Private use in the Feberdin context. Add a formal `LICENSE` file before public redistribution.

## Store Description (EN)
ImYOURhealer is a healer-focused WoW TBC Classic addon that automates party communication across the full dungeon lifecycle: smart run-start messages, configurable completion flow, low-mana and range alerts, cooldown callouts, and practical PallyPower whisper coordination.

## Store Description (DE)
ImYOURhealer ist ein healer-fokussiertes WoW TBC Classic Addon, das die Gruppenkommunikation über den gesamten Instanzverlauf automatisiert: intelligente Startnachrichten, konfigurierbarer Abschluss-Flow, Low-Mana- und Reichweitenwarnungen, Cooldown-Ansagen und praktische PallyPower-Whisper-Koordination.
