// ======================================================================================
// ABANDONED EXPERIMENT - see docs/EXTENSION-API-REQUIREMENTS.md for the status note.
// NOT SHIPPED. NOT COMPILED. This file sits outside r6/ on purpose.
//
// Akiway's forked GuideController.reds, re-expressed as an extension against API-SURFACE.reds.
// Written to answer one question: can the addon do everything it does today without shipping a
// GuideController of its own.
//
// Bodies that only build widgets are elided, with a note of what they build - that code is the
// addon's and it is unchanged by any of this. Bodies that CALL the guide are written out in
// full, because those calls are the API and they are the thing under test.
//
// Findings are at the bottom, and there are three.
// ======================================================================================

module NCZoningLocationTracker.Guide

import NCZoningDistrictGuide.Guide.*
import NCZoning.Api.*
import NCZoning.Data.*

// --- local indices, all relative to the band the registry hands out -------------------
// [B] Every one of these was an absolute number in the fork: 4000-8000, 20000, 30000, and
// -7..-23. They are local now, so nothing here can reach the guide's own numbering and the
// fork's renumbering of NCZDG_IdxImageBase is not needed.
func LT_IdxOpenTagPicker() -> Int32 { return 1; }
func LT_IdxOpenAuthorPicker() -> Int32 { return 2; }
func LT_IdxCycleCategory() -> Int32 { return 3; }
func LT_IdxClearFilters() -> Int32 { return 4; }
func LT_IdxClosePicker() -> Int32 { return 5; }
func LT_IdxCloseDetail() -> Int32 { return 6; }
func LT_IdxOverlayScrim() -> Int32 { return 7; }
func LT_IdxDetailFav() -> Int32 { return 8; }
func LT_IdxDetailVisit() -> Int32 { return 9; }
func LT_IdxDetailWish() -> Int32 { return 10; }
func LT_IdxDetailHide() -> Int32 { return 11; }
func LT_IdxDetailIgnoreAuthor() -> Int32 { return 12; }
func LT_IdxDetailMap() -> Int32 { return 13; }
func LT_IdxDetailTeleport() -> Int32 { return 14; }
// Per-slot bases, spaced past the card pool.
func LT_BaseDetail() -> Int32 { return 1000; }
func LT_BaseFav() -> Int32 { return 2000; }
func LT_BaseVisit() -> Int32 { return 3000; }
func LT_BaseWish() -> Int32 { return 4000; }
func LT_BaseHide() -> Int32 { return 5000; }
// Facet rows, rebuilt per picker open.
func LT_BaseFacet() -> Int32 { return 6000; }
func LT_BaseFacetIgnore() -> Int32 { return 7000; }

public class NCZLTGuideExt extends NCZDGGuideExtension {
  // Per-slot widgets, held in an array indexed by slotIdx rather than hung off NCZDGCardSlot
  // with @addField. @addField works on redscript 0.5.31 and is a hard error in the 1.x rewrite;
  // the card pool is fixed-size with stable indices, so a parallel array costs nothing.
  private let m_slots: array<ref<NCZLTSlotWidgets>>;
  private let m_navBars: array<ref<NCZLTNavBars>>;

  private let m_tracker: Bool;
  private let m_category: Int32;
  private let m_tag: String;
  private let m_author: String;

  // Cached once per Refresh by OnRefreshBegin. [E5]
  private let m_store: ref<NCZLTStore>;
  private let m_hasPos: Bool;
  private let m_playerPos: Vector4;

  // Overlay widgets, built once and hidden.
  private let m_picker: wref<inkCanvas>;
  private let m_detail: wref<inkCanvas>;
  private let m_detailLocId: String;
  private let m_facets: array<ref<NCZLTFacet>>;

  public func Id() -> CName { return n"nczlt"; }
  // Above the default, so the picker and detail sheet parent after anything a lower-priority
  // extension adds. [C4][C5]
  public func Priority() -> Int32 { return 200; }
  public func Enabled() -> Bool {
    let lt = NCZLTConfig.Get();
    return !IsDefined(lt) || lt.enableTracker;
  }

