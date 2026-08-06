// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: GuideModel.reds
// Author: Spuddeh
// Description: The guide's data. No ink here, so it can be reasoned about on its own.
//
//              The nav list comes from the core's district VOCABULARY (GetDistricts /
//              GetSubdistricts, 1.0.0+), NOT from the locations. Deriving it from the locations
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
// Mod Version: 1.1.0
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

  // Only the All row is translated. A district or subdistrict name is registry data and is
  // shown exactly as the board publishes it.
  public func Label() -> String {
    if this.isAll {
      return NCZDG_T("NCZDG.areaAll");
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

  // The locations in an area, filtered by a search expression, sorted recently-updated first, then
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
    // Parsed ONCE, not once per location: the expression is the same for all 295 of them, and
    // parsing it inside the loop would run several string splits per card per keystroke.
    let q = NCZDG_ParseQuery(search);

    let i = 0;
    while i < ArraySize(all) {
      let loc = all[i];
      if this.InArea(loc, area) && q.Matches(loc) {
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

// --------------------------------------------------------------------------------------
// The search expression
// --------------------------------------------------------------------------------------
// The grammar is an OR of AND-GROUPS, one level deep, with no brackets:
//
//   watson & interior || pacifica & !wip
//   -> (watson AND interior) OR (pacifica AND NOT wip)
//
// A SPACE IS PART OF A TERM, not an operator, so "night city" searches that phrase. A space that
// meant AND would take phrase search away entirely: there would be nothing left to express it with.
//
// `&&` and a single `|` are accepted alongside `&` and `||`. Neither character means anything as
// a literal in a mod name, description or tag, so there is nothing to lose by accepting both
// spellings, and typing `a || b` passes through `a | b` on the way.
// --------------------------------------------------------------------------------------

// One term: a substring to look for, and whether finding it should EXCLUDE the location.
// The text is already lowercased and trimmed, and is never empty.
public class NCZDGQueryTerm {
  public let text: String;
  public let negated: Bool;
}

// One AND-group. Every term must pass.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGQueryGroup {
  public let terms: array<ref<NCZDGQueryTerm>>;

  public func Matches(loc: ref<NCZLocation>) -> Bool {
    let i = 0;
    while i < ArraySize(this.terms) {
      let t = this.terms[i];
      let found = NCZDG_Matches(loc, t.text);
      if t.negated {
        if found {
          return false;
        }
      } else {
        if !found {
          return false;
        }
      }
      i += 1;
    }
    return true;
  }
}

// The whole expression. No group means no filter - which is the empty box, and also every
// half-typed state on the way to a real query.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGQuery {
  public let groups: array<ref<NCZDGQueryGroup>>;

  public func Matches(loc: ref<NCZLocation>) -> Bool {
    if ArraySize(this.groups) == 0 {
      return true;
    }
    let g = 0;
    while g < ArraySize(this.groups) {
      if this.groups[g].Matches(loc) {
        return true;
      }
      g += 1;
    }
    return false;
  }
}

// Splits on `|` first and `&` second, which is what makes `&` bind tighter than `||`.
//
// AN EMPTY TERM IS DROPPED, NOT TREATED AS A FILTER. `watson &` has an empty second term for as
// long as it takes to type the next character, and failing it there would blank the card list on
// every keystroke that opens a new term.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ParseQuery(raw: String) -> ref<NCZDGQuery> {
  let q = new NCZDGQuery();
  let norm = StrReplaceAll(StrLower(raw), "||", "|");
  norm = StrReplaceAll(norm, "&&", "&");

  let chunks = StrSplit(norm, "|");   // bind before ArraySize: rvalue-array bug
  let c = 0;
  while c < ArraySize(chunks) {
    let group = new NCZDGQueryGroup();
    let parts = StrSplit(chunks[c], "&");
    let p = 0;
    while p < ArraySize(parts) {
      let term = NCZDG_TrimSpaces(parts[p]);
      let negated = StrBeginsWith(term, "!");
      if negated {
        // StrAfterFirst rather than an index cut: it drops the `!` without counting characters,
        // so a multi-byte term after it survives intact.
        term = NCZDG_TrimSpaces(StrAfterFirst(term, "!"));
      }
      if StrLen(term) > 0 {
        let t = new NCZDGQueryTerm();
        t.text = term;
        t.negated = negated;
        ArrayPush(group.terms, t);
      }
      p += 1;
    }
    if ArraySize(group.terms) > 0 {
      ArrayPush(q.groups, group);
    }
    c += 1;
  }
  return q;
}

// redscript has no trim. Spaces only: the string comes from a text input, so a tab or a newline
// cannot reach it.
//
// Trimming is what lets `watson & interior` be typed the way it reads. Without it the second term
// is " interior", and a leading space matches almost nothing.
public func NCZDG_TrimSpaces(s: String) -> String {
  let out = s;
  while StrLen(out) > 0 && StrBeginsWith(out, " ") {
    out = StrAfterFirst(out, " ");
  }
  while StrLen(out) > 0 && StrEndsWith(out, " ") {
    out = StrBeforeLast(out, " ");
  }
  return out;
}

// Every text field, case-insensitive. This is ONE TERM's test, not the whole expression - the
// expression is NCZDGQuery.Matches, which composes this.
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
