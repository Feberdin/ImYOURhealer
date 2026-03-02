--[[
ImYOURhealer - automatic healer run communication for TBC-style 5-man instances.

Purpose:
- Send one greeting when entering a dungeon run.
- Detect final progress (endboss kill and/or all bosses dead) and run an end-of-run flow.
- Ask via popup if the party wants another run and send the selected follow-up message.
- Provide an easy UI + minimap button for non-programmers.

Inputs/Outputs:
- Input: WoW events (zone changes, combat log, saved instance data, popup clicks, slash commands).
- Output: Chat messages to PARTY by default, or SAY in test mode.

Important invariants:
- Greeting is sent only once per run key (instance + difficulty + instance id), never on UI reload.
- End flow triggers once per run key.
- Errors should be visible in chat/debug, not silently swallowed.

How to debug quickly:
1) /imyh debug on
2) Enter a dungeon and watch chat prefixed with [ImYOURhealer].
3) /imyh selftest for helper tests.
4) If message channel surprises you, verify test mode in UI or /imyh testmode.
]]

local addonName = ...
local addon = CreateFrame("Frame", "ImYOURhealerEventFrame")

local DB_NAME = "ImYOURhealerDB"
local UI_FRAME_NAME = "ImYOURhealerConfigFrame"
local MINIMAP_BUTTON_NAME = "ImYOURhealerMinimapButton"

local L = {}
local LOCALES = {
    de = {
        addon_prefix = "ImYOURhealer",
        title = "ImYOURhealer",
        open_ui = "Konfiguration geöffnet.",
        language = "Sprache",
        test_mode = "Testmodus (/s statt /p)",
        show_minimap = "Minimap-Icon anzeigen",
        debug_mode = "Debug-Logs aktiv",
        range_alert = "Out-of-Range Meldung im Kampf",
        range_alert_seconds = "Sekunden bis Meldung",
        mana_alert = "Low-Mana Meldung aktiv",
        mana_alert_threshold = "Mana-Schwelle (%)",
        mana_alert_cooldown = "Cooldown Low-Mana (Sek.)",
        mana_alert_scope = "Mana-Meldung Bereich",
        mana_scope_group = "In jeder Gruppe",
        mana_scope_instance = "Nur in Instanzen",
        mana_alert_text = "Low-Mana Text",
        mana_innervate_hint = "Anregen-Hinweis (bei Druide)",
        mana_pot_status = "ManaPot-Status melden",
        innervate_thanks = "Automatisch Danke bei Anregen",
        cooldown_announce = "Cooldown-Meldungen",
        silence_alert = "Silence-Meldung",
        pallypower_sync = "PallyPower Gruppeninfo bei Instanzstart",
        pallypower_whisper_apply = "PP-Aenderungen aus Chat direkt anwenden",
        pallypower_manual_button = "PallyPower Info jetzt senden",
        key_check = "Heroic-Schluessel pruefen",
        wait_all_in_instance = "Begruessung erst wenn alle in Instanz sind",
        wait_all_timeout = "Warte-Timeout (Sek.)",
        trigger_mode = "Ende-Erkennung",
        trigger_endboss_or_all = "Endboss ODER alle Bosse",
        trigger_endboss_only = "Nur Endboss",
        trigger_all_only = "Nur alle Bosse",
        greeting_message = "Begrüßungstext",
        finish_message = "Abschlussnachricht",
        rerun_message = "Nochmal-Runde Nachricht",
        farewell_message = "Abschiedsnachricht",
        range_alert_text = "Out-of-Range Text",
        reset_texts = "Texte auf Sprach-Standard setzen",
        mana_innervate_text_label = "Anregen-Hinweis Text",
        mana_pot_ready_label = "ManaPot bereit Text",
        mana_pot_cd_label = "ManaPot auf CD Text",
        silence_seconds_label = "Silence Text mit Dauer",
        silence_unknown_label = "Silence Text ohne Dauer",
        silence_interrupt_label = "Interrupt/Silence Text",
        pallypower_group_header_label = "PallyPower Header",
        pallypower_group_hint_label = "PallyPower Umstell-Hinweis",
        pallypower_group_change_label = "PallyPower Aenderungstext",
        test_greeting = "Begrüßung testen",
        test_finish = "Abschluss testen",
        test_rerun_yes = "Rerun Ja testen",
        test_rerun_no = "Rerun Nein testen",
        test_heroic_list = "Heroic-Liste testen",
        test_saved_ids = "Instanz-IDs testen",
        test_range_alert = "Out-of-Range Test",
        test_mana_alert = "Mana-Test",
        test_cooldown = "Cooldown-Test",
        test_pally_whisper = "PallyPower Gruppeninfo-Test",
        test_pally_self = "PallyPower Selbsttest",
        popup_text = "Möchtest du noch eine Instanz laufen?",
        popup_yes = "Ja",
        popup_no = "Nein",
        minimap_tooltip_left = "Linksklick: Einstellungen",
        minimap_tooltip_right = "Rechtsklick: Testmodus umschalten",
        debug_on = "Debug aktiviert.",
        debug_off = "Debug deaktiviert.",
        test_on = "Testmodus aktiviert. Nachrichten gehen in /s.",
        test_off = "Testmodus deaktiviert. Nachrichten gehen in /p.",
        minimap_on = "Minimap-Icon aktiviert.",
        minimap_off = "Minimap-Icon deaktiviert.",
        key_check_on = "Heroic-Schluesselpruefung aktiviert.",
        key_check_off = "Heroic-Schluesselpruefung deaktiviert.",
        range_alert_on = "Out-of-Range Meldungen aktiviert.",
        range_alert_off = "Out-of-Range Meldungen deaktiviert.",
        cooldown_on = "Cooldown-Meldungen aktiviert.",
        cooldown_off = "Cooldown-Meldungen deaktiviert.",
        silence_on = "Silence-Meldungen aktiviert.",
        silence_off = "Silence-Meldungen deaktiviert.",
        pallypower_on = "PallyPower Gruppeninfo aktiviert.",
        pallypower_off = "PallyPower Gruppeninfo deaktiviert.",
        pallypower_apply_on = "PallyPower Chat-Aenderungen aktiviert.",
        pallypower_apply_off = "PallyPower Chat-Aenderungen deaktiviert.",
        unknown_cmd = "Unbekannter Befehl. Nutze /imyh",
        lang_set = "Sprache gesetzt auf",
        non_party_fallback = "Nicht in Gruppe, sende nach /s.",
        greet_default = "Hallo ich bin %s und fuer diese Instanz euer Healer, ich wuensche euch einen schoenen Run.",
        finish_default = "Danke euch, Instanz ist abgeschlossen.",
        rerun_default = "Wollen wir noch eine Runde laufen?",
        farewell_default = "Danke fuer die Gruppe, ich bin fuer heute raus. Viel Erfolg euch!",
        heroic_suffix = "Heroics ohne ID bei mir",
        heroic_all_locked = "Heute habe ich schon alle Heroics mit ID.",
        heroic_missing_key_suffix = "ohne Schluessel",
        heroic_no_key_available = "Offene Heroics, aber Schluessel fehlt",
        heroic_none_found = "Keine Heroic-Liste konfiguriert.",
        saved_ids_header = "Gespeicherte Instanz-IDs:",
        saved_ids_empty = "Keine gespeicherten Instanzen gefunden.",
        range_alert_message = "%s ist seit %d Sek. ausser Reichweite (im Kampf).",
        range_alert_test_message = "Test: %s ist seit %d Sek. ausser Reichweite (im Kampf).",
        mana_alert_default = "ohoh, mein Mana ist knapp",
        mana_innervate_text = "Ein Anregen waere nicht schlecht.",
        mana_pot_ready = "Ich habe noch mein ManaPot frei.",
        mana_pot_cd = "Ich habe CD auf ManaPot.",
        innervate_thanks_done = "Danke fuer Anregen an %s gesendet.",
        pallypower_missing = "PallyPower Daten nicht verfuegbar.",
        pallypower_whisper_header = "PallyPower fuer dich:",
        pallypower_whisper_hint = "Antwort mit: pp wisdom|might|kings|salv|light|sanc",
        pallypower_whisper_ack = "Anfrage erhalten, ich habe es in PallyPower gesetzt.",
        pallypower_whisper_fail = "Konnte PallyPower nicht automatisch aendern.",
        pallypower_whisper_invalid = "Unbekannter Buff-Wunsch. Nutze z.B. 'pp wisdom'.",
        pallypower_whisper_usage = "PP-Hilfe: Schreibe in Gruppe oder per Whisper: pp weisheit|macht|koenige|erloesung|licht|schutz (auch: wisdom|might|kings|salv|light|sanc).",
        pallypower_group_header = "PallyPower Verteilung aktuell:",
        pallypower_group_line = "%s -> %s (%s)",
        pallypower_group_line_missing = "%s -> keine Zuweisung",
        pallypower_group_hint = "Zum Umstellen: pp wisdom, pp might, pp kings, pp salv, pp light oder pp sanc.",
        pallypower_group_change = "%s hat einen anderen PallyPower-Buff gewaehlt: %s.",
        pallypower_manual_sent = "PallyPower Info in Gruppe gesendet (%d Spieler).",
        pallypower_manual_none = "Keine Spieler fuer PallyPower-Info gefunden.",
        pallypower_manual_off = "PallyPower Gruppeninfo ist deaktiviert.",
        tab_paladin = "Paladin",
        tab_priest = "Priester",
        tab_druid = "Druide",
        tab_shaman = "Schamane",
        tab_mage = "Magier",
        tab_warlock = "Hexer",
        tab_warrior = "Krieger",
        tab_rogue = "Schurke",
        tab_hunter = "Jaeger",
        cooldown_target_none = "niemand",
        cooldown_now_prefix = "CD jetzt",
        silence_msg_seconds = "Ich bin %d Sek. gesilenced (%s)!",
        silence_msg_unknown = "Ich bin gesilenced (%s)!",
        silence_msg_interrupt = "Ich bin fuer %d Sek. unterbrochen/gesilenced (%s)!",
        ui_tab_general = "Allgemein",
        ui_tab_cooldowns = "Cooldowns",
        ui_tab_texts = "Texte",
        ui_tab_tests = "Tests",
        pallypower_selftest_ok = "PallyPower Selbsttest abgeschlossen.",
        pallypower_selftest_skip = "PallyPower Selbsttest nur als Paladin sinnvoll.",
        log_enabled = "Persistentes Log aktiv",
        log_on = "Persistentes Log aktiviert.",
        log_off = "Persistentes Log deaktiviert.",
        log_dump_header = "Letzte Logeintraege:",
        log_empty = "Log ist leer.",
        log_cleared = "Log geleert.",
        test_show_logs = "Logs anzeigen",
        test_clear_logs = "Logs leeren",
        cmd_help_1 = "/imyh - UI oeffnen",
        cmd_help_2 = "/imyh test - Begruessung sofort senden",
        cmd_help_3 = "/imyh testmode - /s umschalten",
        cmd_help_4 = "/imyh lang de|en - Sprache wechseln",
        cmd_help_5 = "/imyh debug on|off - Debug umschalten",
        cmd_help_6 = "/imyh minimap - Minimap-Icon umschalten",
        cmd_help_7 = "/imyh selftest - Helfer-Tests laufen lassen",
        cmd_help_8 = "/imyh keycheck on|off - Heroic-Schluesselpruefung",
        cmd_help_9 = "/imyh ids - gespeicherte Instanz-IDs ausgeben",
        cmd_help_10 = "/imyh range on|off - Out-of-Range Meldungen",
        cmd_help_11 = "/imyh rangetime <sek> - Out-of-Range Delay",
        cmd_help_12 = "/imyh cooldown on|off - Cooldown-Meldungen",
        cmd_help_19 = "/imyh silence on|off - Silence-Meldungen",
        cmd_help_13 = "/imyh pally on|off - PallyPower Whisper",
        cmd_help_15 = "/imyh mana on|off - Low-Mana Meldungen",
        cmd_help_16 = "/imyh manathreshold <1-80> - Mana-Schwelle",
        cmd_help_17 = "/imyh manascope group|instance - Mana nur Gruppe oder nur Instanz",
        cmd_help_18 = "/imyh manacd <5-300> - Cooldown fuer Low-Mana Meldung",
        cmd_help_14 = "/imyh log on|off|show|clear - Persistentes Log",
        selftest_ok = "Selftest erfolgreich.",
        selftest_fail = "Selftest fehlgeschlagen",
    },
    en = {
        addon_prefix = "ImYOURhealer",
        title = "ImYOURhealer",
        open_ui = "Configuration opened.",
        language = "Language",
        test_mode = "Test mode (/s instead of /p)",
        show_minimap = "Show minimap icon",
        debug_mode = "Debug logging enabled",
        range_alert = "Out-of-range alert in combat",
        range_alert_seconds = "Seconds before alert",
        mana_alert = "Low mana alert enabled",
        mana_alert_threshold = "Mana threshold (%)",
        mana_alert_cooldown = "Low mana cooldown (sec)",
        mana_alert_scope = "Low mana scope",
        mana_scope_group = "Any group",
        mana_scope_instance = "Instances only",
        mana_alert_text = "Low mana text",
        mana_innervate_hint = "Innervate hint (if druid)",
        mana_pot_status = "Announce mana potion status",
        innervate_thanks = "Auto thank on Innervate",
        cooldown_announce = "Cooldown announcements",
        silence_alert = "Silence alert",
        pallypower_sync = "PallyPower group info on instance start",
        pallypower_whisper_apply = "Apply PP changes from chat directly",
        pallypower_manual_button = "Send PallyPower info now",
        key_check = "Check heroic key ownership",
        wait_all_in_instance = "Wait for all members before greeting",
        wait_all_timeout = "Wait timeout (sec)",
        trigger_mode = "Completion detection",
        trigger_endboss_or_all = "End boss OR all bosses",
        trigger_endboss_only = "End boss only",
        trigger_all_only = "All bosses only",
        greeting_message = "Greeting message",
        finish_message = "Completion message",
        rerun_message = "Another run message",
        farewell_message = "Farewell message",
        range_alert_text = "Out-of-range text",
        reset_texts = "Reset texts to language default",
        mana_innervate_text_label = "Innervate hint text",
        mana_pot_ready_label = "Mana potion ready text",
        mana_pot_cd_label = "Mana potion cooldown text",
        silence_seconds_label = "Silence text with duration",
        silence_unknown_label = "Silence text without duration",
        silence_interrupt_label = "Interrupt/silence text",
        pallypower_group_header_label = "PallyPower header",
        pallypower_group_hint_label = "PallyPower change hint",
        pallypower_group_change_label = "PallyPower change text",
        test_greeting = "Test greeting",
        test_finish = "Test completion",
        test_rerun_yes = "Test rerun yes",
        test_rerun_no = "Test rerun no",
        test_heroic_list = "Test heroic list",
        test_saved_ids = "Test instance IDs",
        test_range_alert = "Test out-of-range",
        test_mana_alert = "Mana test",
        test_cooldown = "Test cooldown",
        test_pally_whisper = "Test PallyPower group info",
        test_pally_self = "PallyPower selftest",
        popup_text = "Do you want to run another instance?",
        popup_yes = "Yes",
        popup_no = "No",
        minimap_tooltip_left = "Left click: settings",
        minimap_tooltip_right = "Right click: toggle test mode",
        debug_on = "Debug enabled.",
        debug_off = "Debug disabled.",
        test_on = "Test mode enabled. Messages go to /s.",
        test_off = "Test mode disabled. Messages go to /p.",
        minimap_on = "Minimap icon enabled.",
        minimap_off = "Minimap icon disabled.",
        key_check_on = "Heroic key check enabled.",
        key_check_off = "Heroic key check disabled.",
        range_alert_on = "Out-of-range alerts enabled.",
        range_alert_off = "Out-of-range alerts disabled.",
        cooldown_on = "Cooldown announcements enabled.",
        cooldown_off = "Cooldown announcements disabled.",
        silence_on = "Silence alerts enabled.",
        silence_off = "Silence alerts disabled.",
        pallypower_on = "PallyPower group info enabled.",
        pallypower_off = "PallyPower group info disabled.",
        pallypower_apply_on = "PallyPower chat apply enabled.",
        pallypower_apply_off = "PallyPower chat apply disabled.",
        unknown_cmd = "Unknown command. Use /imyh",
        lang_set = "Language set to",
        non_party_fallback = "Not in group, sending to /s.",
        greet_default = "Hello, I am %s and your healer for this instance. Wishing you a great run.",
        finish_default = "Thanks everyone, this instance is completed.",
        rerun_default = "Do we want to run another one?",
        farewell_default = "Thanks for the group, I am done for now. Good luck!",
        heroic_suffix = "Heroics I can still run",
        heroic_all_locked = "I am already saved to all heroics today.",
        heroic_missing_key_suffix = "missing key",
        heroic_no_key_available = "Open heroics found, but key missing",
        heroic_none_found = "No heroic list configured.",
        saved_ids_header = "Saved instance IDs:",
        saved_ids_empty = "No saved instances found.",
        range_alert_message = "%s has been out of range for %d sec (in combat).",
        range_alert_test_message = "Test: %s has been out of range for %d sec (in combat).",
        mana_alert_default = "uh oh, my mana is getting low",
        mana_innervate_text = "An Innervate would be great.",
        mana_pot_ready = "I still have my mana potion ready.",
        mana_pot_cd = "My mana potion is on cooldown.",
        innervate_thanks_done = "Sent Innervate thanks to %s.",
        pallypower_missing = "PallyPower data is not available.",
        pallypower_whisper_header = "PallyPower for you:",
        pallypower_whisper_hint = "Reply with: pp wisdom|might|kings|salv|light|sanc",
        pallypower_whisper_ack = "Request received, I set it in PallyPower.",
        pallypower_whisper_fail = "Could not auto-apply PallyPower change.",
        pallypower_whisper_invalid = "Unknown blessing request. Use for example 'pp wisdom'.",
        pallypower_whisper_usage = "PP help: Write in party/raid chat or whisper: pp wisdom|might|kings|salv|light|sanc (also: weisheit|macht|koenige|erloesung|licht|schutz).",
        pallypower_group_header = "Current PallyPower assignments:",
        pallypower_group_line = "%s -> %s (%s)",
        pallypower_group_line_missing = "%s -> no assignment",
        pallypower_group_hint = "To change yours: pp wisdom, pp might, pp kings, pp salv, pp light, or pp sanc.",
        pallypower_group_change = "%s selected a different PallyPower buff: %s.",
        pallypower_manual_sent = "PallyPower group info sent (%d players).",
        pallypower_manual_none = "No players found for PallyPower info.",
        pallypower_manual_off = "PallyPower group info is disabled.",
        tab_paladin = "Paladin",
        tab_priest = "Priest",
        tab_druid = "Druid",
        tab_shaman = "Shaman",
        tab_mage = "Mage",
        tab_warlock = "Warlock",
        tab_warrior = "Warrior",
        tab_rogue = "Rogue",
        tab_hunter = "Hunter",
        cooldown_target_none = "no target",
        cooldown_now_prefix = "CD now",
        silence_msg_seconds = "I am silenced for %d sec (%s)!",
        silence_msg_unknown = "I am silenced (%s)!",
        silence_msg_interrupt = "I am interrupted/silenced for %d sec (%s)!",
        ui_tab_general = "General",
        ui_tab_cooldowns = "Cooldowns",
        ui_tab_texts = "Texts",
        ui_tab_tests = "Tests",
        pallypower_selftest_ok = "PallyPower selftest completed.",
        pallypower_selftest_skip = "PallyPower selftest is mainly useful on paladin.",
        log_enabled = "Persistent log enabled",
        log_on = "Persistent log enabled.",
        log_off = "Persistent log disabled.",
        log_dump_header = "Recent log entries:",
        log_empty = "Log is empty.",
        log_cleared = "Log cleared.",
        test_show_logs = "Show logs",
        test_clear_logs = "Clear logs",
        cmd_help_1 = "/imyh - open UI",
        cmd_help_2 = "/imyh test - send greeting now",
        cmd_help_3 = "/imyh testmode - toggle /s",
        cmd_help_4 = "/imyh lang de|en - switch language",
        cmd_help_5 = "/imyh debug on|off - toggle debug",
        cmd_help_6 = "/imyh minimap - toggle minimap icon",
        cmd_help_7 = "/imyh selftest - run helper tests",
        cmd_help_8 = "/imyh keycheck on|off - heroic key ownership check",
        cmd_help_9 = "/imyh ids - print saved instance IDs",
        cmd_help_10 = "/imyh range on|off - out-of-range alerts",
        cmd_help_11 = "/imyh rangetime <sec> - out-of-range delay",
        cmd_help_12 = "/imyh cooldown on|off - cooldown announcements",
        cmd_help_19 = "/imyh silence on|off - silence alerts",
        cmd_help_13 = "/imyh pally on|off - pallypower whisper sync",
        cmd_help_15 = "/imyh mana on|off - low mana alerts",
        cmd_help_16 = "/imyh manathreshold <1-80> - mana threshold",
        cmd_help_17 = "/imyh manascope group|instance - low mana scope",
        cmd_help_18 = "/imyh manacd <5-300> - low mana alert cooldown",
        cmd_help_14 = "/imyh log on|off|show|clear - persistent log",
        selftest_ok = "Selftest passed.",
        selftest_fail = "Selftest failed",
    },
}

