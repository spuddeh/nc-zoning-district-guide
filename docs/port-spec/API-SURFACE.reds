// ======================================================================================
// ABANDONED EXPERIMENT - see docs/EXTENSION-API-REQUIREMENTS.md for the status note.
// NOT SHIPPED. NOT COMPILED. This file sits outside r6/ on purpose.
//
// The extension API as the Location Tracker port needs it. Every declaration carries the
// requirement it answers, as a bracketed box number from EXTENSION-API-REQUIREMENTS.md.
// A declaration with no box number does not belong here.
// ======================================================================================

module NCZoningDistrictGuide.Guide

// --------------------------------------------------------------------------------------
// Version
// --------------------------------------------------------------------------------------
// Increments only on a breaking change; adding a hook is additive and does not move it.
// An extension gates on it the way the guide gates on the Core's ApiVersion.
public func NCZDG_GuideApiVersion() -> Int32 { return 1; }

// --------------------------------------------------------------------------------------
// [B] The reserved index range
// --------------------------------------------------------------------------------------
// Everything the guide assigns lives below the floor; its singletons live in -1..-999.
// OnProxyClick and OnProxyHover test the floor FIRST and hand anything above it straight to
// the registry, so the guide's own descending chain can be reordered or extended forever
// without reaching an extension.
public func NCZDG_IdxExtBase() -> Int32 { return 100000; }
public func NCZDG_IdxExtStride() -> Int32 { return 10000; }

// --------------------------------------------------------------------------------------
// [A] The layout record
// --------------------------------------------------------------------------------------
// Seeded from the NCZDG_*() defaults, handed to every extension's OnLayout before anything
// is built, then read by the build code in place of those functions. The free functions stay
// as the defaults so nothing outside the popup has to change.
//
// RESERVATIONS ARE ADDITIVE AND THE GUIDE SUBTRACTS THEM. An extension asks for height; it
// never edits the derived figures, because two extensions each setting bodyHeight would
// silently overwrite one another.
public class NCZDGGuideLayout {
  // [A1]
  public let popupWidth: Float;
  public let popupHeight: Float;
  // [A2]
  public let navWidth: Float;
  // [A3]
  public let pageSize: Int32;
  public let cardsPerRow: Int32;
  // [A5][A6]
  public let cardTextBlockHeight: Float;
  public let titleCap: Int32;
  public let descCap: Int32;
  public let tagsCap: Int32;
  // [A7]
  public let helpTipWidth: Float;
  public let helpTipHeight: Float;
  // [A11][A12] - one height for every row, because ScrollNavToSelected sums them before the
  // first layout pass. A row that changed height with a setting would put that sum out.
  public let navRowTextHeight: Float;
  public let navRowSubTextHeight: Float;
  public let navRowGap: Float;
  public let navRowSubGap: Float;

  // --- reservations -------------------------------------------------------------------
  // [A8] a full-width strip between the top strip and the body
  public func ReserveStrip(owner: CName, height: Float) -> Void;
  // [A9] a block under the nav column, taken off the nav scroll's height
  public func ReserveNavFooter(owner: CName, height: Float) -> Void;
  // [A10] a band inside every card, between the tags and the action strip
  public func ReserveCardBand(owner: CName, height: Float) -> Void;
  // [A11] extra height in every nav row, under the label
  public func ReserveNavRowBand(owner: CName, height: Float) -> Void;
  // [A4] one more button in the card action strip; the guide re-divides the strip's width
  public func ReserveCardAction(owner: CName) -> Void;

  // Read back after every extension has had OnLayout, for an extension that needs to size
  // its own widgets against what it was actually given.
  public func StripHeight() -> Float;
  public func NavFooterHeight() -> Float;
  public func CardBandHeight() -> Float;
  public func CardButtonWidth() -> Float;
}

// --------------------------------------------------------------------------------------
// [D5][D8] Buckets and sorts, contributed rather than replaced
// --------------------------------------------------------------------------------------
public class NCZDGFilterBucket {
  public let key: String;            // stable, namespaced: "lt.fav"
  public let labelKey: String;       // a translation key, resolved by the guide
  public let needsDetection: Bool;   // hidden until the Core's install scan has answered
}

