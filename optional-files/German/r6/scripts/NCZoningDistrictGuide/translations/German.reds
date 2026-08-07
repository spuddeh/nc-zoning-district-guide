// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/German.reds
// Author: D/Code
// Description: The German slot. Current to Ver 1.1.0; new strings show in English until
//              someone fills them in. Filling them in is welcome, and takes no coding.
//
//              TO TRANSLATE - three steps:
//
//                1. Open English.reds and copy ONLY the this.Text(...) lines.
//                   NOT the whole file. Copying the file brings the English
//                   class name with it, and two classes with one name stops
//                   EVERY redscript mod on the player's machine from loading.
//                2. Paste them below, over the "translations go here" line.
//                   Leave everything else in this file exactly as it is.
//                3. Translate the SECOND text on each line. Never change the first.
//
//              this.Text("NCZDG.title",  "NC ZONING BOARD");
//                        ^^^^^^^^^^^^^  the KEY - never change it
//                                        ^^^^^^^^^^^^^^^^^  translate this
//
//              RULES:
//                - Partial is fine. Anything you leave out falls back to English.
//                - Keep {n}, {area}, {name} and friends exactly as written. They are
//                  replaced at runtime, and you may move them anywhere in the sentence.
//                - Plurals are one key per form. Fill in the forms your language uses
//                  and leave the rest.
//
//              Then it ships as its own mod - one file, and nothing has to be
//              released at this end. Full instructions, including how to package
//              and upload it:
//              https://github.com/spuddeh/nc-zoning-district-guide/blob/main/docs/TRANSLATING.md
//
//              MAINTAINER: empty on purpose - a filled slot would override newer
//              English wording. The path, module and class name are public API,
//              because a translation mod REPLACES this file.
// Mod Version: 1.1.0
// Credits: psiberx (Codeware)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_German extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "NC ZONING BOARD");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // ABTEILUNG FÜR STADTPLANUNG");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "NACH NAME, TAG, AUTOR SUCHEN - & | !");

    // --- search syntax, shown by the [ i ] beside the search box ------------------------
    // EACH LINE CARRIES ITS OWN EXAMPLE, because the example words are English and a translator
    // has to be free to swap them for words their reader would actually type. A shared example
    // held in code could not be reached.
    //
    // EVERY EXAMPLE WORD IS IN THE REGISTRY. `watson` is 85 records, `apartment` 156, `pacifica`
    // 14, `corpo` 38 - so each line demonstrates itself when it is typed. An example that returns
    // nothing teaches the reader that the feature is broken.
    //
    // The operators themselves (& | !) are NOT translated. They are what the parser reads.
    this.Text("NCZDG.helpTitle",       "SYNTAX FÜR DIE SUCHE");
    this.Text("NCZDG.helpAnd",         "watson&apartment   -   beide müssen zutreffen");
    this.Text("NCZDG.helpOr",          "watson|pacifica   -   mindestens eines muss zutreffen");
    this.Text("NCZDG.helpNot",         "!corpo   -   alles außer corpo");
    this.Text("NCZDG.helpNotWith",     "apartment!corpo   -   Apartments, außer corpo");
    this.Text("NCZDG.helpMix",         "watson|pacifica&apartment   -   einer der Stadtteile, und ein Apartment");
    this.Text("NCZDG.helpPhrase",      "night city   -   Ohne Operator wird nach dem gesamten Text gesucht.");
    this.Text("NCZDG.helpSpaces",      "Operatoren ohne Leerzeichen eingeben. watson & apartment sucht 'watson ' und ' apartment', mit den Leerzeichen.");
    this.Text("NCZDG.helpFields",      "Jedes Suchwort wird mit Name, Beschreibung, Kategorie, Stadtteil, Tags sowie Autoren verglichen.");

    // --- buttons -----------------------------------------------------------------------
    this.Text("NCZDG.btnClear",        "LÖSCHEN");
    this.Text("NCZDG.btnSetMarker",    "ZEIGE AUF KARTE");
    this.Text("NCZDG.btnClearMarker",  "LÖSCHE WEGPUNKT");
    this.Text("NCZDG.btnTeleport",     "TELEPORTIEREN");
    this.Text("NCZDG.btnExitVehicle",  "FAHRZEUG VERLASSEN");
    this.Text("NCZDG.btnPrev",         "< ZURÜCK");
    this.Text("NCZDG.btnNext",         "NÄCHSTE >");

    // --- install filter ----------------------------------------------------------------
    this.Text("NCZDG.filterAll",       "ZEIGE: ALLE");
    this.Text("NCZDG.filterInstalled", "ZEIGE: INSTALLIERTE");
    this.Text("NCZDG.filterMissing",   "ZEIGE: FEHLENDE");
    this.Text("NCZDG.filterUnknown",   "ZEIGE: UNBEKANNTE");

    // --- the guide's status line -------------------------------------------------------
    // Three forms because the sentence differs, not because the numbers do: a search says
    // how many of the area matched, a paged list says which slice is on screen, and a
    // short list says only the total.
    this.Text("NCZDG.countSearch",     "{n} VON {total} IN {area}");
    this.Text("NCZDG.countPaged",      "{from}-{to} VON {n} IN {area}");
    this.Text("NCZDG.countPlain",      "{n} IN {area}");

    // --- nav column --------------------------------------------------------------------
    this.Text("NCZDG.areaAll",         "ALLE ORTE");
    this.Text("NCZDG.navRecent",       "{n} KÜRZLICH");

    // --- cards -------------------------------------------------------------------------
    this.Text("NCZDG.badgeRecent",     "KÜRZLICH AKTUALISIERT");
    this.Text("NCZDG.badgeInstalled",  "INSTALLIERT");
    this.Text("NCZDG.noImage",         "KEIN BILD IM DATENSATZ");

    // --- lightbox ----------------------------------------------------------------------
    this.Text("NCZDG.imgLoading",      "LÄDT...");
    this.Text("NCZDG.imgLoadingClose", "LÄDT...   -   AN BELIEBIGER STELLE IM FENSTER KLICKEN ZUM SCHLIEßEN");
    this.Text("NCZDG.imgFailed",       "BILD NICHT VERFÜGBAR   -   AN BELIEBIGER STELLE IM FENSTER KLICKEN ZUM SCHLIEßEN");
    this.Text("NCZDG.imgClose",        "AN BELIEBIGER STELLE IM FENSTER KLICKEN ZUM SCHLIEßEN");

    // --- categories --------------------------------------------------------------------
    // The card badge and the map breakdown want the same three words in singular and
    // plural. The registry's own values ("new-location", "location-overhaul") are data
    // and are never translated - only their labels are.
    this.Text("NCZDG.catNew",          "NEUER ORT");
    this.Text("NCZDG.catNewPlural",    "NEUE ORTE");
    this.Text("NCZDG.catOverhaul",     "ÜBERARBEITUNG");
    this.Text("NCZDG.catOverhaulPlural", "ÜBERARBEITUNGEN");
    this.Text("NCZDG.catOther",        "ANDERE");
    this.Text("NCZDG.catOtherPlural",  "ANDERE");

    // --- district notice + fast-travel panel -------------------------------------------
    this.Text("NCZDG.panelEmpty",      "Noch keine eingetragenen Orte in {area}");
    this.Text("NCZDG.panelCountOne",   "{n} eingetragener Ort in {area}");
    this.Text("NCZDG.panelCountMany",  "{n} eingetragene Orte in {area}");
    this.Text("NCZDG.panelNearest",    "Nächstgelegen: {name}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "NC ZONING:");
    this.Text("NCZDG.mapEmpty",        "KEINE EINGETRAGENEN ORTE");
    this.Text("NCZDG.mapCountOne",     "{n} ORT");
    this.Text("NCZDG.mapCountMany",    "{n} ORTE");
    this.Text("NCZDG.mapRecent",       "{n} KÜRZLICH AKTUALISIERT");

    // --- failure states ----------------------------------------------------------------
    // The long form belongs to NCZoningCore (GetStatusMessage) and is localised there.
    this.Text("NCZDG.noData",          "KEINE ORTSDATEN");

    // --- RCF settings panel ------------------------------------------------------------
    // RCF resolves these itself: DVRCF_HubPopup.LocalizeSchema runs every schema string
    // through LocalizationSystem.GetText, so the adapter passes KEYS, not translated text.
    this.Text("NCZDG.modName",         "NC Zoning Board - Reiseführer");
    this.Text("NCZDG.modDesc",         "Welche Orts-Mods sich im Stadtteil um dich herum befinden.");

    this.Text("NCZDG.secLocations",    "Orte");
    this.Text("NCZDG.optSubdistrict",  "Auf Unterbezirk eingrenzen");
    this.Text("NCZDG.tipSubdistrict",  "Anzahl auf den Unterbezirk beziehen, wenn du dich in einem befindest, anstatt auf den ganzen Stadtteil. Gilt für den Reiseführer, das Karten-Panel und die Benachrichtigungen beim Wechsel des Stadtteils.");

    this.Text("NCZDG.secGuide",        "Stadtteil-Reiseführer");
    this.Text("NCZDG.optGuide",        "Reiseführer aktivieren");
    this.Text("NCZDG.tipGuide",        "Erkunde die Orts-Mods in jedem Stadtteil, mit Suche, Wegpunkt und Teleportations-Möglichkeit.");
    this.Text("NCZDG.optKey",          "Reiseführer-Taste");
    this.Text("NCZDG.tipKey",          "Die Taste, die den Reiseführer öffnet. Benötigt Input Loader.");
    this.Text("NCZDG.optModifier",     "Reiseführer-Tastenkombi");
    this.Text("NCZDG.tipModifier",     "Optionale Taste, die zusätzlich gedrückt gehalten werden muss. Kann neben Umschalt, Strg, Alt auch jede andere Taste sein. Leer lassen für keine Tastenkombi.");
    this.Text("NCZDG.optShowing",      "Zeige beim Öffnen");
    this.Text("NCZDG.tipShowing",      "Welche Orte der Reiseführer beim Öffnen anzeigt. Ansicht kann innerhalb des Reiseführers frei gewechselt werden.");
    this.Text("NCZDG.optOpenArea",     "Aktueller Stadtteil beim Öffnen");
    this.Text("NCZDG.tipOpenArea",     "Der Reiseführer öffnet sich für deinen momentanen Stadtteil. Wenn dies deaktiviert ist oder du dich außerhalb der Karte befindest, werden immer ALLE ORTE angezeigt.");
    this.Text("NCZDG.optOpenMap",      "Karte automatisch öffnen");
    this.Text("NCZDG.tipOpenMap",      "ZEIGE AUF KARTE öffnet die Karte und zentriert sie auf den Wegpunkt. Abschalten, um nur einen Wegpunkt zu setzen und im Reiseführer zu verbleiben.");
    this.Text("NCZDG.optAutoTrack",    "Wegpunkt verfolgen");
    this.Text("NCZDG.tipAutoTrack",    "Direkt die Wegsuche starten, anstatt das händisch in der Karte machen zu müssen. Ein zuvor selbst gesetzter Wegpunkt wird ersetzt; die aktuelle verfolgte Mission wird aber nicht überschrieben.");
    this.Text("NCZDG.noteWaypoint",    "Die Wegsuche startet erst nach einmaligem Öffnen der Karte. Dies ist eine Einschränkung des Spiels selbst, keine Einstellung.");

    this.Text("NCZDG.dropAll",         "Alle");
    this.Text("NCZDG.dropInstalled",   "Nur installierte");
    this.Text("NCZDG.dropMissing",     "Nur fehlende");

    this.Text("NCZDG.secMap",          "Karte");
    this.Text("NCZDG.optMap",          "In Karte anzeigen");
    this.Text("NCZDG.tipMap",          "Fügt die Anzahl der Orts-Mods unterteilt nach Kategorie zum Stadtteil-Infopanel der Karte hinzu.");

    this.Text("NCZDG.secNotice",       "Stadtteil-Benachrichtigung");
    this.Text("NCZDG.optNotice",       "In Stadtteil-Benachrichtigung anzeigen");
    this.Text("NCZDG.tipNotice",       "Fügt der Benachrichtigung beim Wechsel des Stadtteils ein Panel hinzu. Die Benachrichtigung selbst bleibt immer aktiv.");
    this.Text("NCZDG.optNearest",      "Nächstgelegenen Ort anzeigen");
    this.Text("NCZDG.tipNearest",      "Den Namen der nächstgelegenen Mod im Umkreis anzeigen. Aus zeigt nur die Anzahl an.");
    this.Text("NCZDG.optFastTravel",   "Bei Schnellreise anzeigen");
    this.Text("NCZDG.tipFastTravel",   "Zeigt eine Stadtteil-Benachrichtigung bei Ankunft nach einer Schnellreise an. Aus belässt die Schnellreise auf Spiel-Standard (keine Benachrichtigung).");
  }
}