local MESSAGE_PRESETS = {
    de = {
        greeting = LOCALES.de.greet_default,
        finish = LOCALES.de.finish_default,
        rerun = LOCALES.de.rerun_default,
        farewell = LOCALES.de.farewell_default,
        manaLow = LOCALES.de.mana_alert_default,
        rangeAlert = LOCALES.de.range_alert_message,
        manaInnervate = LOCALES.de.mana_innervate_text,
        manaPotReady = LOCALES.de.mana_pot_ready,
        manaPotCd = LOCALES.de.mana_pot_cd,
        silenceSeconds = LOCALES.de.silence_msg_seconds,
        silenceUnknown = LOCALES.de.silence_msg_unknown,
        silenceInterrupt = LOCALES.de.silence_msg_interrupt,
        pallyGroupHeader = LOCALES.de.pallypower_group_header,
        pallyGroupHint = LOCALES.de.pallypower_group_hint,
        pallyGroupChange = LOCALES.de.pallypower_group_change,
    },
    en = {
        greeting = LOCALES.en.greet_default,
        finish = LOCALES.en.finish_default,
        rerun = LOCALES.en.rerun_default,
        farewell = LOCALES.en.farewell_default,
        manaLow = LOCALES.en.mana_alert_default,
        rangeAlert = LOCALES.en.range_alert_message,
        manaInnervate = LOCALES.en.mana_innervate_text,
        manaPotReady = LOCALES.en.mana_pot_ready,
        manaPotCd = LOCALES.en.mana_pot_cd,
        silenceSeconds = LOCALES.en.silence_msg_seconds,
        silenceUnknown = LOCALES.en.silence_msg_unknown,
        silenceInterrupt = LOCALES.en.silence_msg_interrupt,
        pallyGroupHeader = LOCALES.en.pallypower_group_header,
        pallyGroupHint = LOCALES.en.pallypower_group_hint,
        pallyGroupChange = LOCALES.en.pallypower_group_change,
    },
}

-- Boss data for TBC dungeons. We keep both end boss and full list for flexible completion logic.
local BOSS_DATA = {
    ["Hellfire Ramparts"] = { endBoss = "Vazruden the Herald", bosses = { "Watchkeeper Gargolmar", "Omor the Unscarred", "Vazruden the Herald" } },
    ["The Blood Furnace"] = { endBoss = "Keli'dan the Breaker", bosses = { "The Maker", "Broggok", "Keli'dan the Breaker" } },
    ["The Shattered Halls"] = { endBoss = "Warchief Kargath Bladefist", bosses = { "Grand Warlock Nethekurse", "Blood Guard Porung", "Warbringer O'mrogg", "Warchief Kargath Bladefist" } },
    ["The Slave Pens"] = { endBoss = "Quagmirran", bosses = { "Mennu the Betrayer", "Rokmar the Crackler", "Quagmirran" } },
    ["The Underbog"] = { endBoss = "The Black Stalker", bosses = { "Hungarfen", "Ghaz'an", "Swamplord Musel'ek", "The Black Stalker" } },
    ["The Steamvault"] = { endBoss = "Warlord Kalithresh", bosses = { "Hydromancer Thespia", "Mekgineer Steamrigger", "Warlord Kalithresh" } },
    ["Mana-Tombs"] = { endBoss = "Nexus-Prince Shaffar", bosses = { "Pandemonius", "Tavarok", "Nexus-Prince Shaffar" } },
    ["Auchenai Crypts"] = { endBoss = "Exarch Maladaar", bosses = { "Shirrak the Dead Watcher", "Exarch Maladaar" } },
    ["Sethekk Halls"] = { endBoss = "Talon King Ikiss", bosses = { "Darkweaver Syth", "Anzu", "Talon King Ikiss" } },
    ["Shadow Labyrinth"] = { endBoss = "Murmur", bosses = { "Ambassador Hellmaw", "Blackheart the Inciter", "Grandmaster Vorpil", "Murmur" } },
    ["Old Hillsbrad Foothills"] = { endBoss = "Epoch Hunter", bosses = { "Lieutenant Drake", "Captain Skarloc", "Epoch Hunter" } },
    ["The Black Morass"] = { endBoss = "Aeonus", bosses = { "Chrono Lord Deja", "Temporus", "Aeonus" } },
    ["The Mechanar"] = { endBoss = "Pathaleon the Calculator", bosses = { "Gatewatcher Gyro-Kill", "Gatewatcher Iron-Hand", "Mechano-Lord Capacitus", "Nethermancer Sepethrea", "Pathaleon the Calculator" } },
    ["The Botanica"] = { endBoss = "Warp Splinter", bosses = { "Commander Sarannis", "High Botanist Freywinn", "Thorngrin the Tender", "Laj", "Warp Splinter" } },
    ["The Arcatraz"] = { endBoss = "Harbinger Skyriss", bosses = { "Zereketh the Unbound", "Dalliah the Doomsayer", "Wrath-Scryer Soccothrates", "Harbinger Skyriss" } },
    ["Magisters' Terrace"] = { endBoss = "Kael'thas Sunstrider", bosses = { "Selin Fireheart", "Vexallus", "Priestess Delrissa", "Kael'thas Sunstrider" } },

    ["Hoellenfeuerbollwerk"] = { endBoss = "Vazruden der Herold", bosses = { "Wachhabender Gargolmar", "Omor der Narbenlose", "Vazruden der Herold" } },
    ["Der Blutkessel"] = { endBoss = "Keli'dan der Zerstorer", bosses = { "Der Schopfer", "Broggok", "Keli'dan der Zerstorer" } },
    ["Die Zerschmetterten Hallen"] = { endBoss = "Kriegshaeuptling Kargath Messerfaust", bosses = { "Grosshexenmeister Nethekurse", "Blutwache Porung", "Kriegsbringer O'mrogg", "Kriegshaeuptling Kargath Messerfaust" } },
    ["Die Sklavenunterkunfte"] = { endBoss = "Quagmirran", bosses = { "Mennu der Verrater", "Rokmar der Zerquetscher", "Quagmirran" } },
    ["Der Tiefensumpf"] = { endBoss = "Der schwarze Hetzer", bosses = { "Hungarfenn", "Ghaz'an", "Sumpffurst Musel'ek", "Der schwarze Hetzer" } },
    ["Die Dampfkammer"] = { endBoss = "Kriegsherr Kalithresh", bosses = { "Hydromantin Thespia", "Mekgineerdaempfduese", "Kriegsherr Kalithresh" } },
    ["Managruft"] = { endBoss = "Nexusprinz Shaffar", bosses = { "Pandemonius", "Tavarok", "Nexusprinz Shaffar" } },
    ["Auchenaikrypta"] = { endBoss = "Exarch Maladaar", bosses = { "Shirrak der Totenwachter", "Exarch Maladaar" } },
    ["Sethekkhallen"] = { endBoss = "Klauenkonig Ikiss", bosses = { "Dunkelwirker Syth", "Anzu", "Klauenkonig Ikiss" } },
    ["Schattenlabyrinth"] = { endBoss = "Murmur", bosses = { "Botschafter Hollenkessel", "Schwarzherz der Hetzer", "Grossmeister Vorpil", "Murmur" } },
    ["Vorgebirge des Alten Huegellands"] = { endBoss = "Epochenjaeger", bosses = { "Leutnant Drach", "Hauptmann Skarloc", "Epochenjaeger" } },
    ["Der schwarze Morast"] = { endBoss = "Aeonus", bosses = { "Chronolord Deja", "Temporus", "Aeonus" } },
    ["Die Mechanar"] = { endBoss = "Pathaleon der Kalkulator", bosses = { "Torwachter Gyrotod", "Torwachter Eisenhand", "Mechanolord Kapazitus", "Nethermantin Sepethrea", "Pathaleon der Kalkulator" } },
    ["Die Botanika"] = { endBoss = "Warpzweig", bosses = { "Kommandantin Sarannis", "Hochbotaniker Freywinn", "Dornenwirkerin Gytha", "Laj", "Warpzweig" } },
    ["Die Arkatraz"] = { endBoss = "Herold Horiziss", bosses = { "Zereketh der Ungebundene", "Dalliah die Verdammnisverkunderin", "Zornschreier Soccothrates", "Herold Horiziss" } },
    ["Terrasse der Magister"] = { endBoss = "Kael'thas Sonnenwanderer", bosses = { "Selin Feuerherz", "Vexallus", "Priesterin Delrissa", "Kael'thas Sonnenwanderer" } },
}

local HEROIC_POOL = {
    { abbr = "Ramps", names = { "Hellfire Ramparts", "Hoellenfeuerbollwerk" }, keyItemID = 28395 },
    { abbr = "BF", names = { "The Blood Furnace", "Der Blutkessel" }, keyItemID = 28395 },
    { abbr = "SH", names = { "The Shattered Halls", "Die Zerschmetterten Hallen" }, keyItemID = 28395 },
    { abbr = "SP", names = { "The Slave Pens", "Die Sklavenunterkunfte" }, keyItemID = 30623 },
    { abbr = "UB", names = { "The Underbog", "Der Tiefensumpf" }, keyItemID = 30623 },
    { abbr = "SV", names = { "The Steamvault", "Die Dampfkammer" }, keyItemID = 30623 },
    { abbr = "MT", names = { "Mana-Tombs", "Managruft" }, keyItemID = 30633 },
    { abbr = "AC", names = { "Auchenai Crypts", "Auchenaikrypta" }, keyItemID = 30633 },
    { abbr = "Sethekk", names = { "Sethekk Halls", "Sethekkhallen" }, keyItemID = 30633 },
    { abbr = "SL", names = { "Shadow Labyrinth", "Schattenlabyrinth" }, keyItemID = 30633 },
    { abbr = "OHF", names = { "Old Hillsbrad Foothills", "Vorgebirge des Alten Huegellands" }, keyItemID = 30635 },
    { abbr = "BM", names = { "The Black Morass", "Der schwarze Morast" }, keyItemID = 30635 },
    { abbr = "Mech", names = { "The Mechanar", "Die Mechanar" }, keyItemID = 30634 },
    { abbr = "Bota", names = { "The Botanica", "Die Botanika" }, keyItemID = 30634 },
    { abbr = "Arca", names = { "The Arcatraz", "Die Arkatraz" }, keyItemID = 30634 },
    { abbr = "MGT", names = { "Magisters' Terrace", "Terrasse der Magister" } },
}