  // --------------------------------------------------------------------------------------
  // 1. Layout  [A]
  // --------------------------------------------------------------------------------------
  public func OnLayout(l: ref<NCZDGGuideLayout>) -> Void {
    l.popupWidth = 2880.0;              // [A1]
    l.popupHeight = 1860.0;             // [A1]
    l.navWidth = 720.0;                 // [A2]
    l.pageSize = 24;                    // [A3]
    l.cardTextBlockHeight = 274.0;      // [A5]
    l.titleCap = 78;                    // [A6]
    l.tagsCap = 54;                     // [A6]
    l.helpTipWidth = 1680.0;            // [A7]
    l.helpTipHeight = 640.0;            // [A7]

    // [A9] the completion panel under the district column
    l.ReserveNavFooter(this.Id(), 400.0);
    // [A10] the four state chips inside every card
    l.ReserveCardBand(this.Id(), 44.0);
    // [A4] the DETAILS button, alongside SHOW ON MAP and TELEPORT
    l.ReserveCardAction(this.Id());
    // [A11] two progress bars under every nav row's label
    l.ReserveNavRowBand(this.Id(), 22.0);

    // [A8] NOT RESERVED HERE - see finding 1. The strip holding TYPE / TAG / AUTHOR is the
    // guide's own, and this extension adds controls to it rather than reserving one.
  }

  // --------------------------------------------------------------------------------------
  // 2. Build
  // --------------------------------------------------------------------------------------
  // [C2] TYPE, TAG and AUTHOR, added to the guide's filter strip. SHOWING, SORT and CLEAR are
  // the guide's, driven by the registered buckets and sorts - see finding 1.
  public func OnBuildStrip(p: wref<NCZDGGuidePopup>, canvas: wref<inkCanvas>) -> Void {
    // ~40 lines: three labelled buttons, built with p.MakeButton and p.MakeProxy so they match
    // the guide's chrome, at this.Idx(LT_IdxCycleCategory()) and the two picker indices.
  }

  // [C3] the completion panel: 8 stat rows, 2 bars, 3 category rows
  public func OnBuildNavFooter(p: wref<NCZDGGuidePopup>, canvas: wref<inkCanvas>) -> Void {
    // ~90 lines, unchanged from BuildStatsPanel. The canvas arrives already sized to the 400
    // reserved above, so nothing here computes a position from the popup's dimensions.
  }

  // [C7] two bars per nav row, in the band reserved in OnLayout
  public func OnBuildNavRow(p: wref<NCZDGGuidePopup>, row: wref<inkCanvas>,
                            area: ref<NCZDGArea>, index: Int32) -> Void {
    // ~20 lines, unchanged from MakeNavBar x2. Held in m_navBars[index] rather than found by
    // name later, which drops the GetWidget lookups the fork does on every refresh.
  }

  // [C8] four chips and the DETAILS button
  public func OnBuildCard(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          band: wref<inkCanvas>, actions: wref<inkCompoundWidget>) -> Void {
    let w = new NCZLTSlotWidgets();
    // ~70 lines: four chips into `band`, one button into `actions`, one distance text.
    // Indices are this.SlotIdx(LT_BaseFav(), slot.slotIdx) and so on.
    ArrayPush(this.m_slots, w);
  }

  // [C4][C5] both overlays, in one hook, parented in the order they are built
  public func OnBuildOverlay(p: wref<NCZDGGuidePopup>, root: wref<inkCompoundWidget>) -> Void {
    // ~65 lines BuildPicker, then ~130 lines BuildDetail. The detail sheet is built second so a
    // picker opened from it does not open behind it.
  }

  // --------------------------------------------------------------------------------------
  // 3. Data  [D]
  // --------------------------------------------------------------------------------------
  // [D6][D7][D9] category, the two facet filters, and suppression of hidden locations and
  // ignored authors. AND-ed with the guide's own filtering, and applied to the district counts
  // by the same path.
  public func Accepts(loc: ref<NCZLocation>) -> Bool {
    if this.m_category > 0 && NCZLT_CategoryIndex(loc.Category()) != this.m_category - 1 {
      return false;
    }
    if StrLen(this.m_tag) > 0 && !NCZLT_HasTag(loc, this.m_tag) { return false; }
    if StrLen(this.m_author) > 0 && !NCZLT_HasAuthor(loc, this.m_author) { return false; }
    // The IGNORED bucket exists to show exactly what everything else hides, so suppression is
    // skipped while it is the active bucket.
    if UnicodeStringEqual(p_ActiveBucket(), "lt.ignored") { return true; }
    return !NCZLT_IsSuppressed(loc, this.m_store);
  }

