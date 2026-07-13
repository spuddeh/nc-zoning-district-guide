// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: RCFAdapter.reds
// Author: Spuddeh
// Description: OPTIONAL support for the Redscript Configuration Framework (RCF) by
//              DigitalVixen: an in-world F8 settings overlay. Follows the same shape as
//              VariantConfigFramework: subclass DVRCF_Provider, register on Session/Ready.
//
//              RCF owns the panel and the saved values (r6/storages/RedscriptConfigFramework);
//              this adapter bridges its Get*/Set* to the one NCZDGConfig instance.
//
//              Every item is guarded by @if(ModuleExists("RedscriptConfigFramework")), so
//              the whole file compiles to nothing when RCF is absent.
//
//              This is the ONLY settings UI. The keybind is the one exception and lives in
//              Mod Settings (see Config.reds), because RCF cannot capture keybinds: its row
//              kinds are Label/Header/Toggle/Slider/Stepper/Button/Dropdown/Image
//              (DVRCF_HubPopup.reds:1476-1501), its provider contract has no EInputKey
//              channel, and its popup handles only n"click". RCF binds its own F8 hotkey
//              through Mod Settings + Input Loader for exactly this reason.
//
//              Values are deliberately NOT pushed back into Mod Settings. The only commit
//              call available to redscript, ModSettings.AcceptChanges(), is GLOBAL: it would
//              apply every other mod's pending unapplied changes as a side effect.
// Mod Version: 0.1.0 (Pre-release)
// Credits: DigitalVixen (RCF)
// ======================================================================================

module NCZoningDistrictGuide.RCF

import NCZoningDistrictGuide.Config.*

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
public func NCZDG_KeyDevMappinActive() -> String { return "devMappinActive"; }   // DEV ONLY, remove at M7

@if(ModuleExists("RedscriptConfigFramework"))
public class NCZDGRcfProvider extends DVRCF_Provider {

  // Rebuilt on every panel open, so it always reflects the live config.
  public func BuildSchema() -> ref<DVRCF_Schema> {
    return DVRCF_SchemaBuilder.New("NC Zoning District Guide")
      .Section("District Guide")
        .Toggle(NCZDG_KeyGuide(), "Enable District Guide")
          .Tip("Open a guide to the location mods in your current district with a keybind.")
        .Toggle(NCZDG_KeySubdistrict(), "Narrow to Subdistrict")
          .Tip("List only the locations in your subdistrict when you are in one, rather than the whole district.")
        .Label("The open key and its modifier are set in Mod Settings. Default is the apostrophe.")
      .Section("World Map")
        .Toggle(NCZDG_KeyMapPanel(), "Show on World Map")
          .Tip("Add a location mod count to the map's district info panel.")
      .Section("Nearby Notice")
        .Toggle(NCZDG_KeyToast(), "Enable Nearby Notice")
          .Tip("When you enter a district, add a panel to the game's district banner. Never suppresses the banner itself.")
        .Toggle(NCZDG_KeyShowNearest(), "Name the Nearest Location")
          .Tip("Also name the closest location mod in the district. Off shows only the count.")
        .Toggle(NCZDG_KeyFastTravel(), "Show on Fast Travel")
          .Tip("Fast travel does not show the game's district banner, so we show the notice on arrival. Off leaves fast travel entirely to the game.")
        .Toggle(NCZDG_KeyDevMappinActive(), "DEV: set mappin active")
          .Tip("Sets MappinData.active on the waypoint pin. Toggle it to compare both settings on the SAME location. Remove before release.")
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
    if UnicodeStringEqual(key, NCZDG_KeyDevMappinActive()) { return cfg.devMappinActive; }
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
    else if UnicodeStringEqual(key, NCZDG_KeyDevMappinActive()) { cfg.devMappinActive = value; }
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
    DVRCF.Register(
      this.GetGameInstance(),
      "NCZoningDistrictGuide",
      "NC Zoning District Guide",
      "Which location mods are in the district around you.",
      new NCZDGRcfProvider()
    );
    NCZDGLog("registered with RCF");
  }
}