local CLASS_TAB_ORDER = { "PALADIN", "PRIEST", "DRUID", "SHAMAN", "MAGE", "WARLOCK", "WARRIOR", "ROGUE", "HUNTER" }

-- Major cooldowns by class. We key by spellID to remain locale-safe.
local COOLDOWN_RULES = {
    PALADIN = {
        { spellID = 633, spellIDs = { 633, 2800, 10310, 27154 }, key = "loh", de = "Handauflegen wurde auf %s gewirkt, das war knapp - ich hab kein Mana mehr!", en = "Lay on Hands was cast on %s, that was close - I am out of mana!" },
        { spellID = 1022, spellIDs = { 1022, 5599, 10278 }, key = "bop", de = "%s wurde durch meine Hand geschuetzt, sei vorsichtig kleiner Mitstreiter.", en = "%s was protected by my hand, stay safe little teammate." },
        { spellID = 642, spellIDs = { 642, 1020 }, key = "bubble", de = "Ich habe Gottesschild gezuendet und sichere kurz die Lage.", en = "I used Divine Shield to stabilize this moment." },
        { spellID = 19752, spellIDs = { 19752 }, key = "di", de = "Goettlicher Eingriff auf %s - rettet den Run.", en = "Divine Intervention on %s - save the run." },
    },
    PRIEST = {
        { spellID = 10060, key = "pi", de = "Power Infusion auf %s aktiv.", en = "Power Infusion on %s is active." },
        { spellID = 33206, key = "pain_sup", de = "Pain Suppression auf %s!", en = "Pain Suppression on %s!" },
        { spellID = 34433, key = "shadowfiend", de = "Schattengeist ist draussen fuer Mana.", en = "Shadowfiend is out for mana." },
    },
    DRUID = {
        { spellID = 29166, key = "innervate", de = "Anregen auf %s.", en = "Innervate on %s." },
        { spellID = 20484, key = "rebirth", de = "Wiedergeburt auf %s.", en = "Rebirth on %s." },
        { spellID = 22812, key = "barkskin", de = "Baumrinde aktiv, ich halte durch.", en = "Barkskin active, holding the line." },
    },
    SHAMAN = {
        { spellID = 2825, key = "bloodlust", de = "Kampfrausch aktiv - alles raus!", en = "Bloodlust active - pump damage!" },
        { spellID = 32182, key = "heroism", de = "Heldentum aktiv - alles raus!", en = "Heroism active - go all in!" },
        { spellID = 20608, key = "reincarnation", de = "Wiedergeburt gezuendet, ich bin zurueck.", en = "Reincarnation used, I am back." },
    },
    MAGE = {
        { spellID = 12051, key = "evocation", de = "Evo laeuft, kurz Mana tanken.", en = "Evocation channeling, refilling mana." },
        { spellID = 12472, key = "icy_veins", de = "Eisige Adern aktiv.", en = "Icy Veins active." },
        { spellID = 45438, key = "ice_block", de = "Eisblock aktiv, einen Moment.", en = "Ice Block active, one moment." },
    },
    WARLOCK = {
        { spellID = 1122, key = "infernal", de = "Infernaler beschworen, Druck nach vorn.", en = "Infernal summoned, heavy pressure now." },
        { spellID = 29858, key = "soulshatter", de = "Seelensplitterung gezuendet, Aggro gedroppt.", en = "Soulshatter used, threat dropped." },
        { spellID = 17962, key = "conflagrate", de = "Sofortschaden gezuendet, Burst ist raus.", en = "Burst cooldown popped, damage is out." },
    },
    WARRIOR = {
        { spellID = 871, key = "shield_wall", de = "Schildwall aktiv, ich halte.", en = "Shield Wall active, I am holding." },
        { spellID = 12975, key = "last_stand", de = "Letztes Gefecht gezuendet.", en = "Last Stand used." },
        { spellID = 1719, key = "recklessness", de = "Todeswuensch/Ruchlosigkeit aktiv, alles in den Boss!", en = "Recklessness up, full send on boss!" },
    },
    ROGUE = {
        { spellID = 1856, key = "vanish", de = "Vanish genutzt, ich resette kurz.", en = "Vanish used, quick reset." },
        { spellID = 31224, key = "cloak", de = "Mantel der Schatten aktiv.", en = "Cloak of Shadows active." },
        { spellID = 5277, key = "evasion", de = "Entrinnen aktiv, ich dodge jetzt.", en = "Evasion active, I am dodging now." },
    },
    HUNTER = {
        { spellID = 34477, key = "md", de = "Fehlleitung auf %s.", en = "Misdirection to %s." },
        { spellID = 19574, key = "bestial_wrath", de = "Zorn des Wildtiers aktiv.", en = "Bestial Wrath active." },
        { spellID = 3045, key = "rapid_fire", de = "Schnellfeuer aktiv.", en = "Rapid Fire active." },
    },
}

local defaults = {
    language = (GetLocale() == "deDE" and "de" or "en"),
    testMode = false,
    showMinimap = true,
    debug = false,
    logEnabled = true,
    logMaxEntries = 300,
    rangeAlertEnabled = false,
    rangeAlertSeconds = 4,
    manaAlertEnabled = true,
    manaAlertThreshold = 20,
    manaAlertCooldownSeconds = 30,
    manaAlertScope = "group",
    manaInnervateHintEnabled = true,
    manaPotStatusEnabled = false,
    autoThankInnervate = true,
    cooldownAnnounceEnabled = true,
    silenceAlertEnabled = true,
    pallyPowerWhisperEnabled = true,
    pallyPowerWhisperApplyEnabled = true,
    keyCheckEnabled = true,
    waitAllInInstance = true,
    waitAllInInstanceTimeout = 20,
    triggerMode = "endboss_or_all",
    minimap = {
        angle = 220,
    },
    greetedRuns = {},
    endedRuns = {},
    pallyPowerWhisperRuns = {},
    logs = {},
    cooldownSettings = {
        classEnabled = {},
        spellEnabled = {},
    },
    messages = {
        greeting = "",
        finish = "",
        rerun = "",
        farewell = "",
        manaLow = "",
        rangeAlert = "",
        manaInnervate = "",
        manaPotReady = "",
        manaPotCd = "",
        silenceSeconds = "",
        silenceUnknown = "",
        silenceInterrupt = "",
        pallyGroupHeader = "",
        pallyGroupHint = "",
        pallyGroupChange = "",
    },
}

local state = {
    currentRunKey = nil,
    currentInstanceName = nil,
    currentInstanceType = nil,
    currentDifficultyID = nil,
    currentDifficultyName = nil,
    currentIsHeroic = false,
    killedBosses = {},
    endedThisSession = false,
    ui = {},
    minimapButton = nil,
    rangeAlertTracker = {},
    onUpdateElapsed = 0,
    selectedCooldownClass = "PALADIN",
    manaLowAnnounced = false,
    lastManaAlertAt = 0,
    lastSilenceAlertAt = 0,
    pendingRunStartKey = nil,
    pendingRunStartAt = 0,
    pendingPallyWhisperRunKey = nil,
    pendingWhisperFallbacks = {},
}

local function tcopy(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            out[k] = tcopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function normalizeName(name)
    if not name then
        return ""
    end
    local base = string.match(name, "^[^-]+") or name
    base = string.lower(base)
    -- Keep locale handling deterministic: convert common German umlauts before stripping punctuation.
    base = string.gsub(base, string.char(195, 164), "ae") -- ae
    base = string.gsub(base, string.char(195, 182), "oe") -- oe
    base = string.gsub(base, string.char(195, 188), "ue") -- ue
    base = string.gsub(base, string.char(195, 159), "ss") -- ss
    base = string.gsub(base, "[%s%p]", "")
    return base
end

local function pickLocaleTable(lang)
    return LOCALES[lang] or LOCALES.en
end

local function setLocale(lang)
    L = pickLocaleTable(lang)
end

local function ensureMessagesForLanguage()
    local lang = ImYOURhealerDB.language
    local preset = MESSAGE_PRESETS[lang] or MESSAGE_PRESETS.en

    if not ImYOURhealerDB.messages.greeting or ImYOURhealerDB.messages.greeting == "" then
        ImYOURhealerDB.messages.greeting = preset.greeting
    end
    if not ImYOURhealerDB.messages.finish or ImYOURhealerDB.messages.finish == "" then
        ImYOURhealerDB.messages.finish = preset.finish
    end
    if not ImYOURhealerDB.messages.rerun or ImYOURhealerDB.messages.rerun == "" then
        ImYOURhealerDB.messages.rerun = preset.rerun
    end
    if not ImYOURhealerDB.messages.farewell or ImYOURhealerDB.messages.farewell == "" then
        ImYOURhealerDB.messages.farewell = preset.farewell
    end
    if not ImYOURhealerDB.messages.manaLow or ImYOURhealerDB.messages.manaLow == "" then
        ImYOURhealerDB.messages.manaLow = preset.manaLow
    end
    if not ImYOURhealerDB.messages.rangeAlert or ImYOURhealerDB.messages.rangeAlert == "" then
        ImYOURhealerDB.messages.rangeAlert = preset.rangeAlert
    end
    if not ImYOURhealerDB.messages.manaInnervate or ImYOURhealerDB.messages.manaInnervate == "" then
        ImYOURhealerDB.messages.manaInnervate = preset.manaInnervate
    end
    if not ImYOURhealerDB.messages.manaPotReady or ImYOURhealerDB.messages.manaPotReady == "" then
        ImYOURhealerDB.messages.manaPotReady = preset.manaPotReady
    end
    if not ImYOURhealerDB.messages.manaPotCd or ImYOURhealerDB.messages.manaPotCd == "" then
        ImYOURhealerDB.messages.manaPotCd = preset.manaPotCd
    end
    if not ImYOURhealerDB.messages.silenceSeconds or ImYOURhealerDB.messages.silenceSeconds == "" then
        ImYOURhealerDB.messages.silenceSeconds = preset.silenceSeconds
    end
    if not ImYOURhealerDB.messages.silenceUnknown or ImYOURhealerDB.messages.silenceUnknown == "" then
        ImYOURhealerDB.messages.silenceUnknown = preset.silenceUnknown
    end
    if not ImYOURhealerDB.messages.silenceInterrupt or ImYOURhealerDB.messages.silenceInterrupt == "" then
        ImYOURhealerDB.messages.silenceInterrupt = preset.silenceInterrupt
    end
    if not ImYOURhealerDB.messages.pallyGroupHeader or ImYOURhealerDB.messages.pallyGroupHeader == "" then
        ImYOURhealerDB.messages.pallyGroupHeader = preset.pallyGroupHeader
    end
    if not ImYOURhealerDB.messages.pallyGroupHint or ImYOURhealerDB.messages.pallyGroupHint == "" then
        ImYOURhealerDB.messages.pallyGroupHint = preset.pallyGroupHint
    end
    if not ImYOURhealerDB.messages.pallyGroupChange or ImYOURhealerDB.messages.pallyGroupChange == "" then
        ImYOURhealerDB.messages.pallyGroupChange = preset.pallyGroupChange
    end
end

local function resetMessagesToLanguagePreset()
    local preset = MESSAGE_PRESETS[ImYOURhealerDB.language] or MESSAGE_PRESETS.en
    ImYOURhealerDB.messages.greeting = preset.greeting
    ImYOURhealerDB.messages.finish = preset.finish
    ImYOURhealerDB.messages.rerun = preset.rerun
    ImYOURhealerDB.messages.farewell = preset.farewell
    ImYOURhealerDB.messages.manaLow = preset.manaLow
    ImYOURhealerDB.messages.rangeAlert = preset.rangeAlert
    ImYOURhealerDB.messages.manaInnervate = preset.manaInnervate
    ImYOURhealerDB.messages.manaPotReady = preset.manaPotReady
    ImYOURhealerDB.messages.manaPotCd = preset.manaPotCd
    ImYOURhealerDB.messages.silenceSeconds = preset.silenceSeconds
    ImYOURhealerDB.messages.silenceUnknown = preset.silenceUnknown
    ImYOURhealerDB.messages.silenceInterrupt = preset.silenceInterrupt
    ImYOURhealerDB.messages.pallyGroupHeader = preset.pallyGroupHeader
    ImYOURhealerDB.messages.pallyGroupHint = preset.pallyGroupHint
    ImYOURhealerDB.messages.pallyGroupChange = preset.pallyGroupChange
end

local function printMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF55CCFF[%s]|r %s", L.addon_prefix, tostring(msg)))
end

local function appendLog(level, msg)
    if not ImYOURhealerDB or not ImYOURhealerDB.logEnabled then
        return
    end
    if type(ImYOURhealerDB.logs) ~= "table" then
        ImYOURhealerDB.logs = {}
    end
    local ts = date("%Y-%m-%d %H:%M:%S")
    local line = string.format("%s [%s] %s", ts, tostring(level), tostring(msg))
    table.insert(ImYOURhealerDB.logs, line)
    local maxEntries = tonumber(ImYOURhealerDB.logMaxEntries) or 300
    while #ImYOURhealerDB.logs > maxEntries do
        table.remove(ImYOURhealerDB.logs, 1)
    end
end

local function dprint(msg)
    appendLog("DEBUG", msg)
    if ImYOURhealerDB and ImYOURhealerDB.debug then
        printMsg("DEBUG: " .. tostring(msg))
    end
end

local function logInfo(msg)
    appendLog("INFO", msg)
end

local function logWarn(msg)
    appendLog("WARN", msg)
end

local function logError(msg)
    appendLog("ERROR", msg)
end

local function dumpLogsToChat()
    local logs = (ImYOURhealerDB and ImYOURhealerDB.logs) or {}
    if #logs == 0 then
        printMsg(L.log_empty)
        return
    end
    printMsg(L.log_dump_header)
    local startAt = math.max(1, #logs - 19)
    for i = startAt, #logs do
        printMsg(logs[i])
    end
end

local function clearLogs()
    ImYOURhealerDB.logs = {}
    printMsg(L.log_cleared)
end

local function sanitizeChatText(msg)
    if msg == nil then
        return ""
    end
    local out = tostring(msg)
    out = string.gsub(out, "|", "||")
    out = string.gsub(out, "[\r\n]", " ")
    return out
end

-- External call safety: we always verify chat state and use a fallback channel.
local function getOutputChannel()
    if ImYOURhealerDB.testMode then
        return "SAY"
    end
    if IsInGroup() then
        return "PARTY"
    end
    printMsg(L.non_party_fallback)
    return "SAY"
end

local function safeSend(msg)
    if not msg or msg == "" then
        dprint("safeSend called with empty message")
        return
    end

    local channel = getOutputChannel()
    local text = sanitizeChatText(msg)
    SendChatMessage(text, channel)
    logInfo(string.format("SendChatMessage channel=%s msg=%s", tostring(channel), tostring(text)))
    dprint(string.format("Sent message to %s: %s", channel, text))
end

local function safeSendDelayed(msg, delaySec)
    local delay = tonumber(delaySec) or 0
    if delay > 0 and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(delay, function()
            safeSend(msg)
        end)
        return
    end
    safeSend(msg)
end

local function isHeroicDifficulty(difficultyID, difficultyName)
    if difficultyID == 2 then
        return true
    end
    if type(difficultyName) == "string" then
        local text = string.lower(difficultyName)
        if string.find(text, "heroic", 1, true) or string.find(text, "heroisch", 1, true) then
            return true
        end
    end
    return false
end

local function buildRunKey(instanceName, difficultyID, instanceID)
    if not instanceName or instanceName == "" then
        return nil
    end
    return table.concat({ instanceName, tostring(difficultyID or 0), tostring(instanceID or 0) }, "#")
end

local function safeGetItemCount(itemID)
    if type(GetItemCount) ~= "function" then
        return 0
    end
    local ok, count = pcall(GetItemCount, itemID, true)
    if ok and type(count) == "number" then
        return count
    end
    ok, count = pcall(GetItemCount, itemID)
    if ok and type(count) == "number" then
        return count
    end
    return 0
end

local function hasRequiredHeroicKey(entry)
    if not ImYOURhealerDB.keyCheckEnabled then
        return true
    end
    if not entry.keyItemID then
        return true
    end
    return safeGetItemCount(entry.keyItemID) > 0
end

local function getCurrentInstanceContext()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return nil
    end

    local name, instanceTypeInfo, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    return {
        name = name,
        instanceType = instanceTypeInfo or instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        instanceID = instanceID,
    }
end

-- We only offer heroic suggestions for TBC dungeons and only when in heroic difficulty.
local function buildHeroicOpenList()
    local lockedByName = {}

    local count = GetNumSavedInstances() or 0
    for i = 1, count do
        local name, _, _, difficultyName, locked = GetSavedInstanceInfo(i)
        if locked and isHeroicDifficulty(nil, difficultyName) then
            lockedByName[normalizeName(name)] = true
        end
    end

    local open = {}
    local blockedByMissingKey = {}
    for _, entry in ipairs(HEROIC_POOL) do
        local isLocked = false
        for _, candidate in ipairs(entry.names) do
            if lockedByName[normalizeName(candidate)] then
                isLocked = true
                break
            end
        end
        local hasKey = hasRequiredHeroicKey(entry)
        if not isLocked and hasKey then
            table.insert(open, entry.abbr)
        elseif not isLocked and not hasKey then
            table.insert(blockedByMissingKey, entry.abbr)
        end
    end

    if #open == 0 then
        if ImYOURhealerDB.keyCheckEnabled and #blockedByMissingKey > 0 then
            return string.format("%s: %s", L.heroic_no_key_available, table.concat(blockedByMissingKey, ", "))
        end
        return L.heroic_all_locked
    end
    if ImYOURhealerDB.keyCheckEnabled and #blockedByMissingKey > 0 then
        return string.format("%s | %s: %s", table.concat(open, ", "), L.heroic_missing_key_suffix, table.concat(blockedByMissingKey, ", "))
    end
    return table.concat(open, ", ")
end

local function dumpSavedInstanceIDsToChat()
    printMsg(L.saved_ids_header)
    local count = GetNumSavedInstances() or 0
    if count == 0 then
        printMsg(L.saved_ids_empty)
        return
    end
    for i = 1, count do
        local name, instanceID, reset, difficultyName, locked = GetSavedInstanceInfo(i)
        local line = string.format(
            "%d) %s | id=%s | diff=%s | locked=%s | reset=%s",
            i,
            tostring(name),
            tostring(instanceID),
            tostring(difficultyName),
            tostring(locked),
            tostring(reset)
        )
        printMsg(line)
    end
end

local function sendHeroicTestMessage()
    local heroicList = buildHeroicOpenList()
    local msg = string.format("%s %s: %s", ImYOURhealerDB.messages.rerun, L.heroic_suffix, heroicList)
    safeSend(msg)
end

local function ensureCooldownSettings()
    if type(ImYOURhealerDB.cooldownSettings) ~= "table" then
        ImYOURhealerDB.cooldownSettings = { classEnabled = {}, spellEnabled = {} }
    end
    if type(ImYOURhealerDB.cooldownSettings.classEnabled) ~= "table" then
        ImYOURhealerDB.cooldownSettings.classEnabled = {}
    end
    if type(ImYOURhealerDB.cooldownSettings.spellEnabled) ~= "table" then
        ImYOURhealerDB.cooldownSettings.spellEnabled = {}
    end

    for _, classToken in ipairs(CLASS_TAB_ORDER) do
        if ImYOURhealerDB.cooldownSettings.classEnabled[classToken] == nil then
            ImYOURhealerDB.cooldownSettings.classEnabled[classToken] = true
        end
        for _, rule in ipairs(COOLDOWN_RULES[classToken] or {}) do
            if ImYOURhealerDB.cooldownSettings.spellEnabled[rule.spellID] == nil then
                ImYOURhealerDB.cooldownSettings.spellEnabled[rule.spellID] = true
            end
        end
    end
end

local function getClassTabLabel(classToken)
    if classToken == "PALADIN" then return L.tab_paladin end
    if classToken == "PRIEST" then return L.tab_priest end
    if classToken == "DRUID" then return L.tab_druid end
    if classToken == "SHAMAN" then return L.tab_shaman end
    if classToken == "MAGE" then return L.tab_mage end
    if classToken == "WARLOCK" then return L.tab_warlock end
    if classToken == "WARRIOR" then return L.tab_warrior end
    if classToken == "ROGUE" then return L.tab_rogue end
    if classToken == "HUNTER" then return L.tab_hunter end
    return classToken
end

local INTERRUPT_LOCKOUT_SECONDS = {
    [1766] = 5,     -- Kick
    [2139] = 10,    -- Counterspell
    [6552] = 4,     -- Pummel
    [19647] = 8,    -- Spell Lock
    [15487] = 5,    -- Silence
    [34490] = 3,    -- Silencing Shot
    [8042] = 2,     -- Earth Shock (lockout on interrupt)
}

local function getPlayerDebuffRemaining(spellName)
    if type(UnitDebuff) ~= "function" then
        return nil
    end
    for i = 1, 40 do
        local name, _, _, _, _, duration, expires = UnitDebuff("player", i)
        if not name then
            break
        end
        if name == spellName and duration and duration > 0 and expires and expires > 0 then
            local now = GetTime and GetTime() or 0
            local rem = math.floor((expires - now) + 0.5)
            if rem < 0 then rem = 0 end
            return rem
        end
    end
    return nil
end

local function maybeAnnounceSilenceByAura(destGUID, spellName, auraType)
    if not ImYOURhealerDB.silenceAlertEnabled then
        return
    end
    if destGUID ~= UnitGUID("player") or auraType ~= "DEBUFF" then
        return
    end
    local lower = string.lower(spellName or "")
    local isSilence = string.find(lower, "silence", 1, true)
        or string.find(lower, "silenced", 1, true)
        or string.find(lower, "stille", 1, true)
    if not isSilence then
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - (state.lastSilenceAlertAt or 0)) < 2 then
        return
    end
    local rem = getPlayerDebuffRemaining(spellName)
    if rem and rem > 0 then
        safeSend(string.format(ImYOURhealerDB.messages.silenceSeconds or L.silence_msg_seconds, rem, spellName))
    else
        safeSend(string.format(ImYOURhealerDB.messages.silenceUnknown or L.silence_msg_unknown, spellName or "?"))
    end
    state.lastSilenceAlertAt = now
end

local function maybeAnnounceSilenceByInterrupt(destGUID, spellID, spellName)
    if not ImYOURhealerDB.silenceAlertEnabled then
        return
    end
    if destGUID ~= UnitGUID("player") then
        return
    end
    local seconds = INTERRUPT_LOCKOUT_SECONDS[spellID]
    if not seconds then
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - (state.lastSilenceAlertAt or 0)) < 2 then
        return
    end
    safeSend(string.format(ImYOURhealerDB.messages.silenceInterrupt or L.silence_msg_interrupt, seconds, spellName or "Interrupt"))
    state.lastSilenceAlertAt = now
