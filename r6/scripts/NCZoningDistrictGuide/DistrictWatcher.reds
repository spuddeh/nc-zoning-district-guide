// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: DistrictWatcher.reds
// Author: Spuddeh
// Description: District-change hook. The game queues a PlayerEnteredNewDistrictEvent at
//              the player whenever DistrictManager.PushDistrict accepts a new district,
//              and PlayerPuppet handles it in the scripted callback OnDistrictChanged.
//              Wrapping that gives us a precise, poll-free district-change signal.
//
//              The event payload carries only gunshot/explosion ranges, not the district,
//              so we re-resolve through Layer 2 (District.reds) on each fire.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
// NCZLocation lives in NCZoning.Data. The Api query functions RETURN array<ref<NCZLocation>>,
// so any file that calls them needs this import too, even if it never names the type.
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*
import NCZoningDistrictGuide.Config.*

// The last district we reported on, so a single boundary crossing does not fire twice.
// Verified in-game: stepping from an interior out to the street queues OnDistrictChanged
// once per district entered, so Little China reported twice within the same second.
@if(ModuleExists("NCZoning.Api"))
@addField(PlayerPuppet)
public let nczdg_lastDistrict: TweakDBID;

@if(ModuleExists("NCZoning.Api"))
@wrapMethod(PlayerPuppet)
protected cb func OnDistrictChanged(evt: ref<PlayerEnteredNewDistrictEvent>) -> Bool {
  let result = wrappedMethod(evt);

  let current = NCZDG_GetCurrentDistrictID(this.GetGame());
  if current == this.nczdg_lastDistrict {
    return result;   // same district, nothing new to say
  }
  this.nczdg_lastDistrict = current;

  NCZDG_OnDistrictChanged(this.GetGame());
  return result;
}

// Kept as a free function so the wrap stays a one-liner and the logic is testable from
// elsewhere (the guide and the toast will both want "where am I now").
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_OnDistrictChanged(gi: GameInstance) -> Void {
  if !IsReady() {
    return;   // registry not loaded yet; nothing to report against
  }
  let cfg = NCZDGConfig.Get();
  if IsDefined(cfg) && !cfg.enablePopupToast {
    return;   // nearby notice switched off in settings
  }

  let here = NCZDG_ResolveCurrent(gi);
  if !IsDefined(here) {
    return;   // off-map (e.g. the Dogtown_Brooklyn flashback): say nothing
  }

  // Confirmed in-game that this can legitimately be 0 (NCX Spaceport / Morro Rock),
  // so treat 0 as "say nothing", never render a bare "0".
  let count = NCZDG_CountHere(here);
  if count <= 0 {
    return;
  }

  NCZDGLog(s"district changed: \(NCZDG_AreaLabel(here)) - \(count) registry locations");
}

// Whether to narrow to the subdistrict: only when the player is in one AND the setting
// allows it. Centralised so the toast, guide and map panel all agree.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_UseSubdistrict(here: ref<NCZDistrictName>) -> Bool {
  if !IsDefined(here) || UnicodeStringEqual(here.subdistrict, "") {
    return false;
  }
  let cfg = NCZDGConfig.Get();
  return !IsDefined(cfg) || cfg.matchSubdistrict;
}

// "Watson / Kabuki", or just "Dogtown" for a top-level district.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_AreaLabel(here: ref<NCZDistrictName>) -> String {
  if !IsDefined(here) {
    return "";
  }
  if NCZDG_UseSubdistrict(here) {
    return here.district + " / " + here.subdistrict;
  }
  return here.district;
}

// Locations in the area the player occupies: the subdistrict when there is one and the
// setting allows narrowing, otherwise the whole district.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_CountHere(here: ref<NCZDistrictName>) -> Int32 {
  if !IsDefined(here) {
    return 0;
  }
  // rvalue-array gotcha: bind the array return to a local before ArraySize.
  if NCZDG_UseSubdistrict(here) {
    let inSub = GetLocationsBySubdistrict(here.subdistrict);
    return ArraySize(inSub);
  }
  let inDistrict = GetLocationsByDistrict(here.district);
  return ArraySize(inDistrict);
}
