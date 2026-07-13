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

public func NCZDG_CardHeight() -> Float { return 240.0; }

// The card POOL is built once and re-bound; cards are never created or destroyed while the popup
// lives. 295 cards would be ~3000 widgets in one scroll area, and ink does not cull offscreen
// children - every one is laid out and submitted every frame. So: a fixed pool, and pages.
public func NCZDG_PageSize() -> Int32 { return 30; }
public func NCZDG_CardsPerRow() -> Int32 { return 2; }

// Proxy index ranges. One click sink, routed by range, because redscript has no closures.
public func NCZDG_IdxCardBase() -> Int32 { return 1000; }
public func NCZDG_IdxWaypointBase() -> Int32 { return 2000; }
public func NCZDG_IdxTeleportBase() -> Int32 { return 3000; }
public func NCZDG_IdxPrevPage() -> Int32 { return -2; }
public func NCZDG_IdxNextPage() -> Int32 { return -3; }
public func NCZDG_IdxClearWaypoint() -> Int32 { return -4; }

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
  private let m_status: wref<inkText>;
  private let m_proxies: array<ref<NCZDGGuideProxy>>;

  private let m_navCol: wref<inkVerticalPanel>;    // district rows go here
  private let m_cardCol: wref<inkVerticalPanel>;   // card ROWS go here (2 cards per row)
  private let m_navScroll: ref<inkScrollController>;
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
    this.m_clearWp = this.MakeButton(pager, "CLEAR WAYPOINT", NCZDG_IdxClearWaypoint());
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
    NCZDGLog("guide: popup created");
  }

  // Every keystroke re-queries and re-binds the pool. No debounce is needed: nothing is allocated,
  // 295 string compares are trivial, and the game is paused anyway.
  protected cb func OnSearchChanged(widget: ref<inkWidget>) -> Bool {
    this.m_query = this.m_search.GetText();
    this.m_page = 0;
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
    this.Refresh();
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
    if IsDefined(this.m_clearWp) {
      this.m_clearWp.SetVisible(IsDefined(actions) && actions.HasPin());
    }

    let shownFrom = n > 0 ? start + 1 : 0;
    let shownTo = start + NCZDG_PageSize() < n ? start + NCZDG_PageSize() : n;
    if StrLen(this.m_query) > 0 {
      this.m_status.SetText(s"\(n) OF \(area.count) IN \(area.Label())");
    } else {
      if n > NCZDG_PageSize() {
        this.m_status.SetText(s"\(shownFrom)-\(shownTo) OF \(n) IN \(area.Label())");
      } else {
        this.m_status.SetText(s"\(n) IN \(area.Label())");
      }
    }
    NCZDGLog(s"guide: '\(area.Label())' q='\(this.m_query)' -> \(n) results, page \(this.m_page + 1)/\(pages)");
  }

  private func BindCard(slot: ref<NCZDGCardSlot>, loc: ref<NCZLocation>) -> Void {
    slot.name.SetText(loc.Name());

    let authors = "";
    let a = 0;
    while a < loc.AuthorCount() {
      authors += (a > 0 ? ", " : "") + loc.AuthorAt(a);
      a += 1;
    }
    let cat = NCZDG_CategoryLabel(loc.Category());
    slot.meta.SetText(StrLen(authors) > 0 ? s"\(cat)  -  \(authors)" : cat);
    slot.meta.BindProperty(n"tintColor", NCZDG_CategoryColor(loc.Category()));
    slot.accent.BindProperty(n"tintColor", NCZDG_CategoryColor(loc.Category()));

    // There is no way to query a wrapped text's height, so the card height is fixed and the
    // description is hard-truncated. Without the cap a long entry pushes past the card frame.
    let d = loc.Description();
    slot.desc.SetText(StrLen(d) > 150 ? StrLeft(d, 147) + "..." : d);

    let tags = "";
    let t = 0;
    while t < loc.TagCount() && t < 5 {
      tags += (t > 0 ? "  " : "") + "#" + loc.TagAt(t);
      t += 1;
    }
    slot.tags.SetText(tags);

    // The waypoint button reflects the CURRENT pin, so it is right on every re-bind.
    let actions = NCZDGWorldActions.Get(this.m_gi);
    let pinned = IsDefined(actions) && actions.IsPinned(loc.Id());
    slot.wpLabel.SetText(pinned ? "CLEAR WAYPOINT" : "SET WAYPOINT");

    let canTp = NCZDG_CanTeleport(this.m_gi);
    slot.tpLabel.SetText(canTp ? "TELEPORT" : "EXIT VEHICLE");
    slot.tpLabel.BindProperty(n"tintColor", canTp ? NCZDG_Cyan() : NCZDG_Gray());
  }

  // Selecting a card reveals its actions and hides the previous one's. Nothing reflows: the strip
  // is always built, only toggled.
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

    let stack = new inkVerticalPanel();
    stack.SetChildOrder(inkEChildOrder.Forward);
    stack.SetFitToContent(true);
    stack.SetAnchor(inkEAnchor.TopLeft);
    stack.SetAnchorPoint(new Vector2(0.0, 0.0));
    stack.SetMargin(new inkMargin(28.0, 18.0, 20.0, 0.0));
    stack.Reparent(card);

    let name = this.MakeText("", NCZDG_White(), 34);
    name.SetFontStyle(n"Semi-Bold");
    name.SetWrappingAtPosition(NCZDG_CardWidth() - 60.0);
    name.SetMargin(new inkMargin(0.0, 0.0, 0.0, 6.0));
    name.Reparent(stack);

    let meta = this.MakeText("", NCZDG_Cyan(), 26);
    meta.SetLetterCase(textLetterCase.UpperCase);
    meta.SetMargin(new inkMargin(0.0, 0.0, 0.0, 10.0));
    meta.Reparent(stack);

    let desc = this.MakeText("", NCZDG_Gray(), 26);
    desc.SetWrappingAtPosition(NCZDG_CardWidth() - 60.0);
    desc.SetMargin(new inkMargin(0.0, 0.0, 0.0, 8.0));
    desc.Reparent(stack);

    let tags = this.MakeText("", NCZDG_Cyan(), 22);
    tags.SetOpacity(0.7);
    tags.SetMargin(new inkMargin(0.0, 0.0, 0.0, 0.0));
    tags.Reparent(stack);

    // The action strip. Built now, hidden until the card is selected, so revealing it reflows
    // nothing and the card height never changes.
    let actions = new inkHorizontalPanel();
    actions.SetName(n"nczdg_actions");
    actions.SetChildOrder(inkEChildOrder.Forward);
    actions.SetFitToContent(true);
    actions.SetAnchor(inkEAnchor.BottomRight);
    actions.SetAnchorPoint(new Vector2(1.0, 1.0));
    actions.SetMargin(new inkMargin(0.0, 0.0, 20.0, 14.0));
    actions.SetVisible(false);
    actions.Reparent(card);

    let wp = this.MakeSmallButton(actions, "SET WAYPOINT", NCZDG_IdxWaypointBase() + slotIdx, 250.0);
    let tp = this.MakeSmallButton(actions, "TELEPORT", NCZDG_IdxTeleportBase() + slotIdx, 190.0);

    let proxy = new NCZDGGuideProxy();
    proxy.popup = this;
    proxy.index = NCZDG_IdxCardBase() + slotIdx;
    ArrayPush(this.m_proxies, proxy);
    card.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");

    let slot = new NCZDGCardSlot();
    slot.root = card;
    slot.accent = accent;
    slot.frame = frame;
    slot.name = name;
    slot.meta = meta;
    slot.desc = desc;
    slot.tags = tags;
    slot.actions = actions;
    slot.wpLabel = wp;
    slot.tpLabel = tp;
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
    ArrayPush(this.m_proxies, proxy);
    box.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");
    return txt;
  }

  // Redscript has no closures, so a click needs a proxy object holding a back-reference and an
  // index. The widget does not own the proxy: keep it alive in m_proxies or the callback dies.
  //
  // A card knows its POOL SLOT, not its location: the slot maps to whatever is bound to it right
  // now, so filtering never touches a proxy.
  public func OnProxyClick(index: Int32) -> Void {
    if index == NCZDG_IdxClearWaypoint() {
      let actions = NCZDGWorldActions.Get(this.m_gi);
      if IsDefined(actions) {
        actions.ClearWaypoint(this.m_gi);
      }
      this.Refresh();
      return;
    }
    if index == NCZDG_IdxPrevPage() {
      if this.m_page > 0 {
        this.m_page -= 1;
        this.Refresh();
      }
      return;
    }
    if index == NCZDG_IdxNextPage() {
      this.m_page += 1;
      this.Refresh();
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
                                keepCtrl: Bool) -> ref<inkVerticalPanel> {
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

    if keepCtrl {
      this.m_navScroll = scroll;
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
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetStyle(NCZDG_StylePath());
    frame.BindProperty(n"tintColor", NCZDG_Cyan());
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
    ArrayPush(this.m_proxies, proxy);   // the widget does not keep the proxy alive
    box.RegisterToCallback(n"OnRelease", proxy, n"OnRelease");
    return box;
  }
}

// The widgets of one pooled card. Held so a re-bind is a handful of SetText calls, with no
// allocation and no proxy churn.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGCardSlot {
  public let root: wref<inkCanvas>;
  public let accent: wref<inkRectangle>;
  public let frame: wref<inkImage>;
  public let name: wref<inkText>;
  public let meta: wref<inkText>;
  public let desc: wref<inkText>;
  public let tags: wref<inkText>;
  // The action strip is always BUILT, only hidden, so revealing it reflows nothing.
  public let actions: wref<inkHorizontalPanel>;
  public let wpLabel: wref<inkText>;     // SET WAYPOINT <-> CLEAR WAYPOINT
  public let tpLabel: wref<inkText>;     // greys out in a vehicle
}

@if(ModuleExists("NCZoning.Api"))
public class NCZDGGuideProxy extends IScriptable {
  public let popup: wref<NCZDGGuidePopup>;
  public let index: Int32;

  protected cb func OnRelease(e: ref<inkPointerEvent>) -> Bool {
    if e.IsAction(n"click") && IsDefined(this.popup) {
      this.popup.OnProxyClick(this.index);
    }
    return true;
  }
}
