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
        mana_alert_scope = "Mana-Meldung Bereich",
        mana_scope_group = "In jeder Gruppe",
        mana_scope_instance = "Nur in Instanzen",
        mana_alert_text = "Low-Mana Text",
        mana_innervate_hint = "Anregen-Hinweis (bei Druide)",
        mana_pot_status = "ManaPot-Status melden",
        innervate_thanks = "Automatisch Danke bei Anregen",
        cooldown_announce = "Cooldown-Meldungen",
        pallypower_sync = "PallyPower Whisper bei Instanzstart",
        pallypower_whisper_apply = "Whisper-Aenderungen direkt anwenden",
        key_check = "Heroic-Schluessel pruefen",
        trigger_mode = "Ende-Erkennung",
        trigger_endboss_or_all = "Endboss ODER alle Bosse",
        trigger_endboss_only = "Nur Endboss",
        trigger_all_only = "Nur alle Bosse",
        greeting_message = "Begrüßungstext",
        finish_message = "Abschlussnachricht",
        rerun_message = "Nochmal-Runde Nachricht",
        farewell_message = "Abschiedsnachricht",
        reset_texts = "Texte auf Sprach-Standard setzen",
        test_greeting = "Begrüßung testen",
        test_finish = "Abschluss testen",
        test_rerun_yes = "Rerun Ja testen",
        test_rerun_no = "Rerun Nein testen",
        test_heroic_list = "Heroic-Liste testen",
        test_saved_ids = "Instanz-IDs testen",
        test_range_alert = "Out-of-Range Test",
        test_mana_alert = "Mana-Test",
        test_cooldown = "Cooldown-Test",
        test_pally_whisper = "PallyPower Whisper-Test",
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
        pallypower_on = "PallyPower Whisper-Info aktiviert.",
        pallypower_off = "PallyPower Whisper-Info deaktiviert.",
        pallypower_apply_on = "PallyPower Whisper-Aenderungen aktiviert.",
        pallypower_apply_off = "PallyPower Whisper-Aenderungen deaktiviert.",
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
        pallypower_whisper_usage = "PP-Hilfe: pp weisheit|macht|koenige|erloesung|licht|schutz (auch: wisdom|might|kings|salv|light|sanc).",
        pallypower_group_change = "%s hat einen anderen PallyPower-Buff gewaehlt: %s.",
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
        ui_tab_general = "Allgemein",
        ui_tab_cooldowns = "Cooldowns",
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
        cmd_help_13 = "/imyh pally on|off - PallyPower Whisper",
        cmd_help_15 = "/imyh mana on|off - Low-Mana Meldungen",
        cmd_help_16 = "/imyh manathreshold <1-80> - Mana-Schwelle",
        cmd_help_17 = "/imyh manascope group|instance - Mana nur Gruppe oder nur Instanz",
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
        mana_alert_scope = "Low mana scope",
        mana_scope_group = "Any group",
        mana_scope_instance = "Instances only",
        mana_alert_text = "Low mana text",
        mana_innervate_hint = "Innervate hint (if druid)",
        mana_pot_status = "Announce mana potion status",
        innervate_thanks = "Auto thank on Innervate",
        cooldown_announce = "Cooldown announcements",
        pallypower_sync = "PallyPower whispers on instance start",
        pallypower_whisper_apply = "Apply whisper requests directly",
        key_check = "Check heroic key ownership",
        trigger_mode = "Completion detection",
        trigger_endboss_or_all = "End boss OR all bosses",
        trigger_endboss_only = "End boss only",
        trigger_all_only = "All bosses only",
        greeting_message = "Greeting message",
        finish_message = "Completion message",
        rerun_message = "Another run message",
        farewell_message = "Farewell message",
        reset_texts = "Reset texts to language default",
        test_greeting = "Test greeting",
        test_finish = "Test completion",
        test_rerun_yes = "Test rerun yes",
        test_rerun_no = "Test rerun no",
        test_heroic_list = "Test heroic list",
        test_saved_ids = "Test instance IDs",
        test_range_alert = "Test out-of-range",
        test_mana_alert = "Mana test",
        test_cooldown = "Test cooldown",
        test_pally_whisper = "Test PallyPower whisper",
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
        pallypower_on = "PallyPower whisper info enabled.",
        pallypower_off = "PallyPower whisper info disabled.",
        pallypower_apply_on = "PallyPower whisper apply enabled.",
        pallypower_apply_off = "PallyPower whisper apply disabled.",
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
        pallypower_whisper_usage = "PP help: pp wisdom|might|kings|salv|light|sanc (also: weisheit|macht|koenige|erloesung|licht|schutz).",
        pallypower_group_change = "%s selected a different PallyPower buff: %s.",
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
        ui_tab_general = "General",
        ui_tab_cooldowns = "Cooldowns",
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
        cmd_help_13 = "/imyh pally on|off - pallypower whisper sync",
        cmd_help_15 = "/imyh mana on|off - low mana alerts",
        cmd_help_16 = "/imyh manathreshold <1-80> - mana threshold",
        cmd_help_17 = "/imyh manascope group|instance - low mana scope",
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
    },
    en = {
        greeting = LOCALES.en.greet_default,
        finish = LOCALES.en.finish_default,
        rerun = LOCALES.en.rerun_default,
        farewell = LOCALES.en.farewell_default,
        manaLow = LOCALES.en.mana_alert_default,
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
    manaAlertScope = "group",
    manaInnervateHintEnabled = true,
    manaPotStatusEnabled = false,
    autoThankInnervate = true,
    cooldownAnnounceEnabled = true,
    pallyPowerWhisperEnabled = true,
    pallyPowerWhisperApplyEnabled = true,
    keyCheckEnabled = true,
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
end

local function resetMessagesToLanguagePreset()
    local preset = MESSAGE_PRESETS[ImYOURhealerDB.language] or MESSAGE_PRESETS.en
    ImYOURhealerDB.messages.greeting = preset.greeting
    ImYOURhealerDB.messages.finish = preset.finish
    ImYOURhealerDB.messages.rerun = preset.rerun
    ImYOURhealerDB.messages.farewell = preset.farewell
    ImYOURhealerDB.messages.manaLow = preset.manaLow
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
    SendChatMessage(msg, channel)
    logInfo(string.format("SendChatMessage channel=%s msg=%s", tostring(channel), tostring(msg)))
    dprint(string.format("Sent message to %s: %s", channel, msg))
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
    if string.find(tpl, "%%s", 1, true) then
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
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do
            local u = "party" .. i
            if UnitExists(u) then
                table.insert(out, u)
            end
        end
    end
    return out
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
                    safeSend(string.format(L.range_alert_message, name, threshold))
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
        return L.mana_pot_cd
    end
    local start, duration = GetItemCooldown(bestItem)
    if not start or not duration or start == 0 or duration == 0 then
        return L.mana_pot_ready
    end
    return L.mana_pot_cd
end

local function updateManaAlerts()
    if not ImYOURhealerDB.manaAlertEnabled then
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

    local manaPct = getPlayerManaPercent()
    if manaPct <= threshold and not state.manaLowAnnounced then
        safeSend(ImYOURhealerDB.messages.manaLow or L.mana_alert_default)
        if ImYOURhealerDB.manaInnervateHintEnabled and groupHasDruid() then
            safeSend(L.mana_innervate_text)
        end
        if ImYOURhealerDB.manaPotStatusEnabled then
            safeSend(getManaPotionStatusText())
        end
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
        safeSend(L.mana_innervate_text)
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

local function sendPallyPowerWhispers(runKey)
    if not ImYOURhealerDB.pallyPowerWhisperEnabled then
        return
    end
    if ImYOURhealerDB.pallyPowerWhisperRuns[runKey] then
        return
    end
    ImYOURhealerDB.pallyPowerWhisperRuns[runKey] = time()

    if not pallyPowerReady() then
        dprint(L.pallypower_missing)
        return
    end

    for _, unit in ipairs(buildGroupUnits()) do
        local name = UnitName(unit)
        if name then
            local spell, by = getPallyPowerAssignmentForPlayer(name)
            local text
            if spell then
                text = string.format("%s %s (%s). %s", L.pallypower_whisper_header, spell, shortName(by or "?"), L.pallypower_whisper_hint)
            else
                text = string.format("%s %s", L.pallypower_whisper_header, L.pallypower_missing)
            end
            SendChatMessage(text, "WHISPER", nil, name)
        end
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

local function handleWhisperRequest(msg, sender)
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
        SendChatMessage(L.pallypower_whisper_usage, "WHISPER", nil, sender)
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
        SendChatMessage(L.pallypower_whisper_invalid, "WHISPER", nil, sender)
        return
    end

    local unit = findGroupUnitByPlayerName(sender)
    if not unit then
        SendChatMessage(L.pallypower_whisper_fail, "WHISPER", nil, sender)
        return
    end
    local tname = UnitName(unit)
    local _, targetClassToken = UnitClass(unit)
    local classID = targetClassToken and PallyPower.ClassToID[targetClassToken]
    if not tname or not classID then
        SendChatMessage(L.pallypower_whisper_fail, "WHISPER", nil, sender)
        return
    end

    local me = UnitName("player")
    if not PallyPower_NormalAssignments[me] then
        PallyPower_NormalAssignments[me] = {}
    end
    if not PallyPower_NormalAssignments[me][classID] then
        PallyPower_NormalAssignments[me][classID] = {}
    end
    local previous = PallyPower_NormalAssignments[me][classID][tname]
    PallyPower_NormalAssignments[me][classID][tname] = buffIndex

    if type(PallyPower.SendNormalBlessings) == "function" then
        PallyPower:SendNormalBlessings(me, classID, tname)
    end
    if type(PallyPower.UpdateLayout) == "function" then
        PallyPower:UpdateLayout()
    end
    SendChatMessage(L.pallypower_whisper_ack, "WHISPER", nil, sender)
    if previous ~= buffIndex then
        local spellName = (PallyPower.Spells and PallyPower.Spells[buffIndex]) or (PallyPower.GSpells and PallyPower.GSpells[buffIndex]) or tostring(buffIndex)
        safeSend(string.format(L.pallypower_group_change, shortName(sender), tostring(spellName)))
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

local function enterInstanceIfNeeded(reason, isInitialLogin, isReloadingUi)
    local ctx = getCurrentInstanceContext()
    if not ctx then
        state.currentRunKey = nil
        state.currentInstanceName = nil
        state.currentIsHeroic = false
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

    ImYOURhealerDB.greetedRuns[runKey] = time()
    safeSend(formatGreeting())
    sendPallyPowerWhispers(runKey)
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

    local tabTests = CreateFrame("Button", UI_FRAME_NAME .. "Tab3", frame, "GameMenuButtonTemplate")
    tabTests:SetID(3)
    tabTests:SetSize(120, 24)
    tabTests:SetText(L.ui_tab_tests)
    tabTests:SetPoint("LEFT", tabCooldowns, "RIGHT", 6, 0)
    tabTests:SetScript("OnClick", function() selectMainTab(3) end)
    mainTabs[3] = tabTests

    -- Page 1: General
    local general = pages[1]
    local y = -8

    createLabel(general, L.language, 0, y)
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
    langDD:SetPoint("TOPLEFT", general, "TOPLEFT", 100, y + 10)
    UIDropDownMenu_SetSelectedValue(langDD, ImYOURhealerDB.language)

    y = y - 24

    local keyCheckCB = CreateFrame("CheckButton", "ImYOURhealerKeyCheckCB", general, "UICheckButtonTemplate")
    keyCheckCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(keyCheckCB, L.key_check)
    keyCheckCB:SetChecked(ImYOURhealerDB.keyCheckEnabled)
    keyCheckCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.keyCheckEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.keyCheckEnabled and L.key_check_on or L.key_check_off)
    end)

    y = y - 24

    local rangeCB = CreateFrame("CheckButton", "ImYOURhealerRangeCB", general, "UICheckButtonTemplate")
    rangeCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(rangeCB, L.range_alert)
    rangeCB:SetChecked(ImYOURhealerDB.rangeAlertEnabled)
    rangeCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.rangeAlertEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.rangeAlertEnabled and L.range_alert_on or L.range_alert_off)
    end)

    createLabel(general, L.range_alert_seconds, 300, y + 3)
    local rangeSecondsBox = CreateFrame("EditBox", "ImYOURhealerRangeSecondsBox", general, "InputBoxTemplate")
    rangeSecondsBox:SetSize(48, 20)
    rangeSecondsBox:SetPoint("TOPLEFT", general, "TOPLEFT", 450, y + 4)
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

    y = y - 24

    local manaCB = CreateFrame("CheckButton", "ImYOURhealerManaCB", general, "UICheckButtonTemplate")
    manaCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(manaCB, L.mana_alert)
    manaCB:SetChecked(ImYOURhealerDB.manaAlertEnabled)
    manaCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaAlertEnabled = self:GetChecked() and true or false
    end)

    createLabel(general, L.mana_alert_threshold, 300, y + 3)
    local manaThresholdBox = CreateFrame("EditBox", "ImYOURhealerManaThresholdBox", general, "InputBoxTemplate")
    manaThresholdBox:SetSize(48, 20)
    manaThresholdBox:SetPoint("TOPLEFT", general, "TOPLEFT", 450, y + 4)
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

    createLabel(general, L.mana_alert_scope, 300, y - 21)
    local manaScopeDD = createDropdown(general, 190, {
        { key = "group", label = L.mana_scope_group },
        { key = "instance", label = L.mana_scope_instance },
    }, function(key)
        ImYOURhealerDB.manaAlertScope = key
    end)
    manaScopeDD:SetPoint("TOPLEFT", general, "TOPLEFT", 375, y - 12)
    UIDropDownMenu_SetSelectedValue(manaScopeDD, ImYOURhealerDB.manaAlertScope or "group")

    y = y - 24

    local manaInnervateCB = CreateFrame("CheckButton", "ImYOURhealerManaInnervateCB", general, "UICheckButtonTemplate")
    manaInnervateCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(manaInnervateCB, L.mana_innervate_hint)
    manaInnervateCB:SetChecked(ImYOURhealerDB.manaInnervateHintEnabled)
    manaInnervateCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaInnervateHintEnabled = self:GetChecked() and true or false
    end)

    local manaPotCB = CreateFrame("CheckButton", "ImYOURhealerManaPotCB", general, "UICheckButtonTemplate")
    manaPotCB:SetPoint("TOPLEFT", general, "TOPLEFT", 300, y)
    setCheckButtonLabel(manaPotCB, L.mana_pot_status)
    manaPotCB:SetChecked(ImYOURhealerDB.manaPotStatusEnabled)
    manaPotCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.manaPotStatusEnabled = self:GetChecked() and true or false
    end)

    y = y - 24

    local innervateThanksCB = CreateFrame("CheckButton", "ImYOURhealerInnervateThanksCB", general, "UICheckButtonTemplate")
    innervateThanksCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(innervateThanksCB, L.innervate_thanks)
    innervateThanksCB:SetChecked(ImYOURhealerDB.autoThankInnervate)
    innervateThanksCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.autoThankInnervate = self:GetChecked() and true or false
    end)

    y = y - 24

    local cooldownCB = CreateFrame("CheckButton", "ImYOURhealerCooldownCB", general, "UICheckButtonTemplate")
    cooldownCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(cooldownCB, L.cooldown_announce)
    cooldownCB:SetChecked(ImYOURhealerDB.cooldownAnnounceEnabled)
    cooldownCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.cooldownAnnounceEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.cooldownAnnounceEnabled and L.cooldown_on or L.cooldown_off)
    end)

    y = y - 24

    local pallyCB = CreateFrame("CheckButton", "ImYOURhealerPallyWhisperCB", general, "UICheckButtonTemplate")
    pallyCB:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y)
    setCheckButtonLabel(pallyCB, L.pallypower_sync)
    pallyCB:SetChecked(ImYOURhealerDB.pallyPowerWhisperEnabled)
    pallyCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.pallyPowerWhisperEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.pallyPowerWhisperEnabled and L.pallypower_on or L.pallypower_off)
    end)

    local pallyApplyCB = CreateFrame("CheckButton", "ImYOURhealerPallyApplyCB", general, "UICheckButtonTemplate")
    pallyApplyCB:SetPoint("TOPLEFT", general, "TOPLEFT", 300, y)
    setCheckButtonLabel(pallyApplyCB, L.pallypower_whisper_apply)
    pallyApplyCB:SetChecked(ImYOURhealerDB.pallyPowerWhisperApplyEnabled)
    pallyApplyCB:SetScript("OnClick", function(self)
        ImYOURhealerDB.pallyPowerWhisperApplyEnabled = self:GetChecked() and true or false
        printMsg(ImYOURhealerDB.pallyPowerWhisperApplyEnabled and L.pallypower_apply_on or L.pallypower_apply_off)
    end)

    y = y - 28

    createLabel(general, L.trigger_mode, 0, y)
    local triggerDD = createDropdown(general, 250, {
        { key = "endboss_or_all", label = L.trigger_endboss_or_all },
        { key = "endboss_only", label = L.trigger_endboss_only },
        { key = "all_only", label = L.trigger_all_only },
    }, function(key)
        ImYOURhealerDB.triggerMode = key
    end)
    triggerDD:SetPoint("TOPLEFT", general, "TOPLEFT", 140, y + 10)
    UIDropDownMenu_SetSelectedValue(triggerDD, ImYOURhealerDB.triggerMode)

    y = y - 30

    createLabel(general, L.greeting_message, 0, y)
    local greetBox = createEditBox(general, 560, 32)
    greetBox:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y - 18)
    greetBox:SetText(ImYOURhealerDB.messages.greeting)
    greetBox:SetScript("OnTextChanged", function(self)
        ImYOURhealerDB.messages.greeting = self:GetText()
    end)

    y = y - 56

    createLabel(general, L.finish_message, 0, y)
    local finishBox = createEditBox(general, 560, 32)
    finishBox:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y - 18)
    finishBox:SetText(ImYOURhealerDB.messages.finish)
    finishBox:SetScript("OnTextChanged", function(self)
        ImYOURhealerDB.messages.finish = self:GetText()
    end)

    y = y - 56

    createLabel(general, L.rerun_message, 0, y)
    local rerunBox = createEditBox(general, 560, 32)
    rerunBox:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y - 18)
    rerunBox:SetText(ImYOURhealerDB.messages.rerun)
    rerunBox:SetScript("OnTextChanged", function(self)
        ImYOURhealerDB.messages.rerun = self:GetText()
    end)

    y = y - 56

    createLabel(general, L.farewell_message, 0, y)
    local farewellBox = createEditBox(general, 560, 32)
    farewellBox:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y - 18)
    farewellBox:SetText(ImYOURhealerDB.messages.farewell)
    farewellBox:SetScript("OnTextChanged", function(self)
        ImYOURhealerDB.messages.farewell = self:GetText()
    end)

    y = y - 56

    createLabel(general, L.mana_alert_text, 0, y)
    local manaBox = createEditBox(general, 560, 32)
    manaBox:SetPoint("TOPLEFT", general, "TOPLEFT", 0, y - 18)
    manaBox:SetText(ImYOURhealerDB.messages.manaLow or L.mana_alert_default)
    manaBox:SetScript("OnTextChanged", function(self)
        ImYOURhealerDB.messages.manaLow = self:GetText()
    end)

    local resetBtn = CreateFrame("Button", nil, general, "GameMenuButtonTemplate")
    resetBtn:SetSize(250, 24)
    resetBtn:SetPoint("BOTTOMLEFT", general, "BOTTOMLEFT", 0, 0)
    resetBtn:SetText(L.reset_texts)
    resetBtn:SetScript("OnClick", function()
        resetMessagesToLanguagePreset()
        greetBox:SetText(ImYOURhealerDB.messages.greeting)
        finishBox:SetText(ImYOURhealerDB.messages.finish)
        rerunBox:SetText(ImYOURhealerDB.messages.rerun)
        farewellBox:SetText(ImYOURhealerDB.messages.farewell)
        manaBox:SetText(ImYOURhealerDB.messages.manaLow)
    end)

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

    -- Page 3: Tests
    local tests = pages[3]
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
        if state.currentRunKey then
            sendPallyPowerWhispers(state.currentRunKey .. "#test")
        else
            sendPallyPowerWhispers("manual-test")
        end
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
        local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID = CombatLogGetCurrentEventInfo()
        if subevent == "UNIT_DIED" and destName then
            handleBossDeath(destName)
        end
        if subevent == "SPELL_CAST_SUCCESS" and sourceGUID == UnitGUID("player") and spellID then
            handlePlayerCooldownCast(spellID, destName)
        end
        if spellID and sourceName then
            handleInnervateThanks(subevent, sourceName, destGUID, spellID)
        end
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        handleWhisperRequest(msg, sender)
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
