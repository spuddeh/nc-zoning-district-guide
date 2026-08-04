// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: RCFAdapter.reds
// Author: Spuddeh
// Description: Support for the Redscript Configuration Framework (RCF) by DigitalVixen: an
//              in-world F8 settings overlay. Follows the same shape as
//              VariantConfigFramework: subclass DVRCF_Provider, register on Session/Ready.
//
//              RCF owns the panel and the saved values (r6/storages/RedscriptConfigFramework);
//              this adapter bridges its Get*/Set* to NCZDGConfig and NCZDGKeybind.
//
//              Every item is guarded by @if(ModuleExists("RedscriptConfigFramework")), so
//              the whole file compiles to nothing when RCF is absent.
//
//              THIS IS THE ONLY SETTINGS UI, WITH NO EXCEPTION - the keybind included. RCF
//              2.0.0 captures keybinds through Keybind/PadKeybind/AnyKeybind/ModifierKeybind
//              rows and a bundled DVRCFInput RED4ext plugin that applies the override.
//
//              RCF IS OPTIONAL ONLY ON PAPER. Without it the mod runs on defaults but
//              has no rebindable key, and RED4ext is in the chain via RCF's bundled plugin.
//              [[CP2077-Mods/wiki/decisions/one-owner-per-setting-rcf-plus-modsettings-keybind]]
//
//              MIRRORING A SETTING BACK TO MOD SETTINGS IS FORBIDDEN. The only commit call
//              available to redscript, ModSettings.AcceptChanges(), is GLOBAL: it applies
//              every other mod's pending unapplied changes as a side effect.
// Mod Version: 0.1.0 (Pre-release)
// Credits: DigitalVixen (RCF)
// ======================================================================================

module NCZoningDistrictGuide.RCF

import NCZoningDistrictGuide.Config.*
import NCZoningDistrictGuide.Input.*

@if(ModuleExists("RedscriptConfigFramework"))
import RedscriptConfigFramework.*

// Binding keys. Kept as one set of constants so the schema and the Get/Set switch can
// never drift apart. Each matches its NCZDGConfig field name.
public func NCZDG_KeyGuide() -> String { return "enableStandaloneGuide"; }
public func NCZDG_KeySubdistrict() -> String { return "matchSubdistrict"; }
public func NCZDG_KeyMapPanel() -> String { return "enableMapPanel"; }
public func NCZDG_KeyToast() -> String { return "enablePopupToast"; }
public func NCZDG_KeyShowNearest() -> String { return "showNearest"; }
public func NCZDG_KeyFastTravel() -> String { return "enableFastTravelNotice"; }
public func NCZDG_KeyOpenArea() -> String { return "openOnCurrentArea"; }
public func NCZDG_KeyOpenMap() -> String { return "openMapOnMarker"; }
public func NCZDG_KeyAutoTrack() -> String { return "autoTrackMarker"; }

// THIS ONE IS NOT JUST A STORAGE KEY. DVRCF_Hotkeys.PushSchema feeds the row key straight to
// RCFInput.SetKeyOverride, so it must equal the `overridableUI` attribute in
// r6/input/nczdg.xml. Change it in one place only and the bind silently stops working -
// there is no error, in any log.
public func NCZDG_KeyDefaultFilter() -> String { return "defaultInstallFilter"; }

public func NCZDG_KeyOpenKey() -> String { return "openGuideKey"; }

// A ModifierKeybind row is `localOnly`: RCF stores it and never pushes it to the plugin, so
// this name only has to match the field. NCZDGModifierWatch resolves it.
public func NCZDG_KeyOpenModifier() -> String { return "openGuideModifier"; }

@if(ModuleExists("RedscriptConfigFramework"))
public class NCZDGRcfProvider extends DVRCF_Provider {

  // Needed only so SetInt can reach NCZDGModifierWatch. DVRCF_Provider carries no GameInstance
  // of its own, so RCF's own providers do the same thing (DVRCF_OptionsProvider.Init).
  private let m_gi: GameInstance;

  public func Init(gi: GameInstance) -> Void {
    this.m_gi = gi;
  }