end

local function getCooldownTextForSpell(spellID)
    if type(GetSpellCooldown) ~= "function" then
        return nil
    end
    local start, duration = GetSpellCooldown(spellID)
    if not duration or duration <= 1.5 then
        return nil
    end
    local total = math.floor(duration + 0.5)
    local min = math.floor(total / 60)
    local sec = total % 60
    local value
    if min > 0 then
        value = string.format("%d:%02d", min, sec)
    else
        value = string.format("%ds", sec)
    end
    return string.format("(%s: %s)", L.cooldown_now_prefix, value)
end

local function formatCooldownMessage(rule, destName, spellID)
    local target = destName
    if not target or target == "" then
        target = L.cooldown_target_none
    end
    local tpl = (ImYOURhealerDB.language == "de" and rule.de) or rule.en or rule.de
    local suffix = getCooldownTextForSpell(spellID or rule.spellID)
    if string.find(tpl, "%s", 1, true) then
        local base = string.format(tpl, target)
        if suffix then
            return base .. " " .. suffix
        end
        return base
    end
    if suffix then
        return tpl .. " " .. suffix
    end
    return tpl
end

local function handlePlayerCooldownCast(spellID, destName)
    if not ImYOURhealerDB.cooldownAnnounceEnabled then
        return
    end
    local _, classToken = UnitClass("player")
    if not classToken then
        return
    end
    if not ImYOURhealerDB.cooldownSettings.classEnabled[classToken] then
        return
    end
    local rules = COOLDOWN_RULES[classToken] or {}
    for _, rule in ipairs(rules) do
        local match = (rule.spellID == spellID)
        if not match and type(rule.spellIDs) == "table" then
            for _, sid in ipairs(rule.spellIDs) do
                if sid == spellID then
                    match = true
                    break
                end
            end
        end
        if match and ImYOURhealerDB.cooldownSettings.spellEnabled[rule.spellID] then
            safeSend(formatCooldownMessage(rule, destName, spellID))
            return
        end
    end
end

local function buildGroupUnits()
    local out = {}
    if IsInRaid() then
        local n = GetNumGroupMembers() or 0
        for i = 1, n do
            local u = "raid" .. i
            if UnitExists(u) and not UnitIsUnit(u, "player") then
                table.insert(out, u)
            end
        end
    else
        local n = 0
        if type(GetNumSubgroupMembers) == "function" then
            n = tonumber(GetNumSubgroupMembers()) or 0
        elseif type(GetNumPartyMembers) == "function" then
            n = tonumber(GetNumPartyMembers()) or 0
        elseif type(GetNumGroupMembers) == "function" and IsInGroup() then
            n = (tonumber(GetNumGroupMembers()) or 1) - 1
        end
        if n < 0 then n = 0 end
        for i = 1, n do
            local u = "party" .. i
            if UnitExists(u) then
                table.insert(out, u)
            end
        end
    end
    return out
end

local function addUnique(list, value)
    if not value or value == "" then
        return
    end
    for _, v in ipairs(list) do
        if v == value then
            return
        end
    end
    table.insert(list, value)
end

local function sendWhisperMessage(msg, target)
    local text = sanitizeChatText(msg)
    local lang = (type(GetDefaultLanguage) == "function" and GetDefaultLanguage("player")) or nil
    local ok, err = pcall(SendChatMessage, text, "WHISPER", lang, target)
    if ok then
        return true
    end
    ok, err = pcall(SendChatMessage, text, "WHISPER", nil, target)
    return ok, err
end

local function getWhisperTargetsByUnit(unit)
    local targets = {}
    local n1, r1 = UnitName(unit)
    local n2, r2 = nil, nil
    if type(UnitFullName) == "function" then
        n2, r2 = UnitFullName(unit)
    end
    local playerName = n2 or n1
    if not playerName or playerName == "" then
        return nil, nil
    end

    local realm = r2 or r1
    if realm and realm ~= "" then
        local realmToken = string.gsub(realm, "[%s%-']", "")
        if realmToken ~= "" then
            addUnique(targets, playerName .. "-" .. realmToken)
        end
    end
    addUnique(targets, playerName)
    return targets, playerName
end

local function isOutOfRange(unit)
    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
        return false
    end
    local inRange = UnitInRange and UnitInRange(unit)
    if inRange == false then
        return true
    end
    if inRange == true then
        return false
    end
    -- Fallback range approximation when UnitInRange is unknown.
    return not CheckInteractDistance(unit, 4)
end

local function updateRangeAlerts()
    if not ImYOURhealerDB.rangeAlertEnabled then
        state.rangeAlertTracker = {}
        return
    end
    if not UnitAffectingCombat("player") then
        state.rangeAlertTracker = {}
        return
    end
    if not IsInGroup() then
        return
    end

    local now = GetTime()
    local threshold = tonumber(ImYOURhealerDB.rangeAlertSeconds) or 4
    if threshold < 1 then
        threshold = 1
    end

    local seen = {}
    for _, unit in ipairs(buildGroupUnits()) do
        local name = UnitName(unit)
        if name then
            seen[name] = true
            local tracker = state.rangeAlertTracker[name] or { outSince = nil, sent = false }
            if isOutOfRange(unit) then
                if not tracker.outSince then
                    tracker.outSince = now
                end
                if not tracker.sent and (now - tracker.outSince) >= threshold then
                    local tpl = ImYOURhealerDB.messages.rangeAlert or L.range_alert_message
                    safeSend(string.format(tpl, name, threshold))
                    tracker.sent = true
                end
            else
                tracker.outSince = nil
                tracker.sent = false
            end
            state.rangeAlertTracker[name] = tracker
        end
    end

    for name in pairs(state.rangeAlertTracker) do
        if not seen[name] then
            state.rangeAlertTracker[name] = nil
        end
    end
end

local function getPlayerManaPercent()
    local cur = UnitPower and UnitPower("player", 0) or UnitMana("player")
    local max = UnitPowerMax and UnitPowerMax("player", 0) or UnitManaMax("player")
    if not max or max <= 0 then
        return 0
    end
    return math.floor((cur / max) * 100 + 0.5)
end

local function groupHasDruid()
    for _, unit in ipairs(buildGroupUnits()) do
        local _, classToken = UnitClass(unit)
        if classToken == "DRUID" then
            return true
        end
    end
    return false
end

local function getManaPotionStatusText()
    -- TBC common mana potions (incl. Fel Mana Potion).
    local manaPotIDs = { 22832, 13444, 31677 }
    local bestItem
    for _, itemID in ipairs(manaPotIDs) do
        if safeGetItemCount(itemID) > 0 then
            bestItem = itemID
            break
        end
    end
    if not bestItem then
        return ImYOURhealerDB.messages.manaPotCd or L.mana_pot_cd
    end
    local start, duration = GetItemCooldown(bestItem)
    if not start or not duration or start == 0 or duration == 0 then
        return ImYOURhealerDB.messages.manaPotReady or L.mana_pot_ready
    end
    return ImYOURhealerDB.messages.manaPotCd or L.mana_pot_cd
end

local function updateManaAlerts()
    if not ImYOURhealerDB.manaAlertEnabled then
        state.manaLowAnnounced = false
        return
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then
        state.manaLowAnnounced = false
        return
    end
    if not IsInGroup() then
        state.manaLowAnnounced = false
        return
    end
    if ImYOURhealerDB.manaAlertScope == "instance" then
        local inInstance, instanceType = IsInInstance()
        if not inInstance or instanceType ~= "party" then
            state.manaLowAnnounced = false
            return
        end
    end

    local threshold = tonumber(ImYOURhealerDB.manaAlertThreshold) or 20
    if threshold < 1 then threshold = 1 end
    if threshold > 80 then threshold = 80 end
    local cooldownSec = tonumber(ImYOURhealerDB.manaAlertCooldownSeconds) or 30
    if cooldownSec < 5 then cooldownSec = 5 end
    if cooldownSec > 300 then cooldownSec = 300 end

    local manaPct = getPlayerManaPercent()
    local now = GetTime and GetTime() or time()
    if manaPct <= threshold and (now - (state.lastManaAlertAt or 0)) >= cooldownSec then
        safeSend(ImYOURhealerDB.messages.manaLow or L.mana_alert_default)
        if ImYOURhealerDB.manaInnervateHintEnabled and groupHasDruid() then
            safeSend(ImYOURhealerDB.messages.manaInnervate or L.mana_innervate_text)
        end
        if ImYOURhealerDB.manaPotStatusEnabled then
            safeSend(getManaPotionStatusText())
        end
        state.lastManaAlertAt = now
        state.manaLowAnnounced = true
        logWarn(string.format("Low mana alert fired at %d%%", manaPct))
        return
    end

    if manaPct >= (threshold + 10) then
        state.manaLowAnnounced = false
    end
