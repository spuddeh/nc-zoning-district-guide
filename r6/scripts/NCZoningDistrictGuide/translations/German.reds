// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/German.reds
// Author: D/Code
// Description: The German translation for every player-facing string. Codeware's
//              ModLocalizationPackage; no TweakXL, no locale JSON, no LocKey registration.
//
//              ADDING A LANGUAGE IS ADDITIVE: copy this file, translate the second
//              argument of every Text() call, extend ModLocalizationPackage under a new
//              name, and add one case to Provider.reds. Never translate the KEY.
//
//              PLACEHOLDERS ARE WHY THE SENTENCES ARE WHOLE. {n}, {area}, {total} and
//              friends are substituted at the call site, so a translator can put the
//              number after the noun, or the area before the count, or drop a word
//              entirely. Assembling a sentence by concatenating a count with " locations"
//              cannot do that - it hardcodes English word order into the code, where a
//              translator cannot reach it.
//
//              PLURALS ARE WHOLE STRINGS, one key per form, never a stem plus "S".
//              English has two forms; Polish and Russian have three, Arabic six. A key
//              per form is a key a translator can fill in; a suffix is not.
// Mod Version: 1.0.0
// Credits: psiberx (Codeware), DigitalVixen (RCF, the reference implementation)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_German extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "NC ZONING BOARD");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // STADTPLANUNGS-ABTEILUNG");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "NACH NAME, AUTOR, TAG SUCHEN");

    // --- buttons -----------------------------------------------------------------------
    this.Text("NCZDG.btnClear",        "LÖSCHEN");
    this.Text("NCZDG.btnSetMarker",    "ZEIGE AUF KARTE");
    this.Text("NCZDG.btnClearMarker",  "WEGPUNKT LÖSCHEN");
    this.Text("NCZDG.btnTeleport",     "TELEPORTIEREN");
    this.Text("NCZDG.btnExitVehicle",  "FAHRZEUG VERLASSEN");
    this.Text("NCZDG.btnPrev",         "< VORHERIGE");
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
    this.Text("NCZDG.navRecent",       "{n} VOR KURZEM");

    // --- cards -------------------------------------------------------------------------
    this.Text("NCZDG.badgeRecent",     "VOR KURZEM AKTUALISIERT");
    this.Text("NCZDG.badgeInstalled",  "INSTALLIERT");
    this.Text("NCZDG.noImage",         "KEIN BILD IN DIESER AKTE VORHANDEN");

    // --- lightbox ----------------------------------------------------------------------
    this.Text("NCZDG.imgLoading",      "LÄDT...");
    this.Text("NCZDG.imgLoadingClose", "LÄDT...   -   IRGENDWO KLICKEN ZUM SCHLIEßEN");
    this.Text("NCZDG.imgFailed",       "BILD NICHT VERFÜGBAR   -   IRGENDWO KLICKEN ZUM SCHLIEßEN");
    this.Text("NCZDG.imgClose",        "IRGENDWO KLICKEN ZUM SCHLIEßEN");

    // --- categories --------------------------------------------------------------------
    // The card badge and the map breakdown want the same three words in singular and
    // plural. The registry's own values ("new-location", "location-overhaul") are data
    // and are never translated - only their labels are.
    this.Text("NCZDG.catNew",          "NEUER ORT");
    this.Text("NCZDG.catNewPlural",    "NEUE ORTE");
    this.Text("NCZDG.catOverhaul",     "ÜBERARBEITETER");
    this.Text("NCZDG.catOverhaulPlural", "ÜBERARBEITETE");
    this.Text("NCZDG.catOther",        "ANDERER");
    this.Text("NCZDG.catOtherPlural",  "ANDERE");

    // --- district notice + fast-travel panel -------------------------------------------
    this.Text("NCZDG.panelEmpty",      "Noch keine eingetragenen Orte in {area}");
    this.Text("NCZDG.panelCountOne",   "{n} eingetragener Ort in {area}");
    this.Text("NCZDG.panelCountMany",  "{n} eingetragene Orte in {area}");
    this.Text("NCZDG.panelNearest",    "Nächstliegend: {name}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "NC ZONING:");
    this.Text("NCZDG.mapEmpty",        "KEINE EINGETRAGENEN ORTE");
    this.Text("NCZDG.mapCountOne",     "{n} ORT");
    this.Text("NCZDG.mapCountMany",    "{n} ORTE");
    this.Text("NCZDG.mapRecent",       "{n} VOR KURZEM AKTUALISIERT");

    // --- failure states ----------------------------------------------------------------
    // The long form belongs to NCZoningCore (GetStatusMessage) and is localised there.
    this.Text("NCZDG.noData",          "KEINE ORTSDATEN");

    // --- RCF settings panel ------------------------------------------------------------
    // RCF resolves these itself: DVRCF_HubPopup.LocalizeSchema runs every schema string
    // through LocalizationSystem.GetText, so the adapter passes KEYS, not translated text.
    this.Text("NCZDG.modName",         "NC Zoning Board - Stadtteil-Reiseführer");
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
    this.Text("NCZDG.tipShowing",      "Welche Orte der Reiseführer beim Öffnen anzeigt. Ansicht kann innerhalb des Reiseführers frei gewechselt werden. Benötigt Cyber Engine Tweaks zum Erkennen installierter Mods.");
    this.Text("NCZDG.optOpenArea",     "Aktueller Stadtteil beim Öffnen");
    this.Text("NCZDG.tipOpenArea",     "Der Reiseführer öffnet sich für deinen momentanen Stadtteil. Wenn dies deaktiviert ist oder du dich außerhalb der Karte befindest, werden immer ALLE ORTE angezeigt.");
    this.Text("NCZDG.optOpenMap",      "Zum Anzeigen Karte öffnen");
    this.Text("NCZDG.tipOpenMap",      "ZEIGE AUF KARTE öffnet die Karte und zentriert sie auf den Wegpunkt. Abschalten, um nur einen Wegpunkt zu setzen und im Reiseführer zu bleiben.");
    this.Text("NCZDG.optAutoTrack",    "Wegpunkt verfolgen");
    this.Text("NCZDG.tipAutoTrack",    "Direkt die Wegsuche einleiten, anstatt das händisch in der Karte machen zu müssen. Ein zuvor selbst gesetzter Wegpunkt wird ersetzt; die aktuelle Missions-Markierung wird aber nicht überschrieben.");
    this.Text("NCZDG.noteWaypoint",    "Die Wegsuche funktioniert erst, nachdem einmal die Karte geöffnet wurde. Dies ist eine Einschränkung des Spiels selbst, keine Einstellung.");

    this.Text("NCZDG.dropAll",         "Alle");
    this.Text("NCZDG.dropInstalled",   "Nur installierte");
    this.Text("NCZDG.dropMissing",     "Nur fehlende");

    this.Text("NCZDG.secMap",          "Karte");
    this.Text("NCZDG.optMap",          "In Karte anzeigen");
    this.Text("NCZDG.tipMap",          "Fügt die Anzahl der Orts-Mods unterteilt nach Kategorie zum Bezirksinfo-Panel der Karte hinzu.");

    this.Text("NCZDG.secNotice",       "Stadtteil-Benachrichtigung");
    this.Text("NCZDG.optNotice",       "In Stadtteil-Benachrichtigung anzeigen");
    this.Text("NCZDG.tipNotice",       "Fügt der Benachrichtigung beim Wechsel des Stadtteils ein Panel hinzu. Die Benachrichtigung selbst bleibt immer aktiv.");
    this.Text("NCZDG.optNearest",      "Nächstgelegenen Ort anzeigen");
    this.Text("NCZDG.tipNearest",      "Den Namen der nächstgelegenen Mod im Umkreis anzeigen. Aus zeigt nur die Anzahl an.");
    this.Text("NCZDG.optFastTravel",   "Bei Schnellreise anzeigen");
    this.Text("NCZDG.tipFastTravel",   "Zeigt eine Stadtteil-Benachrichtigung bei Ankunft nach einer Schnellreise an. Aus belässt die Schnellreise auf Spiel-Standard (keine Benachrichtigung).");
  }
}