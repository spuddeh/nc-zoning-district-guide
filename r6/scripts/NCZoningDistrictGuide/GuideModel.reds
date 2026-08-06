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
// FLAT - no precedence, no brackets. The query is scanned left to right. Each operator ends the
// current word and governs the NEXT one; the first word is governed by `|`.
//
//   watson&apartment!corpo   ->   `watson` OR word, `apartment` AND word, `corpo` NOT word
//
// A location matches when
//
//   (some OR word matched) AND (every AND word matched) AND (no NOT word matched)
//
// An empty OR pool counts as satisfied, so `!corpo` means everything except corpo.
//
// SPACES BELONG TO THE WORD. Nothing is trimmed. `watson & apartment` searches for `watson ` and
// ` apartment` - 6 and 103 records, against 85 and 156 for the tight spelling. The help panel
// states this.
//
// The whole query is tested as a plain substring first, so a phrase (`night city`) and a name
// containing an operator character both still find themselves.
//
// Parsed once per Query() call; the terms do not depend on the location.
// --------------------------------------------------------------------------------------
public func NCZDG_OpOr() -> Int32 { return 0; }
public func NCZDG_OpAnd() -> Int32 { return 1; }
public func NCZDG_OpNot() -> Int32 { return 2; }

// One word of the query, and the operator that governs it. Lowercased, never empty, and NOT
// trimmed - a space the player typed is part of what they asked for.
public class NCZDGQueryTerm {
  public let text: String;
  public let op: Int32;
}

@if(ModuleExists("NCZoning.Api"))
public class NCZDGQuery {
  public let raw: String;                        // the whole lowercased query, for the plain test
  public let terms: array<ref<NCZDGQueryTerm>>;  // in the order they were typed
  public let hasPlainWord: Bool;                 // is any word governed by `|`

  public func Matches(loc: ref<NCZLocation>) -> Bool {
    if StrLen(this.raw) == 0 {
      return true;
    }
    if NCZDG_Matches(loc, this.raw) {
      return true;
    }
    // An empty OR pool counts as satisfied, so `!corpo` reads as everything except corpo. The
    // first word of a query is governed by `|`, so the pool is empty only when the query opens
    // with an operator.
    //
    // IN ORDER, AND BAILING EARLY: an AND word that misses, or a NOT word that hits, ends the
    // test before any later word is looked at.
    let anyMatch = !this.hasPlainWord;
    let i = 0;
    while i < ArraySize(this.terms) {
      let t = this.terms[i];
      if t.op == NCZDG_OpAnd() {
        if !NCZDG_Matches(loc, t.text) {
          return false;
        }
      } else {
        if t.op == NCZDG_OpNot() {
          if NCZDG_Matches(loc, t.text) {
            return false;
          }
        } else {
          if !anyMatch && NCZDG_Matches(loc, t.text) {
            anyMatch = true;
          }
        }
      }
      i += 1;
    }
    return anyMatch;
  }
}

// One left-to-right pass, character by character. StrSplit cannot do this: the three operators
// have to be read in the order they appear, and each one governs the word that follows it.
//
// AN EMPTY WORD IS DROPPED, so `||` and `&&` behave as single operators, and the card list holds
// steady while `watson&` waits for its next character.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_ParseQuery(raw: String) -> ref<NCZDGQuery> {
  let q = new NCZDGQuery();
  q.raw = StrLower(raw);

  let word = "";
  let op = NCZDG_OpOr();   // the first word is a plain word
  let n = StrLen(q.raw);
  let i = 0;
  // ONE PAST THE END, where the pending word is flushed under the operator it is already under.
  while i <= n {
    let atEnd = i >= n;
    let ch = atEnd ? "" : StrMid(q.raw, i, 1);
    let isOp = atEnd
      || UnicodeStringEqual(ch, "|")
      || UnicodeStringEqual(ch, "&")
      || UnicodeStringEqual(ch, "!");
    if isOp {
      if StrLen(word) > 0 {
        let t = new NCZDGQueryTerm();
        t.text = word;
        t.op = op;
        ArrayPush(q.terms, t);
        if op == NCZDG_OpOr() {
          q.hasPlainWord = true;
        }
      }
      word = "";
      if UnicodeStringEqual(ch, "&") {
        op = NCZDG_OpAnd();
      }
      if UnicodeStringEqual(ch, "!") {
        op = NCZDG_OpNot();
      }
      if UnicodeStringEqual(ch, "|") {
        op = NCZDG_OpOr();
      }
    } else {
      word = word + ch;
    }
    i += 1;
  }
  return q;
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
