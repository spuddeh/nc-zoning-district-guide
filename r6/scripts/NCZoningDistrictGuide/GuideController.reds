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
public func NCZDG_PopupHeight() -> Float { return 1600.0; }

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
public func NCZDG_TopStripHeight() -> Float { return 150.0; }
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

public func NCZDG_CardWidth() -> Float {
  return (NCZDG_CardsWidth() - NCZDG_ScrollBarStrip() - NCZDG_CardGap()) / 2.0;
}

// 240 is a budget with no slack for a bottom badge: name + meta + two desc lines + tags fills it,
// and ink can neither clip an overflow nor cap a wrapped text's line count. That is why the
// RECENTLY UPDATED badge lives ON the meta row (a fixed-height canvas, out of the vertical
// budget), and why BindCard hard-truncates the description to ~2 lines. Do not fix an overflow by
// raising this: a taller card reads as empty next to the short one-line descriptions, which are
// the common case.
public func NCZDG_CardHeight() -> Float { return 240.0; }

// The card POOL is built once and re-bound; cards are never created or destroyed while the popup
// lives. 295 cards would be ~3000 widgets in one scroll area, and ink does not cull offscreen
// children - every one is laid out and submitted every frame. So: a fixed pool, and pages.
public func NCZDG_PageSize() -> Int32 { return 30; }
public func NCZDG_CardsPerRow() -> Int32 { return 2; }

// Proxy index ranges. One click sink, routed by range, because redscript has no closures.
// --- card thumbnail -----------------------------------------------------------------------
// 16:9, because the registry's images are Nexus screenshots. The image is scaled to fit
// INSIDE this box preserving its own aspect, so a differently-shaped image letterboxes
// rather than overflowing - ink cannot clip a child, so an oversized image would draw over
// the card's text.
public func NCZDG_ThumbWidth() -> Float { return 240.0; }
public func NCZDG_ThumbHeight() -> Float { return 135.0; }
public func NCZDG_ThumbGap() -> Float { return 20.0; }
public func NCZDG_ThumbInset() -> Float { return 28.0; }

// How far the text column starts from the card's left edge, with and without a thumbnail.
// A card whose location has no image reclaims the space rather than showing an empty box.
public func NCZDG_TextInset() -> Float { return 28.0; }
public func NCZDG_TextInsetThumb() -> Float {
  return NCZDG_ThumbInset() + NCZDG_ThumbWidth() + NCZDG_ThumbGap();
}

