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
//              THE MOD SETTINGS DEPENDENCY IS GONE, AND THE REASON IT EXISTED IS DEAD.
//              This file used to state as fact that "RCF cannot capture keybinds: its row
//              kinds are Label/Header/Toggle/Slider/Stepper/Button/Dropdown/Image
//              (DVRCF_HubPopup.reds:1476-1501), its provider has no EInputKey channel, and
//              its popup only handles n"click"." Every clause of that was true of RCF
//              1.3.0 and is FALSE of 2.0.0, which added Keybind/PadKeybind/AnyKeybind/
//              ModifierKeybind rows, a capture UI, and a bundled DVRCFInput RED4ext plugin
//              that applies the override. A framework limitation is a fact about a VERSION.
//
//              WHAT THAT COSTS, accepted deliberately: RCF is no longer merely recommended.
//              Without it the mod still runs, but the key is stuck on the nczdg.xml default
//              with no modifier and no way to rebind. RED4ext is now in the chain too, via
//              RCF's bundled plugin.
//
//              One owner per setting is UNCHANGED - it never rested on the keybind
//              limitation. Only WHICH framework owns the keybind changed.
//              [[CP2077-Mods/wiki/decisions/one-owner-per-setting-rcf-plus-modsettings-keybind]]
// Mod Version: 0.1.0 (Pre-release)
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

  // Which install filter the guide OPENS on: 0 all, 1 installed, 2 missing. A preference for
  // the starting view, not a memory of the last click - cycling the filter in the guide is
  // session-local and deliberately does not write back here.
  //
  // Has no effect without CET, which is what detection needs; the guide then hides the filter
  // control entirely rather than offering one that cannot work.
  public let defaultInstallFilter: Int32 = 0;

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
// ONE declaration now. This class used to be declared twice under
// @if(ModuleExists("ModSettingsModule")) - annotated for Mod Settings, bare without it -
// following DVRCF_Config.reds. Mod Settings is gone, so the twin is gone with it.
//
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
// N is photo mode, so the default is the apostrophe: EInputKey.IK_SingleQuote (222, verified
// against the RTTI dump). There is no IK_Apostrophe.
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