  // Rebuilt on every panel open, so it always reflects the live config.
  public func BuildSchema() -> ref<DVRCF_Schema> {
    // Dropdown takes an array<String>, not a delimited string, and the INDEX is what the
    // provider stores - so this order is the contract with NCZDG_Filter*() and must not be
    // reordered without changing them.
    //
    // THE DROPDOWN OPTIONS ARE THE ONE PLACE THAT PASSES TEXT RATHER THAN A KEY.
    // DVRCF_HubPopup.LocalizeSchema walks tab.name, section.name, row.label, row.tooltip,
    // row.caption and row.caption2 - and stops there. The options array is not on that list,
    // so a key put here renders to the player as "NCZDG.dropAll".
    let filterOptions: array<String>;
    ArrayPush(filterOptions, NCZDG_T("NCZDG.dropAll"));
    ArrayPush(filterOptions, NCZDG_T("NCZDG.dropInstalled"));
    ArrayPush(filterOptions, NCZDG_T("NCZDG.dropMissing"));

    // Everything below is a LocKey, not a label. RCF resolves each one itself and falls back
    // to the raw string when a lookup comes back empty - so a key missing from English.reds
    // shows up as the key, in the panel, where it is hard to miss.
    return DVRCF_SchemaBuilder.New("NCZDG.modName")
      .Section("NCZDG.secLocations")
        .Toggle(NCZDG_KeySubdistrict(), "NCZDG.optSubdistrict")
          .Tip("NCZDG.tipSubdistrict")
      .Section("NCZDG.secGuide")
        .Toggle(NCZDG_KeyGuide(), "NCZDG.optGuide")
          .Tip("NCZDG.tipGuide")
        .Keybind(NCZDG_KeyOpenKey(), "NCZDG.optKey")
          .Tip("NCZDG.tipKey")
        .ModifierKeybind(NCZDG_KeyOpenModifier(), "NCZDG.optModifier")
          .Tip("NCZDG.tipModifier")
        .Dropdown(NCZDG_KeyDefaultFilter(), "NCZDG.optShowing", filterOptions)
          .Tip("NCZDG.tipShowing")
        .Toggle(NCZDG_KeyOpenArea(), "NCZDG.optOpenArea")
          .Tip("NCZDG.tipOpenArea")
        .Toggle(NCZDG_KeyOpenMap(), "NCZDG.optOpenMap")
          .Tip("NCZDG.tipOpenMap")
        .Toggle(NCZDG_KeyAutoTrack(), "NCZDG.optAutoTrack")
          .Tip("NCZDG.tipAutoTrack")
        .Label("NCZDG.noteWaypoint")
      .Section("NCZDG.secMap")
        .Toggle(NCZDG_KeyMapPanel(), "NCZDG.optMap")
          .Tip("NCZDG.tipMap")
      .Section("NCZDG.secNotice")
        .Toggle(NCZDG_KeyToast(), "NCZDG.optNotice")
          .Tip("NCZDG.tipNotice")
        .Toggle(NCZDG_KeyShowNearest(), "NCZDG.optNearest")
          .Tip("NCZDG.tipNearest")
        .Toggle(NCZDG_KeyFastTravel(), "NCZDG.optFastTravel")
          .Tip("NCZDG.tipFastTravel")
      .Build();
  }

  public func GetBool(key: String) -> Bool {
    let cfg = NCZDGConfig.Get();
    if !IsDefined(cfg) {
      return false;
    }
    if UnicodeStringEqual(key, NCZDG_KeyGuide()) { return cfg.enableStandaloneGuide; }
    if UnicodeStringEqual(key, NCZDG_KeySubdistrict()) { return cfg.matchSubdistrict; }
    if UnicodeStringEqual(key, NCZDG_KeyMapPanel()) { return cfg.enableMapPanel; }
    if UnicodeStringEqual(key, NCZDG_KeyToast()) { return cfg.enablePopupToast; }
    if UnicodeStringEqual(key, NCZDG_KeyShowNearest()) { return cfg.showNearest; }
    if UnicodeStringEqual(key, NCZDG_KeyFastTravel()) { return cfg.enableFastTravelNotice; }
    if UnicodeStringEqual(key, NCZDG_KeyOpenMap()) { return cfg.openMapOnMarker; }
    if UnicodeStringEqual(key, NCZDG_KeyAutoTrack()) { return cfg.autoTrackMarker; }
    if UnicodeStringEqual(key, NCZDG_KeyOpenArea()) { return cfg.openOnCurrentArea; }
    return false;
  }