end

local function triggerManaAlertTest()
    safeSend(ImYOURhealerDB.messages.manaLow or L.mana_alert_default)
    if ImYOURhealerDB.manaInnervateHintEnabled and groupHasDruid() then
        safeSend(ImYOURhealerDB.messages.manaInnervate or L.mana_innervate_text)
    end
    if ImYOURhealerDB.manaPotStatusEnabled then
        safeSend(getManaPotionStatusText())
    end
end

local function handleInnervateThanks(subevent, sourceName, destGUID, spellID)
    if not ImYOURhealerDB.autoThankInnervate then
        return
    end
    if spellID ~= 29166 then
        return
    end
    if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_CAST_SUCCESS" then
        return
    end
    if destGUID ~= UnitGUID("player") then
        return
    end

    local sourceShort = string.match(sourceName or "", "^[^-]+") or sourceName
    if not sourceShort or sourceShort == "" then
        DoEmote("THANK")
        return
    end

    local hadTarget = UnitExists("target")
    local switched = false
    local previousTargetSame = hadTarget and (normalizeName(UnitName("target")) == normalizeName(sourceShort))

    if previousTargetSame then
        DoEmote("THANK", "target")
    else
        TargetByName(sourceShort, true)
        if UnitExists("target") and normalizeName(UnitName("target")) == normalizeName(sourceShort) then
            switched = true
            DoEmote("THANK", "target")
        else
            DoEmote("THANK", sourceShort)
        end
    end

    if switched then
        if hadTarget then
            TargetLastTarget()
        else
            ClearTarget()
        end
    end
    dprint(string.format(L.innervate_thanks_done, sourceShort))
end

local function shortName(fullName)
    return string.match(fullName or "", "^[^-]+") or fullName
end

local function findGroupUnitByPlayerName(name)
    local target = normalizeName(name)
    if target == "" then
        return nil
    end
    for _, unit in ipairs(buildGroupUnits()) do
        local uname = UnitName(unit)
        if uname and normalizeName(uname) == target then
            return unit
        end
    end
    if normalizeName(UnitName("player")) == target then
        return "player"
    end
    return nil
end

local function isSingleClassInFiveMan(targetClassToken)
    if not targetClassToken or IsInRaid() then
        return false
    end
    local subgroup = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    if (subgroup + 1) ~= 5 then
        return false
    end
    local count = 0
    local _, myClass = UnitClass("player")
    if myClass == targetClassToken then
        count = count + 1
    end
    for _, unit in ipairs(buildGroupUnits()) do
        local _, classToken = UnitClass(unit)
        if classToken == targetClassToken then
            count = count + 1
        end
    end
    return count == 1
end

local function pallyPowerReady()
    return type(PallyPower) == "table"
        and type(PallyPower_Assignments) == "table"
        and type(PallyPower_NormalAssignments) == "table"
        and type(PallyPower.ClassToID) == "table"
        and type(PallyPower.Spells) == "table"
        and type(PallyPower.GSpells) == "table"
end

local function getPallyPowerAssignmentForPlayer(playerName)
    if not pallyPowerReady() then
        return nil
    end
    local unit = findGroupUnitByPlayerName(playerName)
    if not unit then
        return nil
    end
    local _, classToken = UnitClass(unit)
    if not classToken then
        return nil
    end
    local classID = PallyPower.ClassToID[classToken]
    if not classID then
        return nil
    end

    local bestSpell, bestBy
    for paladinName, classTable in pairs(PallyPower_Assignments) do
        local g = classTable and classTable[classID]
        local n = PallyPower_NormalAssignments[paladinName]
            and PallyPower_NormalAssignments[paladinName][classID]
            and PallyPower_NormalAssignments[paladinName][classID][playerName]
        local chosen = tonumber(n or g or 0) or 0
        if chosen > 0 then
            bestSpell = PallyPower.Spells[chosen] or PallyPower.GSpells[chosen]
            bestBy = paladinName
            break
        end
    end
    if not bestSpell then
        return nil
    end
    return bestSpell, bestBy
end

local function buildPallyPowerRoster()
    local roster = {}
    local seen = {}
    local function addUnit(unit)
        if not unit or not UnitExists(unit) then
            return
        end
        local name = UnitName(unit)
        local key = normalizeName(name)
        if key == "" or seen[key] then
            return
        end
        seen[key] = true
        table.insert(roster, { unit = unit, name = name })
    end

    addUnit("player")
    for _, unit in ipairs(buildGroupUnits()) do
        addUnit(unit)
    end
    return roster
end

local function sendPallyPowerWhispers(runKey, force)
    if not ImYOURhealerDB.pallyPowerWhisperEnabled then
        return false, 0, "disabled"
    end
    if not force and ImYOURhealerDB.pallyPowerWhisperRuns[runKey] then
        return true, 0, "already_sent"
    end

    local sentCount = 0
    local roster = buildPallyPowerRoster()
    if #roster == 0 then
        return true, 0, "empty"
    end
    local ppReady = pallyPowerReady()
    if not ppReady then
        dprint(L.pallypower_missing)
    end
    safeSend(ImYOURhealerDB.messages.pallyGroupHeader or L.pallypower_group_header)
    for _, entry in ipairs(roster) do
        local playerName = entry.name
        local text = string.format(L.pallypower_group_line_missing, shortName(playerName or "?"))
        if ppReady then
            local okAssign, spell, by = pcall(getPallyPowerAssignmentForPlayer, playerName)
            if not okAssign then
                logError("getPallyPowerAssignmentForPlayer failed: " .. tostring(spell))
                dprint("PP assign error for " .. tostring(playerName) .. ": " .. tostring(spell))
            elseif spell then
                text = string.format(L.pallypower_group_line, shortName(playerName), tostring(spell), shortName(by or "?"))
            end
        end
        safeSend(text)
        sentCount = sentCount + 1
    end
    safeSendDelayed(ImYOURhealerDB.messages.pallyGroupHint or L.pallypower_group_hint or L.pallypower_whisper_usage, 0.8)
    ImYOURhealerDB.pallyPowerWhisperRuns[runKey] = time()
    dprint(string.format("PallyPower group run=%s count=%d ready=%s", tostring(runKey), sentCount, tostring(ppReady)))
    return true, sentCount, (ppReady and "ok" or "missing")
end