// Text wrap width for each of the two layouts. 60 is the existing right-hand allowance.
public func NCZDG_TextWidth() -> Float { return NCZDG_CardWidth() - 60.0; }
public func NCZDG_TextWidthThumb() -> Float {
  return NCZDG_CardWidth() - 60.0 - NCZDG_ThumbWidth() - NCZDG_ThumbGap();
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
      NCZDGLog("guide: disabled in settings");
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
    NCZDGLog(s"guide: open requested (popup=\(IsDefined(this.m_popup)))");
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
    NCZDGLog("guide: popup detached (ESC, right-click, CLOSE, or the queue)");
    super.OnDetach();   // must chain: this is what un-pauses and pops the game context
  }

  protected cb func OnCreate() -> Void {
    super.OnCreate();
    this.m_selected = -1;
    this.m_selCard = -1;

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

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetTitle("NC ZONING BOARD");
    // Both fluff slots default to an unresolved LocKey (TRN_TCLAS_*), which renders as raw key text.
    // The voice is Night Corp: official, authoritative, slightly sterile.
    this.m_header.SetFluffLeft("NIGHT CORP // URBAN PLANNING DIVISION");
    this.m_header.SetFluffRight("NC-ZB-01");
    this.m_header.Reparent(this);

    this.m_footer = InGamePopupFooter.Create();
    this.m_footer.SetFluffText("NC ZONING BOARD");
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
    this.m_search.SetDefaultText("SEARCH NAME, AUTHOR, TAG");
    this.m_search.Reparent(body);
    this.m_search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");

    let searchRoot = this.m_search.GetRootWidget();
    searchRoot.SetAnchor(inkEAnchor.TopLeft);
    searchRoot.SetAnchorPoint(new Vector2(0.0, 0.0));
    searchRoot.SetHAlign(inkEHorizontalAlign.Left);
    NCZDG_RebrandInput(searchRoot);

    // Clear-search, beside the input, styled like the pager buttons. Bespoke rather than
    // MakeButton because it needs an absolute spot in the top strip, and that helper flows its
    // box from the parent's layout. 52 high inside the input's 80, so top 14 centres it. Hidden
    // until there is a query.
    let clearBox = new inkCanvas();
    clearBox.SetName(n"nczdg_search_clear");
    clearBox.SetSize(new Vector2(160.0, 52.0));
    clearBox.SetAnchor(inkEAnchor.TopLeft);
    clearBox.SetAnchorPoint(new Vector2(0.0, 0.0));
    clearBox.SetMargin(new inkMargin(NCZDG_NavWidth() + 16.0, 14.0, 0.0, 0.0));
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

    let clearTxt = this.MakeText("CLEAR", NCZDG_Cyan(), 34);
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

    let count = this.MakeText("", NCZDG_Gray(), 32);
    count.SetName(n"nczdg_count");
    count.SetAnchor(inkEAnchor.TopRight);
    count.SetAnchorPoint(new Vector2(1.0, 0.0));
    count.SetHAlign(inkEHorizontalAlign.Right);
    count.SetHorizontalAlignment(textHorizontalAlignment.Right);
    count.SetMargin(new inkMargin(0.0, 20.0, 0.0, 0.0));
    count.Reparent(body);
    this.m_status = count;

    // Paging. The card column scrolls, but a pool of 30 cannot show 295 locations, so ALL needs a
    // way through. Sits under the count, right-aligned with it.
    let pager = new inkHorizontalPanel();
    pager.SetName(n"nczdg_pager");
    pager.SetChildOrder(inkEChildOrder.Forward);
    pager.SetFitToContent(true);
    pager.SetAnchor(inkEAnchor.TopRight);
    pager.SetAnchorPoint(new Vector2(1.0, 0.0));
    pager.SetHAlign(inkEHorizontalAlign.Right);
    pager.SetMargin(new inkMargin(0.0, 68.0, 0.0, 0.0));
    pager.Reparent(body);
    // Clearing the pin must not require finding the card it came from - the player may have
    // searched or paged away from it, and a pin they cannot see is a pin they cannot remove.
    this.m_clearWp = this.MakeButton(pager, "CLEAR MARKER", NCZDG_IdxClearWaypoint());
    this.m_clearWp.SetVisible(false);
    this.m_clearWp.SetSize(new Vector2(280.0, 52.0));
    this.MakeButton(pager, "< PREV", NCZDG_IdxPrevPage());
    this.MakeButton(pager, "NEXT >", NCZDG_IdxNextPage());

    // --- body: districts | cards ----------------------------------------------------------
    this.m_navCol = this.MakeScrollColumn(body, 0.0, NCZDG_TopStripHeight(),
                                          NCZDG_NavWidth(), NCZDG_BodyHeight(), true);

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

    NCZDGLog(s"guide: usable \(NCZDG_UsableWidth())x\(NCZDG_UsableHeight()), nav \(NCZDG_NavWidth()), cards \(NCZDG_CardsWidth()), card \(NCZDG_CardWidth())");

    this.BuildCardPool();
    this.BuildNav();
    // LAST, and onto the popup's own root widget rather than the body: ink draws in child order
    // with no z-index, so this is the only way the overlay covers the header and footer too.
    // Note `this` is an inkCustomController, NOT a widget - reach the widget explicitly.
    this.BuildLightbox(this.GetRootCompoundWidget());
    NCZDGLog("guide: popup created");
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
    NCZDGLog(s"guide: nav built - \(n) areas, \(this.m_model.Total()) locations");

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
      let recent = this.MakeText(s"\(area.recentCount) RECENT", NCZDG_Green(), 22);
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
      // A slot's identity changes under a filter or a page turn, so the selection cannot survive it.
      this.m_cards[slot].actions.SetVisible(false);
      this.m_cards[slot].frame.SetOpacity(0.35);
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
      counts = s"\(n) OF \(area.count) IN \(area.Label())";
    } else {
      if n > NCZDG_PageSize() {
        counts = s"\(shownFrom)-\(shownTo) OF \(n) IN \(area.Label())";
      } else {
        counts = s"\(n) IN \(area.Label())";
      }
    }
    if marked && !routing {
      counts += "   ·   FOR DIRECTIONS: OPEN THE WORLD MAP, HOVER THE NC MARKER, TRACK WAYPOINT";
    }
    this.m_status.SetText(counts);
    NCZDGLog(s"guide: '\(area.Label())' q='\(this.m_query)' -> \(n) results, page \(this.m_page + 1)/\(pages)");
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
    this.SetCardLayout(slot, hasImage);
    slot.picUrl = hasImage ? loc.PictureUrl() : "";
    if hasImage {
      this.QueueImage(thumbUrl, slot.image, NCZDG_ThumbWidth(), NCZDG_ThumbHeight(), slot.slotIdx);
    }

    slot.name.SetText(loc.Name());

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
    let cap = IsDefined(slot.imgBox) && slot.imgBox.IsVisible() ? NCZDG_DescCapThumb() : NCZDG_DescCap();
    let d = loc.Description();
    slot.desc.SetText(StrLen(d) > cap ? StrLeft(d, cap - 3) + "..." : d);

    // Capped by count AND length: the tags line does not wrap, so an unbounded run of long tags
    // walks off the card's right edge.
    let tags = "";
    let t = 0;
    while t < loc.TagCount() && t < 5 && StrLen(tags) < 60 {
      tags += (t > 0 ? "  " : "") + "#" + loc.TagAt(t);
      t += 1;
    }
    slot.tags.SetText(tags);

    // Server-computed recency: the guide cannot derive "updated within N days" (no in-game clock),
    // so it shows what the API decided.
    slot.badge.SetVisible(loc.RecentlyUpdated());

    // The waypoint button reflects the CURRENT pin, so it is right on every re-bind.
    let actions = NCZDGWorldActions.Get(this.m_gi);
    // A button says what CLICKING it does, and nothing else. Routing state is not an action - no
    // script can track a mappin, only the player can, from the map - so it belongs in a hint, not on
    // a control that does something different from what it reads.
    let pinned = IsDefined(actions) && actions.IsPinned(loc.Id());
    slot.wpLabel.SetText(pinned ? "CLEAR MARKER" : "SET MARKER");
    slot.wpLabel.BindProperty(n"tintColor", NCZDG_Cyan());

    let canTp = NCZDG_CanTeleport(this.m_gi);
    slot.tpLabel.SetText(canTp ? "TELEPORT" : "EXIT VEHICLE");
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

    // The scrim is what swallows the click, so it must fill the overlay and be interactive.
    let scrim = new inkRectangle();
    scrim.SetAnchor(inkEAnchor.Fill);
    scrim.SetTintColor(NCZDG_CardBgColor());
    scrim.SetOpacity(0.96);
    scrim.Reparent(box);

    let img = new inkImage();
    img.SetName(n"nczdg_lightbox_img");
    img.SetAnchor(inkEAnchor.Centered);
    img.SetAnchorPoint(new Vector2(0.5, 0.5));
    img.SetVisible(false);
    img.Reparent(box);

    let caption = this.MakeText("LOADING...", NCZDG_Cyan(), 30);
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
    this.m_lightboxCaption.SetText("LOADING...   -   CLICK ANYWHERE TO CLOSE");
    this.m_lightbox.SetVisible(true);
    // The full-size picture is a SECOND fetch - the card holds the thumbnail. slotIdx -1 keeps
    // it out of the per-slot replacement logic, which is about cards and not about this.
    this.QueueImage(url, this.m_lightboxImg,
                    NCZDG_PopupWidth() - 320.0, NCZDG_PopupHeight() - 320.0, -1);
    NCZDGLog(s"images: lightbox opened for \(url)");
  }

  public func CloseLightbox() -> Void {
    if IsDefined(this.m_lightbox) {
      this.m_lightbox.SetVisible(false);
    }
  }

  // The card has exactly two layouts, and this is the only place that switches between them.
  // Every width the card uses is derived from the mode, so the two can never disagree.
  private func SetCardLayout(slot: ref<NCZDGCardSlot>, withThumb: Bool) -> Void {
    if !IsDefined(slot.imgBox) || !IsDefined(slot.stack) {
      return;
    }
    slot.imgBox.SetVisible(withThumb);
    // Hide the image itself too: the box is shown immediately but the texture is not bound
    // until the fetch lands, and a stale texture from the slot's previous location would
    // otherwise sit there under a different card's name until the new one arrived.
    if IsDefined(slot.image) {
      slot.image.SetVisible(false);
    }
    let inset = withThumb ? NCZDG_TextInsetThumb() : NCZDG_TextInset();
    let width = withThumb ? NCZDG_TextWidthThumb() : NCZDG_TextWidth();
    slot.stack.SetMargin(new inkMargin(inset, 18.0, 20.0, 0.0));
    slot.name.SetWrappingAtPosition(width);
    slot.desc.SetWrappingAtPosition(width);
    // The meta row is a fixed-size canvas, not a flow child, so it does not inherit the
    // stack's narrowing - resize it or the right-aligned RECENTLY UPDATED badge keeps
    // anchoring to the old, wider edge and drifts off the card.
    if IsDefined(slot.metaRow) {
      slot.metaRow.SetSize(new Vector2(width - 12.0, 34.0));
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
            NCZDGLog(s"images: gave up on \(p.url)");
            if p.slotIdx < 0 && IsDefined(this.m_lightboxCaption) {
              this.m_lightboxCaption.SetText("IMAGE UNAVAILABLE   -   CLICK ANYWHERE TO CLOSE");
            }
            // A card whose image will never arrive returns to the full-width layout rather than
            // keeping a permanently empty box. This is the one case that reflows a live card.
            if p.slotIdx >= 0 && p.slotIdx < ArraySize(this.m_cards) {
              this.SetCardLayout(this.m_cards[p.slotIdx], false);
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
      this.m_lightboxCaption.SetText("CLICK ANYWHERE TO CLOSE");
    }
  }

  // Selecting a card (hover, or a click) reveals its actions and hides the previous one's. Nothing
  // reflows: the strip is always built, only toggled.
  private func SelectCard(slotIdx: Int32) -> Void {
    if this.m_selCard >= 0 && this.m_selCard < ArraySize(this.m_cards) {
      this.m_cards[this.m_selCard].actions.SetVisible(false);
      this.m_cards[this.m_selCard].frame.SetOpacity(0.35);
    }
    if slotIdx < 0 || slotIdx >= ArraySize(this.m_cards) {
      this.m_selCard = -1;
      return;
    }
    this.m_selCard = slotIdx;
    this.m_cards[slotIdx].actions.SetVisible(true);
    this.m_cards[slotIdx].frame.SetOpacity(1.0);
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
    NCZDGLog(s"guide: card pool built - \(ArraySize(this.m_cards)) slots in \(rows) rows");
  }

  private func MakeCard(parent: wref<inkCompoundWidget>, slotIdx: Int32, gapLeft: Bool) -> ref<NCZDGCardSlot> {
    let card = new inkCanvas();
    card.SetName(n"nczdg_card");
    card.SetSize(new Vector2(NCZDG_CardWidth(), NCZDG_CardHeight()));
    card.SetInteractive(true);
    card.SetMargin(new inkMargin(gapLeft ? NCZDG_CardGap() : 0.0, 0.0, 0.0, 0.0));
    card.Reparent(parent);

    // Corporate Navy surface, at the same 0.95 the site uses so the world stays faintly visible.
    let bg = new inkRectangle();
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

    // The thumbnail box, built once and toggled per bind. Vertically centred against the
    // card so it reads level with the text block whatever the image's aspect turns out to be.
    // Interactive: clicking it opens the full-size picture in the lightbox.
    let imgBox = new inkCanvas();
    imgBox.SetName(n"nczdg_thumb");
    imgBox.SetSize(new Vector2(NCZDG_ThumbWidth(), NCZDG_ThumbHeight()));
    imgBox.SetAnchor(inkEAnchor.CenterLeft);
    imgBox.SetAnchorPoint(new Vector2(0.0, 0.5));
    imgBox.SetMargin(new inkMargin(NCZDG_ThumbInset(), 0.0, 0.0, 0.0));
    imgBox.SetInteractive(true);
    imgBox.SetVisible(false);
    imgBox.Reparent(card);

    // A dim plate behind the image, so a slow fetch reads as "loading here" rather than as a
    // gap, and so a letterboxed image sits on something rather than floating.
    let imgPlate = new inkRectangle();
    imgPlate.SetAnchor(inkEAnchor.Fill);
    imgPlate.SetTintColor(NCZDG_CardBgColor());
    imgPlate.SetOpacity(0.6);
    imgPlate.Reparent(imgBox);

    let img = new inkImage();
    img.SetName(n"nczdg_thumb_img");
    img.SetAnchor(inkEAnchor.Centered);
    img.SetAnchorPoint(new Vector2(0.5, 0.5));
    img.SetSize(new Vector2(NCZDG_ThumbWidth(), NCZDG_ThumbHeight()));
    img.SetVisible(false);   // shown only once a real texture is bound
    img.Reparent(imgBox);

    let imgProxy = new NCZDGGuideProxy();
    imgProxy.popup = this;
    imgProxy.index = NCZDG_IdxImageBase() + slotIdx;
    ArrayPush(this.m_proxies, imgProxy);
    imgBox.RegisterToCallback(n"OnRelease", imgProxy, n"OnRelease");

    let stack = new inkVerticalPanel();
    stack.SetChildOrder(inkEChildOrder.Forward);
    stack.SetFitToContent(true);
    stack.SetAnchor(inkEAnchor.TopLeft);
    stack.SetAnchorPoint(new Vector2(0.0, 0.0));
    stack.SetMargin(new inkMargin(NCZDG_TextInset(), 18.0, 20.0, 0.0));
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
    metaRow.SetSize(new Vector2(NCZDG_CardWidth() - 48.0, 34.0));
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
    let badge = this.MakeText("RECENTLY UPDATED", NCZDG_Green(), 22);
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
    let actionsBox = new inkCanvas();
    actionsBox.SetName(n"nczdg_actions");
    actionsBox.SetSize(new Vector2(464.0, 46.0));
    actionsBox.SetAnchor(inkEAnchor.BottomRight);
    actionsBox.SetAnchorPoint(new Vector2(1.0, 1.0));
    actionsBox.SetMargin(new inkMargin(0.0, 0.0, 20.0, 14.0));
    actionsBox.SetVisible(false);
    actionsBox.Reparent(card);

    let actionsBg = new inkRectangle();
    actionsBg.SetAnchor(inkEAnchor.Fill);
    actionsBg.SetTintColor(NCZDG_CardBgColor());   // interactive context: tint directly, like the card bg
    actionsBg.SetOpacity(1.0);
    actionsBg.Reparent(actionsBox);

    let actions = new inkHorizontalPanel();
    actions.SetChildOrder(inkEChildOrder.Forward);
    actions.SetFitToContent(true);
    actions.SetAnchor(inkEAnchor.TopLeft);
    actions.SetAnchorPoint(new Vector2(0.0, 0.0));
    actions.Reparent(actionsBox);

    let wp = this.MakeSmallButton(actions, "SET WAYPOINT", NCZDG_IdxWaypointBase() + slotIdx, 250.0);
    let tp = this.MakeSmallButton(actions, "TELEPORT", NCZDG_IdxTeleportBase() + slotIdx, 190.0);

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
    slot.stack = stack;
    slot.metaRow = metaRow;
    slot.slotIdx = slotIdx;
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
      this.m_page += 1;
      this.ScrollCardsToTop();
      this.Refresh();
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
  // Held so BindCard can re-inset the text between the two layouts.
  public let stack: wref<inkVerticalPanel>;
  public let metaRow: wref<inkCanvas>;
  // The full-size image for this card's location, for the lightbox. Empty means the card is
  // not clickable - the click handler checks this rather than trusting the box's visibility.
  public let picUrl: String;
  // This slot's own index, so a pending fetch can be matched back to the card that wanted it
  // and dropped when a page turn rebinds the slot to a different location.
  public let slotIdx: Int32;
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
