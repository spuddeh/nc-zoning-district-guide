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

    this.BuildNav();
    NCZDGLog("guide: popup created");
  }

  protected cb func OnSearchChanged(widget: ref<inkWidget>) -> Bool {
    NCZDGLog(s"guide: search='\(this.m_search.GetText())'");
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

    // A district is a heading; a subdistrict is indented under it; All is the pinned accent.
    let colour = area.isAll ? NCZDG_Amber() : (area.isSub ? NCZDG_Gray() : NCZDG_Cyan());
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
    let cnt = this.MakeText(s"\(area.count)", area.count > 0 ? NCZDG_Gray() : NCZDG_Amber(), 28);
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

    let area = this.m_model.AreaAt(index);
    if IsDefined(area) {
      this.m_status.SetText(s"\(area.count) IN \(area.Label())");
      NCZDGLog(s"guide: selected '\(area.Label())' (\(area.count))");
    }
  }

  private func SetRowSelected(row: wref<inkCanvas>, on: Bool) -> Void {
    let sel = NCZDG_FindByName(row, n"sel");
    if IsDefined(sel) {
      sel.SetOpacity(on ? 0.18 : 0.0);
    }
  }

  // Redscript has no closures, so a click needs a proxy object holding a back-reference and an
  // index. The widget does not own the proxy: keep it alive in m_proxies or the callback dies.
  public func OnProxyClick(index: Int32) -> Void {
    this.SelectArea(index);
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

    let track = new inkRectangle();
    track.SetAnchor(inkEAnchor.Fill);
    track.SetStyle(NCZDG_StylePath());
    track.BindProperty(n"tintColor", NCZDG_Cyan());
    track.SetOpacity(0.12);
    track.Reparent(barArea);

    let handle = new inkRectangle();
    handle.SetAnchor(inkEAnchor.TopFillHorizontaly);
    handle.SetSize(new Vector2(barW, 60.0));
    handle.SetInteractive(true);
    handle.SetStyle(NCZDG_StylePath());
    handle.BindProperty(n"tintColor", NCZDG_Cyan());
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

  private func MakeButton(parent: wref<inkCompoundWidget>, label: String, index: Int32) -> Void {
    let box = new inkCanvas();
    box.SetName(n"nczdg_btn");
    box.SetSize(new Vector2(260.0, 64.0));
    box.SetHAlign(inkEHorizontalAlign.Left);   // or the panel fills it to the frame edge
    box.SetMargin(new inkMargin(0.0, 32.0, 0.0, 0.0));
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
  }
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
