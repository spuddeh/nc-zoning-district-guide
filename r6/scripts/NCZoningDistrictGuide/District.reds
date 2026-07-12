// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: District.reds
// Author: Spuddeh
// Description: Layer 2 - the runtime district resolver. NCZoningCore ships the static
//              Layer-1 table (NCZDistrictMap.Lookup, game TweakDBID -> API district
//              strings); reading live game state to feed it is the consumer's job.
//
//              Resolves the district the player is standing in, then walks the district
//              record's parent chain until the map answers. Returns null off-map (e.g.
//              the Dogtown_Brooklyn flashback, deliberately excluded from the map).
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

module NCZoningDistrictGuide.District

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*

// How far up the parent chain to walk. The game's own GetRadioEntryName unrolls this to
// three levels (subdistrict -> district -> region), so 8 is generous with no runaway.
public func NCZDG_MaxParentWalk() -> Int32 { return 8; }

// --- the player's current District ------------------------------------------------
// PreventionSystem.GetCurrentDistrict() is public and const, and forwards to its private
// m_districtManager. NOTE: the CET Lua recipe reads the `districtManager` FIELD and walks
// `dm.stack`; neither is reachable from redscript, because both m_districtManager and
// DistrictManager.m_stack are PRIVATE. CET sees engine property names and ignores privacy;
// redscript does not. Hence the public getter here, and the record parent-chain walk below
// instead of the stack walk.
public func NCZDG_GetCurrentDistrict(gi: GameInstance) -> wref<District> {
  let container = GameInstance.GetScriptableSystemsContainer(gi);
  if !IsDefined(container) {
    return null;
  }
  let ps = container.Get(n"PreventionSystem") as PreventionSystem;
  if !IsDefined(ps) {
    return null;
  }
  return ps.GetCurrentDistrict();
}

// The player's current district id, or an invalid TweakDBID if it cannot be read yet.
// Unguarded (no core types), so callers can use it to dedupe district-change fires even
// when the core is absent. NOTE: TweakDBID has a real == operator (unlike String, which
// needs UnicodeStringEqual); the core's own Layer-1 map compares ids with ==.
public func NCZDG_GetCurrentDistrictID(gi: GameInstance) -> TweakDBID {
  let district = NCZDG_GetCurrentDistrict(gi);
  if !IsDefined(district) {
    return TDBID.None();
  }
  return district.GetDistrictID();
}

// --- Layer 2 resolve ---------------------------------------------------------------
// Guarded: NCZDistrictName / NCZDistrictMap only exist when the core is installed.

@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ResolveCurrent(gi: GameInstance) -> ref<NCZDistrictName> {
  let district = NCZDG_GetCurrentDistrict(gi);
  if !IsDefined(district) {
    // Expected before DistrictManager is seeded (~10s after Session/Ready). Callers should
    // resolve on demand, not at data-ready.
    return null;
  }
  // GetDistrictID() returns the record's TweakDBID in PATH form (e.g. Districts.Kabuki),
  // which is exactly what the Layer-1 map keys on. Try the most specific level first.
  let hit = NCZDistrictMap.Lookup(district.GetDistrictID());
  if IsDefined(hit) {
    return hit;
  }
  // Not directly on the map (an interior, or an unmapped subdistrict): climb the record's
  // parent chain until something answers.
  return NCZDG_ResolveFromRecord(district.GetDistrictRecord());
}
// No @if(!ModuleExists) twin for the resolvers: their return type ref<NCZDistrictName> does
// not exist without the core, so there is nothing sane to return. Every CALL SITE is itself
// inside an @if(ModuleExists("NCZoning.Api")) item, so these simply compile away together.

// Walk a district record outward (subdistrict -> district -> region), asking the map at
// each level. First non-null wins. Mirrors the game's own ParentDistrict() chain walk in
// DistrictManager.GetRadioEntryName.
// Takes a wref so both callers fit: District.GetDistrictRecord() hands back a ref (which
// coerces), MappinUtils.GetDistrictRecord() hands back a wref (which would not).
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ResolveFromRecord(startRecord: wref<District_Record>) -> ref<NCZDistrictName> {
  // Confirmed in-game: an interior carries its own district record that is absent from the
  // map (e.g. Districts.GrandImperialMall), and one step up resolves it (Districts.Coastview).
  let record: wref<District_Record> = startRecord;
  let steps: Int32 = 0;
  while IsDefined(record) && steps < NCZDG_MaxParentWalk() {
    let hit = NCZDistrictMap.Lookup(record.GetRecordID());
    if IsDefined(hit) {
      return hit;
    }
    record = record.ParentDistrict();
    steps += 1;
  }
  return null;   // off-map: nothing in the chain is in the registry's vocabulary
}

// The map screen supplies a gamedataDistrict ENUM, not a TweakDBID. The enum NAME and the
// record PATH differ in 105 of 132 records, so never string-build the path. Go through the
// record, which knows its own id.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ResolveFromEnum(district: gamedataDistrict) -> ref<NCZDistrictName> {
  let record = MappinUtils.GetDistrictRecord(district);
  if !IsDefined(record) {
    return null;
  }
  return NCZDG_ResolveFromRecord(record);
}

// Resolve from a district ENUM NAME string (e.g. "Kabuki"). The district-enter banner freezes
// this string (District_Record.EnumName(), via the UI_Map blackboard) at the moment of the
// crossing, so resolving from it keeps the count matching the banner even when the player has since
// flown on to another district. EnumValueFromString maps the name to the gamedataDistrict enum.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ResolveFromEnumName(enumName: String) -> ref<NCZDistrictName> {
  if UnicodeStringEqual(enumName, "") {
    return null;
  }
  let value = EnumValueFromString("gamedataDistrict", enumName);
  return NCZDG_ResolveFromEnum(IntEnum<gamedataDistrict>(Cast<Int32>(value)));
}
