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
    ArrayPush(this.m_areas, allRow);

    let districts = GetDistricts();
    let d = 0;
    while d < ArraySize(districts) {
      let name = districts[d];

      let dRow = new NCZDGArea();
      dRow.district = name;
      dRow.count = this.CountIn(all, name, "");
      ArrayPush(this.m_areas, dRow);

      let subs = GetSubdistricts(name);
      let s = 0;
      while s < ArraySize(subs) {
        let sRow = new NCZDGArea();
        sRow.district = name;
        sRow.subdistrict = subs[s];
        sRow.isSub = true;
        sRow.count = this.CountIn(all, name, subs[s]);
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
}
