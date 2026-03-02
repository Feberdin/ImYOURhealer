# Contributing

## Entwicklungsablauf
1. Kleine, nachvollziehbare Aenderungen machen.
2. Addon in WoW testen (`/imyh`, Instanz-Enter, Boss-Kill, Popup).
3. `/imyh selftest` ausfuehren.
4. Debug-Logs bei Bedarf mit `/imyh debug on` pruefen.

## Coding-Style
- Lesbarer, klar benannter Lua-Code
- Defensive Checks vor externen API-Calls
- Keine still geschluckten Fehler
- Kommentare erklaeren Absicht

## Test-Checklist
- Begruessung nur einmal pro Instanz-Run
- Kein doppelter Gruess bei `/reload`
- Ende-Flow wird nur einmal ausgeloest
- Ja/Nein-Popup sendet richtige Folge-Nachricht
- Heroic-Text wird nur in Heroic angehaengt
