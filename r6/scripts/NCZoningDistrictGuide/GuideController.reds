// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: GuideController.reds
// Author: Spuddeh
// Description: The standalone guide: a keybind-opened, game-pausing overlay.
//
//              Extends Codeware's InGamePopup, which is what RCF's F8 panel does. That supplies,
//              with no code here: the time dilation that pauses the game, the ModalPopup game
//              context that blocks player input, the background blur, the mouse cursor, and
//              ESC-to-close. Hand-rolling any of it would be a worse copy.
//
//              NOTHING NATIVE IS WRAPPED. The popup rides Codeware's CustomPopupManager, so the
//              additive-injection rule holds by construction.
//
//              M5.0 SCAFFOLD. Only the shell exists: header, footer, a search box and a close
//              button. It is here to answer two questions that decide the design, and which are
//              cheaper to test than to reason about:
//                R1  Does the open keybind still fire while the popup is up, or does the
//                    ModalPopup input context swallow it? If it is swallowed, the feature is
//                    "keybind opens, ESC closes", not a toggle.
//                R3  Does clicking a widget blur the Codeware text input, and does ESC still
//                    close while the input holds focus?
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore), psiberx (Codeware), DigitalVixen (RCF, the popup pattern)
// ======================================================================================

module NCZoningDistrictGuide.Guide

import Codeware.UI.*
import NCZoningDistrictGuide.Config.*
import NCZoningDistrictGuide.Bridge.*
import NCZoningDistrictGuide.Images.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*

// --------------------------------------------------------------------------------------
// LAYOUT. Every number here is in 4K DESIGN UNITS (3840x2160), never screen pixels.
//
// The game scales the whole popup tree by screenH/2160 (0.5 at 1080p, 0.667 at 1440p, 1.0 at 4K),
// so design units are already resolution-independent: 2800 units is the same FRACTION of the screen
// at every resolution. Ultrawide is safe too, because the scale is driven by HEIGHT - a wider screen
// just leaves more empty space beside the panel.
//
// So: never write a screen pixel, and never derive a width from the root window's GetSize(). (The
// fast-travel panel is the opposite case: it parents onto the top-level window at scale 1.0 and has
// to apply screenH/2160 by hand. Inside the popup the scale is inherited.)
public func NCZDG_PopupWidth() -> Float { return 2800.0; }

// Sized so TWO full rows fit, plus a sliver of the third - the sliver is deliberate, it is what
// says there is more below.
//   body   = 1760 - 135 - 118 (InGamePopupContent's own insets) = 1507
//   cards  = 1507 - 96 (top strip)  = 1411
//   needed = 2 * 668 + 24 gap       = 1360, leaving ~51 of the third row showing
//
// 1600 -> 1700 bought the second row; 1700 -> 1760 bought the reserved button band under the
// tags (see NCZDG_TextBlockHeight). 1760 of the 2160-unit design height still leaves ~200 clear
// above and below.
public func NCZDG_PopupHeight() -> Float { return 1760.0; }

// InGamePopupContent insets itself by (76, 135, 0, 118) - note the RIGHT margin is ZERO, while the
// header and footer both inset by 76. Measured from the live tree at container 1600x1100:
//
//   header frame width = 1600 - 76 - 76 = 1448
//   content size       = (1524, 847)    = 1600 - 76 - 0
//
// so the content region runs 76 units PAST the visible frame on the right, and anything placed
// against its right edge overhangs it. Re-inset by hand; do not trust content.GetSize().X as the
// usable width.
public func NCZDG_FrameInset() -> Float { return 76.0; }

// The width actually INSIDE the frame. Lay the split columns out against this, never against the
// content widget's own width.
public func NCZDG_UsableWidth() -> Float {
  return NCZDG_PopupWidth() - NCZDG_FrameInset() - NCZDG_FrameInset();
}

// Content height = container - InGamePopupContent's own top/bottom insets (135 / 118).
public func NCZDG_UsableHeight() -> Float {
  return NCZDG_PopupHeight() - 135.0 - 118.0;
}

// --- the split ---------------------------------------------------------------------------
//   +--------------------------------------------------------------+
//   | search                                     N OF M IN <AREA>   |  top strip
//   +-------------+------------------------------------------------+
//   | districts   |  cards, 2 across                               |  body
//   | (scrolls)   |  (scrolls)                                     |
//   +-------------+------------------------------------------------+
// ONE ROW, so this is just the row plus a little air. It was 150, then 132, and both were
// driven by the RIGHT-hand side rather than the left: the count sat at y=20 with the pager
// stacked under it at y=68, ending at 120, while the search box finished at 80. The strip had
// to clear the taller column, which left visible dead space under the search box - the gap read
// as a top-strip problem when it was really a stacking problem.
//
// The count now sits INSIDE the pager row rather than above it, so everything finishes at 80.
public func NCZDG_TopStripHeight() -> Float { return 96.0; }

// The install filter sits above the district list rather than in the search row. These size the
// gap it occupies, and the nav scroll below is shortened by exactly the same amount - derive it,
// never type it twice.
public func NCZDG_NavFilterHeight() -> Float { return 60.0; }
public func NCZDG_NavFilterGap() -> Float { return 14.0; }
public func NCZDG_NavTop() -> Float {
  return NCZDG_TopStripHeight() + NCZDG_NavFilterHeight() + NCZDG_NavFilterGap();
}
public func NCZDG_NavWidth() -> Float { return 760.0; }
public func NCZDG_ColumnGap() -> Float { return 40.0; }

public func NCZDG_BodyHeight() -> Float {
  return NCZDG_UsableHeight() - NCZDG_TopStripHeight();
}

public func NCZDG_CardsWidth() -> Float {
  return NCZDG_UsableWidth() - NCZDG_NavWidth() - NCZDG_ColumnGap();
}

// A scroll column reserves 20 units on the right for its bar (12 bar + 8 gap), so the cards fit
// inside CardsWidth - 20, two across with a gutter between them.
public func NCZDG_ScrollBarStrip() -> Float { return 20.0; }
public func NCZDG_CardGap() -> Float { return 24.0; }

// The card POOL is built once and re-bound; cards are never created or destroyed while the popup
// lives. 295 cards would be ~3000 widgets in one scroll area, and ink does not cull offscreen
// children - every one is laid out and submitted every frame. So: a fixed pool, and pages.
public func NCZDG_PageSize() -> Int32 { return 30; }
public func NCZDG_CardsPerRow() -> Int32 { return 3; }

public func NCZDG_CardWidth() -> Float {
  let gaps = NCZDG_CardGap() * Cast<Float>(NCZDG_CardsPerRow() - 1);
  return (NCZDG_CardsWidth() - NCZDG_ScrollBarStrip() - gaps) / Cast<Float>(NCZDG_CardsPerRow());
}

// --- gallery card: image on top, text beneath ----------------------------------------------
//
// THREE COLUMNS WITH A BANNER IMAGE, replacing a two-column card with a small left thumbnail.
// The banner was considered and rejected at two columns for a concrete reason - at 902 wide a
// 16:9 image is 507 tall, and the card would have reached ~750. At three columns the card is
// ~593 wide, so the same 16:9 image is only ~334 tall and the whole card lands near 620.
// **Narrower columns are what make a banner affordable at all**; ink still cannot crop, so the
// image height is dictated by the width and nothing else.
//
// Left padding clears the two state bars (category accent + install), so the image starts
// inside them rather than covering them.
public func NCZDG_CardPadLeft() -> Float { return 20.0; }
public func NCZDG_CardPadRight() -> Float { return 20.0; }

public func NCZDG_ImageWidth() -> Float {
  return NCZDG_CardWidth() - NCZDG_CardPadLeft();
}
// 16:9, because the registry's images are Nexus screenshots. A differently-shaped image is
// scaled to FIT this box and letterboxes inside it - ink cannot clip a child, so an image
// sized to fill would draw over the text below it.
public func NCZDG_ImageHeight() -> Float {
  return NCZDG_ImageWidth() * 9.0 / 16.0;
}

// Everything under the image: the text, plus a RESERVED BAND at the bottom for the action strip.
//
// Budgeted for the WORST case, not the common one, because there is no way to query a wrapped
// text's rendered height: 14 top + a 2-line 34px title (~97) + 6 + the 34-high meta row + 10 +
// a 2-line 26px description (~74) + 8 + a 22px tags line (~31) + 12 = ~286 for the text, plus
// NCZDG_ActionBandHeight() beneath it.
//
// THE BAND IS WHY THE TAGS SURVIVE. Earlier versions had the strip share the tags' space and
// hide them on hover, which punished every card for a problem only long ones had - and the tags
// appear nowhere else in the mod, so hiding them lost the information outright. Reserving the
// space costs card height, and that height was bought by growing the popup rather than by
// shrinking the image or the buttons.
public func NCZDG_ActionBandHeight() -> Float { return 60.0; }
public func NCZDG_TextBlockHeight() -> Float { return 286.0 + NCZDG_ActionBandHeight(); }

// Derived, never a literal: the image height follows the column count, so a card height typed
// as a number would silently stop matching the moment either changed.
public func NCZDG_CardHeight() -> Float {
  return NCZDG_ImageHeight() + NCZDG_TextBlockHeight();
}

public func NCZDG_TextInset() -> Float { return 28.0; }
public func NCZDG_TextWidth() -> Float {
  return NCZDG_CardWidth() - NCZDG_TextInset() - NCZDG_CardPadRight();
}

// BOTH MEASURED IN-GAME, not derived. Counting characters on a rendered line beats any estimate
// here, because there is no way to query a wrapped text's height and the arithmetic was wrong in
// both directions: ~38 title characters fit one line at 34px, and ~49 description characters fit
// one line at 26px - well over the ~39 the line-width estimate predicted.
//
// Title: 2 lines. It is capped at all only since the three-column grid; at ~545 wide an uncapped
// mod name reaches a third line and pushes the tags into the button band.
public func NCZDG_TitleCap() -> Int32 { return 74; }

// Description: 3 lines.
//
// 128, NOT 147. Multiplying the 49-character first line by three was wrong, because 49 is what
// fits on ONE line of ONE description - a proportional font gives a different count per line and
// per string. Measured across seven cards that overflowed at a 145 cap, three lines actually
// held 133 to 141 characters, the narrowest being a wide-glyph run. 128 clears the worst
// observed case with a margin for ones not yet seen.
//
// A CAP CANNOT BE DERIVED FROM ONE MEASURED LINE. It has to clear the worst line, and the only
// way to find that is to cap high, look for overflow, and count what spilled.
//
// The third line fits at all because the height budget is conservative, not because the card
// grew: the budget assumes ~1.42x font size per rendered line where the real figure is nearer
// 1.2. That slack is spent now. A fourth line reaches the reserved button band, and ink cannot
// clip, so it draws over the buttons rather than being trimmed.
public func NCZDG_DescCap() -> Int32 { return 128; }

// Tags are ONE LINE, ALWAYS. The widget has no wrap position set, so it does not wrap - it runs
// straight off the right edge of the card, which ink will not clip. The cap is what keeps it on
// the card, so it is a correctness bound rather than a tidiness one.
//
// ~50 at 22px against the ~49-per-line measured at 26px, scaled by the font ratio and held back
// for glyph variance the same way the description cap is.
public func NCZDG_TagsCap() -> Int32 { return 50; }
public func NCZDG_TagsMax() -> Int32 { return 5; }

// --- no-image placeholder icon --------------------------------------------------------------
// SIZED TO THE ATLAS PART'S OWN ASPECT. `quest_file_failed` is 66 x 157 px, NOT square: measured
// from base\gameplay\gui\common\icons\atlas_common.inkatlas, whose clippingRectInUVCoords for
// that part is 0.04024 x 0.30664 against a 1640 x 512 texture. It is a document glyph, which is
// why it is taller than it is wide.
//
// AN inkImage DOES NOT PRESERVE ASPECT. SetSize stretches the part to whatever it is given, so a
// square size on a 0.42-aspect part squashes it 1.45x horizontally - which is visible at a
// glance and was the first version of this. To size any atlas part correctly, read its UV rect
// and multiply by the texture's real dimensions; the part name alone tells you nothing.
public func NCZDG_PhIconHeight() -> Float { return 110.0; }
public func NCZDG_PhIconWidth() -> Float {
  return NCZDG_PhIconHeight() * 66.0 / 157.0;
}