local function triggerPallyPowerWhispersNow()
    local key = string.format("manual-%.3f", (GetTime and GetTime()) or time())
    dprint(string.format("Manual pally info trigger key=%s inGroup=%s raid=%s units=%d", key, tostring(IsInGroup()), tostring(IsInRaid()), #buildGroupUnits()))
    local okCall, ok, count, reason = pcall(sendPallyPowerWhispers, key, true)
    if not okCall then
        logError("triggerPallyPowerWhispersNow failed: " .. tostring(ok))
        printMsg("PallyPower manual whisper error: " .. tostring(ok))
        return
    end
    if not ok then
        state.pendingPallyWhisperRunKey = key
        if reason == "disabled" then
            printMsg(L.pallypower_manual_off)
        else
            printMsg(L.pallypower_missing)
        end
        return
    end
    if (count or 0) > 0 then
        printMsg(string.format(L.pallypower_manual_sent, count))
    else
        printMsg(L.pallypower_manual_none)
    end
end

local function getBlessingIndexFromWhisper(request)
    local r = string.lower(request or "")
    local map = {
        wisdom = 1, weisheit = 1,
        might = 2, macht = 2,
        kings = 3, koenige = 3, kingss = 3,
        salv = 4, salvation = 4, erloesung = 4,
        light = 5, licht = 5,
        sanc = 6, sanctuary = 6, schutz = 6,
    }
    return map[r]
end

local function sendPallyPowerCommandResponse(replyChannel, sender, text)
    local message = sanitizeChatText(text)
    if replyChannel == "WHISPER" then
        SendChatMessage(message, "WHISPER", nil, sender)
        return
    end
    safeSend(string.format("%s: %s", shortName(sender or "?"), message))
end

local function handleWhisperRequest(msg, sender, replyChannel)
    local channel = replyChannel or "WHISPER"
    if not pallyPowerReady() then
        return
    end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PALADIN" then
        return
    end

    local cleaned = string.lower(msg or "")
    cleaned = string.gsub(cleaned, "^%s+", "")
    cleaned = string.gsub(cleaned, "%s+$", "")
    if cleaned == "pp" then
        sendPallyPowerCommandResponse(channel, sender, L.pallypower_whisper_usage)
        return
    end
    if not ImYOURhealerDB.pallyPowerWhisperApplyEnabled then
        return
    end
    local keyword = string.match(cleaned, "^pp%s+([%a]+)")
    if not keyword then
        return
    end

    local buffIndex = getBlessingIndexFromWhisper(keyword)
    if not buffIndex then
        sendPallyPowerCommandResponse(channel, sender, L.pallypower_whisper_invalid)
        return
    end

    local unit = findGroupUnitByPlayerName(sender)
    if not unit then
        sendPallyPowerCommandResponse(channel, sender, L.pallypower_whisper_fail)
        return
    end
    local tname = UnitName(unit)
    local _, targetClassToken = UnitClass(unit)
    local classID = targetClassToken and PallyPower.ClassToID[targetClassToken]
    if not tname or not classID then
        sendPallyPowerCommandResponse(channel, sender, L.pallypower_whisper_fail)
        return
    end

    local me = UnitName("player")
    local useGreater = isSingleClassInFiveMan(targetClassToken)
    local previous

    if useGreater then
        if not PallyPower_Assignments[me] then
            PallyPower_Assignments[me] = {}
        end
        previous = tonumber(PallyPower_Assignments[me][classID] or 0) or 0
        PallyPower_Assignments[me][classID] = buffIndex

        if PallyPower_NormalAssignments[me]
            and PallyPower_NormalAssignments[me][classID]
            and PallyPower_NormalAssignments[me][classID][tname] then
            PallyPower_NormalAssignments[me][classID][tname] = nil
        end

        if type(PallyPower.SendMessage) == "function" then
            PallyPower:SendMessage("ASSIGN " .. tostring(me) .. " " .. tostring(classID) .. " " .. tostring(buffIndex))
        end
    else
        if not PallyPower_NormalAssignments[me] then
            PallyPower_NormalAssignments[me] = {}
        end
        if not PallyPower_NormalAssignments[me][classID] then
            PallyPower_NormalAssignments[me][classID] = {}
        end
        previous = tonumber(PallyPower_NormalAssignments[me][classID][tname] or 0) or 0
        PallyPower_NormalAssignments[me][classID][tname] = buffIndex

        if type(PallyPower.SendNormalBlessings) == "function" then
            PallyPower:SendNormalBlessings(me, classID, tname)
        end
    end
    if type(PallyPower.UpdateLayout) == "function" then
        PallyPower:UpdateLayout()
    end
    sendPallyPowerCommandResponse(channel, sender, L.pallypower_whisper_ack)
    if previous ~= (tonumber(buffIndex) or buffIndex) then
        local spellName = (PallyPower.Spells and PallyPower.Spells[buffIndex]) or (PallyPower.GSpells and PallyPower.GSpells[buffIndex]) or tostring(buffIndex)
        local changeTpl = ImYOURhealerDB.messages.pallyGroupChange or L.pallypower_group_change
        safeSend(string.format(changeTpl, shortName(sender), tostring(spellName)))
    end
end

local function initializeBossTracking(instanceName)
    state.killedBosses = {}
    state.currentInstanceName = instanceName
    dprint("Boss tracking initialized for " .. tostring(instanceName))
end

local function formatGreeting()
    local playerName = UnitName("player") or "Healer"
    return string.format(ImYOURhealerDB.messages.greeting, playerName)
end

local function refreshMinimapPosition()
    if not state.minimapButton then
        return
    end

    local angle = tonumber(ImYOURhealerDB.minimap.angle) or 220
    local radius = 80
    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius
    state.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local createConfigUI

local function toggleConfigUI(show)
    local frame = _G[UI_FRAME_NAME]
    if not frame then
        local ok, err = pcall(createConfigUI)
        if not ok then
            logError("toggleConfigUI/createConfigUI failed: " .. tostring(err))
            printMsg("UI error: " .. tostring(err))
            return
        end
        frame = _G[UI_FRAME_NAME]
        if not frame then
            printMsg("UI error: frame not created.")
            return
        end
    end

    if show == nil then
        show = not frame:IsShown()
    end

    if show then
        if type(frame.SelectMainTab) == "function" then
            frame.SelectMainTab(1)
        end
        frame:Show()
        printMsg(L.open_ui)
    else
        frame:Hide()
    end
end

local function shouldTriggerEndByMode(hitEndBoss, allBossesDown)
    local mode = ImYOURhealerDB.triggerMode
    if mode == "endboss_only" then
        return hitEndBoss
    end
    if mode == "all_only" then
        return allBossesDown
    end
    return hitEndBoss or allBossesDown
end

local function runEndFlow()
    if state.currentRunKey == nil then
        dprint("runEndFlow skipped: no current run key")
        return
    end

    if ImYOURhealerDB.endedRuns[state.currentRunKey] then
        dprint("runEndFlow skipped: already ended for this run")
        return
    end

    ImYOURhealerDB.endedRuns[state.currentRunKey] = true
    state.endedThisSession = true

    if ImYOURhealerDB.messages.finish and ImYOURhealerDB.messages.finish ~= "" then
        safeSend(ImYOURhealerDB.messages.finish)
    end

    StaticPopup_Show("IMYOURHEALER_CONFIRM_RERUN")
end

-- Why this exists:
-- Combat log is the most reliable low-level source in Classic-compatible clients to detect boss deaths.
-- What happens:
-- If a dead unit name matches configured dungeon bosses, we track it and trigger end flow by selected mode.
local function handleBossDeath(destName)
    if not state.currentInstanceName or not state.currentRunKey then
        return
    end
    if ImYOURhealerDB.endedRuns[state.currentRunKey] then
        return
    end

    local bossData = BOSS_DATA[state.currentInstanceName]
    if not bossData then
        return
    end

    local normalizedKilled = normalizeName(destName)
    if normalizedKilled == "" then
        return
    end

    local isKnownBoss = false
    local allBossesDown = true
    local hitEndBoss = normalizeName(bossData.endBoss) == normalizedKilled

    for _, bossName in ipairs(bossData.bosses) do
        local key = normalizeName(bossName)
        if key == normalizedKilled then
            isKnownBoss = true
            state.killedBosses[key] = true
        end
        if not state.killedBosses[key] then
            allBossesDown = false
        end
    end

    if not isKnownBoss then
        return
    end

    dprint(string.format("Boss kill tracked: %s (end=%s, all=%s)", tostring(destName), tostring(hitEndBoss), tostring(allBossesDown)))

    if shouldTriggerEndByMode(hitEndBoss, allBossesDown) then
        runEndFlow()
    end
end

local function sendRerunMessage(accepted)
    if accepted then
        local msg = ImYOURhealerDB.messages.rerun
        if state.currentIsHeroic then
            local heroicList = buildHeroicOpenList()
            if heroicList and heroicList ~= "" then
                msg = string.format("%s %s: %s", msg, L.heroic_suffix, heroicList)
            end
        end
        safeSend(msg)
    else
        safeSend(ImYOURhealerDB.messages.farewell)
    end
end

StaticPopupDialogs["IMYOURHEALER_CONFIRM_RERUN"] = {
    text = "",
    button1 = "",
    button2 = "",
    OnAccept = function()
        sendRerunMessage(true)
    end,
    OnCancel = function()
        sendRerunMessage(false)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function applyPopupLocale()
    local popup = StaticPopupDialogs["IMYOURHEALER_CONFIRM_RERUN"]
    popup.text = L.popup_text
    popup.button1 = L.popup_yes
    popup.button2 = L.popup_no
end

local function areGroupMembersLikelyInsideInstance()
    if not IsInGroup() then
        return true
    end
    for _, unit in ipairs(buildGroupUnits()) do
        if UnitExists(unit) then
            if not UnitIsConnected(unit) then
                return false
            end
            if UnitInRange then
                local inRange = UnitInRange(unit)
                if inRange == false then
                    return false
                end
            end
        end
    end
    return true
end

local function sendRunStartMessages(runKey)
    if not runKey or ImYOURhealerDB.greetedRuns[runKey] then
        return
    end
    ImYOURhealerDB.greetedRuns[runKey] = time()
    safeSend(formatGreeting())
    if not ImYOURhealerDB.pallyPowerWhisperEnabled then
        state.pendingPallyWhisperRunKey = nil
        return
    end
    local ppOK = sendPallyPowerWhispers(runKey)
    if not ppOK then
        state.pendingPallyWhisperRunKey = runKey
    else
        state.pendingPallyWhisperRunKey = nil
    end
end

local function processPendingRunStart()
    local runKey = state.pendingRunStartKey
    if not runKey then
        return
    end
    if runKey ~= state.currentRunKey then
        state.pendingRunStartKey = nil
        state.pendingRunStartAt = 0
        return
    end
    if ImYOURhealerDB.greetedRuns[runKey] then
        state.pendingRunStartKey = nil
        state.pendingRunStartAt = 0
        return
    end

    local timeout = tonumber(ImYOURhealerDB.waitAllInInstanceTimeout) or 20
    if timeout < 5 then timeout = 5 end
    if timeout > 120 then timeout = 120 end
    local waited = time() - (state.pendingRunStartAt or time())

    if areGroupMembersLikelyInsideInstance() or waited >= timeout then
        dprint(string.format("Pending start resolved for %s (waited=%d)", tostring(runKey), tonumber(waited) or 0))
        sendRunStartMessages(runKey)
        state.pendingRunStartKey = nil
        state.pendingRunStartAt = 0
    end
end

local function processPendingPallyWhispers()
    local runKey = state.pendingPallyWhisperRunKey
    if not runKey then
        return
    end
    if not ImYOURhealerDB.pallyPowerWhisperEnabled then
        state.pendingPallyWhisperRunKey = nil
        return
    end
    if runKey ~= state.currentRunKey then
        state.pendingPallyWhisperRunKey = nil
        return
    end
    if ImYOURhealerDB.pallyPowerWhisperRuns[runKey] then
        state.pendingPallyWhisperRunKey = nil
        return
    end
    if sendPallyPowerWhispers(runKey) then
        state.pendingPallyWhisperRunKey = nil
    end
end

local function processExpiredWhisperFallbacks()
    local now = (GetTime and GetTime()) or 0
    for key, item in pairs(state.pendingWhisperFallbacks) do
        if not item or not item.expiresAt or item.expiresAt <= now then
            state.pendingWhisperFallbacks[key] = nil
        end
    end
end

local function handleSystemWhisperFailure(msg)
    local lower = string.lower(msg or "")
    local looksLikeNoPlayer = string.find(lower, "no player named", 1, true)
        or string.find(lower, "is not online", 1, true)
        or string.find(lower, "isn't online", 1, true)
        or string.find(lower, "kein spieler namens", 1, true)
        or string.find(lower, "nicht online", 1, true)
    if not looksLikeNoPlayer then
        return
    end

    for key, item in pairs(state.pendingWhisperFallbacks) do
        if item and item.targets and item.index and item.targets[item.index] then
            local currentTarget = item.targets[item.index]
            local currentLower = string.lower(currentTarget or "")
            local shortLower = string.lower(string.match(currentTarget or "", "^[^-]+") or currentTarget or "")
            if (currentLower ~= "" and string.find(lower, currentLower, 1, true))
                or (shortLower ~= "" and string.find(lower, shortLower, 1, true)) then
                if item.index < #item.targets then
                    item.index = item.index + 1
                    local retryTarget = item.targets[item.index]
                    local okSend, sendErr = sendWhisperMessage(item.text, retryTarget)
                    if okSend then
                        dprint("Whisper fallback attempted to " .. tostring(retryTarget))
                    else
                        dprint("Whisper fallback failed to " .. tostring(retryTarget) .. ": " .. tostring(sendErr))
                        state.pendingWhisperFallbacks[key] = nil
                    end
                else
                    state.pendingWhisperFallbacks[key] = nil
                end
                return
            end
        end
    end
end

local function enterInstanceIfNeeded(reason, isInitialLogin, isReloadingUi)
    local ctx = getCurrentInstanceContext()
    if not ctx then
        state.currentRunKey = nil
        state.currentInstanceName = nil
        state.currentIsHeroic = false
        state.pendingRunStartKey = nil
        state.pendingRunStartAt = 0
        state.pendingPallyWhisperRunKey = nil
        return
    end

    if ctx.instanceType ~= "party" then
        return
    end

    local runKey = buildRunKey(ctx.name, ctx.difficultyID, ctx.instanceID)
    if not runKey then
        return
    end

    state.currentRunKey = runKey
    state.currentInstanceType = ctx.instanceType
    state.currentDifficultyID = ctx.difficultyID
    state.currentDifficultyName = ctx.difficultyName
    state.currentIsHeroic = isHeroicDifficulty(ctx.difficultyID, ctx.difficultyName)

    initializeBossTracking(ctx.name)

    -- Skip greeting on initial login and UI reload to avoid noise.
    if isInitialLogin or isReloadingUi then
        dprint(string.format("Greeting skipped (%s): initial=%s reload=%s", reason, tostring(isInitialLogin), tostring(isReloadingUi)))
        return
    end

    if ImYOURhealerDB.greetedRuns[runKey] then
        dprint("Greeting already sent for run key " .. runKey)
        return
    end

    if ImYOURhealerDB.waitAllInInstance and not areGroupMembersLikelyInsideInstance() then
        state.pendingRunStartKey = runKey
        state.pendingRunStartAt = time()
        dprint(string.format("Greeting delayed until group is inside (run=%s)", tostring(runKey)))
        return
    end

    sendRunStartMessages(runKey)
end

local function createEditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    box:SetMultiLine(true)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:ClearFocus()
    end)
    return box
end

local function createLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function setCheckButtonLabel(checkButton, labelText)
    local buttonName = checkButton:GetName()
    local textRegion = buttonName and _G[buttonName .. "Text"] or nil
    if textRegion then
        textRegion:SetText(labelText)
        return
    end

    if checkButton._imyrhLabel and checkButton._imyrhLabel.SetText then
        checkButton._imyrhLabel:SetText(labelText)
        return
    end

    local label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkButton, "RIGHT", 2, 1)
    label:SetText(labelText or "")
    checkButton._imyrhLabel = label
end

local function createDropdown(parent, width, values, onChanged)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetWidth(width)

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, value in ipairs(values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = value.label
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dd, value.key)
                onChanged(value.key)
            end
            info.value = value.key
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return dd
end

-- Why this exists:
-- Non-programmers should configure behavior quickly without slash commands.
-- What happens:
-- We build a single panel with grouped options and editable message templates.
createConfigUI = function()
    if _G[UI_FRAME_NAME] then
        return
    end

    local frame = CreateFrame("Frame", UI_FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(620, 650)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText(L.title)

    local pages = {}
    local function makePage()
        local p = CreateFrame("Frame", nil, frame)
        p:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
        p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 24)
        p:Hide()
        return p
    end
    pages[1] = makePage()
    pages[2] = makePage()
    pages[3] = makePage()
    pages[4] = makePage()

    local mainTabs = {}
    local function setTabSelected(btn, selected)
        if not btn then
            return
        end
        local textObj = btn.Text or (btn.GetFontString and btn:GetFontString()) or nil
        if selected then
            btn:LockHighlight()
            if textObj and textObj.SetTextColor then
                textObj:SetTextColor(1, 1, 1)
            end
        else
            btn:UnlockHighlight()
            if textObj and textObj.SetTextColor then
                textObj:SetTextColor(1, 0.82, 0)
            end
        end
    end

    local function selectMainTab(tabID)
        for i = 1, #pages do
            pages[i]:SetShown(i == tabID)
            setTabSelected(mainTabs[i], i == tabID)
        end
    end
    frame.SelectMainTab = selectMainTab

    local tabGeneral = CreateFrame("Button", UI_FRAME_NAME .. "Tab1", frame, "GameMenuButtonTemplate")
    tabGeneral:SetID(1)
    tabGeneral:SetSize(120, 24)
    tabGeneral:SetText(L.ui_tab_general)
    tabGeneral:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -28)
    tabGeneral:SetScript("OnClick", function() selectMainTab(1) end)
    mainTabs[1] = tabGeneral

    local tabCooldowns = CreateFrame("Button", UI_FRAME_NAME .. "Tab2", frame, "GameMenuButtonTemplate")
    tabCooldowns:SetID(2)
    tabCooldowns:SetSize(120, 24)
    tabCooldowns:SetText(L.ui_tab_cooldowns)
    tabCooldowns:SetPoint("LEFT", tabGeneral, "RIGHT", 6, 0)
    tabCooldowns:SetScript("OnClick", function() selectMainTab(2) end)
    mainTabs[2] = tabCooldowns

    local tabTexts = CreateFrame("Button", UI_FRAME_NAME .. "Tab3", frame, "GameMenuButtonTemplate")
    tabTexts:SetID(3)
    tabTexts:SetSize(120, 24)
    tabTexts:SetText(L.ui_tab_texts)
    tabTexts:SetPoint("LEFT", tabCooldowns, "RIGHT", 6, 0)
    tabTexts:SetScript("OnClick", function() selectMainTab(3) end)
    mainTabs[3] = tabTexts

    local tabTests = CreateFrame("Button", UI_FRAME_NAME .. "Tab4", frame, "GameMenuButtonTemplate")
    tabTests:SetID(4)
    tabTests:SetSize(120, 24)
    tabTests:SetText(L.ui_tab_tests)
    tabTests:SetPoint("LEFT", tabTexts, "RIGHT", 6, 0)
    tabTests:SetScript("OnClick", function() selectMainTab(4) end)
    mainTabs[4] = tabTests

    -- Page 1: General
    local general = pages[1]
    local leftX = 0
    local rightX = 340
    local rowStep = 32
    local yTop = -8

    createLabel(general, L.language, leftX, yTop)
    local langDD = createDropdown(general, 130, {
        { key = "de", label = "Deutsch" },
        { key = "en", label = "English" },
    }, function(key)
        ImYOURhealerDB.language = key
        setLocale(key)
        resetMessagesToLanguagePreset()
        applyPopupLocale()
        frame:Hide()
        _G[UI_FRAME_NAME] = nil
        createConfigUI()
        toggleConfigUI(true)
        printMsg(L.lang_set .. ": " .. key)
    end)
    langDD:SetPoint("TOPLEFT", general, "TOPLEFT", 100, yTop + 10)
    UIDropDownMenu_SetSelectedValue(langDD, ImYOURhealerDB.language)

    local leftY = yTop - 50
    local rightY = yTop - 50

    local keyCheckCB = CreateFrame("CheckButton", "ImYOURhealerKeyCheckCB", general, "UICheckButtonTemplate")
    keyCheckCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(keyCheckCB, L.key_check)
    keyCheckCB:SetChecked(ImYOURhealerDB.keyCheckEnabled)
    keyCheckCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.keyCheckEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.keyCheckEnabled and L.key_check_on or L.key_check_off)
    end)
    leftY = leftY - rowStep

    local waitAllCB = CreateFrame("CheckButton", "ImYOURhealerWaitAllCB", general, "UICheckButtonTemplate")
    waitAllCB:SetPoint("TOPLEFT", general, "TOPLEFT", rightX, rightY)
    setCheckButtonLabel(waitAllCB, L.wait_all_in_instance)
    waitAllCB:SetChecked(ImYOURhealerDB.waitAllInInstance)
    waitAllCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.waitAllInInstance = self:GetChecked() and true or false
    end)
    rightY = rightY - rowStep

    createLabel(general, L.wait_all_timeout, rightX + 22, rightY + 3)
    local waitTimeoutBox = CreateFrame("EditBox", "ImYOURhealerWaitTimeoutBox", general, "InputBoxTemplate")
    waitTimeoutBox:SetSize(48, 20)
    waitTimeoutBox:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 190, rightY + 4)
    waitTimeoutBox:SetAutoFocus(false)
    waitTimeoutBox:SetNumeric(true)
    waitTimeoutBox:SetMaxLetters(3)
    waitTimeoutBox:SetText(tostring(ImYOURhealerDB.waitAllInInstanceTimeout or 20))
    waitTimeoutBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 5 and val <= 120 then
            ImYOURhealerDB.waitAllInInstanceTimeout = val
        end
        self:SetText(tostring(ImYOURhealerDB.waitAllInInstanceTimeout or 20))
        self:ClearFocus()
    end)
    waitTimeoutBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 5 and val <= 120 then
            ImYOURhealerDB.waitAllInInstanceTimeout = val
        end
        self:SetText(tostring(ImYOURhealerDB.waitAllInInstanceTimeout or 20))
    end)
    rightY = rightY - rowStep

    local rangeCB = CreateFrame("CheckButton", "ImYOURhealerRangeCB", general, "UICheckButtonTemplate")
    rangeCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(rangeCB, L.range_alert)
    rangeCB:SetChecked(ImYOURhealerDB.rangeAlertEnabled)
    rangeCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.rangeAlertEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.rangeAlertEnabled and L.range_alert_on or L.range_alert_off)
    end)
    leftY = leftY - rowStep

    createLabel(general, L.range_alert_seconds, rightX + 22, rightY + 3)
    local rangeSecondsBox = CreateFrame("EditBox", "ImYOURhealerRangeSecondsBox", general, "InputBoxTemplate")
    rangeSecondsBox:SetSize(48, 20)
    rangeSecondsBox:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 190, rightY + 4)
    rangeSecondsBox:SetAutoFocus(false)
    rangeSecondsBox:SetNumeric(true)
    rangeSecondsBox:SetMaxLetters(2)
    rangeSecondsBox:SetText(tostring(ImYOURhealerDB.rangeAlertSeconds or 4))
    rangeSecondsBox:SetScript("OnEnterPressed", function(self)
        local sec = tonumber(self:GetText())
        if sec and sec >= 1 and sec <= 30 then
            ImYOURhealerDB.rangeAlertSeconds = sec
        else
            self:SetText(tostring(ImYOURhealerDB.rangeAlertSeconds or 4))
        end
        self:ClearFocus()
    end)
    rangeSecondsBox:SetScript("OnEditFocusLost", function(self)
        local sec = tonumber(self:GetText())
        if sec and sec >= 1 and sec <= 30 then
            ImYOURhealerDB.rangeAlertSeconds = sec
        end
        self:SetText(tostring(ImYOURhealerDB.rangeAlertSeconds or 4))
    end)
    rightY = rightY - rowStep

    local manaCB = CreateFrame("CheckButton", "ImYOURhealerManaCB", general, "UICheckButtonTemplate")
    manaCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(manaCB, L.mana_alert)
    manaCB:SetChecked(ImYOURhealerDB.manaAlertEnabled)
    manaCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaAlertEnabled = self:GetChecked() and true or false
    end)
    leftY = leftY - rowStep

    createLabel(general, L.mana_alert_threshold, rightX + 22, rightY + 3)
    local manaThresholdBox = CreateFrame("EditBox", "ImYOURhealerManaThresholdBox", general, "InputBoxTemplate")
    manaThresholdBox:SetSize(48, 20)
    manaThresholdBox:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 190, rightY + 4)
    manaThresholdBox:SetAutoFocus(false)
    manaThresholdBox:SetNumeric(true)
    manaThresholdBox:SetMaxLetters(2)
    manaThresholdBox:SetText(tostring(ImYOURhealerDB.manaAlertThreshold or 20))
    manaThresholdBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 80 then
            ImYOURhealerDB.manaAlertThreshold = val
        end
        self:SetText(tostring(ImYOURhealerDB.manaAlertThreshold or 20))
        self:ClearFocus()
    end)
    manaThresholdBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 80 then
            ImYOURhealerDB.manaAlertThreshold = val
        end
        self:SetText(tostring(ImYOURhealerDB.manaAlertThreshold or 20))
    end)
    rightY = rightY - rowStep

    createLabel(general, L.mana_alert_cooldown, rightX + 22, rightY + 3)
    local manaCooldownBox = CreateFrame("EditBox", "ImYOURhealerManaCooldownBox", general, "InputBoxTemplate")
    manaCooldownBox:SetSize(48, 20)
    manaCooldownBox:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 190, rightY + 4)
    manaCooldownBox:SetAutoFocus(false)
    manaCooldownBox:SetNumeric(true)
    manaCooldownBox:SetMaxLetters(3)
    manaCooldownBox:SetText(tostring(ImYOURhealerDB.manaAlertCooldownSeconds or 30))
    manaCooldownBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 5 and val <= 300 then
            ImYOURhealerDB.manaAlertCooldownSeconds = val
        end
        self:SetText(tostring(ImYOURhealerDB.manaAlertCooldownSeconds or 30))
        self:ClearFocus()
    end)
    manaCooldownBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 5 and val <= 300 then
            ImYOURhealerDB.manaAlertCooldownSeconds = val
        end
        self:SetText(tostring(ImYOURhealerDB.manaAlertCooldownSeconds or 30))
    end)
    rightY = rightY - rowStep

    createLabel(general, L.mana_alert_scope, rightX + 22, rightY + 3)
    local manaScopeDD = createDropdown(general, 190, {
        { key = "group", label = L.mana_scope_group },
        { key = "instance", label = L.mana_scope_instance },
    }, function(key)
        ImYOURhealerDB.manaAlertScope = key
    end)
    manaScopeDD:SetPoint("TOPLEFT", general, "TOPLEFT", rightX + 50, rightY + 12)
    UIDropDownMenu_SetSelectedValue(manaScopeDD, ImYOURhealerDB.manaAlertScope or "group")
    rightY = rightY - rowStep

    local manaInnervateCB = CreateFrame("CheckButton", "ImYOURhealerManaInnervateCB", general, "UICheckButtonTemplate")
    manaInnervateCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(manaInnervateCB, L.mana_innervate_hint)
    manaInnervateCB:SetChecked(ImYOURhealerDB.manaInnervateHintEnabled)
    manaInnervateCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaInnervateHintEnabled = self:GetChecked() and true or false
    end)
    leftY = leftY - rowStep

    local manaPotCB = CreateFrame("CheckButton", "ImYOURhealerManaPotCB", general, "UICheckButtonTemplate")
    manaPotCB:SetPoint("TOPLEFT", general, "TOPLEFT", rightX, rightY)
    setCheckButtonLabel(manaPotCB, L.mana_pot_status)
    manaPotCB:SetChecked(ImYOURhealerDB.manaPotStatusEnabled)
    manaPotCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaPotStatusEnabled = self:GetChecked() and true or false
    end)
    rightY = rightY - rowStep

    local innervateThanksCB = CreateFrame("CheckButton", "ImYOURhealerInnervateThanksCB", general, "UICheckButtonTemplate")
    innervateThanksCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(innervateThanksCB, L.innervate_thanks)
    innervateThanksCB:SetChecked(ImYOURhealerDB.autoThankInnervate)
    innervateThanksCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.autoThankInnervate = self:GetChecked() and true or false
    end)
    leftY = leftY - rowStep

    local cooldownCB = CreateFrame("CheckButton", "ImYOURhealerCooldownCB", general, "UICheckButtonTemplate")
    cooldownCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(cooldownCB, L.cooldown_announce)
    cooldownCB:SetChecked(ImYOURhealerDB.cooldownAnnounceEnabled)
    cooldownCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.cooldownAnnounceEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.cooldownAnnounceEnabled and L.cooldown_on or L.cooldown_off)
    end)
    leftY = leftY - rowStep

    local silenceCB = CreateFrame("CheckButton", "ImYOURhealerSilenceCB", general, "UICheckButtonTemplate")
    silenceCB:SetPoint("TOPLEFT", general, "TOPLEFT", rightX, rightY)
    setCheckButtonLabel(silenceCB, L.silence_alert)
    silenceCB:SetChecked(ImYOURhealerDB.silenceAlertEnabled)
    silenceCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.silenceAlertEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.silenceAlertEnabled and L.silence_on or L.silence_off)
    end)
    rightY = rightY - rowStep

    local pallyCB = CreateFrame("CheckButton", "ImYOURhealerPallyWhisperCB", general, "UICheckButtonTemplate")
    pallyCB:SetPoint("TOPLEFT", general, "TOPLEFT", leftX, leftY)
    setCheckButtonLabel(pallyCB, L.pallypower_sync)
    pallyCB:SetChecked(ImYOURhealerDB.pallyPowerWhisperEnabled)
    pallyCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.pallyPowerWhisperEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.pallyPowerWhisperEnabled and L.pallypower_on or L.pallypower_off)
    end)
    leftY = leftY - rowStep

    local pallyApplyCB = CreateFrame("CheckButton", "ImYOURhealerPallyApplyCB", general, "UICheckButtonTemplate")
    pallyApplyCB:SetPoint("TOPLEFT", general, "TOPLEFT", rightX, rightY)
    setCheckButtonLabel(pallyApplyCB, L.pallypower_whisper_apply)
    pallyApplyCB:SetChecked(ImYOURhealerDB.pallyPowerWhisperApplyEnabled)
    pallyApplyCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.pallyPowerWhisperApplyEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.pallyPowerWhisperApplyEnabled and L.pallypower_apply_on or L.pallypower_apply_off)
    end)
    rightY = rightY - rowStep

    local pallyManualBtn = CreateFrame("Button", nil, general, "GameMenuButtonTemplate")
    pallyManualBtn:SetSize(230, 24)
    pallyManualBtn:SetPoint("TOPLEFT", general, "TOPLEFT", rightX, rightY)
    pallyManualBtn:SetText(L.pallypower_manual_button)
    pallyManualBtn:SetScript("OnClick", function()
        triggerPallyPowerWhispersNow()
    end)
    rightY = rightY - 44

    createLabel(general, L.trigger_mode, leftX, leftY - 6)
    local triggerDD = createDropdown(general, 250, {
        { key = "endboss_or_all", label = L.trigger_endboss_or_all },
        { key = "endboss_only", label = L.trigger_endboss_only },
        { key = "all_only", label = L.trigger_all_only },
    }, function(key)
        ImYOURhealerDB.triggerMode = key
    end)
    triggerDD:SetPoint("TOPLEFT", general, "TOPLEFT", 140, leftY + 4)
    UIDropDownMenu_SetSelectedValue(triggerDD, ImYOURhealerDB.triggerMode)

    -- Page 2: Cooldowns with real class tabs
    local cooldownPage = pages[2]
    local cY = -8
    createLabel(cooldownPage, L.cooldown_announce, 0, cY)
    local cooldownGlobalCB = CreateFrame("CheckButton", "ImYOURhealerCooldownGlobalCB", cooldownPage, "UICheckButtonTemplate")
    cooldownGlobalCB:SetPoint("TOPLEFT", cooldownPage, "TOPLEFT", 230, cY + 1)
    setCheckButtonLabel(cooldownGlobalCB, "")
    cooldownGlobalCB:SetChecked(ImYOURhealerDB.cooldownAnnounceEnabled)
    cooldownGlobalCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.cooldownAnnounceEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.cooldownAnnounceEnabled and L.cooldown_on or L.cooldown_off)
    end)

    local classTabHost = CreateFrame("Frame", nil, cooldownPage)
    classTabHost:SetPoint("TOPLEFT", cooldownPage, "TOPLEFT", 0, -28)
    classTabHost:SetSize(560, 52)
    local classPages = {}
    local classTabs = {}

    local function showClassTab(tabID)
        state.selectedCooldownClass = CLASS_TAB_ORDER[tabID]
        for i = 1, #classPages do
            classPages[i]:SetShown(i == tabID)
            setTabSelected(classTabs[i], i == tabID)
        end
    end

    for i, classToken in ipairs(CLASS_TAB_ORDER) do
        local tab = CreateFrame("Button", nil, classTabHost, "GameMenuButtonTemplate")
        tab:SetID(i)
        tab:SetSize(104, 22)
        tab:SetText(getClassTabLabel(classToken))
        local col = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        tab:SetPoint("TOPLEFT", classTabHost, "TOPLEFT", col * 110, -row * 24)
        tab:SetScript("OnClick", function() showClassTab(i) end)
        classTabs[i] = tab

        local classFrame = CreateFrame("Frame", nil, cooldownPage)
        classFrame:SetPoint("TOPLEFT", cooldownPage, "TOPLEFT", 0, -90)
        classFrame:SetSize(560, 420)
        classFrame:Hide()
        classPages[i] = classFrame

        local classCB = CreateFrame("CheckButton", nil, classFrame, "UICheckButtonTemplate")
        classCB:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 0, 0)
        setCheckButtonLabel(classCB, getClassTabLabel(classToken))
        classCB:SetChecked(ImYOURhealerDB.cooldownSettings.classEnabled[classToken])
        classCB:SetScript("OnClick", function(self)
            ImYOURhealerDB.cooldownSettings.classEnabled[classToken] = self:GetChecked() and true or false
        end)

        for idx, rule in ipairs(COOLDOWN_RULES[classToken] or {}) do
            local row = CreateFrame("CheckButton", nil, classFrame, "UICheckButtonTemplate")
            row:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 0, -26 - ((idx - 1) * 24))
            local spellName = GetSpellInfo(rule.spellID) or ("spell#" .. tostring(rule.spellID))
            setCheckButtonLabel(row, spellName)
            row:SetChecked(ImYOURhealerDB.cooldownSettings.spellEnabled[rule.spellID])
            row:SetScript("OnClick", function(self)
                ImYOURhealerDB.cooldownSettings.spellEnabled[rule.spellID] = self:GetChecked() and true or false
            end)
        end
    end
    showClassTab(1)

    -- Page 3: Text messages
    local texts = pages[3]
    local textBoxes = {}
    local textFieldIndex = 0
    local textColX = { 0, 286 }
    local textStartY = -8
    local textStepY = 66

    local function addMessageField(labelText, key, fallback)
        textFieldIndex = textFieldIndex + 1
        local col = ((textFieldIndex - 1) % 2) + 1
        local row = math.floor((textFieldIndex - 1) / 2)
        local x = textColX[col]
        local y = textStartY - (row * textStepY)

        createLabel(texts, labelText, x, y)
        local box = createEditBox(texts, 270, 28)
        box:SetPoint("TOPLEFT", texts, "TOPLEFT", x, y - 18)
        box:SetText(ImYOURhealerDB.messages[key] or fallback or "")
        box:SetScript("OnTextChanged", function(self)
            ImYOURhealerDB.messages[key] = self:GetText()
        end)
        textBoxes[key] = box
    end

    addMessageField(L.greeting_message, "greeting", L.greet_default)
    addMessageField(L.finish_message, "finish", L.finish_default)
    addMessageField(L.rerun_message, "rerun", L.rerun_default)
    addMessageField(L.farewell_message, "farewell", L.farewell_default)
    addMessageField(L.mana_alert_text, "manaLow", L.mana_alert_default)
    addMessageField(L.range_alert_text, "rangeAlert", L.range_alert_message)
    addMessageField(L.mana_innervate_text_label, "manaInnervate", L.mana_innervate_text)
    addMessageField(L.mana_pot_ready_label, "manaPotReady", L.mana_pot_ready)
    addMessageField(L.mana_pot_cd_label, "manaPotCd", L.mana_pot_cd)
    addMessageField(L.silence_seconds_label, "silenceSeconds", L.silence_msg_seconds)
    addMessageField(L.silence_unknown_label, "silenceUnknown", L.silence_msg_unknown)
    addMessageField(L.silence_interrupt_label, "silenceInterrupt", L.silence_msg_interrupt)
    addMessageField(L.pallypower_group_header_label, "pallyGroupHeader", L.pallypower_group_header)
    addMessageField(L.pallypower_group_hint_label, "pallyGroupHint", L.pallypower_group_hint)
    addMessageField(L.pallypower_group_change_label, "pallyGroupChange", L.pallypower_group_change)

    local resetBtn = CreateFrame("Button", nil, texts, "GameMenuButtonTemplate")
    resetBtn:SetSize(250, 24)
    resetBtn:SetPoint("BOTTOMLEFT", texts, "BOTTOMLEFT", 0, 0)
    resetBtn:SetText(L.reset_texts)
    resetBtn:SetScript("OnClick", function()
        resetMessagesToLanguagePreset()
        for key, box in pairs(textBoxes) do
            if box and box.SetText then
                box:SetText(ImYOURhealerDB.messages[key] or "")
            end
        end
    end)

    -- Page 4: Tests
    local tests = pages[4]
    local testModeCB = CreateFrame("CheckButton", "ImYOURhealerTestModeCB", tests, "UICheckButtonTemplate")
    testModeCB:SetPoint("TOPLEFT", tests, "TOPLEFT", 0, -8)
    setCheckButtonLabel(testModeCB, L.test_mode)
    testModeCB:SetChecked(ImYOURhealerDB.testMode)
    testModeCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.testMode = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.testMode and L.test_on or L.test_off)
    end)

    local minimapCB = CreateFrame("CheckButton", "ImYOURhealerMinimapCB", tests, "UICheckButtonTemplate")
    minimapCB:SetPoint("TOPLEFT", tests, "TOPLEFT", 0, -34)
    setCheckButtonLabel(minimapCB, L.show_minimap)
    minimapCB:SetChecked(ImYOURhealerDB.showMinimap)
    minimapCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.showMinimap = self:GetChecked() and true or false
        if state.minimapButton then
            state.minimapButton:SetShown(ImYOURhealerDB.showMinimap)
        end
        printMsg(ImYOURhealerDB.showMinimap and L.minimap_on or L.minimap_off)
    end)

    local debugCB = CreateFrame("CheckButton", "ImYOURhealerDebugCB", tests, "UICheckButtonTemplate")
    debugCB:SetPoint("TOPLEFT", tests, "TOPLEFT", 0, -60)
    setCheckButtonLabel(debugCB, L.debug_mode)
    debugCB:SetChecked(ImYOURhealerDB.debug)
    debugCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.debug = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.debug and L.debug_on or L.debug_off)
    end)

    local logCB = CreateFrame("CheckButton", "ImYOURhealerLogCB", tests, "UICheckButtonTemplate")
    logCB:SetPoint("TOPLEFT", tests, "TOPLEFT", 0, -86)
    setCheckButtonLabel(logCB, L.log_enabled)
    logCB:SetChecked(ImYOURhealerDB.logEnabled)
    logCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.logEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.logEnabled and L.log_on or L.log_off)
    end)

    local function addTestButton(label, x, yPos, callback)
        local btn = CreateFrame("Button", nil, tests, "GameMenuButtonTemplate")
        btn:SetSize(268, 24)
        btn:SetPoint("TOPLEFT", tests, "TOPLEFT", x, yPos)
        btn:SetText(label)
        btn:SetScript("OnClick", callback)
        return btn
    end

    addTestButton(L.test_greeting, 0, -124, function() safeSend(formatGreeting()) end)
    addTestButton(L.test_finish, 286, -124, function() safeSend(ImYOURhealerDB.messages.finish) end)
    addTestButton(L.test_rerun_yes, 0, -154, function() sendRerunMessage(true) end)
    addTestButton(L.test_rerun_no, 286, -154, function() sendRerunMessage(false) end)
    addTestButton(L.test_heroic_list, 0, -184, function() sendHeroicTestMessage() end)
    addTestButton(L.test_saved_ids, 286, -184, function() dumpSavedInstanceIDsToChat() end)
    addTestButton(L.test_range_alert, 0, -214, function()
        local name = UnitName("target") or UnitName("player") or "Teammate"
        safeSend(string.format(L.range_alert_test_message, name, tonumber(ImYOURhealerDB.rangeAlertSeconds) or 4))
    end)
    addTestButton(L.test_mana_alert, 286, -214, function()
        triggerManaAlertTest()
    end)
    addTestButton(L.test_cooldown, 0, -244, function()
        local classToken = state.selectedCooldownClass or "PALADIN"
        local rule = (COOLDOWN_RULES[classToken] or {})[1]
        if rule then
            safeSend(formatCooldownMessage(rule, UnitName("target")))
        end
    end)
    addTestButton(L.test_pally_whisper, 286, -244, function()
        triggerPallyPowerWhispersNow()
    end)
    addTestButton(L.test_pally_self, 0, -274, function()
        local _, classToken = UnitClass("player")
        if classToken ~= "PALADIN" then
            printMsg(L.pallypower_selftest_skip)
            return
        end
        handleWhisperRequest("pp wisdom", UnitName("player"))
        printMsg(L.pallypower_selftest_ok)
    end)
    addTestButton(L.test_show_logs, 286, -274, function()
        dumpLogsToChat()
    end)
    addTestButton(L.test_clear_logs, 0, -304, function()
        clearLogs()
    end)

    selectMainTab(1)

    state.ui.frame = frame