public class NCZDGSortOption {
  public let key: String;
  public let labelKey: String;
}

// [C6][D10] one line in the guide's search-syntax panel
public class NCZDGHelpLine {
  public let textKey: String;
  public let colour: CName;
  public let gapAfter: Float;
}

// --------------------------------------------------------------------------------------
// The extension itself
// --------------------------------------------------------------------------------------
// An addon subclasses this, overrides what it needs, and registers one instance. Every method
// here has a do-nothing default, so an extension that wants one hook writes one method.
//
// THIS IS THE ONLY WAY IN. An addon cannot @wrapMethod or @addMethod any class the guide
// declares - verified against redscript 0.5.31 - so a call site the guide writes is the whole
// mechanism, not one option among several.
public abstract class NCZDGGuideExtension extends IScriptable {
  // Assigned by the registry. Read them, never set them.
  public let band: Int32;
  public let registered: Bool;

  public func Id() -> CName;
  // Ascending. Decides OnLayout order and, more importantly, overlay parenting order, because
  // ink draws in child order and has no z-index. [C4][C5]
  public func Priority() -> Int32 { return 100; }
  // Checked once when the popup opens. False means the guide builds as though the extension
  // were not installed. [C3]
  public func Enabled() -> Bool { return true; }

  // [B] Local numbers only; the registry adds the band and strips it again on dispatch.
  public final func Idx(local: Int32) -> Int32 { return this.band + local; }
  public final func SlotIdx(localBase: Int32, slot: Int32) -> Int32 {
    return this.band + localBase + slot;
  }

  // --- 1. layout, before anything is built [A] ------------------------------------------
  public func OnLayout(l: ref<NCZDGGuideLayout>) -> Void {}

  // After the build, before the first Refresh. The one place to seed a saved default that must
  // stay session-local afterwards: OnLayout is too early to reach SetActiveBucket, and
  // OnRefreshBegin runs on every keystroke and would re-apply it every time. [D5]
  public func OnOpen(p: wref<NCZDGGuidePopup>) -> Void {}

  // --- 2. build ------------------------------------------------------------------------
  // Each canvas is already sized to what the extension reserved and parented in the right
  // place. Anything drawn outside it will not be clipped - ink cannot clip a child.
  public func OnBuildStrip(p: wref<NCZDGGuidePopup>, canvas: wref<inkCanvas>) -> Void {}        // [C2]
  public func OnBuildNavFooter(p: wref<NCZDGGuidePopup>, canvas: wref<inkCanvas>) -> Void {}    // [C3]
  public func OnBuildCard(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          band: wref<inkCanvas>, actions: wref<inkCompoundWidget>) -> Void {}   // [C8]
  public func OnBuildNavRow(p: wref<NCZDGGuidePopup>, row: wref<inkCanvas>,
                            area: ref<NCZDGArea>, index: Int32) -> Void {}                      // [C7]
  // Runs last, on the popup's own root widget, in Priority order, so an overlay covers the
  // header and footer as well as the body. [C4][C5]
  public func OnBuildOverlay(p: wref<NCZDGGuidePopup>, root: wref<inkCompoundWidget>) -> Void {}

  // --- 3. data [D] ----------------------------------------------------------------------
  // AND-ed with the guide's own filtering, and applied to the district counts by the same
  // path as the card list, so the two cannot disagree. [D6][D7][D9]
  public func Accepts(loc: ref<NCZLocation>) -> Bool { return true; }

  public func Buckets() -> array<ref<NCZDGFilterBucket>> { return []; }                          // [D5]
  public func BucketAccepts(key: String, loc: ref<NCZLocation>) -> Bool { return true; }
  public func Sorts() -> array<ref<NCZDGSortOption>> { return []; }                              // [D8]
  public func SortCompare(key: String, a: ref<NCZLocation>, b: ref<NCZLocation>) -> Int32 { return 0; }

  // [D10] `is:` keywords the extension claims. The guide owns the parser, the quoting, the
  // trimming and the field prefixes; an extension answers for its own state words only.
  public func StateKeywords() -> array<String> { return []; }
  public func StateMatches(word: String, loc: ref<NCZLocation>) -> Bool { return false; }
  // [C6] Contributed to the guide's panel, so the panel cannot document a parser that is not
  // running.
  public func HelpLines() -> array<ref<NCZDGHelpLine>> { return []; }