// Description caps, one per layout. 140 was tuned empirically against the full width; the
// narrow cap is that scaled by the width ratio and rounded down. BOTH are approximate - a
// char cap against a proportional font varies ~20% by glyph mix, and there is no way to
// query a wrapped text's rendered height to do better.
public func NCZDG_DescCap() -> Int32 { return 140; }
public func NCZDG_DescCapThumb() -> Int32 { return 95; }

public func NCZDG_IdxCardBase() -> Int32 { return 1000; }
public func NCZDG_IdxWaypointBase() -> Int32 { return 2000; }
public func NCZDG_IdxTeleportBase() -> Int32 { return 3000; }
// Above teleport, and OnProxyClick MUST test this base BEFORE the others. That dispatch is a
// descending chain of `index >= base` tests, so a 4000 reaching the `>= 3000` arm first would
// read as a teleport - clicking a thumbnail would move the player across the city.
public func NCZDG_IdxImageBase() -> Int32 { return 4000; }
public func NCZDG_IdxPrevPage() -> Int32 { return -2; }
public func NCZDG_IdxNextPage() -> Int32 { return -3; }
public func NCZDG_IdxClearWaypoint() -> Int32 { return -4; }
public func NCZDG_IdxClearSearch() -> Int32 { return -5; }
public func NCZDG_IdxCloseLightbox() -> Int32 { return -6; }
public func NCZDG_IdxCycleFilter() -> Int32 { return -7; }

// --- install filter -----------------------------------------------------------------------
// Four states, cycled by one button. MISSING is not decoration: the guide is partly a DISCOVERY
// tool, and "what is in this district that I do not have" is the question that sends someone to
// Nexus.
//
// UNKNOWN IS ITS OWN BUCKET, and that is a correction. It first appeared under BOTH installed
// and missing, on the reasoning that an undetectable mod might be either - which is true, and
// unusable: AMM location mods then showed up in a list headed INSTALLED that the player had no
// reason to believe. A state that cannot be determined is its own answer, so it gets its own
// view and is excluded from the two definite ones.
//
// Deliberately NOT offered as the RCF default. Opening on a list of undetectable mods is not a
// preference anyone holds; it is a thing you go and look at once.
public func NCZDG_FilterAll() -> Int32 { return 0; }
public func NCZDG_FilterInstalled() -> Int32 { return 1; }
public func NCZDG_FilterMissing() -> Int32 { return 2; }
public func NCZDG_FilterUnknown() -> Int32 { return 3; }
public func NCZDG_FilterCount() -> Int32 { return 4; }

public func NCZDG_FilterLabel(f: Int32) -> String {
  if f == NCZDG_FilterInstalled() { return NCZDG_T("NCZDG.filterInstalled"); }
  if f == NCZDG_FilterMissing() { return NCZDG_T("NCZDG.filterMissing"); }
  if f == NCZDG_FilterUnknown() { return NCZDG_T("NCZDG.filterUnknown"); }
  return NCZDG_T("NCZDG.filterAll");
}

// True when the location passes the given filter. One place, so the card list and the nav
// counts can never disagree about what a filter means.
//
// GUARDED, WITH NO FALLBACK ARM. NCZInstallState is a core type, so this signature cannot even
// be written without the core - and unlike the classes below, a free function is not implicitly
// covered by anything. Its only callers are inside guarded classes, so the guarded arm alone is
// enough. (Caught by the -BothConfigs fallback build, not by the normal one: the real branch has
// the core installed and compiles this happily.)
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_PassesFilter(st: NCZInstallState, f: Int32) -> Bool {
  if f == NCZDG_FilterInstalled() { return Equals(st, NCZInstallState.Installed); }
  if f == NCZDG_FilterMissing() { return Equals(st, NCZInstallState.NotInstalled); }
  if f == NCZDG_FilterUnknown() { return Equals(st, NCZInstallState.Unknown); }
  return true;
}

// The entry point Input.reds calls. Declared in this module so the import there resolves.
//
// The twin matters: with the core absent EVERY other item in this module compiles away (they all
// name NCZLocation, directly or through NCZDGGuideModel), and an all-empty module breaks
// `import NCZoningDistrictGuide.Guide.*` in Input.reds. The no-op keeps the module non-empty.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_OpenGuide(gi: GameInstance) -> Void {
  let sys = NCZDGGuideSystem.Get(gi);
  if IsDefined(sys) {
    sys.Toggle();
  }
}

@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_OpenGuide(gi: GameInstance) -> Void {}

// --------------------------------------------------------------------------------------
// The system owns the popup, so re-pressing the key cannot stack a second one, and so the
// popup's lifetime is not tied to whatever widget happened to open it.
// --------------------------------------------------------------------------------------
@if(ModuleExists("NCZoning.Api"))
public class NCZDGGuideSystem extends ScriptableSystem {
  private let m_popup: ref<NCZDGGuidePopup>;

  public final static func Get(gi: GameInstance) -> ref<NCZDGGuideSystem> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"NCZoningDistrictGuide.Guide.NCZDGGuideSystem") as NCZDGGuideSystem;
  }

  private func IsOpen() -> Bool {
    return IsDefined(this.m_popup) && !this.m_popup.IsClosed();
  }

  // The keybind OPENS only; ESC / right-click / the CLOSE button dismiss.
  //
  // Two reasons, and either alone would settle it. The popup pushes UIGameContext.ModalPopup, which
  // switches input away from the gameplay contexts the key is bound into, so while the popup is up
  // the listener never fires at all (verified: pressing it logs nothing). And the panel owns a text
  // input, so a key that closed the window could not also be typed into the search box - binding the
  // guide to ' would make ' undismissable as a search character.
  public func Toggle() -> Void {
    if this.IsOpen() {
      return;   // unreachable while ModalPopup holds input; harmless if that ever changes
    }
    this.Open();
  }

  public func Open() -> Void {
    let cfg = NCZDGConfig.Get();
    if !IsDefined(cfg) || !cfg.enableStandaloneGuide {
      return;
    }
    // No panel at the main menu; there is no player and no HUD layer to host it.
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    if this.IsOpen() {
      return;
    }
    let gi = this.GetGameInstance();
    this.m_popup = NCZDGGuidePopup.Show(gi);
  }
}

// --------------------------------------------------------------------------------------
// The popup
// --------------------------------------------------------------------------------------
@if(ModuleExists("NCZoning.Api"))
public class NCZDGGuidePopup extends InGamePopup {
  private let m_gi: GameInstance;
  private let m_isClosed: Bool;
  private let m_header: ref<InGamePopupHeader>;
  private let m_footer: ref<InGamePopupFooter>;
  private let m_content: ref<InGamePopupContent>;
  private let m_search: ref<HubTextInput>;
  private let m_searchClear: wref<inkCanvas>;   // the X beside the input; visible only with a query
  private let m_status: wref<inkText>;
  private let m_proxies: array<ref<NCZDGGuideProxy>>;

  private let m_navCol: wref<inkVerticalPanel>;    // district rows go here
  private let m_cardCol: wref<inkVerticalPanel>;   // card ROWS go here (2 cards per row)
  private let m_navScroll: ref<inkScrollController>;
  private let m_cardScroll: ref<inkScrollController>;
  private let m_navRows: array<wref<inkCanvas>>;
  private let m_selected: Int32;   // set to -1 in OnCreate; a negative field default is INVALID_CONSTANT
  private let m_model: ref<NCZDGGuideModel>;

  private let m_cards: array<ref<NCZDGCardSlot>>;
  private let m_cardRows: array<wref<inkHorizontalPanel>>;
  private let m_shown: array<ref<NCZLocation>>;   // the current query result
  private let m_query: String;
  private let m_page: Int32;
  private let m_selCard: Int32;   // pool slot of the selected card, -1 for none
  private let m_clearWp: wref<inkCanvas>;

  // In-flight image fetches, and the single poll chain that drains them.
  private let m_pending: array<ref<NCZDGPendingImage>>;
  private let m_polling: Bool;

  // Install filter. Seeded from the RCF setting on open, then session-local - changing it in
  // the guide does not rewrite the saved default, which is a preference for how the guide
  // OPENS rather than a record of the last thing you clicked.
  private let m_filter: Int32;
  private let m_filterBtn: wref<inkCanvas>;
  private let m_filterLabel: wref<inkText>;

  private let m_prevBtn: wref<inkCanvas>;
  private let m_nextBtn: wref<inkCanvas>;

  // The lightbox: a full-popup overlay, built once and hidden. Parented LAST so it draws over
  // the header, footer and body - ink draw order is child order and there is no z-index.
  private let m_lightbox: wref<inkCanvas>;
  private let m_lightboxImg: wref<inkImage>;
  private let m_lightboxCaption: wref<inkText>;

  public static func Show(gi: GameInstance) -> ref<NCZDGGuidePopup> {
    let self = new NCZDGGuidePopup();
    self.m_gi = gi;
    if !self.OpenSelf() {
      return null;
    }
    return self;
  }

  // The HUD layer's controller is only used as the requester handed to CustomPopup.Open; the popup
  // itself is parented by Codeware's CustomPopupManager onto the native popup queue.
  private func OpenSelf() -> Bool {
    let inkSystem = GameInstance.GetInkSystem();
    if !IsDefined(inkSystem) {
      return false;
    }
    let layer = inkSystem.GetLayer(n"inkHUDLayer");
    if !IsDefined(layer) {
      return false;
    }
    let controller = layer.GetGameController() as inkGameController;
    if !IsDefined(controller) {
      return false;
    }
    this.Open(controller);
    return true;
  }

  // Required for clicks AND for the text input to receive characters.
  public func UseCursor() -> Bool {
    return true;
  }

  public func IsClosed() -> Bool {
    return this.m_isClosed;
  }

  protected cb func OnDetach() -> Void {
    this.m_isClosed = true;
    // Drop every in-flight fetch. A pending tick can still fire after this - the DelaySystem
    // callback is already scheduled - but it reads m_isClosed and stops the chain there.
    ArrayClear(this.m_pending);
    super.OnDetach();   // must chain: this is what un-pauses and pops the game context
  }

