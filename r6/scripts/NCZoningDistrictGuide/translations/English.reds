// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: translations/English.reds
// Author: Spuddeh
// Description: The source of truth for every player-facing string. Codeware's
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
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware), DigitalVixen (RCF, the reference implementation)
// ======================================================================================

module NCZoningDistrictGuide.Translations

import Codeware.Localization.*

public class NCZDG_English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // --- guide chrome ------------------------------------------------------------------
    this.Text("NCZDG.title",           "NC ZONING BOARD");
    this.Text("NCZDG.headerLeft",      "NIGHT CORP // URBAN PLANNING DIVISION");
    this.Text("NCZDG.headerRight",     "NC-ZB-01");
    this.Text("NCZDG.searchHint",      "SEARCH NAME, AUTHOR, TAG");

    // --- buttons -----------------------------------------------------------------------
    this.Text("NCZDG.btnClear",        "CLEAR");
    this.Text("NCZDG.btnSetMarker",    "SET MARKER");
    this.Text("NCZDG.btnSetWaypoint",  "SHOW ON MAP");
    this.Text("NCZDG.btnClearMarker",  "CLEAR MARKER");
    this.Text("NCZDG.btnTeleport",     "TELEPORT");
    this.Text("NCZDG.btnExitVehicle",  "EXIT VEHICLE");
    this.Text("NCZDG.btnPrev",         "< PREV");
    this.Text("NCZDG.btnNext",         "NEXT >");

    // --- install filter ----------------------------------------------------------------
    this.Text("NCZDG.filterAll",       "SHOWING: ALL");
    this.Text("NCZDG.filterInstalled", "SHOWING: INSTALLED");
    this.Text("NCZDG.filterMissing",   "SHOWING: MISSING");
    this.Text("NCZDG.filterUnknown",   "SHOWING: UNKNOWN");

    // --- the guide's status line -------------------------------------------------------
    // Three forms because the sentence differs, not because the numbers do: a search says
    // how many of the area matched, a paged list says which slice is on screen, and a
    // short list says only the total.
    this.Text("NCZDG.countSearch",     "{n} OF {total} IN {area}");
    this.Text("NCZDG.countPaged",      "{from}-{to} OF {n} IN {area}");
    this.Text("NCZDG.countPlain",      "{n} IN {area}");
    this.Text("NCZDG.routingHint",     "   ·   FOR DIRECTIONS: OPEN THE WORLD MAP, HOVER THE NC MARKER, TRACK WAYPOINT");

    // --- nav column --------------------------------------------------------------------
    this.Text("NCZDG.areaAll",         "ALL LOCATIONS");
    this.Text("NCZDG.navRecent",       "{n} RECENT");

    // --- cards -------------------------------------------------------------------------
    this.Text("NCZDG.badgeRecent",     "RECENTLY UPDATED");
    this.Text("NCZDG.noImage",         "NO SURVEY IMAGE ON FILE");

    // --- lightbox ----------------------------------------------------------------------
    this.Text("NCZDG.imgLoading",      "LOADING...");
    this.Text("NCZDG.imgLoadingClose", "LOADING...   -   CLICK ANYWHERE TO CLOSE");
    this.Text("NCZDG.imgFailed",       "IMAGE UNAVAILABLE   -   CLICK ANYWHERE TO CLOSE");
    this.Text("NCZDG.imgClose",        "CLICK ANYWHERE TO CLOSE");

    // --- categories --------------------------------------------------------------------
    // The card badge and the map breakdown want the same three words in singular and
    // plural. The registry's own values ("new-location", "location-overhaul") are data
    // and are never translated - only their labels are.
    this.Text("NCZDG.catNew",          "NEW LOCATION");
    this.Text("NCZDG.catNewPlural",    "NEW LOCATIONS");
    this.Text("NCZDG.catOverhaul",     "OVERHAUL");
    this.Text("NCZDG.catOverhaulPlural", "OVERHAULS");
    this.Text("NCZDG.catOther",        "OTHER");
    this.Text("NCZDG.catOtherPlural",  "OTHER");

    // --- district notice + fast-travel panel -------------------------------------------
    this.Text("NCZDG.panelEmpty",      "No registered locations in {area} yet");
    this.Text("NCZDG.panelCountOne",   "{n} registered location in {area}");
    this.Text("NCZDG.panelCountMany",  "{n} registered locations in {area}");
    this.Text("NCZDG.panelNearest",    "Nearest: {name}");

    // --- world map panel ---------------------------------------------------------------
    this.Text("NCZDG.mapCaption",      "NC ZONING:");
    this.Text("NCZDG.mapEmpty",        "NO REGISTERED LOCATIONS");
    this.Text("NCZDG.mapCountOne",     "{n} LOCATION");
    this.Text("NCZDG.mapCountMany",    "{n} LOCATIONS");
    this.Text("NCZDG.mapRecent",       "{n} RECENTLY UPDATED");
    this.Text("NCZDG.mapMarkerIdle",   "MARKER SET - TRACK IT TO ROUTE");

    // --- failure states ----------------------------------------------------------------
    // The long form belongs to NCZoningCore (GetStatusMessage) and is localised there.
    this.Text("NCZDG.noData",          "NO LOCATION DATA");

    // --- RCF settings panel ------------------------------------------------------------
    // RCF resolves these itself: DVRCF_HubPopup.LocalizeSchema runs every schema string
    // through LocalizationSystem.GetText, so the adapter passes KEYS, not translated text.
    this.Text("NCZDG.modName",         "NC Zoning District Guide");
    this.Text("NCZDG.modDesc",         "Which location mods are in the district around you.");

    this.Text("NCZDG.secLocations",    "Locations");
    this.Text("NCZDG.optSubdistrict",  "Narrow to Subdistrict");
    this.Text("NCZDG.tipSubdistrict",  "Scope every count to your subdistrict when you are in one, rather than the whole district. Applies to the guide, the map panel and the district notice.");

    this.Text("NCZDG.secGuide",        "District Guide");
    this.Text("NCZDG.optGuide",        "Enable District Guide");
    this.Text("NCZDG.tipGuide",        "Browse the location mods in any district, with search, a map waypoint and a teleport.");
    this.Text("NCZDG.optKey",          "Open Guide Key");
    this.Text("NCZDG.tipKey",          "Key that opens the district guide. Requires Input Loader.");
    this.Text("NCZDG.optModifier",     "Open Guide Modifier");
    this.Text("NCZDG.tipModifier",     "Optional key to hold alongside the open key. Any key will do, not just Shift, Alt or Ctrl. Leave unset for no modifier.");
    this.Text("NCZDG.optShowing",      "Open Guide Showing");
    this.Text("NCZDG.tipShowing",      "Which locations the guide lists when it opens. You can still switch between them inside the guide. Requires Cyber Engine Tweaks, which is what detects your installed mods.");
    this.Text("NCZDG.optOpenMap",      "Open the Map on Show");
    this.Text("NCZDG.tipOpenMap",      "SHOW ON MAP opens the world map and centres it on the marker. Turn this off to place the marker and stay in the guide.");
    this.Text("NCZDG.optAutoTrack",    "Track the Marker");
    this.Text("NCZDG.tipAutoTrack",    "Also route to the marker, the way tracking a quest does. There is only one tracked slot, so this replaces whatever you are following, a quest included.");
    this.Text("NCZDG.noteWaypoint",    "A marker only draws its route once the world map has opened. That is a game limitation, not a setting.");

    this.Text("NCZDG.dropAll",         "All");
    this.Text("NCZDG.dropInstalled",   "Installed only");
    this.Text("NCZDG.dropMissing",     "Missing only");

    this.Text("NCZDG.secMap",          "World Map");
    this.Text("NCZDG.optMap",          "Show on World Map");
    this.Text("NCZDG.tipMap",          "Add a location mod count and category breakdown to the map's district info panel.");

    this.Text("NCZDG.secNotice",       "District Notice");
    this.Text("NCZDG.optNotice",       "Enable District Notice");
    this.Text("NCZDG.tipNotice",       "When you enter a district, add a panel below the game's district banner. Never suppresses the banner itself.");
    this.Text("NCZDG.optNearest",      "Name the Nearest Location");
    this.Text("NCZDG.tipNearest",      "Also name the closest location mod in the area. Off shows only the count.");
    this.Text("NCZDG.optFastTravel",   "Show on Fast Travel");
    this.Text("NCZDG.tipFastTravel",   "Fast travel fires no district banner, so the notice appears on arrival instead. Off leaves fast travel entirely to the game.");
  }
}