end

-- Why this exists:
-- A dedicated minimap button is a faster entry point than slash commands.
-- What happens:
-- Left-click opens config, right-click toggles test mode, dragging moves the icon.
local function createMinimapButton()
    if state.minimapButton then
        return
    end

    local btn = CreateFrame("Button", MINIMAP_BUTTON_NAME, Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_HolyBolt")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.isMoving = true
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false

        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetScale()
        px = px / scale
        py = py / scale

        local angle
        if math.atan2 then
            angle = math.deg(math.atan2(py - my, px - mx))
        else
            angle = math.deg(math.atan(py - my, px - mx))
        end
        ImYOURhealerDB.minimap.angle = angle
        refreshMinimapPosition()
    end)

    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            toggleConfigUI(true)
        else
            ImYOURhealerDB.testMode = not ImYOURhealerDB.testMode
            printMsg(ImYOURhealerDB.testMode and L.test_on or L.test_off)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.title)
        GameTooltip:AddLine(L.minimap_tooltip_left, 1, 1, 1)
        GameTooltip:AddLine(L.minimap_tooltip_right, 1, 1, 1)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetMovable(true)
    btn:EnableMouse(true)

    state.minimapButton = btn
    refreshMinimapPosition()
    btn:SetShown(ImYOURhealerDB.showMinimap)