  protected cb func OnCreate() -> Void {
    super.OnCreate();
    this.m_selected = -1;
    this.m_selCard = -1;

    // Seed the filter from the saved preference. Read once, at open: cycling inside the guide
    // is session-local and must not write back, or "which view it opens on" silently becomes
    // "the last thing you clicked".
    let cfg = NCZDGConfig.Get();
    this.m_filter = IsDefined(cfg) ? cfg.defaultInstallFilter : NCZDG_FilterAll();
    if this.m_filter < 0 || this.m_filter >= NCZDG_FilterCount() {
      this.m_filter = NCZDG_FilterAll();
    }

    // Size the container BEFORE reparenting the content: InGamePopupContent measures itself off the
    // container at OnReparent, so a later resize does not reach it.
    this.m_container.SetWidth(NCZDG_PopupWidth());
    this.m_container.SetHeight(NCZDG_PopupHeight());

    // Codeware centres the container but then lifts it with a 200-unit BOTTOM margin, which is fine
    // for a short dialog and pushes a tall one off the top of the screen. This panel is tall, so
    // centre it honestly.
    this.m_container.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));

    // The vignette defaults to MainColors.Red (Codeware's alert styling). This is not an alert.
    if IsDefined(this.m_vignette) {
      this.m_vignette.BindProperty(n"tintColor", NCZDG_Cyan());
    }

    // THE PANEL HAS NO BACKDROP, deliberately. The blurred world shows between the cards, and
    // the cards being the only solid surfaces is what gives them their weight.
    //
    // A backdrop belongs as the FIRST child of m_container, not the popup root: ink draws in
    // child order with no z-index, Codeware's SetContainerWidget routes the header, footer and
    // content into that same canvas so anything added later covers it, and the vignette is a
    // screen-wide glow outside the container that should keep framing the panel.

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetTitle(NCZDG_T("NCZDG.title"));
    // Both fluff slots default to an unresolved LocKey (TRN_TCLAS_*), which renders as raw key text.
    // The voice is Night Corp: official, authoritative, slightly sterile.
    this.m_header.SetFluffLeft(NCZDG_T("NCZDG.headerLeft"));
    this.m_header.SetFluffRight(NCZDG_T("NCZDG.headerRight"));
    this.m_header.Reparent(this);

    this.m_footer = InGamePopupFooter.Create();
    this.m_footer.SetFluffText(NCZDG_T("NCZDG.title"));
    this.m_footer.Reparent(this);

    // Codeware's chrome is bound to MainColors.Red - its alert styling. Rebrand it to Zoning Cyan.
    NCZDG_Rebrand(this.m_header.GetRootWidget());
    NCZDG_Rebrand(this.m_footer.GetRootWidget());

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    // An inkCustomController is not a widget: reach its widget with GetRootCompoundWidget().
    let content = this.m_content.GetRootCompoundWidget();

    // A CANVAS, not a flow panel: the two columns are placed absolutely. The right margin re-insets
    // the content region back inside the frame (see NCZDG_FrameInset).
    let body = new inkCanvas();
    body.SetName(n"nczdg_body");
    body.SetSize(new Vector2(NCZDG_UsableWidth(), NCZDG_UsableHeight()));
    body.SetAnchor(inkEAnchor.TopLeft);
    body.SetAnchorPoint(new Vector2(0.0, 0.0));
    body.SetMargin(new inkMargin(0.0, 0.0, NCZDG_FrameInset(), 0.0));
    body.Reparent(content);

    // --- top strip: search (left) + result count (right) ---------------------------------
    this.m_search = HubTextInput.Create();
    this.m_search.SetName(n"nczdg_search");
    this.m_search.SetWidth(NCZDG_NavWidth());
    this.m_search.SetMaxLength(64);
    this.m_search.SetLetterCase(textLetterCase.OriginalCase);
    this.m_search.SetDefaultText(NCZDG_T("NCZDG.searchHint"));
    this.m_search.Reparent(body);
    this.m_search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");

    let searchRoot = this.m_search.GetRootWidget();
    searchRoot.SetAnchor(inkEAnchor.TopLeft);
    searchRoot.SetAnchorPoint(new Vector2(0.0, 0.0));
    searchRoot.SetHAlign(inkEHorizontalAlign.Left);
    NCZDG_RebrandInput(searchRoot);

    // Clear-search, beside the input, styled like the pager buttons. Bespoke rather than
    // MakeButton because it needs an absolute spot in the top strip, and that helper flows its
    // box from the parent's layout. Hidden until there is a query.
    //
    // FULL 80 HIGH AND TOP-ALIGNED, matching the input. It used to be 52 centred inside the
    // input's 80, which reads as a small box floating beside a tall one - unnoticeable with one
    // button, ragged once there were more controls on the row.
    let clearBox = new inkCanvas();
    clearBox.SetName(n"nczdg_search_clear");
    clearBox.SetSize(new Vector2(160.0, 80.0));
    clearBox.SetAnchor(inkEAnchor.TopLeft);
    clearBox.SetAnchorPoint(new Vector2(0.0, 0.0));
    clearBox.SetMargin(new inkMargin(NCZDG_NavWidth() + 16.0, 0.0, 0.0, 0.0));
    clearBox.SetInteractive(true);
    clearBox.SetVisible(false);
    clearBox.Reparent(body);

    let clearFrame = new inkImage();
    clearFrame.SetName(n"frame");   // findable, so OnSearchChanged can reset a hover on hide
    clearFrame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    clearFrame.SetTexturePart(n"cell_fg");
    clearFrame.SetNineSliceScale(true);
    clearFrame.SetAnchor(inkEAnchor.Fill);
    clearFrame.SetTintColor(NCZDG_CyanColor());   // interactive: tint directly, not via a style bind
    clearFrame.SetOpacity(0.8);
    clearFrame.Reparent(clearBox);

    let clearTxt = this.MakeText(NCZDG_T("NCZDG.btnClear"), NCZDG_Cyan(), 34);
    clearTxt.SetHAlign(inkEHorizontalAlign.Center);
    clearTxt.SetVAlign(inkEVerticalAlign.Center);
    clearTxt.SetAnchor(inkEAnchor.Centered);
    clearTxt.SetAnchorPoint(new Vector2(0.5, 0.5));
    clearTxt.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    clearTxt.Reparent(clearBox);

    let clearProxy = new NCZDGGuideProxy();
    clearProxy.popup = this;
    clearProxy.index = NCZDG_IdxClearSearch();
    clearProxy.hoverFrame = clearFrame;
    clearProxy.restOpacity = 0.8;
    ArrayPush(this.m_proxies, clearProxy);   // the widget does not keep the proxy alive
    clearBox.RegisterToCallback(n"OnRelease", clearProxy, n"OnRelease");
    clearBox.RegisterToCallback(n"OnEnter", clearProxy, n"OnEnter");
    clearBox.RegisterToCallback(n"OnLeave", clearProxy, n"OnLeave");
    this.m_searchClear = clearBox;

    // Install filter. It sits at the TOP OF THE DISTRICT COLUMN, not in the search row, because
    // it filters that column as well as the cards - the counts beside every district change
    // with it. A control that reshapes a list belongs on the list.
    //
    // Placed as a sibling ABOVE the nav scroll rather than as its first row: a row would scroll
    // away with the districts, and this has to stay reachable.
    //
    // Its visibility is a GATE, not a preference: without CET nothing is detectable, so the
    // control is hidden rather than shown filtering nothing. Refresh() re-applies that, because
    // the scan completes on session ready and the guide may be built either side of it.
    let filterBox = new inkCanvas();
    filterBox.SetName(n"nczdg_filter");
    filterBox.SetSize(new Vector2(NCZDG_NavWidth() - NCZDG_ScrollBarStrip(), NCZDG_NavFilterHeight()));
    filterBox.SetAnchor(inkEAnchor.TopLeft);
    filterBox.SetAnchorPoint(new Vector2(0.0, 0.0));
    filterBox.SetMargin(new inkMargin(0.0, NCZDG_TopStripHeight(), 0.0, 0.0));
    filterBox.SetInteractive(true);
    filterBox.SetVisible(false);
    filterBox.Reparent(body);

    let filterFrame = new inkImage();
    filterFrame.SetName(n"frame");
    filterFrame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    filterFrame.SetTexturePart(n"cell_fg");
    filterFrame.SetNineSliceScale(true);
    filterFrame.SetAnchor(inkEAnchor.Fill);
    filterFrame.SetTintColor(NCZDG_CyanColor());   // interactive: tint directly, not via a style bind
    filterFrame.SetOpacity(0.8);
    filterFrame.Reparent(filterBox);

    let filterTxt = this.MakeText(NCZDG_FilterLabel(this.m_filter), NCZDG_Cyan(), 28);
    filterTxt.SetHAlign(inkEHorizontalAlign.Center);
    filterTxt.SetVAlign(inkEVerticalAlign.Center);
    filterTxt.SetAnchor(inkEAnchor.Centered);
    filterTxt.SetAnchorPoint(new Vector2(0.5, 0.5));
    filterTxt.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    filterTxt.Reparent(filterBox);

    let filterProxy = new NCZDGGuideProxy();
    filterProxy.popup = this;
    filterProxy.index = NCZDG_IdxCycleFilter();
    filterProxy.hoverFrame = filterFrame;
    filterProxy.restOpacity = 0.8;
    ArrayPush(this.m_proxies, filterProxy);
    filterBox.RegisterToCallback(n"OnRelease", filterProxy, n"OnRelease");
    filterBox.RegisterToCallback(n"OnEnter", filterProxy, n"OnEnter");
    filterBox.RegisterToCallback(n"OnLeave", filterProxy, n"OnLeave");
    this.m_filterBtn = filterBox;
    this.m_filterLabel = filterTxt;

    // Paging. The card column scrolls, but a pool of 30 cannot show 295 locations, so ALL needs a
    // way through.
    //
    // ONE RIGHT-ALIGNED ROW, sharing the search box's 80-high band. The count used to sit ABOVE
    // this and the whole strip had to be tall enough for both, which is what put dead space under
    // the search box.
    let pager = new inkHorizontalPanel();
    pager.SetName(n"nczdg_pager");
    pager.SetChildOrder(inkEChildOrder.Forward);
    pager.SetFitToContent(true);
    pager.SetAnchor(inkEAnchor.TopRight);
    pager.SetAnchorPoint(new Vector2(1.0, 0.0));
    pager.SetHAlign(inkEHorizontalAlign.Right);
    pager.SetMargin(new inkMargin(0.0, 14.0, 0.0, 0.0));   // 52-high buttons centred in the 80 band
    pager.Reparent(body);

    // First child of the pager row, so it flows to the LEFT of the buttons and the whole group
    // stays right-aligned however wide the count text gets.
    let count = this.MakeText("", NCZDG_Gray(), 32);
    count.SetName(n"nczdg_count");
    count.SetVAlign(inkEVerticalAlign.Center);
    count.SetHorizontalAlignment(textHorizontalAlignment.Right);
    count.SetMargin(new inkMargin(0.0, 0.0, 24.0, 0.0));
    count.Reparent(pager);
    this.m_status = count;
    // Clearing the pin must not require finding the card it came from - the player may have
    // searched or paged away from it, and a pin they cannot see is a pin they cannot remove.
    this.m_clearWp = this.MakeButton(pager, NCZDG_T("NCZDG.btnClearMarker"), NCZDG_IdxClearWaypoint());
    this.m_clearWp.SetVisible(false);
    this.m_clearWp.SetSize(new Vector2(280.0, 52.0));
    // Held so Refresh can grey them when there is nowhere to page to. A button that looks
    // active and does nothing reads as a broken button, not as an empty list.
    this.m_prevBtn = this.MakeButton(pager, NCZDG_T("NCZDG.btnPrev"), NCZDG_IdxPrevPage());
    this.m_nextBtn = this.MakeButton(pager, NCZDG_T("NCZDG.btnNext"), NCZDG_IdxNextPage());

    // --- body: districts | cards ----------------------------------------------------------
    // Starts below the filter button and loses exactly that much height, so the two columns
    // still end level at the bottom of the body.
    this.m_navCol = this.MakeScrollColumn(body, 0.0, NCZDG_NavTop(), NCZDG_NavWidth(),
      NCZDG_BodyHeight() - NCZDG_NavFilterHeight() - NCZDG_NavFilterGap(), true);

    let divider = new inkRectangle();
    divider.SetName(n"nczdg_divider");
    divider.SetSize(new Vector2(2.0, NCZDG_BodyHeight()));
    divider.SetAnchor(inkEAnchor.TopLeft);
    divider.SetAnchorPoint(new Vector2(0.0, 0.0));
    divider.SetMargin(new inkMargin(NCZDG_NavWidth() + (NCZDG_ColumnGap() / 2.0),
                                    NCZDG_TopStripHeight(), 0.0, 0.0));
    divider.SetStyle(NCZDG_StylePath());
    divider.BindProperty(n"tintColor", NCZDG_Cyan());
    divider.SetOpacity(0.25);
    divider.Reparent(body);

    this.m_cardCol = this.MakeScrollColumn(body, NCZDG_NavWidth() + NCZDG_ColumnGap(),
                                           NCZDG_TopStripHeight(), NCZDG_CardsWidth(),
                                           NCZDG_BodyHeight(), false);

    this.BuildCardPool();
    this.BuildNav();
    // The saved default may not be ALL, in which case the nav is already wrong the moment it is
    // built. Apply it once here so the guide opens consistent.
    this.ApplyNavFilter();
    // LAST, and onto the popup's own root widget rather than the body: ink draws in child order
    // with no z-index, so this is the only way the overlay covers the header and footer too.
    // Note `this` is an inkCustomController, NOT a widget - reach the widget explicitly.
    this.BuildLightbox(this.GetRootCompoundWidget());
  }

  // Every keystroke re-queries and re-binds the pool. No debounce is needed: nothing is allocated,
  // 295 string compares are trivial, and the game is paused anyway.
  protected cb func OnSearchChanged(widget: ref<inkWidget>) -> Bool {
    this.m_query = this.m_search.GetText();
    if IsDefined(this.m_searchClear) {
      let show = StrLen(this.m_query) > 0;
      this.m_searchClear.SetVisible(show);
      // Hiding a hovered button eats its OnLeave, so reset the hover by hand or it comes back white.
      if !show {
        this.ResetButtonHover(this.m_searchClear, 0.8);
      }
    }
    this.m_page = 0;
    this.ScrollCardsToTop();
    this.Refresh();
    return true;
  }

  // --------------------------------------------------------------------------------------
  // Nav
  // --------------------------------------------------------------------------------------
  // Rows are 1:1 with the model's areas and are built ONCE: the counts cannot change while the
  // popup is open, so selecting is a restyle, never a rebuild.
  private func BuildNav() -> Void {
    if !NCZDG_CoreUsable() {
      return;
    }
    this.m_model = new NCZDGGuideModel();
    this.m_model.Build();

    let n = this.m_model.AreaCount();
    let i = 0;
    while i < n {
      let area = this.m_model.AreaAt(i);
      this.MakeNavRow(area, i);
      i += 1;
    }
    // The one line the guide gets per open. BuildNav is called once, from the popup build, so
    // this doubles as "the guide opened" - and it carries the location total, which is what
    // separates "the guide is empty" from "the registry is empty".
    NCZDGLog(s"guide: opened - \(n) areas, \(this.m_model.Total()) locations");

    // Open on the area the player is standing in. Layer 2 resolves subdistricts in-world, which the
    // map screen cannot do, so this is more specific than the map panel can be. Off-map falls to All.
    let idx = 0;
    let here = NCZDG_ResolveCurrent(this.m_gi);
    if IsDefined(here) {
      idx = this.m_model.FindArea(here.district, here.subdistrict);
      if idx < 0 {
        idx = this.m_model.FindArea(here.district, "");
      }
      if idx < 0 {
        idx = 0;
      }
    }
    this.SelectArea(idx);
  }

  private func MakeNavRow(area: ref<NCZDGArea>, index: Int32) -> Void {
    let rowW = NCZDG_NavWidth() - NCZDG_ScrollBarStrip();

    let row = new inkCanvas();
    row.SetName(n"nczdg_nav_row");
    row.SetSize(new Vector2(rowW, area.isSub ? 54.0 : 64.0));
    row.SetInteractive(true);
    row.SetHAlign(inkEHorizontalAlign.Left);
    row.SetMargin(new inkMargin(0.0, area.isAll ? 0.0 : (area.isSub ? 0.0 : 18.0), 0.0, 0.0));
    row.Reparent(this.m_navCol);

    // The selection wash. Opacity 0 until selected, so selecting costs one property write.
    let sel = new inkRectangle();
    sel.SetName(n"sel");
    sel.SetAnchor(inkEAnchor.Fill);
    sel.SetStyle(NCZDG_StylePath());
    sel.BindProperty(n"tintColor", NCZDG_Cyan());
    sel.SetOpacity(0.0);
    sel.Reparent(row);

    // Cyan is "this area has something in it". An EMPTY area drops to grey - label and count both -
    // so the eye skips it, but it is still listed and still countable. Counts are amber.
    // Hierarchy comes from size and indent, not from colour.
    let empty = area.count <= 0;
    let colour = empty ? NCZDG_Gray() : NCZDG_Cyan();
    let countColour = empty ? NCZDG_Gray() : NCZDG_Amber();
    let size = area.isSub ? 30 : 34;

    let label = this.MakeText(area.Label(), colour, size);
    label.SetName(n"label");
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetAnchor(inkEAnchor.CenterLeft);
    label.SetAnchorPoint(new Vector2(0.0, 0.5));
    label.SetMargin(new inkMargin(area.isSub ? 48.0 : 16.0, 0.0, 0.0, 0.0));
    label.Reparent(row);

    // An empty area still shows its zero. That is the point of building the nav from the
    // vocabulary rather than from the locations.
    let cnt = this.MakeText(s"\(area.count)", countColour, 28);
    cnt.SetName(n"count");
    cnt.SetAnchor(inkEAnchor.CenterRight);
    cnt.SetAnchorPoint(new Vector2(1.0, 0.5));
    cnt.SetMargin(new inkMargin(0.0, 0.0, 20.0, 0.0));
    cnt.Reparent(row);

    // Of that total, how many are recently updated - green, to the left of the amber total, and only
    // when there are any. The colour ties back to the green RECENTLY UPDATED badge on the cards.
    if area.recentCount > 0 {
      let recent = this.MakeText(NCZDG_T1("NCZDG.navRecent", "{n}", IntToString(area.recentCount)), NCZDG_Green(), 22);
      recent.SetName(n"recent");
      recent.SetAnchor(inkEAnchor.CenterRight);
      recent.SetAnchorPoint(new Vector2(1.0, 0.5));
      recent.SetMargin(new inkMargin(0.0, 0.0, 100.0, 0.0));
      recent.Reparent(row);
    }

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = index;
    ArrayPush(this.m_proxies, proxy);   // the widget does not keep the proxy alive
    row.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");

    ArrayPush(this.m_navRows, row);
  }

  private func SelectArea(index: Int32) -> Void {
    if index < 0 || index >= ArraySize(this.m_navRows) {
      return;
    }
    if this.m_selected >= 0 && this.m_selected < ArraySize(this.m_navRows) {
      this.SetRowSelected(this.m_navRows[this.m_selected], false);
    }
    this.m_selected = index;
    this.SetRowSelected(this.m_navRows[index], true);
    this.m_page = 0;
    this.ScrollCardsToTop();
    this.Refresh();
  }

  // Back to the rest state a hidden button's OnLeave would have restored. The frame child is
  // named n"frame" in both button builders for exactly this lookup.
  private func ResetButtonHover(box: wref<inkWidget>, restOpacity: Float) -> Void {
    let frame = NCZDG_FindByName(box, n"frame");
    if IsDefined(frame) {
      frame.SetTintColor(NCZDG_CyanColor());
      frame.SetOpacity(restOpacity);
    }
  }

  // The scroll offset survives a re-bind, which is right for a marker refresh (the pointer is on a
  // card; yanking the view would move the card out from under it) and wrong for a page turn, a new
  // area, or a new query, where the fresh content starts above the viewport. So the reset is called
  // at those three sites, never inside Refresh. SetScrollPosition(0.0) is the vanilla idiom - the
  // vendor grid does exactly this on restock.
  private func ScrollCardsToTop() -> Void {
    if IsDefined(this.m_cardScroll) {
      this.m_cardScroll.SetScrollPosition(0.0);
    }
  }

  private func SetRowSelected(row: wref<inkCanvas>, on: Bool) -> Void {
    let sel = NCZDG_FindByName(row, n"sel");
    if IsDefined(sel) {
      sel.SetOpacity(on ? 0.18 : 0.0);
    }
  }

  // --------------------------------------------------------------------------------------
  // Cards
  // --------------------------------------------------------------------------------------
  // Re-query and re-bind. Called on selection, on every keystroke, and on a page change. No widget
  // is created here: the cost is a few hundred property writes, on a frame the game has paused.
  private func Refresh() -> Void {
    let area = this.m_model.AreaAt(this.m_selected);
    if !IsDefined(area) {
      return;
    }
    this.m_shown = this.m_model.Query(this.m_selected, this.m_query);
    this.ApplyInstallFilter();

    let n = ArraySize(this.m_shown);
    let pages = (n + NCZDG_PageSize() - 1) / NCZDG_PageSize();
    if this.m_page >= pages {
      this.m_page = pages > 0 ? pages - 1 : 0;
    }
    let start = this.m_page * NCZDG_PageSize();

    let slot = 0;
    while slot < ArraySize(this.m_cards) {
      let f = start + slot;
      if f < n {
        this.BindCard(this.m_cards[slot], this.m_shown[f]);
        this.m_cards[slot].root.SetVisible(true);
      } else {
        this.m_cards[slot].root.SetVisible(false);
      }
      // A slot's identity changes under a filter or a page turn, so the selection cannot survive
      // it. Goes through SetCardActions so the tags come back with the strip going away.
      this.SetCardActions(this.m_cards[slot], false);
      slot += 1;
    }
    // A row with both cards hidden still occupies its height in the flow, so hide the row too.
    let r = 0;
    while r < ArraySize(this.m_cardRows) {
      let firstOfRow = start + (r * NCZDG_CardsPerRow());
      this.m_cardRows[r].SetVisible(firstOfRow < n);
      r += 1;
    }

    this.m_selCard = -1;

    // Availability is a gate. Re-checked here rather than only at build time because the scan
    // finishes on session ready, which can land either side of the guide being built.
    if IsDefined(this.m_filterBtn) {
      this.m_filterBtn.SetVisible(NCZDG_InstallDetection());
    }

    // Page buttons only mean something when there is a page to go to.
    this.SetButtonEnabled(this.m_prevBtn, this.m_page > 0);
    this.SetButtonEnabled(this.m_nextBtn, this.m_page + 1 < pages);

    let actions = NCZDGWorldActions.Get(this.m_gi);
    let marked = IsDefined(actions) && actions.HasPin();
    if IsDefined(this.m_clearWp) {
      this.m_clearWp.SetVisible(marked);
      // Hiding a hovered button eats its OnLeave, so reset the hover by hand or it comes back white.
      if !marked {
        this.ResetButtonHover(this.m_clearWp, 1.0);
      }
    }

    // A marker that is placed but not tracked draws a pin and no route, and only the player can fix
    // that - from the map. Saying so once, in the footer, beats a card button that cannot do it.
    //
    // The hint must say HOVER. The map only tracks the mappin under the cursor; pressing the track key
    // with nothing hovered drops a plain custom waypoint at the cursor instead, which is correct
    // vanilla behaviour and looks exactly like the mod misfiring.
    let routing = marked && actions.IsRouting(this.m_gi);
    let shownFrom = n > 0 ? start + 1 : 0;
    let shownTo = start + NCZDG_PageSize() < n ? start + NCZDG_PageSize() : n;
    let counts: String;
    if StrLen(this.m_query) > 0 {
      counts = NCZDG_T3("NCZDG.countSearch", "{n}", IntToString(n),
                        "{total}", IntToString(area.count), "{area}", area.Label());
    } else {
      if n > NCZDG_PageSize() {
        counts = NCZDG_T4("NCZDG.countPaged", "{from}", IntToString(shownFrom),
                          "{to}", IntToString(shownTo), "{n}", IntToString(n),
                          "{area}", area.Label());
      } else {
        counts = NCZDG_T2("NCZDG.countPlain", "{n}", IntToString(n), "{area}", area.Label());
      }
    }
    if marked && !routing {
      counts += NCZDG_T("NCZDG.routingHint");
    }
    // Not logged. Refresh runs on every nav click, every page turn and every keystroke in the
    // search box - it is the single noisiest thing the guide does.
    this.m_status.SetText(counts);
  }

  // Narrows m_shown to the current filter. A no-op when the filter is ALL, and ALSO a no-op
  // when detection is unavailable - without CET every record is Unknown, so filtering would
  // either empty the list or change nothing, and both are lies about the data.
  //
  // Unknown is excluded from INSTALLED and MISSING and has its own view - see the note on the
  // filter constants for why showing it in both was wrong.
  private func ApplyInstallFilter() -> Void {
    if this.m_filter == NCZDG_FilterAll() || !NCZDG_InstallDetection() {
      return;
    }
    let kept: array<ref<NCZLocation>>;
    let i = 0;
    while i < ArraySize(this.m_shown) {
      if NCZDG_PassesFilter(NCZDG_InstallStateOf(this.m_shown[i]), this.m_filter) {
        ArrayPush(kept, this.m_shown[i]);
      }
      i += 1;
    }
    this.m_shown = kept;
  }

  // How many of an area's locations survive the current filter. Used for the nav counts, so the
  // left column can never claim 45 while the card list shows 3.
  private func FilteredAreaCount(areaIdx: Int32) -> Int32 {
    let locs = this.m_model.Query(areaIdx, "");
    if this.m_filter == NCZDG_FilterAll() || !NCZDG_InstallDetection() {
      return ArraySize(locs);
    }
    let n = 0;
    let i = 0;
    while i < ArraySize(locs) {
      if NCZDG_PassesFilter(NCZDG_InstallStateOf(locs[i]), this.m_filter) {
        n += 1;
      }
      i += 1;
    }
    return n;
  }

  // Re-counts and re-colours every nav row against the current filter, and HIDES the areas with
  // nothing left in them.
  //
  // Called on a filter change and once at open - NOT from Refresh(). Refresh runs on every
  // search keystroke, and the nav has never reflected the search term; recomputing ~40 areas
  // over ~300 locations per keypress would be pure waste.
  private func ApplyNavFilter() -> Void {
    let filtering = this.m_filter != NCZDG_FilterAll() && NCZDG_InstallDetection();
    let selectedVanished = false;
    let r = 0;
    while r < ArraySize(this.m_navRows) {
      let area = this.m_model.AreaAt(r);
      if IsDefined(area) && IsDefined(this.m_navRows[r]) {
        let n = filtering ? this.FilteredAreaCount(r) : area.count;

        // ALL LOCATIONS always stays: it is the way back when a filter empties everything else.
        let visible = !filtering || n > 0 || area.isAll;
        this.m_navRows[r].SetVisible(visible);
        if !visible && r == this.m_selected {
          selectedVanished = true;
        }

        let cntTxt = this.m_navRows[r].GetWidget(n"count") as inkText;
        if IsDefined(cntTxt) {
          cntTxt.SetText(s"\(n)");
          cntTxt.BindProperty(n"tintColor", n <= 0 ? NCZDG_Gray() : NCZDG_Amber());
        }
        let lblTxt = this.m_navRows[r].GetWidget(n"label") as inkText;
        if IsDefined(lblTxt) {
          lblTxt.BindProperty(n"tintColor", n <= 0 ? NCZDG_Gray() : NCZDG_Cyan());
        }
        // The recency count is about the registry, not about what is installed, so it would be
        // lying next to a filtered total. Hide it while filtering rather than recompute it.
        let recTxt = this.m_navRows[r].GetWidget(n"recent") as inkText;
        if IsDefined(recTxt) {
          recTxt.SetVisible(!filtering);
        }
      }
      r += 1;
    }
    // Standing on an area the filter just emptied leaves a selected-but-hidden row and an empty
    // card list with no visible cause. Fall back to ALL LOCATIONS.
    if selectedVanished {
      this.SelectArea(0);
    }
  }

  // Greys a pager button and takes it out of the input path.
  //
  // Opacity on the BOX, not a grey tint on each child: it dims the frame and the label together
  // in one write, and there is no NCZDG_GrayColor() to tint chrome with anyway - the grey in
  // this palette is a style-bind CName, and interactive chrome must be tinted directly because
  // widget states override style-bound tints.
  //
  // Interactivity is cleared as well as dimmed. A button that still brightens on hover reads as
  // active however faint it is, and a non-interactive widget also cannot eat an OnEnter it will
  // never balance with an OnLeave - which is how the CLEAR button used to stick white.
  private func SetButtonEnabled(box: wref<inkCanvas>, on: Bool) -> Void {
    if !IsDefined(box) {
      return;
    }
    box.SetInteractive(on);
    box.SetOpacity(on ? 1.0 : 0.3);
  }

  public func CycleFilter() -> Void {
    this.m_filter = (this.m_filter + 1) % NCZDG_FilterCount();
    if IsDefined(this.m_filterLabel) {
      this.m_filterLabel.SetText(NCZDG_FilterLabel(this.m_filter));
    }
    this.m_page = 0;   // the old page number means nothing against a different result set
    this.ScrollCardsToTop();
    // Nav first: it can change the selected area, and Refresh reads that.
    this.ApplyNavFilter();
    this.Refresh();
  }

  private func BindCard(slot: ref<NCZDGCardSlot>, loc: ref<NCZLocation>) -> Void {
    // Decide the layout FIRST: everything below is capped against whichever width it picks.
    //
    // The test is "is there a URL", not "has the image loaded". Those differ, and using the
    // second would make every card jump from wide to narrow as fetches landed. A URL is known
    // the instant the record binds, and 296 of 297 records have one - so the narrow layout is
    // chosen up front and nothing reflows later. A card only widens again if the fetch
    // actually FAILS, which is rare enough that the reflow is acceptable.
    let thumbUrl = loc.ThumbnailUrl();
    let hasImage = NCZDG_Img.Available() && StrLen(thumbUrl) > 0;
    this.SetCardImageState(slot, hasImage);
    slot.picUrl = hasImage ? loc.PictureUrl() : "";
    if hasImage {
      this.QueueImage(thumbUrl, slot.image, NCZDG_ImageWidth(), NCZDG_ImageHeight(), slot.slotIdx);
    }

    // Capped, which it never used to be. At ~545 wide a long mod name wraps to three lines and
    // pushes the tags out of the bottom of the card - and ink cannot clip, so they would draw
    // over the card below rather than being trimmed.
    let title = loc.Name();
    slot.name.SetText(StrLen(title) > NCZDG_TitleCap()
      ? StrLeft(title, NCZDG_TitleCap() - 3) + "..."
      : title);

    let authors = "";
    let a = 0;
    while a < loc.AuthorCount() {
      authors += (a > 0 ? ", " : "") + loc.AuthorAt(a);
      a += 1;
    }
    // Capped so a long author list cannot run into the badge sharing the meta row: the badge is
    // ~240 wide on an ~850 row, and 40 chars of 26px meta stays well left of it.
    let cat = NCZDG_CategoryLabel(loc.Category());
    let metaStr = StrLen(authors) > 0 ? s"\(cat)  -  \(authors)" : cat;
    slot.meta.SetText(StrLen(metaStr) > 40 ? StrLeft(metaStr, 37) + "..." : metaStr);
    slot.meta.BindProperty(n"tintColor", NCZDG_CategoryColor(loc.Category()));
    slot.accent.BindProperty(n"tintColor", NCZDG_CategoryColor(loc.Category()));

    // There is no way to query a wrapped text's height, so the card height is fixed and the
    // description is hard-truncated. 140 chars fills ~2 wrapped lines at this width; an unusually
    // narrow-glyphed 140 can reach a 3rd line, which only nudges the tags line into the row gap -
    // the badge is on the meta row and out of reach. 150 reached 3 lines routinely; 110 left the
    // 2nd line visibly half-empty.
    let d = loc.Description();
    slot.desc.SetText(StrLen(d) > NCZDG_DescCap()
      ? StrLeft(d, NCZDG_DescCap() - 3) + "..."
      : d);

    // Capped by count AND length, and the length check is done on the PROSPECTIVE string. The
    // old form tested the length already accumulated and then appended anyway, so the result
    // could exceed the cap by an entire tag - a 15-character tag arriving at 59 gave 74. That is
    // not a tidiness slip: the tags widget has no wrap position, so it does not wrap onto a
    // second line, it runs off the right edge of the card, and ink will not clip it.
    let tags = "";
    let t = 0;
    while t < loc.TagCount() && t < NCZDG_TagsMax() {
      let next = (t > 0 ? "  " : "") + "#" + loc.TagAt(t);
      if StrLen(tags) + StrLen(next) > NCZDG_TagsCap() {
        break;
      }
      tags += next;
      t += 1;
    }
    slot.tags.SetText(tags);

    // Server-computed recency: the guide cannot derive "updated within N days" (no in-game clock),
    // so it shows what the API decided.
    slot.badge.SetVisible(loc.RecentlyUpdated());

    // Install state. Unknown draws nothing at all - see the note on the widget.
    if IsDefined(slot.installBar) {
      let st = NCZDG_InstallStateOf(loc);
      if Equals(st, NCZInstallState.Installed) {
        slot.installBar.SetVisible(true);
        slot.installBar.BindProperty(n"tintColor", NCZDG_Green());
      } else {
        if Equals(st, NCZInstallState.NotInstalled) {
          slot.installBar.SetVisible(true);
          slot.installBar.BindProperty(n"tintColor", NCZDG_Gray());
        } else {
          slot.installBar.SetVisible(false);
        }
      }
    }

    // The waypoint button reflects the CURRENT pin, so it is right on every re-bind.
    let actions = NCZDGWorldActions.Get(this.m_gi);
    // A button says what CLICKING it does, and nothing else. Routing state is not an action - no
    // script can track a mappin, only the player can, from the map - so it belongs in a hint, not on
    // a control that does something different from what it reads.
    let pinned = IsDefined(actions) && actions.IsPinned(loc.Id());
    slot.wpLabel.SetText(pinned ? NCZDG_T("NCZDG.btnClearMarker") : NCZDG_T("NCZDG.btnSetMarker"));
    slot.wpLabel.BindProperty(n"tintColor", NCZDG_Cyan());

    let canTp = NCZDG_CanTeleport(this.m_gi);
    slot.tpLabel.SetText(canTp ? NCZDG_T("NCZDG.btnTeleport") : NCZDG_T("NCZDG.btnExitVehicle"));
    slot.tpLabel.BindProperty(n"tintColor", canTp ? NCZDG_Cyan() : NCZDG_Gray());
  }

  // --- lightbox ---------------------------------------------------------------------------
  //
  // Built once in OnCreate and hidden. It covers the whole popup, so it is parented LAST: ink
  // draws in child order and offers no z-index, which is also why it cannot simply live inside
  // the card it was opened from.
  //
  // IT CLOSES ON CLICK, ANYWHERE. ESC is Codeware's and closes the whole guide, and there is no
  // supported way to intercept it ahead of the popup - so rather than half-capture it, the
  // scrim is one big button. ESC while the lightbox is open therefore closes the guide outright;
  // that is a known wart, not an oversight.
  private func BuildLightbox(parent: wref<inkCompoundWidget>) -> Void {
    let box = new inkCanvas();
    box.SetName(n"nczdg_lightbox");
    box.SetSize(new Vector2(NCZDG_PopupWidth(), NCZDG_PopupHeight()));
    box.SetAnchor(inkEAnchor.Centered);
    box.SetAnchorPoint(new Vector2(0.5, 0.5));
    box.SetInteractive(true);
    box.SetVisible(false);
    box.Reparent(parent);

    // The scrim swallows the click AND blacks out the guide behind it, so the photo is the only
    // thing to look at.
    //
    // FULLY OPAQUE, AND SIZED EXPLICITLY. The first cut used inkEAnchor.Fill at 0.96 opacity and
    // read clearly translucent in-game - the nav column and card text were legible straight
    // through it. Both halves of that are now pinned down rather than trusted: an explicit size
    // instead of Fill, and 1.0 instead of a fraction.
    let scrim = new inkRectangle();
    scrim.SetSize(new Vector2(NCZDG_PopupWidth(), NCZDG_PopupHeight()));
    scrim.SetAnchor(inkEAnchor.Centered);
    scrim.SetAnchorPoint(new Vector2(0.5, 0.5));
    scrim.SetTintColor(NCZDG_NavyColor());   // the darkest brand surface, not the card colour
    scrim.SetOpacity(1.0);
    scrim.Reparent(box);

    let img = new inkImage();
    img.SetName(n"nczdg_lightbox_img");
    img.SetAnchor(inkEAnchor.Centered);
    img.SetAnchorPoint(new Vector2(0.5, 0.5));
    img.SetVisible(false);
    img.Reparent(box);

    let caption = this.MakeText(NCZDG_T("NCZDG.imgLoading"), NCZDG_Cyan(), 30);
    caption.SetHAlign(inkEHorizontalAlign.Center);
    caption.SetAnchor(inkEAnchor.BottomCenter);
    caption.SetAnchorPoint(new Vector2(0.5, 1.0));
    caption.SetMargin(new inkMargin(0.0, 0.0, 0.0, 60.0));
    caption.Reparent(box);

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = NCZDG_IdxCloseLightbox();
    ArrayPush(this.m_proxies, proxy);
    box.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");

    this.m_lightbox = box;
    this.m_lightboxImg = img;
    this.m_lightboxCaption = caption;
  }

  public func OpenLightbox(slotIdx: Int32) -> Void {
    if slotIdx < 0 || slotIdx >= ArraySize(this.m_cards) || !IsDefined(this.m_lightbox) {
      return;
    }
    let url = this.m_cards[slotIdx].picUrl;
    // Guarded on the URL, not on the thumbnail being visible: a card whose fetch failed has
    // collapsed its box but its proxy is still registered.
    if StrLen(url) == 0 {
      return;
    }
    this.m_lightboxImg.SetVisible(false);
    this.m_lightboxCaption.SetVisible(true);
    this.m_lightboxCaption.SetText(NCZDG_T("NCZDG.imgLoadingClose"));
    this.m_lightbox.SetVisible(true);
    // The full-size picture is a SECOND fetch - the card holds the thumbnail. slotIdx -1 keeps
    // it out of the per-slot replacement logic, which is about cards and not about this.
    this.QueueImage(url, this.m_lightboxImg,
                    NCZDG_PopupWidth() - 320.0, NCZDG_PopupHeight() - 320.0, -1);
  }

  public func CloseLightbox() -> Void {
    if IsDefined(this.m_lightbox) {
      this.m_lightbox.SetVisible(false);
    }
  }

  // The card geometry no longer changes - every card is the same height and reserves the same
  // image box. All this switches is WHAT FILLS the box: a real image, or the placeholder.
  //
  // Called on every bind, and it must hide the image widget even when the new location does
  // have one: the texture is not bound until the fetch lands, so a slot recycled by a page turn
  // would otherwise show the PREVIOUS location's picture under the new location's name.
  private func SetCardImageState(slot: ref<NCZDGCardSlot>, hasImage: Bool) -> Void {
    if IsDefined(slot.image) {
      slot.image.SetVisible(false);
    }
    if IsDefined(slot.phIcon) {
      slot.phIcon.SetVisible(!hasImage);
    }
    if IsDefined(slot.phText) {
      slot.phText.SetVisible(!hasImage);
    }
  }

  // Queue a fetch. Idempotent per (url, image): a page turn that rebinds the same location to
  // the same slot must not stack a second pending entry.
  private func QueueImage(url: String, image: wref<inkImage>, boxW: Float, boxH: Float,
                          slotIdx: Int32) -> Void {
    if !NCZDG_Img.Available() || StrLen(url) == 0 || !IsDefined(image) {
      return;
    }
    let i = 0;
    while i < ArraySize(this.m_pending) {
      // Same slot, different location: the old fetch is now pointless, so replace it rather
      // than letting it land on a card that has moved on.
      if this.m_pending[i].slotIdx == slotIdx && slotIdx >= 0 {
        if UnicodeStringEqual(this.m_pending[i].url, url) {
          return;
        }
        ArrayErase(this.m_pending, i);
        break;
      }
      i += 1;
    }
    let p = new NCZDGPendingImage();
    p.url = url;
    p.image = image;
    p.boxW = boxW;
    p.boxH = boxH;
    p.slotIdx = slotIdx;
    p.applied = false;
    ArrayPush(this.m_pending, p);
    this.EnsureImagePoll();
  }

  // One poll chain at a time, started on demand and left to die when the queue empties or the
  // popup closes. Deliberately NOT an onUpdate: this is a UI fetch, not game logic, and it must
  // stop dead the moment the guide is gone.
  private func EnsureImagePoll() -> Void {
    if this.m_polling || this.m_isClosed || ArraySize(this.m_pending) == 0 {
      return;
    }
    this.m_polling = true;
    this.ScheduleImagePoll();
  }

  private func ScheduleImagePoll() -> Void {
    let cb = new NCZDGImagePollCB();
    cb.popup = this;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(cb, 0.25, false);
  }

  // Prepare() answers "" until the image is ready, so this re-asks each tick. Every entry that
  // resolves or fails is dropped; the chain stops when nothing is left to wait for.
  public func OnImagePoll() -> Void {
    if this.m_isClosed {
      this.m_polling = false;
      ArrayClear(this.m_pending);
      return;
    }
    // Single exit per iteration via `drop`, because redscript has no `continue` - and an early
    // ArrayErase without advancing would otherwise need one. Erasing shifts the next entry into
    // the current index, so a dropped entry must NOT advance i.
    let i = 0;
    while i < ArraySize(this.m_pending) {
      let p = this.m_pending[i];
      let drop = false;
      if !IsDefined(p.image) {
        drop = true;
      } else {
        let atlas = NCZDG_Img.Prepare(p.url);
        if StrLen(atlas) > 0 {
          this.ApplyImage(p, atlas);
          drop = true;
        } else {
          if NCZDG_Img.Failed(p.url) {
            NCZDGWarn(s"images: gave up on \(p.url)");
            if p.slotIdx < 0 && IsDefined(this.m_lightboxCaption) {
              this.m_lightboxCaption.SetText(NCZDG_T("NCZDG.imgFailed"));
            }
            // A card whose image will never arrive shows the placeholder instead. Nothing
            // reflows now: the box is reserved either way, so this only swaps what fills it.
            if p.slotIdx >= 0 && p.slotIdx < ArraySize(this.m_cards) {
              this.SetCardImageState(this.m_cards[p.slotIdx], false);
            }
            drop = true;
          }
        }
      }
      if drop {
        ArrayErase(this.m_pending, i);
      } else {
        i += 1;
      }
    }
    if ArraySize(this.m_pending) > 0 {
      this.ScheduleImagePoll();
      return;
    }
    this.m_polling = false;
  }

  // Scale to FIT the box, preserving the image's own aspect. Never scale to fill: ink cannot
  // clip a child, so an image larger than its box draws over the card's text.
  private func ApplyImage(p: ref<NCZDGPendingImage>, atlas: String) -> Void {
    let uvW = NCZDG_Img.UvWidth(p.url);
    let uvH = NCZDG_Img.UvHeight(p.url);
    if uvW <= 0.0 { uvW = 1.0; }
    if uvH <= 0.0 { uvH = 1.0; }
    let scale = p.boxW / uvW;
    let byHeight = p.boxH / uvH;
    if byHeight < scale {
      scale = byHeight;
    }
    p.image.SetAtlasResource(ResRef.FromString(atlas));
    p.image.SetTexturePart(n"full");
    p.image.SetSize(new Vector2(uvW * scale, uvH * scale));
    p.image.SetVisible(true);
    p.applied = true;
    // The lightbox (slot -1) shows a LOADING caption in place of the image; swap it for the
    // close hint once there is something to look at.
    if p.slotIdx < 0 && IsDefined(this.m_lightboxCaption) {
      this.m_lightboxCaption.SetText(NCZDG_T("NCZDG.imgClose"));
    }
  }

  // The strip has its own reserved band under the tags (NCZDG_ActionBandHeight), so revealing it
  // overlaps nothing and hides nothing. THE TAGS ARE NEVER TOUCHED HERE - an earlier version
  // swapped the two, and that was wrong twice over: it punished every card for a problem only
  // long ones had, and the tags appear nowhere else in the mod, so hiding them lost the
  // information rather than deferring it.
  private func SetCardActions(slot: ref<NCZDGCardSlot>, on: Bool) -> Void {
    if IsDefined(slot.actions) {
      slot.actions.SetVisible(on);
    }
    if IsDefined(slot.frame) {
      slot.frame.SetOpacity(on ? 1.0 : 0.35);
    }
  }

  // Selecting a card (hover, or a click) reveals its actions and hides the previous one's. Nothing
  // reflows: both the strip and the tags are always built, only toggled.
  private func SelectCard(slotIdx: Int32) -> Void {
    if this.m_selCard >= 0 && this.m_selCard < ArraySize(this.m_cards) {
      this.SetCardActions(this.m_cards[this.m_selCard], false);
    }
    if slotIdx < 0 || slotIdx >= ArraySize(this.m_cards) {
      this.m_selCard = -1;
      return;
    }
    this.m_selCard = slotIdx;
    this.SetCardActions(this.m_cards[slotIdx], true);
  }

  // The pool slot -> the location currently bound to it. Null if the slot is empty on this page.
  private func LocForSlot(slotIdx: Int32) -> ref<NCZLocation> {
    let f = (this.m_page * NCZDG_PageSize()) + slotIdx;
    if f < 0 || f >= ArraySize(this.m_shown) {
      return null;
    }
    return this.m_shown[f];
  }

  private func BuildCardPool() -> Void {
    let rows = NCZDG_PageSize() / NCZDG_CardsPerRow();
    let r = 0;
    while r < rows {
      let row = new inkHorizontalPanel();
      row.SetName(n"nczdg_card_row");
      row.SetChildOrder(inkEChildOrder.Forward);
      row.SetFitToContent(true);
      row.SetHAlign(inkEHorizontalAlign.Left);
      row.SetMargin(new inkMargin(0.0, 0.0, 0.0, NCZDG_CardGap()));
      row.Reparent(this.m_cardCol);
      ArrayPush(this.m_cardRows, row);

      let c = 0;
      while c < NCZDG_CardsPerRow() {
        let slotIdx = (r * NCZDG_CardsPerRow()) + c;
        ArrayPush(this.m_cards, this.MakeCard(row, slotIdx, c > 0));
        c += 1;
      }
      r += 1;
    }
  }

  private func MakeCard(parent: wref<inkCompoundWidget>, slotIdx: Int32, gapLeft: Bool) -> ref<NCZDGCardSlot> {
    let card = new inkCanvas();
    card.SetName(n"nczdg_card");
    card.SetSize(new Vector2(NCZDG_CardWidth(), NCZDG_CardHeight()));
    card.SetInteractive(true);
    card.SetMargin(new inkMargin(gapLeft ? NCZDG_CardGap() : 0.0, 0.0, 0.0, 0.0));
    card.Reparent(parent);

    // Corporate Navy surface, at the same 0.95 the site uses so the world stays faintly visible.
    //
    // AN inkImage ON cell_bg, NOT AN inkRectangle. The cell_fg frame below has a chamfered
    // corner; a plain rectangle is square, so the navy fill drew straight through the cut and
    // the chamfer read as a line over a solid corner rather than as a corner. cell_bg is the
    // chamfered counterpart of cell_fg in the same atlas and matches it exactly. Nine-sliced,
    // or the chamfer scales with the card instead of staying a fixed cut.
    let bg = new inkImage();
    bg.SetName(n"bg");
    bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    bg.SetTexturePart(n"cell_bg");
    bg.SetNineSliceScale(true);
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(NCZDG_CardBgColor());
    bg.SetOpacity(NCZDG_PanelOpacity());
    bg.Reparent(card);

    let frame = new inkImage();
    frame.SetName(n"frame");
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetStyle(NCZDG_StylePath());
    frame.BindProperty(n"tintColor", NCZDG_Cyan());
    frame.SetOpacity(0.35);
    frame.Reparent(card);

    // The category chip, as a colour bar down the left edge. Same mapping as the map panel.
    let accent = new inkRectangle();
    accent.SetName(n"accent");
    accent.SetSize(new Vector2(6.0, NCZDG_CardHeight()));
    accent.SetAnchor(inkEAnchor.LeftFillVerticaly);
    accent.SetStyle(NCZDG_StylePath());
    accent.BindProperty(n"tintColor", NCZDG_Cyan());
    accent.Reparent(card);

    // Install state, as a second bar immediately inside the category one. It goes here rather
    // than on the meta row because that row is already tight - the meta string is capped at 40
    // chars specifically so it cannot reach the RECENTLY UPDATED badge - and a bar costs no
    // layout space at all.
    //
    // HIDDEN means "no information", and that is the honest rendering for Unknown: an AMM mod
    // is undetectable in principle, and with no CET nothing is detectable at all. Only a known
    // state draws a bar.
    let installBar = new inkRectangle();
    installBar.SetName(n"install");
    installBar.SetSize(new Vector2(6.0, NCZDG_CardHeight()));
    installBar.SetAnchor(inkEAnchor.LeftFillVerticaly);
    installBar.SetMargin(new inkMargin(8.0, 0.0, 0.0, 0.0));
    installBar.SetStyle(NCZDG_StylePath());   // style bind, like the accent bar beside it
    installBar.SetVisible(false);
    installBar.Reparent(card);

    // The banner image, across the top. ALWAYS PRESENT AND ALWAYS THE SAME SIZE - it is not
    // toggled per bind any more. In a three-across grid a card that collapses its image sits a
    // third as tall as the two beside it, and a row that does not line up reads as broken; a
    // reserved box with an honest placeholder does not. That reverses the collapse behaviour
    // the two-column list had, and the reason is the grid, not a change of mind about images.
    let imgBox = new inkCanvas();
    imgBox.SetName(n"nczdg_thumb");
    imgBox.SetSize(new Vector2(NCZDG_ImageWidth(), NCZDG_ImageHeight()));
    imgBox.SetAnchor(inkEAnchor.TopLeft);
    imgBox.SetAnchorPoint(new Vector2(0.0, 0.0));
    imgBox.SetMargin(new inkMargin(NCZDG_CardPadLeft(), 0.0, 0.0, 0.0));
    imgBox.SetInteractive(true);
    imgBox.Reparent(card);

    // A dim plate behind the image, so a slow fetch reads as "loading here" rather than a gap,
    // and so a letterboxed image sits on something rather than floating.
    let imgPlate = new inkRectangle();
    imgPlate.SetAnchor(inkEAnchor.Fill);
    imgPlate.SetTintColor(NCZDG_NavyColor());
    imgPlate.SetOpacity(0.85);
    imgPlate.Reparent(imgBox);

    let img = new inkImage();
    img.SetName(n"nczdg_thumb_img");
    img.SetAnchor(inkEAnchor.Centered);
    img.SetAnchorPoint(new Vector2(0.5, 0.5));
    img.SetSize(new Vector2(NCZDG_ImageWidth(), NCZDG_ImageHeight()));
    img.SetVisible(false);   // shown only once a real texture is bound
    img.Reparent(imgBox);

    // --- the no-image placeholder ----------------------------------------------------------
    // Two widgets, ICON PLUS TEXT, and the text is the load-bearing half. A texture part that
    // does not resolve renders nothing at all, silently - so an icon-only placeholder would be
    // indistinguishable from a blank card if the atlas part name were ever wrong. The caption
    // stands on its own.
    let phIcon = new inkImage();
    phIcon.SetName(n"ph_icon");
    phIcon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\atlas_common.inkatlas");
    phIcon.SetTexturePart(n"quest_file_failed");
    phIcon.SetSize(new Vector2(NCZDG_PhIconWidth(), NCZDG_PhIconHeight()));
    phIcon.SetAnchor(inkEAnchor.Centered);
    phIcon.SetAnchorPoint(new Vector2(0.5, 0.5));
    phIcon.SetMargin(new inkMargin(0.0, 0.0, 0.0, 45.0));   // lifted, to sit above the caption
    phIcon.SetStyle(NCZDG_StylePath());
    phIcon.BindProperty(n"tintColor", NCZDG_Gray());
    phIcon.SetOpacity(0.55);
    phIcon.Reparent(imgBox);

    // Night Corp's voice: official, faintly bureaucratic, never apologetic.
    let phText = this.MakeText(NCZDG_T("NCZDG.noImage"), NCZDG_Gray(), 26);
    phText.SetName(n"ph_text");
    phText.SetHAlign(inkEHorizontalAlign.Center);
    phText.SetVAlign(inkEVerticalAlign.Center);
    phText.SetAnchor(inkEAnchor.Centered);
    phText.SetAnchorPoint(new Vector2(0.5, 0.5));
    // Icon centred at -45 spans -100..+10; this caption centred at +40 spans +25..+55, leaving a
    // 15-unit gap between them.
    phText.SetMargin(new inkMargin(0.0, 40.0, 0.0, 0.0));
    phText.SetOpacity(0.7);
    phText.Reparent(imgBox);

    let imgProxy = new NCZDGGuideProxy();
    imgProxy.popup = this;
    imgProxy.index = NCZDG_IdxImageBase() + slotIdx;
    ArrayPush(this.m_proxies, imgProxy);
    imgBox.RegisterToCallback(n"OnRelease", imgProxy, n"OnRelease");

    // Text block, beneath the image. Offset by the image height, so the two never overlap
    // however the image turns out.
    let stack = new inkVerticalPanel();
    stack.SetChildOrder(inkEChildOrder.Forward);
    stack.SetFitToContent(true);
    stack.SetAnchor(inkEAnchor.TopLeft);
    stack.SetAnchorPoint(new Vector2(0.0, 0.0));
    stack.SetMargin(new inkMargin(NCZDG_TextInset(), NCZDG_ImageHeight() + 14.0,
                                  NCZDG_CardPadRight(), 0.0));
    stack.Reparent(card);

    let name = this.MakeText("", NCZDG_White(), 34);
    name.SetFontStyle(n"Semi-Bold");
    name.SetWrappingAtPosition(NCZDG_TextWidth());
    name.SetMargin(new inkMargin(0.0, 0.0, 0.0, 6.0));
    name.Reparent(stack);

    // Meta row: category + authors at the left, the recency badge at the right - one fixed-height
    // canvas, so the badge sits outside the vertical budget entirely and no description can ever
    // push it off the card (which is what happened when it lived at the bottom of the stack).
    // BindCard caps the meta string so it cannot reach the badge from the left.
    let metaRow = new inkCanvas();
    metaRow.SetSize(new Vector2(NCZDG_TextWidth(), 34.0));
    metaRow.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
    metaRow.Reparent(stack);

    let meta = this.MakeText("", NCZDG_Cyan(), 26);
    meta.SetLetterCase(textLetterCase.UpperCase);
    meta.SetVAlign(inkEVerticalAlign.Center);
    meta.SetAnchor(inkEAnchor.CenterLeft);
    meta.SetAnchorPoint(new Vector2(0.0, 0.5));
    meta.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    meta.Reparent(metaRow);

    // Green (the brand's Approval colour, unused elsewhere in the guide) so it reads apart from
    // the category-tinted meta line. Built once and hidden; BindCard toggles it per mod from the
    // core's server-computed RecentlyUpdated() - there is no in-game clock to derive it.
    let badge = this.MakeText(NCZDG_T("NCZDG.badgeRecent"), NCZDG_Green(), 22);
    badge.SetFontStyle(n"Semi-Bold");
    badge.SetLetterCase(textLetterCase.UpperCase);
    badge.SetHAlign(inkEHorizontalAlign.Right);
    badge.SetVAlign(inkEVerticalAlign.Center);
    badge.SetAnchor(inkEAnchor.CenterRight);
    badge.SetAnchorPoint(new Vector2(1.0, 0.5));
    badge.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    badge.SetVisible(false);
    badge.Reparent(metaRow);

    let desc = this.MakeText("", NCZDG_Gray(), 26);
    desc.SetWrappingAtPosition(NCZDG_TextWidth());
    desc.SetMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
    desc.Reparent(stack);

    let tags = this.MakeText("", NCZDG_Cyan(), 22);
    tags.SetOpacity(0.7);
    tags.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    tags.Reparent(stack);

    // The action strip. Built now, hidden until the card is hovered, so revealing it reflows
    // nothing and the card height never changes.
    //
    // The strip is a CANVAS with a card-coloured backing, not a bare panel: the buttons' cell_fg
    // frames have translucent interiors, so without the backing whatever the card drew underneath
    // (a long tags line) reads straight through the buttons. 464x46 is exactly the two buttons
    // plus their 12-unit lead-in margins.
    // In the reserved band at the card's bottom, BELOW the tags rather than over them. The band
    // is always there whether or not the strip is drawn in it, so revealing on hover moves
    // nothing and hides nothing.
    //
    // Two earlier placements, both rejected in play: on the image, which put a control panel
    // across the photograph; and sharing the tags' line with the tags hidden on hover, which
    // punished every card for a problem only long-titled ones had.
    //
    // NO SHARED BACKING PLATE. This canvas is transparent: each button carries its own fill,
    // because one rectangle spanning both of them - and the gap between them - reads as a slab
    // pasted onto the card, which is glaring over a bright image.
    let actionsBox = new inkCanvas();
    actionsBox.SetName(n"nczdg_actions");
    actionsBox.SetSize(new Vector2(404.0, 46.0));   // 2 * 190 + their 12 lead-in margins
    actionsBox.SetAnchor(inkEAnchor.BottomRight);
    actionsBox.SetAnchorPoint(new Vector2(1.0, 1.0));
    actionsBox.SetMargin(new inkMargin(0.0, 0.0, NCZDG_CardPadRight(), 14.0));
    actionsBox.SetVisible(false);
    actionsBox.Reparent(card);

    let actions = new inkHorizontalPanel();
    actions.SetChildOrder(inkEChildOrder.Forward);
    actions.SetFitToContent(true);
    actions.SetAnchor(inkEAnchor.TopLeft);
    actions.SetAnchorPoint(new Vector2(0.0, 0.0));
    actions.Reparent(actionsBox);

    // Both 190, sized to the LONGEST label each can ever show rather than to its initial one:
    // the first retitles between SET MARKER and CLEAR MARKER, the second between TELEPORT and
    // EXIT VEHICLE - 12 characters at 26px either way. 250 was sized to nothing in particular
    // and left the first button visibly emptier than the second.
    let wp = this.MakeSmallButton(actions, NCZDG_T("NCZDG.btnSetWaypoint"), NCZDG_IdxWaypointBase() + slotIdx, 190.0);
    let tp = this.MakeSmallButton(actions, NCZDG_T("NCZDG.btnTeleport"), NCZDG_IdxTeleportBase() + slotIdx, 190.0);

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = NCZDG_IdxCardBase() + slotIdx;
    ArrayPush(this.m_proxies, proxy);
    // Click kept alongside hover: harmless, and it still selects on input paths with no hover.
    card.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");
    card.RegisterToCallback(n"OnEnter", proxy, n"OnEnter");
    card.RegisterToCallback(n"OnLeave", proxy, n"OnLeave");

    let slot = new NCZDGCardSlot();
    slot.root = card;
    slot.accent = accent;
    slot.frame = frame;
    slot.name = name;
    slot.meta = meta;
    slot.desc = desc;
    slot.tags = tags;
    slot.badge = badge;
    slot.actions = actionsBox;
    slot.wpLabel = wp;
    slot.tpLabel = tp;
    slot.imgBox = imgBox;
    slot.image = img;
    slot.phIcon = phIcon;
    slot.phText = phText;
    slot.stack = stack;
    slot.metaRow = metaRow;
    slot.slotIdx = slotIdx;
    slot.installBar = installBar;
    return slot;
  }

  // Returns the LABEL, so the caller can retitle it (SET <-> CLEAR WAYPOINT) without a rebuild.
  private func MakeSmallButton(parent: wref<inkCompoundWidget>, label: String, index: Int32,
                               width: Float) -> ref<inkText> {
    let box = new inkCanvas();
    box.SetSize(new Vector2(width, 46.0));
    box.SetHAlign(inkEHorizontalAlign.Left);
    box.SetMargin(new inkMargin(12.0, 0.0, 0.0, 0.0));
    box.SetInteractive(true);
    box.Reparent(parent);

    // Each button carries its OWN fill, chamfered to match its own frame. The strip used to sit
    // on one shared rectangle spanning both buttons and the gap between them, which reads as a
    // slab laid over the card - and cell_fg's interior is translucent, so without any fill the
    // card's tags would read straight through the buttons instead.
    let bg = new inkImage();
    bg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    bg.SetTexturePart(n"cell_bg");
    bg.SetNineSliceScale(true);
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetTintColor(NCZDG_NavyColor());
    bg.SetOpacity(0.95);
    bg.Reparent(box);

    let frame = new inkImage();
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(NCZDG_CyanColor());   // interactive: tint directly, not via a style bind
    frame.SetOpacity(0.8);
    frame.Reparent(box);

    let txt = this.MakeText(label, NCZDG_Cyan(), 26);
    txt.SetLetterCase(textLetterCase.UpperCase);
    txt.SetHAlign(inkEHorizontalAlign.Center);
    txt.SetVAlign(inkEVerticalAlign.Center);
    txt.SetAnchor(inkEAnchor.Centered);
    txt.SetAnchorPoint(new Vector2(0.5, 0.5));
    txt.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    txt.Reparent(box);

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = index;
    proxy.hoverFrame = frame;
    proxy.restOpacity = 0.8;
    ArrayPush(this.m_proxies, proxy);
    box.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");
    box.RegisterToCallback(n"OnEnter", proxy, n"OnEnter");
    box.RegisterToCallback(n"OnLeave", proxy, n"OnLeave");
    return txt;
  }

  // Redscript has no closures, so a click needs a proxy object holding a back-reference and an
  // index. The widget does not own the proxy: keep it alive in m_proxies or the callback dies.
  //
  // A card knows its POOL SLOT, not its location: the slot maps to whatever is bound to it right
  // now, so filtering never touches a proxy.
  public func OnProxyClick(index: Int32) -> Void {
    // First, and unconditionally: while the lightbox is up it covers everything, so any click
    // that arrives is a click on it.
    if index == NCZDG_IdxCloseLightbox() {
      this.CloseLightbox();
      return;
    }
    if index == NCZDG_IdxCycleFilter() {
      this.CycleFilter();
      return;
    }
    if index == NCZDG_IdxClearWaypoint() {
      let actions = NCZDGWorldActions.Get(this.m_gi);
      if IsDefined(actions) {
        actions.ClearWaypoint(this.m_gi);
      }
      this.Refresh();
      return;
    }
    // One call, on purpose: Codeware's SetText fires the input's OnInput callback itself, so
    // OnSearchChanged handles the query, the X's visibility, the page reset, the scroll and the
    // refresh - clearing here too would do it all twice.
    if index == NCZDG_IdxClearSearch() {
      this.m_search.SetText("");
      return;
    }
    if index == NCZDG_IdxPrevPage() {
      if this.m_page > 0 {
        this.m_page -= 1;
        this.ScrollCardsToTop();
        this.Refresh();
      }
      return;
    }
    if index == NCZDG_IdxNextPage() {
      // Bounded, not just greyed. The button is taken out of the input path when disabled, but
      // a page number that can run past the end would survive a filter change that shrinks the
      // result set, and land the player on an empty page.
      let pages = (ArraySize(this.m_shown) + NCZDG_PageSize() - 1) / NCZDG_PageSize();
      if this.m_page + 1 < pages {
        this.m_page += 1;
        this.ScrollCardsToTop();
        this.Refresh();
      }
      return;
    }
    // MUST precede the teleport arm. This chain tests `index >= base` in descending order, so
    // an image index reaching the >= 3000 test first would fire a teleport instead.
    if index >= NCZDG_IdxImageBase() {
      this.OpenLightbox(index - NCZDG_IdxImageBase());
      return;
    }
    if index >= NCZDG_IdxTeleportBase() {
      this.DoTeleport(index - NCZDG_IdxTeleportBase());
      return;
    }
    if index >= NCZDG_IdxWaypointBase() {
      this.DoWaypoint(index - NCZDG_IdxWaypointBase());
      return;
    }
    if index >= NCZDG_IdxCardBase() {
      this.SelectCard(index - NCZDG_IdxCardBase());
      return;
    }
    this.SelectArea(index);
  }

  // Hover drives the action strip: entering a card reveals its buttons, leaving hides them. Only
  // card indices react - the nav rows and buttons register no hover callbacks, but the range check
  // keeps this honest anyway. On a card-to-card move the events can land in either order: OnEnter
  // first is fine (the OnLeave that follows fails the m_selCard guard), OnLeave first is fine too.
  public func OnProxyHover(index: Int32, entered: Bool) -> Void {
    if index < NCZDG_IdxCardBase() || index >= NCZDG_IdxWaypointBase() {
      return;
    }
    let slotIdx = index - NCZDG_IdxCardBase();
    if entered {
      this.SelectCard(slotIdx);
    } else {
      if this.m_selCard == slotIdx {
        this.SelectCard(-1);
      }
    }
  }

  private func DoWaypoint(slotIdx: Int32) -> Void {
    let loc = this.LocForSlot(slotIdx);
    let actions = NCZDGWorldActions.Get(this.m_gi);
    if !IsDefined(loc) || !IsDefined(actions) {
      return;
    }
    if actions.IsPinned(loc.Id()) {
      actions.ClearWaypoint(this.m_gi);
    } else {
      actions.SetWaypoint(this.m_gi, loc.Pos(), loc.Id(), loc.Name());
    }
    // Re-bind so every card's button reflects the one pin the game allows.
    this.Refresh();
    this.SelectCard(slotIdx);
  }

  // Close FIRST, teleport after. The popup holds ModalPopup and pins time dilation at ~1e-6, and a
  // long-distance teleport triggers streaming; vanilla's own map DEBUG_Teleport closes the menu
  // immediately after teleporting for the same reason.
  private func DoTeleport(slotIdx: Int32) -> Void {
    let loc = this.LocForSlot(slotIdx);
    if !IsDefined(loc) {
      return;
    }
    if !NCZDG_CanTeleport(this.m_gi) {
      NCZDGLog("guide: teleport refused - mounted to a vehicle");
      return;
    }
    let cb = new NCZDGTeleportCallback();
    cb.gi = this.m_gi;
    cb.pos = loc.Pos();
    cb.yaw = loc.Yaw();
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(cb, 0.15);
    this.Close();
  }

  // A scrolling column: an inkScrollArea holding a fit-to-content vertical panel, plus a slider
  // bar. inkScrollArea alone does not scroll - it needs an inkScrollController attached to the
  // OUTER box, with the area and the bar wired into it. Codeware supplies inkScrollAreaRef.Create
  // and AttachController; neither exists in vanilla RTTI.
  //
  // Returns the inner panel. Reparent rows into that, never into the scroll area itself.
  private func MakeScrollColumn(parent: wref<inkCompoundWidget>, x: Float, y: Float,
                                width: Float, height: Float,
                                isNav: Bool) -> ref<inkVerticalPanel> {
    let barW: Float = 12.0;
    let viewW: Float = width - NCZDG_ScrollBarStrip();

    let box = new inkCanvas();
    box.SetSize(new Vector2(width, height));
    box.SetAnchor(inkEAnchor.TopLeft);
    box.SetAnchorPoint(new Vector2(0.0, 0.0));
    box.SetMargin(new inkMargin(x, y, 0.0, 0.0));
    box.Reparent(parent);

    let area = new inkScrollArea();
    area.SetSize(new Vector2(viewW, height));
    area.SetAnchor(inkEAnchor.TopLeft);
    area.SetAnchorPoint(new Vector2(0.0, 0.0));
    area.SetFitToContentDirection(inkFitToContentDirection.Horizontal);
    area.SetInteractive(true);
    area.Reparent(box);

    let col = new inkVerticalPanel();
    col.SetChildOrder(inkEChildOrder.Forward);
    col.SetFitToContent(true);
    col.SetAnchor(inkEAnchor.TopLeft);
    col.SetAnchorPoint(new Vector2(0.0, 0.0));
    col.Reparent(area);

    let barArea = new inkCanvas();
    barArea.SetSize(new Vector2(barW, height));
    barArea.SetAnchor(inkEAnchor.TopRight);
    barArea.SetAnchorPoint(new Vector2(1.0, 0.0));

    // Tinted DIRECTLY, not through a style bind. The handle is interactive, so it gets widget
    // states, and a state overrides a bound tintColor while leaving SetTintColor alone - which is
    // what left the handle red at rest and cyan only on hover.
    let track = new inkRectangle();
    track.SetAnchor(inkEAnchor.Fill);
    track.SetTintColor(NCZDG_CyanColor());
    track.SetOpacity(0.12);
    track.Reparent(barArea);

    let handle = new inkRectangle();
    handle.SetAnchor(inkEAnchor.TopFillHorizontaly);
    handle.SetSize(new Vector2(barW, 60.0));
    handle.SetInteractive(true);
    handle.SetTintColor(NCZDG_CyanColor());
    handle.SetOpacity(0.8);
    handle.Reparent(barArea);
    barArea.Reparent(box);

    let slider = new inkSliderController();
    slider.slidingAreaRef = inkWidgetRef.Create(barArea);
    slider.handleRef = inkWidgetRef.Create(handle);
    slider.direction = inkESliderDirection.Vertical;
    slider.autoSizeHandle = true;
    slider.percentHandleSize = 0.4;
    slider.minHandleSize = 50.0;
    slider.Setup(0.0, 1.0, 0.0);
    barArea.AttachController(slider);

    let scroll = new inkScrollController();
    scroll.ScrollArea = inkScrollAreaRef.Create(area);
    scroll.VerticalScrollBarRef = inkWidgetRef.Create(barArea);
    scroll.autoHideVertical = true;
    box.AttachController(scroll);

    if isNav {
      this.m_navScroll = scroll;
    } else {
      this.m_cardScroll = scroll;
    }
    return col;
  }

  private func MakeText(label: String, colour: CName, size: Int32) -> ref<inkText> {
    let t = new inkText();
    t.SetText(label);
    t.SetFontFamily(NCZDG_Font());   // raj IS Rajdhani, the brand's body face
    t.SetFontStyle(n"Medium");
    t.SetFontSize(size);
    t.SetStyle(NCZDG_StylePath());
    t.BindProperty(n"tintColor", colour);
    t.SetHAlign(inkEHorizontalAlign.Left);
    t.SetMargin(new inkMargin(0.0, 0.0, 0.0, 24.0));
    return t;
  }

  private func MakeButton(parent: wref<inkCompoundWidget>, label: String, index: Int32) -> ref<inkCanvas> {
    let box = new inkCanvas();
    box.SetName(n"nczdg_btn");
    box.SetSize(new Vector2(180.0, 52.0));
    box.SetHAlign(inkEHorizontalAlign.Left);   // or the panel fills it to the frame edge
    box.SetVAlign(inkEVerticalAlign.Top);
    box.SetMargin(new inkMargin(16.0, 0.0, 0.0, 0.0));
    box.SetInteractive(true);
    box.Reparent(parent);

    let frame = new inkImage();
    frame.SetName(n"frame");   // findable, so a hide site can reset a hover the widget never left
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetTintColor(NCZDG_CyanColor());   // interactive: tint directly, not via a style bind
    frame.Reparent(box);

    let txt = this.MakeText(label, NCZDG_Cyan(), 34);
    txt.SetName(n"label");   // findable, so SetButtonEnabled can grey it without a rebuild
    txt.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    txt.SetHAlign(inkEHorizontalAlign.Center);
    txt.SetVAlign(inkEVerticalAlign.Center);
    txt.SetAnchor(inkEAnchor.Centered);
    txt.SetAnchorPoint(new Vector2(0.5, 0.5));
    txt.Reparent(box);

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = index;
    proxy.hoverFrame = frame;
    proxy.restOpacity = 1.0;
    ArrayPush(this.m_proxies, proxy);   // the widget does not keep the proxy alive
    box.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");
    box.RegisterToCallback(n"OnEnter", proxy, n"OnEnter");
    box.RegisterToCallback(n"OnLeave", proxy, n"OnLeave");
    return box;
  }
}