  // [D5] the five buckets the guide does not have. ALL, INSTALLED, MISSING and UNKNOWN stay
  // the guide's, so the picker shows nine and the fork's own SHOWING control disappears.
  public func Buckets() -> array<ref<NCZDGFilterBucket>> {
    return [
      NCZLT_Bucket("lt.fav",       "NCZLT.showFav",       false),
      NCZLT_Bucket("lt.wish",      "NCZLT.showWish",      false),
      NCZLT_Bucket("lt.visited",   "NCZLT.showVisited",   false),
      NCZLT_Bucket("lt.unvisited", "NCZLT.showUnvisited", false),
      NCZLT_Bucket("lt.ignored",   "NCZLT.showIgnored",   false)
    ];
  }

  public func BucketAccepts(key: String, loc: ref<NCZLocation>) -> Bool {
    let id = loc.Id();
    if !IsDefined(this.m_store) { return true; }
    if UnicodeStringEqual(key, "lt.fav")       { return this.m_store.IsFavourite(id); }
    if UnicodeStringEqual(key, "lt.wish")      { return this.m_store.IsWishlisted(id); }
    if UnicodeStringEqual(key, "lt.visited")   { return this.m_store.IsVisited(id); }
    if UnicodeStringEqual(key, "lt.unvisited") { return !this.m_store.IsVisited(id); }
    if UnicodeStringEqual(key, "lt.ignored")   { return NCZLT_IsSuppressed(loc, this.m_store); }
    return true;
  }

  // [D8] NAME and RECENT are the guide's; DISTANCE needs a player position and is this one's.
  public func Sorts() -> array<ref<NCZDGSortOption>> {
    return [NCZLT_Sort("lt.distance", "NCZLT.sortDistance")];
  }

  public func SortCompare(key: String, a: ref<NCZLocation>, b: ref<NCZLocation>) -> Int32 {
    if !this.m_hasPos { return 0; }
    let da = NCZLT_DistanceTo(this.m_playerPos, a.Pos());
    let db = NCZLT_DistanceTo(this.m_playerPos, b.Pos());
    return da < db ? -1 : (da > db ? 1 : 0);
  }

  // [D10] the guide owns the parser; this claims five `is:` words
  public func StateKeywords() -> array<String> {
    return ["fav", "favourite", "favorite", "wish", "wishlist",
            "visited", "unvisited", "hidden", "ignored"];
  }

  public func StateMatches(word: String, loc: ref<NCZLocation>) -> Bool {
    if !IsDefined(this.m_store) { return false; }
    let id = loc.Id();
    if UnicodeStringEqual(word, "fav") || UnicodeStringEqual(word, "favourite")
       || UnicodeStringEqual(word, "favorite") { return this.m_store.IsFavourite(id); }
    if UnicodeStringEqual(word, "wish") || UnicodeStringEqual(word, "wishlist") {
      return this.m_store.IsWishlisted(id);
    }
    if UnicodeStringEqual(word, "visited")   { return this.m_store.IsVisited(id); }
    if UnicodeStringEqual(word, "unvisited") { return !this.m_store.IsVisited(id); }
    if UnicodeStringEqual(word, "hidden") || UnicodeStringEqual(word, "ignored") {
      return NCZLT_IsSuppressed(loc, this.m_store);
    }
    return false;
  }

  // [C6] one line in the guide's own syntax panel
  public func HelpLines() -> array<ref<NCZDGHelpLine>> {
    return [NCZLT_Help("NCZLT.helpIs", NCZDG_Cyan(), 18.0)];
  }

