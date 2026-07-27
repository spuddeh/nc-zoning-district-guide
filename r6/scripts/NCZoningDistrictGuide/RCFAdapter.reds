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
//              THIS IS NOW THE ONLY SETTINGS UI, WITH NO EXCEPTION. The keybind used to live
//              in Mod Settings because RCF 1.3.0 could not capture one - no keybind row kind,
//              no EInputKey channel, popup handled only n"click". All of that is FALSE of
//              2.0.0 (2026-07-26), which added Keybind/PadKeybind/AnyKeybind/ModifierKeybind
//              rows and a bundled DVRCFInput RED4ext plugin that applies the override. The
//              Mod Settings dependency is gone.
//
//              THE PRICE, accepted: RCF is no longer merely recommended. Without it the mod
//              runs on defaults but has no rebindable key at all, and RED4ext is now in the
//              chain via RCF's bundled plugin.
//              [[CP2077-Mods/wiki/decisions/one-owner-per-setting-rcf-plus-modsettings-keybind]]
//
//              Mod Settings push-back is not merely removed, it is FORBIDDEN. The only commit
//              call available to redscript, ModSettings.AcceptChanges(), is GLOBAL: it would
//              apply every other mod's pending unapplied changes as a side effect. That is
//              why no future setting may be mirrored there.
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

// THIS ONE IS NOT JUST A STORAGE KEY. DVRCF_Hotkeys.PushSchema feeds the row key straight to
// RCFInput.SetKeyOverride, so it must equal the `overridableUI` attribute in
// r6/input/nczdg.xml. Change it in one place only and the bind silently stops working -
// there is no error, in any log.
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
    return DVRCF_SchemaBuilder.New("NC Zoning District Guide")
      .Section("Locations")
        .Toggle(NCZDG_KeySubdistrict(), "Narrow to Subdistrict")
          .Tip("Scope every count to your subdistrict when you are in one, rather than the whole district. Applies to the guide, the map panel and the district notice.")
      .Section("District Guide")
        .Toggle(NCZDG_KeyGuide(), "Enable District Guide")
          .Tip("Browse the location mods in any district, with search, a map waypoint and a teleport.")
        .Keybind(NCZDG_KeyOpenKey(), "Open Guide Key")
          .Tip("Key that opens the district guide. Requires Input Loader.")
        .ModifierKeybind(NCZDG_KeyOpenModifier(), "Open Guide Modifier")
          .Tip("Optional key to hold alongside the open key. Any key will do, not just Shift, Alt or Ctrl. Leave unset for no modifier.")
        .Label("A waypoint set from the guide only draws its route once you open the world map. That is a game limitation, not a setting.")
      .Section("World Map")
        .Toggle(NCZDG_KeyMapPanel(), "Show on World Map")
          .Tip("Add a location mod count and category breakdown to the map's district info panel.")
      .Section("District Notice")
        .Toggle(NCZDG_KeyToast(), "Enable District Notice")
          .Tip("When you enter a district, add a panel below the game's district banner. Never suppresses the banner itself.")
        .Toggle(NCZDG_KeyShowNearest(), "Name the Nearest Location")
          .Tip("Also name the closest location mod in the area. Off shows only the count.")
        .Toggle(NCZDG_KeyFastTravel(), "Show on Fast Travel")
          .Tip("Fast travel fires no district banner, so the notice appears on arrival instead. Off leaves fast travel entirely to the game.")
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
  }

  // Keybind rows travel on the Int channel as an EInputKey cast to Int32; there is no
  // EInputKey channel on the provider contract.
  //
  // NEVER RETURN 0 FOR THE OPEN KEY. DVRCF_Hotkeys.PushSchema pushes whatever this returns
  // straight into RCFInput.SetKeyOverride with no >0 guard of its own, so a 0 here would
  // override the binding with "no key" and the guide would become unopenable. RCF's own
  // GetInt("dvrcfOpenKey") carries the identical guard for the identical reason.
  public func GetInt(key: String) -> Int32 {
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
      "NCZoningDistrictGuide",
      "NC Zoning District Guide",
      "Which location mods are in the district around you.",
      provider
    );
    NCZDGLog("registered with RCF");
  }
}