end

local function mergeDefaults(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            mergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

local function initializeDB()
    if type(_G[DB_NAME]) ~= "table" then
        _G[DB_NAME] = {}
    end
    -- Compatibility migration: keep previous DB if present.
    if type(_G.ImYOUhealerDB) == "table" and next(_G[DB_NAME]) == nil then
        _G[DB_NAME] = _G.ImYOUhealerDB
    end
    ImYOURhealerDB = _G[DB_NAME]
    mergeDefaults(ImYOURhealerDB, tcopy(defaults))
    if ImYOURhealerDB.manaAlertScope ~= "group" and ImYOURhealerDB.manaAlertScope ~= "instance" then
        ImYOURhealerDB.manaAlertScope = "group"
    end
    local cd = tonumber(ImYOURhealerDB.manaAlertCooldownSeconds) or 30
    if cd < 5 then cd = 5 end
    if cd > 300 then cd = 300 end
    ImYOURhealerDB.manaAlertCooldownSeconds = cd
    local waitT = tonumber(ImYOURhealerDB.waitAllInInstanceTimeout) or 20
    if waitT < 5 then waitT = 5 end
    if waitT > 120 then waitT = 120 end
    ImYOURhealerDB.waitAllInInstanceTimeout = waitT
    _G.ImYOURhealerDB = ImYOURhealerDB
    _G.ImYOUhealerDB = ImYOURhealerDB

    setLocale(ImYOURhealerDB.language)
    ensureMessagesForLanguage()
    ensureCooldownSettings()
    applyPopupLocale()
end

local function printHelp()
    printMsg(L.cmd_help_1)
    printMsg(L.cmd_help_2)
    printMsg(L.cmd_help_3)
    printMsg(L.cmd_help_4)
    printMsg(L.cmd_help_5)
    printMsg(L.cmd_help_6)
    printMsg(L.cmd_help_7)
    printMsg(L.cmd_help_8)
    printMsg(L.cmd_help_9)
    printMsg(L.cmd_help_10)
    printMsg(L.cmd_help_11)
    printMsg(L.cmd_help_12)
    printMsg(L.cmd_help_13)
    printMsg(L.cmd_help_14)
    printMsg(L.cmd_help_15)
    printMsg(L.cmd_help_16)
    printMsg(L.cmd_help_17)
    printMsg(L.cmd_help_18)
    printMsg(L.cmd_help_19)
end

local function runSelfTests()
    local failures = {}

    if normalizeName("Kael'thas Sunstrider") ~= "kaelthassunstrider" then
        table.insert(failures, "normalizeName punctuation handling")
    end

    local key = buildRunKey("Test Dungeon", 2, 12345)
    if key ~= "Test Dungeon#2#12345" then
        table.insert(failures, "buildRunKey format")
    end

    if isHeroicDifficulty(2, "") ~= true then
        table.insert(failures, "isHeroicDifficulty by id")
    end

    if isHeroicDifficulty(nil, "Heroic") ~= true then
        table.insert(failures, "isHeroicDifficulty by name")
    end

    if #failures > 0 then
        printMsg(L.selftest_fail .. ": " .. table.concat(failures, ", "))
        return false
    end

    printMsg(L.selftest_ok)
    return true
end

SLASH_IMYOURHEALER1 = "/imyh"
SLASH_IMYOURHEALER2 = "/imyrh"
SLASH_IMYOURHEALER3 = "/imyourhealer"
SLASH_IMYOURHEALER4 = "/imyour"
SlashCmdList["IMYOURHEALER"] = function(msg)
    local cmd, arg = string.match(msg or "", "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    arg = string.lower(arg or "")

    if cmd == "" then
        toggleConfigUI(true)
        return
    end

    if cmd == "test" then
        safeSend(formatGreeting())
        return
    end

    if cmd == "testmode" then
        ImYOURhealerDB.testMode = not ImYOURhealerDB.testMode
        printMsg(ImYOURhealerDB.testMode and L.test_on or L.test_off)
        return
    end

    if cmd == "lang" then
        if arg ~= "de" and arg ~= "en" then
            printHelp()
            return
        end
        ImYOURhealerDB.language = arg
        setLocale(arg)
        resetMessagesToLanguagePreset()
        applyPopupLocale()
        printMsg(L.lang_set .. ": " .. arg)
        return
    end

    if cmd == "debug" then
        if arg == "on" then
            ImYOURhealerDB.debug = true
        elseif arg == "off" then
            ImYOURhealerDB.debug = false
        else
            ImYOURhealerDB.debug = not ImYOURhealerDB.debug
        end
        printMsg(ImYOURhealerDB.debug and L.debug_on or L.debug_off)
        return
    end

    if cmd == "minimap" then
        ImYOURhealerDB.showMinimap = not ImYOURhealerDB.showMinimap
        if state.minimapButton then
            state.minimapButton:SetShown(ImYOURhealerDB.showMinimap)
        end
        printMsg(ImYOURhealerDB.showMinimap and L.minimap_on or L.minimap_off)
        return
    end

    if cmd == "selftest" then
        runSelfTests()
        return
    end

    if cmd == "keycheck" then
        if arg == "on" then
            ImYOURhealerDB.keyCheckEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.keyCheckEnabled = false
        else
            ImYOURhealerDB.keyCheckEnabled = not ImYOURhealerDB.keyCheckEnabled
        end
        printMsg(ImYOURhealerDB.keyCheckEnabled and L.key_check_on or L.key_check_off)
        return
    end

    if cmd == "ids" then
        dumpSavedInstanceIDsToChat()
        return
    end

    if cmd == "range" then
        if arg == "on" then
            ImYOURhealerDB.rangeAlertEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.rangeAlertEnabled = false
        else
            ImYOURhealerDB.rangeAlertEnabled = not ImYOURhealerDB.rangeAlertEnabled
        end
        printMsg(ImYOURhealerDB.rangeAlertEnabled and L.range_alert_on or L.range_alert_off)
        return
    end

    if cmd == "rangetime" then
        local sec = tonumber(arg)
        if sec and sec >= 1 and sec <= 30 then
            ImYOURhealerDB.rangeAlertSeconds = sec
            printMsg(string.format("%s: %d", L.range_alert_seconds, sec))
        else
            printMsg("/imyh rangetime <1-30>")
        end
        return
    end

    if cmd == "cooldown" then
        if arg == "on" then
            ImYOURhealerDB.cooldownAnnounceEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.cooldownAnnounceEnabled = false
        else
            ImYOURhealerDB.cooldownAnnounceEnabled = not ImYOURhealerDB.cooldownAnnounceEnabled
        end
        printMsg(ImYOURhealerDB.cooldownAnnounceEnabled and L.cooldown_on or L.cooldown_off)
        return
    end

    if cmd == "silence" then
        if arg == "on" then
            ImYOURhealerDB.silenceAlertEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.silenceAlertEnabled = false
        else
            ImYOURhealerDB.silenceAlertEnabled = not ImYOURhealerDB.silenceAlertEnabled
        end
        printMsg(ImYOURhealerDB.silenceAlertEnabled and L.silence_on or L.silence_off)
        return
    end

    if cmd == "pally" then
        if arg == "on" then
            ImYOURhealerDB.pallyPowerWhisperEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.pallyPowerWhisperEnabled = false
        else
            ImYOURhealerDB.pallyPowerWhisperEnabled = not ImYOURhealerDB.pallyPowerWhisperEnabled
        end
        printMsg(ImYOURhealerDB.pallyPowerWhisperEnabled and L.pallypower_on or L.pallypower_off)
        return
    end

    if cmd == "mana" then
        if arg == "on" then
            ImYOURhealerDB.manaAlertEnabled = true
        elseif arg == "off" then
            ImYOURhealerDB.manaAlertEnabled = false
        else
            ImYOURhealerDB.manaAlertEnabled = not ImYOURhealerDB.manaAlertEnabled
        end
        printMsg(ImYOURhealerDB.manaAlertEnabled and L.mana_alert or (L.mana_alert .. " OFF"))
        return
    end

    if cmd == "manathreshold" then
        local val = tonumber(arg)
        if val and val >= 1 and val <= 80 then
            ImYOURhealerDB.manaAlertThreshold = val
            printMsg(string.format("%s: %d", L.mana_alert_threshold, val))
        else
            printMsg("/imyh manathreshold <1-80>")
        end
        return
    end

    if cmd == "manascope" then
        if arg == "group" then
            ImYOURhealerDB.manaAlertScope = "group"
            printMsg(L.mana_scope_group)
        elseif arg == "instance" then
            ImYOURhealerDB.manaAlertScope = "instance"
            printMsg(L.mana_scope_instance)
        else
            printMsg("/imyh manascope group|instance")
        end
        return
    end

    if cmd == "manacd" then
        local sec = tonumber(arg)
        if sec and sec >= 5 and sec <= 300 then
            ImYOURhealerDB.manaAlertCooldownSeconds = sec
            printMsg(string.format("%s: %d", L.mana_alert_cooldown, sec))
        else
            printMsg("/imyh manacd <5-300>")
        end
        return
    end

    if cmd == "log" then
        if arg == "on" then
            ImYOURhealerDB.logEnabled = true
            printMsg(L.log_on)
            return
        end
        if arg == "off" then
            ImYOURhealerDB.logEnabled = false
            printMsg(L.log_off)
            return
        end
        if arg == "show" then
            dumpLogsToChat()
            return
        end
        if arg == "clear" then
            clearLogs()
            return
        end
        printMsg(L.cmd_help_14)
        return
    end

    printMsg(L.unknown_cmd)
    printHelp()
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:RegisterEvent("CHAT_MSG_WHISPER")
addon:RegisterEvent("CHAT_MSG_PARTY")
addon:RegisterEvent("CHAT_MSG_PARTY_LEADER")
addon:RegisterEvent("CHAT_MSG_RAID")
addon:RegisterEvent("CHAT_MSG_RAID_LEADER")
addon:RegisterEvent("CHAT_MSG_SYSTEM")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")

addon:SetScript("OnUpdate", function(_, elapsed)
    if not ImYOURhealerDB then
        return
    end
    state.onUpdateElapsed = state.onUpdateElapsed + elapsed
    if state.onUpdateElapsed >= 1.0 then
        state.onUpdateElapsed = 0
        updateRangeAlerts()
        updateManaAlerts()
        processPendingRunStart()
        processPendingPallyWhispers()
        processExpiredWhisperFallbacks()
    end
end)

addon:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then
            return
        end

        initializeDB()
        local okUI, errUI = pcall(createConfigUI)
        if not okUI then
            logError("createConfigUI failed: " .. tostring(errUI))
            printMsg("UI error: " .. tostring(errUI))
        else
            logInfo("createConfigUI ok")
        end
        local okMap, errMap = pcall(createMinimapButton)
        if not okMap then
            logError("createMinimapButton failed: " .. tostring(errMap))
            printMsg("Minimap error: " .. tostring(errMap))
        else
            logInfo("createMinimapButton ok")
        end
        dprint("Addon initialized")
        return
    end

    if not ImYOURhealerDB then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        enterInstanceIfNeeded("PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi)
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        enterInstanceIfNeeded("ZONE_CHANGED_NEW_AREA", false, false)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName, _, auraType = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" and destName then
            handleBossDeath(destName)
        end
        if subevent == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("player") and spellID then
            handlePlayerCooldownCast(spellID, destName)
        end
        if subevent == "SPELL_AURA_APPLIED" and spellName then
            maybeAnnounceSilenceByAura(destGUID, spellName, auraType)
        end
        if subevent == "SPELL_INTERRUPT" and spellID then
            maybeAnnounceSilenceByInterrupt(destGUID, spellID, spellName)
        end
        if spellID and sourceName then
            handleInnervateThanks(subevent, sourceName, destGUID, spellID)
        end
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        handleWhisperRequest(msg, sender, "WHISPER")
        return
    end

    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        local msg, sender = ...
        handleWhisperRequest(msg, sender, "PARTY")
        return
    end

    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        local msg, sender = ...
        handleWhisperRequest(msg, sender, "RAID")
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        handleSystemWhisperFailure(msg)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        state.rangeAlertTracker = {}
        return
    end
end)

-- Export a tiny test API used by ImYOURhealer_Tests.lua.
_G.ImYOURhealerTestAPI = {
    normalizeName = normalizeName,
    buildRunKey = buildRunKey,
    isHeroicDifficulty = isHeroicDifficulty,
}
