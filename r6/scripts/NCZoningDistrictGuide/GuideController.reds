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

  public func Toggle() -> Void {
    // R1: a key that still fires while the popup is open closes it, making the feature a real
    // toggle. If ModalPopup swallows the key this branch never runs, and ESC is the only way out.
    if this.IsOpen() {
      NCZDGLog("guide: key FIRED WHILE OPEN -> closing (R1: the keybind is a real toggle)");
      this.m_popup.Close();
      this.m_popup = null;
      return;
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
    super.OnDetach();   // must chain: this is what un-pauses and pops the game context
  }

  protected cb func OnCreate() -> Void {
    super.OnCreate();

    // Size the container BEFORE reparenting the content: InGamePopupContent measures itself off the
    // container at reparent time.
    this.m_container.SetWidth(1750.0);
    this.m_container.SetHeight(1150.0);

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetTitle("NC ZONING BOARD");
    this.m_header.SetFluffRight("M5.0 SCAFFOLD");
    this.m_header.Reparent(this);

    this.m_footer = InGamePopupFooter.Create();
    this.m_footer.SetFluffText("NC ZONING BOARD");
    this.m_footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    // An inkCustomController is not a widget: reach its widget with GetRootCompoundWidget().
    let content = this.m_content.GetRootCompoundWidget();

    let root = new inkVerticalPanel();
    root.SetName(n"nczdg_guide_root");
    root.SetChildOrder(inkEChildOrder.Forward);
    root.SetFitToContent(true);
    root.SetMargin(new inkMargin(40.0, 40.0, 0.0, 0.0));
    root.Reparent(content);

    this.m_status = this.MakeText(
      "R1: press the guide key (') now.   R3: type below, click this text, click back. ESC must close.",
      n"MainColors.Grey", 32);
    this.m_status.Reparent(root);

    this.m_search = HubTextInput.Create();
    this.m_search.SetName(n"nczdg_search");
    this.m_search.SetWidth(700.0);
    this.m_search.SetMaxLength(64);
    this.m_search.SetLetterCase(textLetterCase.OriginalCase);
    this.m_search.Reparent(root);
    this.m_search.RegisterToCallback(n"OnInput", this, n"OnSearchChanged");

    this.MakeButton(root, "CLOSE", -1);

    NCZDGLog("guide: popup created");
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
    t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    t.SetFontStyle(n"Medium");
    t.SetFontSize(size);
    t.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    t.BindProperty(n"tintColor", colour);
    t.SetMargin(new inkMargin(0.0, 0.0, 0.0, 24.0));
    return t;
  }

  private func MakeButton(parent: wref<inkCompoundWidget>, label: String, index: Int32) -> Void {
    let box = new inkCanvas();
    box.SetName(n"nczdg_btn");
    box.SetSize(new Vector2(260.0, 64.0));
    box.SetMargin(new inkMargin(0.0, 32.0, 0.0, 0.0));
    box.SetInteractive(true);
    box.Reparent(parent);

    let frame = new inkImage();
    frame.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    frame.SetTexturePart(n"cell_fg");
    frame.SetNineSliceScale(true);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    frame.BindProperty(n"tintColor", n"MainColors.Blue");
    frame.Reparent(box);

    let txt = this.MakeText(label, n"MainColors.Blue", 34);
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