  // --------------------------------------------------------------------------------------
  // 4. Bind and refresh  [E]
  // --------------------------------------------------------------------------------------
  public func OnRefreshBegin(p: wref<NCZDGGuidePopup>) -> Void {
    this.m_store = NCZLTStore.Get();
    // Once per refresh, not once per card. The game is paused while the window is up, so the
    // player cannot move.
    this.m_hasPos = NCZLT_HasPlayerPos(p.GetGame());
    this.m_playerPos = NCZLT_PlayerPos(p.GetGame());
  }

  public func OnCardBound(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          loc: ref<NCZLocation>) -> Void {
    let w = this.m_slots[slot.slotIdx];
    let id = loc.Id();
    this.SetChip(w.chipFav,   this.m_store.IsFavourite(id));
    this.SetChip(w.chipVisit, this.m_store.IsVisited(id));
    this.SetChip(w.chipWish,  this.m_store.IsWishlisted(id));
    this.SetChip(w.chipHide,  this.m_store.IsHidden(id));

    // Hidden rather than zeroed with no player to measure from: "0 M" from the main menu is a
    // wrong answer that looks like a right one.
    let lt = NCZLTConfig.Get();
    let showDist = this.m_hasPos && (!IsDefined(lt) || lt.showDistance);
    w.dist.SetVisible(showDist);
    if showDist {
      w.dist.SetText(NCZLT_FormatDistance(NCZLT_DistanceTo(this.m_playerPos, loc.Pos())));
    }
  }

  public func OnNavRowBound(p: wref<NCZDGGuidePopup>, row: wref<inkCanvas>,
                            area: ref<NCZDGArea>, index: Int32) -> Void {
    // ~15 lines: resize the two fills from area.stats. The installed fraction is the guide's
    // own figure; the visited fraction is this extension's.
  }

  public func OnRefreshEnd(p: wref<NCZDGGuidePopup>) -> Void {
    // ~50 lines: UpdateStatsPanel for the selected district, then the TYPE / TAG / AUTHOR
    // button labels.
  }

  public func OnCardHover(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          entered: Bool) -> Void {
    // Chips follow the hover, except that an active chip stays visible when it ends.
  }

  // --------------------------------------------------------------------------------------
  // 5. Interaction  [F]
  // --------------------------------------------------------------------------------------
  public func OnClick(p: wref<NCZDGGuidePopup>, local: Int32) -> Void {
    if local == LT_IdxOverlayScrim() { return; }        // eats the click, does nothing
    if local == LT_IdxClosePicker() { this.ClosePicker(); return; }
    if local == LT_IdxCloseDetail() { this.CloseDetail(); return; }
    if local == LT_IdxOpenTagPicker() { this.OpenPicker(p, false); return; }
    if local == LT_IdxOpenAuthorPicker() { this.OpenPicker(p, true); return; }
    if local == LT_IdxCycleCategory() {
      this.m_category = (this.m_category + 1) % NCZLT_CategoryFilterCount();
      p.AfterFilterChange();                             // [F9] page reset, scroll, refresh
      return;
    }
    if local == LT_IdxClearFilters() {
      this.m_category = 0;
      this.m_tag = "";
      this.m_author = "";
      p.AfterFilterChange();
      return;
    }
    // The detail sheet acts on a remembered id, because a refresh can rebind the slot it was
    // opened from. [F5] is what makes these two reachable at all.
    if local == LT_IdxDetailMap() { p.DoWaypointFor(this.LocForDetail()); return; }
    if local == LT_IdxDetailTeleport() { p.DoTeleportFor(this.LocForDetail()); return; }
    if local == LT_IdxDetailFav() { this.ToggleDetailState(p, 1); return; }
    if local == LT_IdxDetailVisit() { this.ToggleDetailState(p, 2); return; }
    if local == LT_IdxDetailWish() { this.ToggleDetailState(p, 3); return; }
    if local == LT_IdxDetailHide() { this.ToggleDetailState(p, 4); return; }
    if local == LT_IdxDetailIgnoreAuthor() { this.ToggleDetailAuthor(p); return; }

    // Descending base chain, exactly as the fork's, but entirely inside this band.
    if local >= LT_BaseFacetIgnore() { this.IgnoreFacetAuthor(p, local - LT_BaseFacetIgnore()); return; }
    if local >= LT_BaseFacet() { this.PickFacet(p, local - LT_BaseFacet() - 1); return; }
    if local >= LT_BaseHide() { this.ToggleSlotState(p, local - LT_BaseHide(), 4); return; }
    if local >= LT_BaseWish() { this.ToggleSlotState(p, local - LT_BaseWish(), 3); return; }
    if local >= LT_BaseVisit() { this.ToggleSlotState(p, local - LT_BaseVisit(), 2); return; }
    if local >= LT_BaseFav() { this.ToggleSlotState(p, local - LT_BaseFav(), 1); return; }
    if local >= LT_BaseDetail() { this.OpenDetail(p, local - LT_BaseDetail()); return; }
  }

