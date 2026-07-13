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

// The entry point Input.reds calls. Declared in this module so the import there resolves.
public func NCZDG_OpenGuide(gi: GameInstance) -> Void {
  let sys = NCZDGGuideSystem.Get(gi);
  if IsDefined(sys) {
    sys.Toggle();
  }
}

// --------------------------------------------------------------------------------------
// The system owns the popup, so re-pressing the key cannot stack a second one, and so the
// popup's lifetime is not tied to whatever widget happened to open it.
// --------------------------------------------------------------------------------------
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
public class NCZDGGuidePopup extends InGamePopup {
  private let m_gi: GameInstance;
  private let m_isClosed: Bool;
  private let m_header: ref<InGamePopupHeader>;
  private let m_footer: ref<InGamePopupFooter>;
  private let m_content: ref<InGamePopupContent>;
  private let m_search: ref<HubTextInput>;
  private let m_status: wref<inkText>;
  private let m_proxies: array<ref<NCZDGGuideProxy>>;

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

    // The right margin re-insets the content region back inside the frame (see NCZDG_FrameInset).
    let root = new inkVerticalPanel();
    root.SetName(n"nczdg_guide_root");
    root.SetChildOrder(inkEChildOrder.Forward);
    root.SetFitToContent(true);
    root.SetHAlign(inkEHorizontalAlign.Left);
    root.SetMargin(new inkMargin(0.0, 0.0, NCZDG_FrameInset(), 0.0));
    root.Reparent(content);

    NCZDGLog(s"guide: popup \(NCZDG_PopupWidth())x\(NCZDG_PopupHeight()), usable width \(NCZDG_UsableWidth())");

    // Hold a STRONG local ref while reparenting. Assigning `new inkText()` straight into a wref
    // field leaves nothing owning the widget, so it is collected before Reparent and never appears.
    let status = this.MakeText(
      "Welcome to the NC Zoning Board internal repository.", NCZDG_Gray(), 32);
    status.Reparent(root);
    this.m_status = status;

    this.m_search = HubTextInput.Create();
    this.m_search.SetName(n"nczdg_search");
    this.m_search.SetWidth(700.0);
    this.m_search.SetMaxLength(64);
    this.m_search.SetLetterCase(textLetterCase.OriginalCase);
    this.m_search.Reparent(root);
    this.m_search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");
    // A vertical panel FILLS its children horizontally by default, which overrides SetWidth/SetSize
    // and stretches them into the frame edge. Every child needs an explicit alignment.
    this.m_search.GetRootWidget().SetHAlign(inkEHorizontalAlign.Left);

    // No CLOSE button: ESC and right-click both dismiss, and the footer already carries the hint.
    // A button that duplicates two working affordances is just a card slot given away.

    NCZDGLog("guide: popup created");
    // DEV: the panel's right edge reads as clipped. Dump the live tree rather than guessing which
    // widget overflows; every ink geometry question in this mod has been answered this way.
    NCZDGLog("[GUIDE] popup tree:");
    NCZDG_DumpWidget(this.GetRootCompoundWidget(), 0, 4);
  }

  protected cb func OnSearchChanged(widget: ref<inkWidget>) -> Bool {
    NCZDGLog(s"guide: search='\(this.m_search.GetText())'");
    return true;
  }

  // Redscript has no closures, so a click needs a proxy object holding a back-reference and an
  // index. The widget does not own the proxy: keep it alive in m_proxies or the callback dies.
  public func OnProxyClick(index: Int32) -> Void {
    NCZDGLog(s"guide: click index=\(index)");
    if index == -1 {
      this.Close();
    }
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
