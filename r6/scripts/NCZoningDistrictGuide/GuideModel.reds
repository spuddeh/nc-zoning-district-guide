// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: GuideModel.reds
// Author: Spuddeh
// Description: The guide's data. No ink here, so it can be reasoned about on its own.
//
//              The nav list comes from the core's district VOCABULARY (GetDistricts /
//              GetSubdistricts, 0.3.0+), NOT from the locations. Deriving it from the locations
//              looks equivalent and is not: an area with zero locations appears in no location, so
//              it would silently vanish - and those are exactly the areas worth showing, because an
//              empty district is an invitation to a modder rather than an error.
//
//              The vocabulary is static, so the nav also renders correctly before the fetch lands
//              and while it is missing entirely.
//
//              A district's count is NOT the sum of its subdistricts: some locations are attributed
//              to a district directly, inside no subdistrict (Badlands has 3). Counts therefore come
//              from one pass over GetAllLocations(), bucketed by District()/Subdistrict() - never
//              from 40 separate GetLocationsByDistrict calls.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

module NCZoningDistrictGuide.Guide

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*

// One row in the left nav. "All" is a row like any other, so nothing downstream special-cases it.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGArea {
  public let district: String;
  public let subdistrict: String;   // "" for a district row
  public let isAll: Bool;
  public let isSub: Bool;
  public let count: Int32;
  public let recentCount: Int32;   // of `count`, how many carry the API's recently_updated flag

  public func Label() -> String {
    if this.isAll {
      return "ALL LOCATIONS";
    }
    return this.isSub ? this.subdistrict : this.district;
  }

  // Stable identity, for remembering the selection across a close/reopen.
  public func Key() -> String {
    if this.isAll {
      return "*";
    }
    return this.district + "|" + this.subdistrict;
  }
}

@if(ModuleExists("NCZoning.Api"))
public class NCZDGGuideModel {
  private let m_areas: array<ref<NCZDGArea>>;
  private let m_total: Int32;

  public func AreaCount() -> Int32 { return ArraySize(this.m_areas); }
  public func Total() -> Int32 { return this.m_total; }

  public func AreaAt(i: Int32) -> ref<NCZDGArea> {
    if i < 0 || i >= ArraySize(this.m_areas) {
      return null;
    }
    return this.m_areas[i];
  }

  // Build the nav: All, then each district followed by its subdistricts. The core returns both
  // lists already A-Z, so no sort is needed here.
  public func Build() -> Void {
    ArrayClear(this.m_areas);
    this.m_total = 0;

    let all = GetAllLocations();            // bind before ArraySize: rvalue-array bug
    this.m_total = ArraySize(all);

    let allRow = new NCZDGArea();
    allRow.isAll = true;
    allRow.count = this.m_total;
    allRow.recentCount = this.CountRecentIn(all, "", "");
    ArrayPush(this.m_areas, allRow);

    let districts = GetDistricts();
    let d = 0;
    while d < ArraySize(districts) {
      let name = districts[d];

      let dRow = new NCZDGArea();
      dRow.district = name;
      dRow.count = this.CountIn(all, name, "");
      dRow.recentCount = this.CountRecentIn(all, name, "");
      ArrayPush(this.m_areas, dRow);

      let subs = GetSubdistricts(name);
      let s = 0;
      while s < ArraySize(subs) {
        let sRow = new NCZDGArea();
        sRow.district = name;
        sRow.subdistrict = subs[s];
        sRow.isSub = true;
        sRow.count = this.CountIn(all, name, subs[s]);
        sRow.recentCount = this.CountRecentIn(all, name, subs[s]);
        ArrayPush(this.m_areas, sRow);
        s += 1;
      }
      d += 1;
    }
  }

  // One pass over the locations. `sub` empty = the whole district, INCLUDING the locations that sit
  // in no subdistrict.
  private func CountIn(locs: array<ref<NCZLocation>>, district: String, sub: String) -> Int32 {
    let n = 0;
    let i = 0;
    while i < ArraySize(locs) {
      let loc = locs[i];
      if UnicodeStringEqual(loc.District(), district) {
        if StrLen(sub) == 0 || UnicodeStringEqual(loc.Subdistrict(), sub) {
          n += 1;
        }
      }
      i += 1;
    }
    return n;
  }

