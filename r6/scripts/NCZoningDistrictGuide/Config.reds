// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Config.reds
// Author: Spuddeh
// Description: The single source of truth for every setting.
//
//              The split follows how RCF itself is built (DVRCF_Config.reds):
//                - NCZDGConfig  : all real settings. Configured in RCF's F8 panel
//                                 (see RCFAdapter.reds). Plain fields, no annotations.
//                - NCZDGKeybind : the open key and its modifier ONLY. Configured in Mod
//                                 Settings, because RCF cannot capture keybinds: its row
//                                 kinds are Label/Header/Toggle/Slider/Stepper/Button/
//                                 Dropdown/Image (DVRCF_HubPopup.reds:1476-1501), its
//                                 provider has no EInputKey channel, and its popup only
//                                 handles n"click". RCF binds its own F8 hotkey the same
//                                 way this file does.
//
//              Both frameworks are OPTIONAL. With neither installed the mod runs on the
//              defaults below. Nothing here hard-depends on either.
// Mod Version: 0.1.0 (Pre-release)
// Credits: jackhumbert (Mod Settings, Input Loader), DigitalVixen (RCF)
// ======================================================================================

module NCZoningDistrictGuide.Config

// Optional modifier held alongside the guide key. Input Loader has no modifier concept, so
// the listener tracks these keys as their own actions (see r6/input/nczdg.xml).
public enum NCZDGModifier {
  None = 0,
  Shift = 1,
  Alt = 2,
  Ctrl = 3,
}

// --- settings (RCF's F8 panel) --------------------------------------------------------
// No @runtimeProperty annotations: these are not exposed to Mod Settings. RCF reads and
// writes them through NCZDGRcfProvider, and reads live state on every panel open.

public class NCZDGConfig extends ScriptableService {
  // District guide
  public let enableStandaloneGuide: Bool = true;
  public let matchSubdistrict: Bool = true;

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

// --- keybind (Mod Settings) -----------------------------------------------------------
// Declared twice, exactly as RCF declares DVRCFConfig: annotated when Mod Settings is
// present, bare when it is not. Mod Settings writes these fields directly, and the
// overridableUI attribute in r6/input/nczdg.xml names openGuideKey so the chosen key
// reaches the input system.
//
// N is photo mode, so the default is the apostrophe: EInputKey.IK_SingleQuote (222).
// There is no IK_Apostrophe.

@if(ModuleExists("ModSettingsModule"))
public class NCZDGKeybind extends ScriptableService {
  @runtimeProperty("ModSettings.mod", "NC Zoning District Guide")
  @runtimeProperty("ModSettings.category", "Keybinds")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Open Guide Key")
  @runtimeProperty("ModSettings.description", "Key that opens the district guide. Requires Input Loader. Default is the apostrophe.")
  public let openGuideKey: EInputKey = EInputKey.IK_SingleQuote;

  @runtimeProperty("ModSettings.mod", "NC Zoning District Guide")
  @runtimeProperty("ModSettings.category", "Keybinds")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Open Guide Modifier")
  @runtimeProperty("ModSettings.description", "Hold this key with the open key. Set to None for no modifier.")
  @runtimeProperty("ModSettings.displayValues.None", "None")
  @runtimeProperty("ModSettings.displayValues.Shift", "Shift")
  @runtimeProperty("ModSettings.displayValues.Alt", "Alt")
  @runtimeProperty("ModSettings.displayValues.Ctrl", "Ctrl")
  public let openGuideModifier: NCZDGModifier = NCZDGModifier.None;

  public final static func Get() -> ref<NCZDGKeybind> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.Config.NCZDGKeybind") as NCZDGKeybind;
  }
}

@if(!ModuleExists("ModSettingsModule"))
public class NCZDGKeybind extends ScriptableService {
  public let openGuideKey: EInputKey = EInputKey.IK_SingleQuote;
  public let openGuideModifier: NCZDGModifier = NCZDGModifier.None;

  public final static func Get() -> ref<NCZDGKeybind> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"NCZoningDistrictGuide.Config.NCZDGKeybind") as NCZDGKeybind;
  }
}