  // --- 4. bind and refresh [E] -----------------------------------------------------------
  // Once per Refresh, before the query runs: cache anything a per-location call would
  // otherwise recompute per card. [E5]
  public func OnRefreshBegin(p: wref<NCZDGGuidePopup>) -> Void {}
  public func OnCardBound(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          loc: ref<NCZLocation>) -> Void {}                                      // [E1]
  public func OnNavRowBound(p: wref<NCZDGGuidePopup>, row: wref<inkCanvas>,
                            area: ref<NCZDGArea>, index: Int32) -> Void {}                       // [E2]
  // After the cards, the nav and the count line. [E3][E4]
  public func OnRefreshEnd(p: wref<NCZDGGuidePopup>) -> Void {}
  public func OnCardHover(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>,
                          entered: Bool) -> Void {}                                              // [E6]

  // --- 5. interaction [F] -----------------------------------------------------------------
  public func OnClick(p: wref<NCZDGGuidePopup>, local: Int32) -> Void {}                         // [F1]
  public func OnHover(p: wref<NCZDGGuidePopup>, local: Int32, entered: Bool) -> Void {}          // [F2]
  // The one place an extension may stand the guide down. Returning true means the thumbnail
  // click was handled and the guide's lightbox does not open. [C5]
  public func OnCardImageClick(p: wref<NCZDGGuidePopup>, slot: ref<NCZDGCardSlot>) -> Bool {
    return false;
  }
  // The popup is closing. [G2]
  public func OnClose(p: wref<NCZDGGuidePopup>) -> Void {}
}

// --------------------------------------------------------------------------------------
// The registry
// --------------------------------------------------------------------------------------
// An addon registers at session ready. Registration assigns the band, so no addon picks its
// own numbers and two installed together cannot collide. [B]
public class NCZDGGuideExtensions extends ScriptableService {
  public static func Get() -> ref<NCZDGGuideExtensions>;
  public func Register(ext: ref<NCZDGGuideExtension>) -> Bool;
  public func Count() -> Int32;
  public func At(i: Int32) -> ref<NCZDGGuideExtension>;
}

// --------------------------------------------------------------------------------------
// What the popup has to expose
// --------------------------------------------------------------------------------------
// Added to NCZDGGuidePopup as public methods. Everything here is called by the port.
//
//   GetGame() -> GameInstance                                     the extension's own systems
//   Layout() -> ref<NCZDGGuideLayout>                             read the settled figures
//   Refresh() -> Void                                             [E5]
//   AfterFilterChange() -> Void      reset the page, scroll to top, refresh   [F9]
//   SelectedArea() -> Int32                                       [D3]
//   AreaLocations(areaIdx: Int32) -> array<ref<NCZLocation>>      facet enumeration [D4]
//   LocForSlot(slotIdx: Int32) -> ref<NCZLocation>                [F3]
//   ActiveBucket() -> String / SetActiveBucket(key: String)       [D5]
//   ActiveSort() -> String / SetActiveSort(key: String)           [D8]
//   DoWaypointFor(loc: ref<NCZLocation>) -> Void                  [F5]
//   DoTeleportFor(loc: ref<NCZLocation>) -> Void                  [F5]
//   QueueImage(url, image, boxW, boxH, slotIdx) -> Void           detail-sheet picture [C5]
//
// Brand-consistent builders, so an extension's widgets cannot drift from the guide's:
//
//   MakeText(label, colour, size) -> ref<inkText>
//   MakeButton(parent, label, index) -> ref<inkCanvas>
//   MakeProxy(index, hoverFrame, restOpacity) -> ref<NCZDGGuideProxy>
//   MakeFrame(parent, colour, opacity) -> ref<inkImage>
//   MakePlate(parent, colour, opacity) -> ref<inkImage>
//   MakeScrollColumn(parent, x, y, w, h, id) -> wref<inkVerticalPanel>
//
// [F5] is the only one that changes existing guide code rather than adding to it: DoWaypoint
// and DoTeleport currently take a slot index, and the detail sheet acts on a remembered
// location id because a refresh can rebind the slot it was opened from.
