// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Config.reds
// Author: Spuddeh
// Description: The single source of truth for every setting.
//
//              RCF owns EVERY setting, the keybind included:
//                - NCZDGConfig  : all toggles and sliders. Plain fields, no annotations.
//                - NCZDGKeybind : the open key and its modifier. Also RCF, via a Keybind
//                                 row and a ModifierKeybind row (see RCFAdapter.reds).
//
//              MOD SETTINGS IS NOT USED, AND MUST NOT BE REINTRODUCED. RCF 2.0.0 captures
//              keybinds itself, through Keybind/PadKeybind/AnyKeybind/ModifierKeybind rows
//              and a bundled DVRCFInput RED4ext plugin that applies the override. RCF 1.3.0
//              could not; that limit was a fact about the version, not about RCF.
//
//              RCF IS OPTIONAL ONLY ON PAPER. Without it the mod still runs, but the
//              key is stuck on the nczdg.xml default with no modifier and no way to rebind,
//              and RED4ext is in the chain either way via RCF's bundled plugin.
// Mod Version: 1.1.0
// Credits: jackhumbert (Mod Settings, Input Loader), DigitalVixen (RCF)
// ======================================================================================

module NCZoningDistrictGuide.Config

// --- settings (RCF's F8 panel) --------------------------------------------------------
// No @runtimeProperty annotations: these are not exposed to Mod Settings. RCF reads and
// writes them through NCZDGRcfProvider, and reads live state on every panel open.

public class NCZDGConfig extends ScriptableService {
  // Applies to EVERY surface - the guide, the banner and the map panel all scope their counts
  // through NCZDG_UseSubdistrict. It is not a guide setting, so it does not live in that section.
  public let matchSubdistrict: Bool = true;

  // District guide
  public let enableStandaloneGuide: Bool = true;

  // Which install filter the guide OPENS on: 0 all, 1 installed, 2 missing. The starting view,
  // not a memory of the last click - cycling the filter in the guide is session-local and does
  // not write back here.
  //
  // Has no effect without CET, which detection needs; the guide then hides the filter control.
  public let defaultInstallFilter: Int32 = 0;

  // Which AREA the guide opens on: the district the player is standing in (ON), or the ALL
  // LOCATIONS row (OFF). Off-map always opens on ALL, whatever this says.
  public let openOnCurrentArea: Bool = true;

  // What SHOW ON MAP does beyond placing the waypoint. Both default ON.
  //
  // AUTO-TRACK DOES NOT COST THE PLAYER THEIR QUEST. The player-tracked and quest-tracked slots are
  // separate: vanilla's TryTrackQuestOrSetWaypoint (worldMap.swift:845) sends quest tracking through
  // CanQuestTrackMappin -> TrackQuestMappin and player tracking through CanPlayerTrackMappin ->
  // TrackMappin, and the player branch clears only UntrackCustomPositionMappin - a custom map
  // waypoint. The tracked quest is untouched.
  //
  // Field names say "Marker" because they are RCF STORAGE KEYS: renaming one silently orphans every
  // existing user's saved value. Player-facing text says "waypoint", the game's own word.
  public let openMapOnMarker: Bool = true;
  public let autoTrackMarker: Bool = true;

  // World map panel
  public let enableMapPanel: Bool = true;

  // Nearby notice (the district-enter banner)
  public let enablePopupToast: Bool = true;
  public let showNearest: Bool = true;
  // Fast travel fires no district banner, so a standalone panel shows on arrival. Off = leave
  // fast travel entirely to the game (the notice then only appears when the game banners).
  public let enableFastTravelNotice: Bool = true;

  public final static func Get() -> ref<NCZDGConfig> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.Config.NCZDGConfig") as NCZDGConfig;
  }
}

// --- keybind (RCF) ---------------------------------------------------------------------
// Both fields are written by NCZDGRcfProvider.SetInt and read back by GetInt, so they hold
// whatever RCF captured and persisted in
// r6/storages/RedscriptConfigFramework/NCZoningDistrictGuide.json.
//
// openGuideKey is STORAGE, NOT THE THING THE LISTENER MATCHES ON. Nothing reads it to decide
// whether a press counts: the listener matches the input action n"NCZDG_ToggleGuide", and
// RCF pushes this value to the DVRCFInput plugin, which overrides the key bound to the
// `overridableUI="openGuideKey"` mapping in r6/input/nczdg.xml. The row key, the field name
// and that XML attribute are ONE name in three places - rename any of them and the bind
// silently stops working with no error anywhere.
//
// The default is the apostrophe: EInputKey.IK_SingleQuote (222, verified against the RTTI
// dump). There is no IK_Apostrophe.
//
// openGuideModifier is any key, not a Shift/Alt/Ctrl choice. IK_None means no modifier. It
// is a `localOnly` RCF row, so RCF never pushes it to the plugin and it is resolved in
// script - see NCZDGModifierWatch, which tracks whether it is held.
public class NCZDGKeybind extends ScriptableService {
  public let openGuideKey: EInputKey = EInputKey.IK_SingleQuote;
  public let openGuideModifier: EInputKey = EInputKey.IK_None;

  public final static func Get() -> ref<NCZDGKeybind> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.Config.NCZDGKeybind") as NCZDGKeybind;
  }
}

// --- the session's effective settings, in one line ---------------------------------------
// Emitted once at session ready, BEFORE the core-present check, so the settings are on record
// even when the mod is dormant. No surface logs its own "disabled in settings" line.
public func NCZDG_LogConfig() -> Void {
  let cfg = NCZDGConfig.Get();
  let keys = NCZDGKeybind.Get();
  if !IsDefined(cfg) || !IsDefined(keys) {
    NCZDGWarn("[CFG] settings service is not up - the defaults below are NOT what is running");
    return;
  }
  NCZDGLog(s"[CFG] guide=\(NCZDG_OnOff(cfg.enableStandaloneGuide)) map=\(NCZDG_OnOff(cfg.enableMapPanel)) banner=\(NCZDG_OnOff(cfg.enablePopupToast)) nearest=\(NCZDG_OnOff(cfg.showNearest)) fastTravel=\(NCZDG_OnOff(cfg.enableFastTravelNotice)) subdistrict=\(NCZDG_OnOff(cfg.matchSubdistrict)) filter=\(cfg.defaultInstallFilter) openArea=\(NCZDG_OnOff(cfg.openOnCurrentArea)) openMap=\(NCZDG_OnOff(cfg.openMapOnMarker)) autoTrack=\(NCZDG_OnOff(cfg.autoTrackMarker))");
  NCZDGLog(s"[CFG] openKey=\(EnumValueToString("EInputKey", Cast<Int64>(EnumInt(keys.openGuideKey)))) modifier=\(EnumValueToString("EInputKey", Cast<Int64>(EnumInt(keys.openGuideModifier))))");
}

private func NCZDG_OnOff(v: Bool) -> String {
  return v ? "on" : "off";
}