// The widgets of one pooled card. Held so a re-bind is a handful of SetText calls, with no
// allocation and no proxy churn.
@if(ModuleExists("NCZoning.Api"))
// Drives the image poll. A DelayCallback rather than an onUpdate: the chain re-arms itself only
// while something is still in flight, so an idle guide costs nothing.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGImagePollCB extends DelayCallback {
  // WEAK: the popup must be free to be destroyed while a tick is pending, and a strong ref here
  // would keep the whole widget tree alive past its own teardown.
  public let popup: wref<NCZDGGuidePopup>;

  public func Call() -> Void {
    if IsDefined(this.popup) {
      this.popup.OnImagePoll();
    }
  }
}

public class NCZDGCardSlot {
  public let root: wref<inkCanvas>;
  public let accent: wref<inkRectangle>;
  public let frame: wref<inkImage>;
  public let name: wref<inkText>;
  public let meta: wref<inkText>;
  public let desc: wref<inkText>;
  public let tags: wref<inkText>;
  public let badge: wref<inkText>;       // "RECENTLY UPDATED"; shown per the core's recency bool
  // The action strip is always BUILT, only hidden, so revealing it reflows nothing. The canvas
  // carries a card-coloured backing so card text cannot read through the buttons.
  public let actions: wref<inkCanvas>;
  public let wpLabel: wref<inkText>;     // SET WAYPOINT <-> CLEAR WAYPOINT
  public let tpLabel: wref<inkText>;     // greys out in a vehicle