  // RCF calls Set* live per click, and again on load via DVRCF_Store.RestoreInto, so these
  // must tolerate running before anything else has. They only touch the config singleton.
  public func SetBool(key: String, value: Bool) -> Void {
    let cfg = NCZDGConfig.Get();
    if !IsDefined(cfg) {
      return;
    }
    if UnicodeStringEqual(key, NCZDG_KeyGuide()) { cfg.enableStandaloneGuide = value; }
    else if UnicodeStringEqual(key, NCZDG_KeySubdistrict()) { cfg.matchSubdistrict = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyMapPanel()) { cfg.enableMapPanel = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyToast()) { cfg.enablePopupToast = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyShowNearest()) { cfg.showNearest = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyFastTravel()) { cfg.enableFastTravelNotice = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyOpenMap()) { cfg.openMapOnMarker = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyAutoTrack()) { cfg.autoTrackMarker = value; }
    else if UnicodeStringEqual(key, NCZDG_KeyOpenArea()) { cfg.openOnCurrentArea = value; }
  }

  // Keybind rows travel on the Int channel as an EInputKey cast to Int32; there is no
  // EInputKey channel on the provider contract.
  //
  // NEVER RETURN 0 FOR THE OPEN KEY. DVRCF_Hotkeys.PushSchema pushes whatever this returns
  // straight into RCFInput.SetKeyOverride with no >0 guard of its own, so a 0 here would
  // override the binding with "no key" and the guide would become unopenable. RCF's own
  // GetInt("dvrcfOpenKey") carries the identical guard for the identical reason.
  public func GetInt(key: String) -> Int32 {
    // A Dropdown rides the same Int channel as a Keybind; the value is the selected INDEX.
    if UnicodeStringEqual(key, NCZDG_KeyDefaultFilter()) {
      let cfg = NCZDGConfig.Get();
      return IsDefined(cfg) ? cfg.defaultInstallFilter : 0;
    }
    let keys = NCZDGKeybind.Get();
    if !IsDefined(keys) {
      return 0;
    }
    if UnicodeStringEqual(key, NCZDG_KeyOpenKey()) {
      let k = EnumInt(keys.openGuideKey);
      return k > 0 ? k : EnumInt(EInputKey.IK_SingleQuote);
    }
    // 0 is the correct answer here: IK_None means no modifier, and a localOnly row is never
    // pushed to the plugin.
    if UnicodeStringEqual(key, NCZDG_KeyOpenModifier()) {
      return EnumInt(keys.openGuideModifier);
    }
    return 0;
  }

  // Called live as the user captures a key, and again during DVRCF.Register's SyncOnRegister
  // before the panel has ever been opened, so it must tolerate running early.
  public func SetInt(key: String, value: Int32) -> Void {
    if UnicodeStringEqual(key, NCZDG_KeyDefaultFilter()) {
      let cfg = NCZDGConfig.Get();
      if IsDefined(cfg) {
        // Clamped: RCF restores whatever is in its JSON, which may predate a change to the
        // option list, and an out-of-range index would select a filter that does not exist.
        cfg.defaultInstallFilter = value >= 0 && value < 3 ? value : 0;
      }
      return;
    }
    let keys = NCZDGKeybind.Get();
    if !IsDefined(keys) {
      return;
    }
    if UnicodeStringEqual(key, NCZDG_KeyOpenKey()) {
      keys.openGuideKey = IntEnum<EInputKey>(value);
    } else if UnicodeStringEqual(key, NCZDG_KeyOpenModifier()) {
      keys.openGuideModifier = IntEnum<EInputKey>(value);
      // The watcher caches the key it listens for, so without this a modifier changed in the
      // panel would not take effect until the next launch.
      let watch = NCZDGModifierWatch.Get(this.m_gi);
      if IsDefined(watch) {
        watch.Refresh();
      }
    }
  }
}

// Registers the provider once the session is up. DVRCF.Register also pushes the saved values
// in through Set*, so registration alone restores the user's settings.
@if(ModuleExists("RedscriptConfigFramework"))
public class NCZDGRcfLoader extends ScriptableSystem {
  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    let provider = new NCZDGRcfProvider();
    // Must precede Register: Register calls SyncOnRegister, which pushes saved values in
    // through SetInt, and SetInt needs the GameInstance to reach the modifier watcher.
    provider.Init(this.GetGameInstance());
    DVRCF.Register(
      this.GetGameInstance(),
      // The mod id is STORAGE and is never translated - it names the JSON file in
      // r6/storages. The display name and description are LocKeys: RCF runs displayName
      // through Loc() everywhere it draws it, as its own logs provider does.
      "NCZoningDistrictGuide",
      "NCZDG.modName",
      "NCZDG.modDesc",
      provider
    );
  }
}