  public func OnHover(p: wref<NCZDGGuidePopup>, local: Int32, entered: Bool) -> Void {
    // Chip hover brightening, ~10 lines.
  }

  // [C5] the detail sheet takes the thumbnail click; the guide's lightbox stands down
  public func OnCardImageClick(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>) -> Bool {
    this.OpenDetail(p, slot.slotIdx);
    return true;
  }

  public func OnClose(p: wref<NCZDGGuidePopup>) -> Void {
    let store = NCZLTStore.Get();
    if IsDefined(store) { store.Flush(); }
    NCZLT_MarkPinsDirty(p.GetGame());
  }

  // --- the extension's own internals, all unchanged from the fork -----------------------
  // SetChip, SetChipHover, OpenPicker, ClosePicker, RebuildPickerRows, MakePickerRow,
  // PickFacet, IgnoreFacetAuthor, OpenDetail, CloseDetail, UpdateDetail, LocForDetail,
  // ToggleSlotState, ToggleDetailState, ToggleDetailAuthor, ApplyStateToggle, SetToggleLabel,
  // UpdateStatsPanel, MakeStatRow, MakeStatBar, PercentText.
  //
  // ToggleSlotState calls p.Refresh() rather than patching the card, because hiding a location
  // while SHOWING: ALL is a request for it to leave - and the district counts behind it have to
  // move at the same instant.
}

// Registered at session ready, the same place TrackerRCF and TrackerPins already hook.
public class NCZLTGuideExtLoader extends ScriptableSystem {
  private func OnAttach() -> Void {
    if NCZDG_GuideApiVersion() < 1 { return; }
    NCZDGGuideExtensions.Get().Register(new NCZLTGuideExt());
  }
}

// ======================================================================================
// FINDINGS
// ======================================================================================
//
// 1. THE FILTER STRIP IS THE GUIDE'S, NOT THE EXTENSION'S.  [A8][C2][D5][D8]
//
//    The fork builds a SHOWING picker of nine buckets and a SORT control. If an extension
//    reserved its own strip for those, the guide would still have its own four-state install
//    filter above the nav, and two controls would do the same job.
//
//    So the guide grows the strip: a bucket picker over every registered bucket, a sort
//    control over every registered sort, and CLEAR. Its own four buckets and two sorts are
//    registered the same way an extension's are, which is what keeps the one code path
//    honest. The old cycle button above the nav goes.  [A14]
//
//    This is guide work beyond adding a hook, and it is the largest single item in the port.
//
// 2. AN OnOpen HOOK IS MISSING.  [D5]
//
//    The addon seeds the active bucket from its own RCF setting, once, when the window opens -
//    session-local afterwards, so changing it inside the guide must not write back. There is
//    nowhere to do that: OnLayout is too early to call SetActiveBucket, and OnRefreshBegin runs
//    on every keystroke and would re-apply it every time.
//
//    Added to the surface: OnOpen(p), after the build and before the first Refresh.
//
// 3. THE HEADER CHROME FIX IS THE GUIDE'S.  [A13]
//
//    At the wider container Codeware's header template drops its right-hand rectangle on its
//    own clip edge, and the fork nudges it back. Since the width now comes from the layout
//    record, the guide is what widened itself and the guide is what should correct for it, at
//    any width, with no hook involved.
//
// Nothing else in the inventory failed to fit.
