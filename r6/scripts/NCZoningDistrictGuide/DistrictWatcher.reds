// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: DistrictWatcher.reds
// Author: Spuddeh
// Description: District-change hook. The game queues a PlayerEnteredNewDistrictEvent at
//              the player whenever DistrictManager.PushDistrict accepts a new district,
//              and PlayerPuppet handles it in the scripted callback OnDistrictChanged.
//              Wrapping it yields a precise, poll-free district-change signal.
//
//              The event payload carries only gunshot/explosion ranges, not the district,
//              so each fire re-resolves through Layer 2 (District.reds).
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

// The last district reported, so a single boundary crossing does not fire twice. Stepping from an
// interior out to the street queues OnDistrictChanged once per district entered, which reports the
// same district twice within a second.
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
  // Not logged. Crossing a district is something the world does, not something the player
  // chose, and it happens continuously while driving.
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

// The most-specific area name the count is scoped to: the subdistrict when narrowing is on
// and one exists, otherwise the district. This is the area the count actually describes.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_AreaName(here: ref<NCZDistrictName>) -> String {
  if !IsDefined(here) {
    return "";
  }
  if NCZDG_UseSubdistrict(here) {
    return here.subdistrict;
  }
  return here.district;
}

// The registry locations in the area the player occupies: the subdistrict when there is one
// and the setting allows narrowing, otherwise the whole district. One place so the count and
// the nearest-location line always agree on the same set.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_LocationsHere(here: ref<NCZDistrictName>) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  if !IsDefined(here) {
    return out;
  }
  if NCZDG_UseSubdistrict(here) {
    out = GetLocationsBySubdistrict(here.subdistrict);
  } else {
    out = GetLocationsByDistrict(here.district);
  }
  return out;
}

@if(ModuleExists("NCZoning.Api"))
public func NCZDG_CountHere(here: ref<NCZDistrictName>) -> Int32 {
  // rvalue-array gotcha: bind the array return to a local before ArraySize.
  let locs = NCZDG_LocationsHere(here);
  return ArraySize(locs);
}

// Near-ties draw at random. Clustered locations - several mods of the same building - would
// otherwise pin the nearest line to one winner forever; anything within this many metres of the
// closest is an equally true answer.
public func NCZDG_NearestTieband() -> Float { return 25.0; }

// The closest registry location to `from` among a set, by squared distance. No radius: the
// set is already district-scoped (2-84 entries), so the scan is cheap and always names one.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ClosestInArea(locs: array<ref<NCZLocation>>, from: Vector4) -> ref<NCZLocation> {
  let best: ref<NCZLocation>;
  let bestSq: Float = 0.0;
  let i = 0;
  while i < ArraySize(locs) {
    let loc = locs[i];
    if IsDefined(loc) {
      let d = Vector4.DistanceSquared(from, loc.Pos());
      if !IsDefined(best) || d < bestSq {
        best = loc;
        bestSq = d;
      }
    }
    i += 1;
  }
  if !IsDefined(best) {
    return best;
  }
  // Distances are compared SQUARED throughout, so the tieband threshold squares too.
  let limit = SqrtF(bestSq) + NCZDG_NearestTieband();
  let limitSq = limit * limit;
  let ties: array<ref<NCZLocation>>;
  i = 0;
  while i < ArraySize(locs) {
    let loc = locs[i];
    if IsDefined(loc) && Vector4.DistanceSquared(from, loc.Pos()) <= limitSq {
      ArrayPush(ties, loc);
    }
    i += 1;
  }
  if ArraySize(ties) <= 1 {
    return best;
  }
  return ties[RandRange(0, ArraySize(ties))];
}