  // The recently-updated subset of the same area CountIn describes. An empty `district` means "all
  // areas" (the ALL row); a non-empty district with an empty `sub` means the whole district. Recency
  // is the core's server-computed flag - redscript has no clock to derive it from a date.
  private func CountRecentIn(locs: array<ref<NCZLocation>>, district: String, sub: String) -> Int32 {
    let n = 0;
    let i = 0;
    while i < ArraySize(locs) {
      let loc = locs[i];
      if loc.RecentlyUpdated() {
        if StrLen(district) == 0 {
          n += 1;
        } else {
          if UnicodeStringEqual(loc.District(), district) {
            if StrLen(sub) == 0 || UnicodeStringEqual(loc.Subdistrict(), sub) {
              n += 1;
            }
          }
        }
      }
      i += 1;
    }
    return n;
  }

  // The row for a resolved area, preferring the subdistrict. -1 when nothing matches.
  public func FindArea(district: String, subdistrict: String) -> Int32 {
    let i = 0;
    while i < ArraySize(this.m_areas) {
      let a = this.m_areas[i];
      if !a.isAll
         && UnicodeStringEqual(a.district, district)
         && UnicodeStringEqual(a.subdistrict, subdistrict) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  // The locations in an area, filtered by a free-text query, sorted recently-updated first, then
  // A-Z by name.
  //
  // Search covers EVERY text field a location carries - name, description, category, tags and
  // authors - so "watson", "interior", an author's handle and a tag all find the same thing.
  public func Query(areaIdx: Int32, search: String) -> array<ref<NCZLocation>> {
    let out: array<ref<NCZLocation>>;
    let area = this.AreaAt(areaIdx);
    if !IsDefined(area) {
      return out;
    }
    let all = GetAllLocations();
    let q = StrLower(search);

    let i = 0;
    while i < ArraySize(all) {
      let loc = all[i];
      if this.InArea(loc, area) && NCZDG_Matches(loc, q) {
        ArrayPush(out, loc);
      }
      i += 1;
    }
    return NCZDG_SortByName(out);
  }

  private func InArea(loc: ref<NCZLocation>, area: ref<NCZDGArea>) -> Bool {
    if area.isAll {
      return true;
    }
    if !UnicodeStringEqual(loc.District(), area.district) {
      return false;
    }
    if StrLen(area.subdistrict) == 0 {
      return true;   // a district row includes the locations that sit in no subdistrict
    }
    return UnicodeStringEqual(loc.Subdistrict(), area.subdistrict);
  }
}

// Every text field, case-insensitive. An empty query matches everything.
//
// Tags and authors MUST be read through TagCount()/TagAt() and AuthorCount()/AuthorAt(): applying
// an array intrinsic straight to a method's array return reads garbage in redscript, and the core's
// own header warns about it.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_Matches(loc: ref<NCZLocation>, lowerQuery: String) -> Bool {
  if StrLen(lowerQuery) == 0 {
    return true;
  }
  if StrContains(StrLower(loc.Name()), lowerQuery) { return true; }
  if StrContains(StrLower(loc.Description()), lowerQuery) { return true; }
  if StrContains(StrLower(loc.Category()), lowerQuery) { return true; }
  if StrContains(StrLower(loc.District()), lowerQuery) { return true; }
  if StrContains(StrLower(loc.Subdistrict()), lowerQuery) { return true; }

  let i = 0;
  while i < loc.TagCount() {
    if StrContains(StrLower(loc.TagAt(i)), lowerQuery) { return true; }
    i += 1;
  }
  i = 0;
  while i < loc.AuthorCount() {
    if StrContains(StrLower(loc.AuthorAt(i)), lowerQuery) { return true; }
    i += 1;
  }
  return false;
}

// Insertion sort, two keys: recently-updated first, then lowercased name A-Z within each group.
// Recency is the core's server-computed flag, so a mod falls back into the alphabetical run by
// itself once the flag expires - no clock, no state, nothing to clean up here.
//
// redscript has no comparator sort, and the sets here are small (295 worst case, once per
// selection, on a paused frame).
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_SortByName(locs: array<ref<NCZLocation>>) -> array<ref<NCZLocation>> {
  let out: array<ref<NCZLocation>>;
  let i = 0;
  while i < ArraySize(locs) {
    let loc = locs[i];
    let key = StrLower(loc.Name());
    let recent = loc.RecentlyUpdated();
    let j = ArraySize(out);
    while j > 0 && NCZDG_OrdersBefore(recent, key, out[j - 1]) {
      j -= 1;
    }
    ArrayInsert(out, j, loc);
    i += 1;
  }
  return out;
}

// True when (recent, key) sorts before `other`: recent beats not-recent, ties fall through to A-Z.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_OrdersBefore(recent: Bool, key: String, other: ref<NCZLocation>) -> Bool {
  let otherRecent = other.RecentlyUpdated();
  if recent && !otherRecent {
    return true;
  }
  if !recent && otherRecent {
    return false;
  }
  return UnicodeStringLessThan(key, StrLower(other.Name()));
}