  // Thumbnail. The box is always built and only toggled, like the action strip; the image
  // inside it stays hidden until a real texture is bound, so a failed fetch shows the plate
  // rather than a stretched placeholder.
  public let imgBox: wref<inkCanvas>;
  public let image: wref<inkImage>;
  public let stack: wref<inkVerticalPanel>;
  public let metaRow: wref<inkCanvas>;
  // The no-image placeholder: icon plus caption. Shown together, hidden together. The caption
  // carries the meaning on its own, because an atlas part that fails to resolve draws nothing
  // and says nothing about why.
  public let phIcon: wref<inkImage>;
  public let phText: wref<inkText>;
  // The full-size image for this card's location, for the lightbox. Empty means the card is
  // not clickable - the click handler checks this rather than trusting the box's visibility.
  public let picUrl: String;
  // This slot's own index, so a pending fetch can be matched back to the card that wanted it
  // and dropped when a page turn rebinds the slot to a different location.
  public let slotIdx: Int32;
  // Install state, as a bar beside the category accent. Hidden for Unknown - no bar means no
  // information, which is exactly what Unknown asserts.
  public let installBar: wref<inkRectangle>;
}

@if(ModuleExists("NCZoning.Api"))
public class NCZDGGuideProxy extends IScriptable {
  public let popup: wref<NCZDGGuidePopup>;
  public let index: Int32;
  // A button frame to brighten on hover, plus its rest opacity to restore. Cards leave these
  // unset: their hover feedback (frame + action strip) is the popup's job, via OnProxyHover.
  public let hoverFrame: wref<inkImage>;
  public let restOpacity: Float;

  protected cb func OnRelease(e: ref<inkPointerEvent>) -> Bool {
    if e.IsAction(n"click") && IsDefined(this.popup) {
      this.popup.OnProxyClick(this.index);
    }
    return true;
  }

  // Registered on the cards and the buttons (base-game pairing, e.g. sliderController's
  // OnEnter/OnLeave). Buttons brighten their own frame here; cards defer to the popup.
  protected cb func OnEnter(e: ref<inkPointerEvent>) -> Bool {
    if IsDefined(this.hoverFrame) {
      this.hoverFrame.SetTintColor(NCZDG_TextColor());   // Archival White, matching hovered chrome
      this.hoverFrame.SetOpacity(1.0);
    }
    if IsDefined(this.popup) {
      this.popup.OnProxyHover(this.index, true);
    }
    return true;
  }

  protected cb func OnLeave(e: ref<inkPointerEvent>) -> Bool {
    if IsDefined(this.hoverFrame) {
      this.hoverFrame.SetTintColor(NCZDG_CyanColor());
      this.hoverFrame.SetOpacity(this.restOpacity);
    }
    if IsDefined(this.popup) {
      this.popup.OnProxyHover(this.index, false);
    }
    return true;
  }
}
