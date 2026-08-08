// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: FastTravelWatcher.reds
// Author: Spuddeh
// Description: Listens for fast-travel arrival and builds the standalone arrival panel.
//              Confirmed in-game: a cross-district fast travel fires NO district banner, so
//              the banner hook never runs and there is nothing to attach to - hence a panel
//              of its own, placed where the banner-attached one would have gone.
//
//              The hook is the FastTRavelSystem blackboard bool FastTravelLoadingScreenFinished
//              (verified from bossHealthBar.RegisterFastTravelCallback).
// Mod Version: 1.1.0
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.Bridge.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.Panel.*
import NCZoningDistrictGuide.Config.*

// A direct child by name, or null. GetWidgetByPathName takes a whole path, but its separator is
// undocumented and a wrong one returns null in silence - here that would be indistinguishable
// from "the HUD tree has changed", which is the one case the caller must be able to report.
// Walking one level at a time uses only the index API, which cannot be got wrong.
func NCZDG_ChildNamed(parent: ref<inkCompoundWidget>, name: CName) -> wref<inkWidget> {
  if !IsDefined(parent) {
    return null;
  }
  let count = parent.GetNumChildren();
  let i = 0;
  while i < count {
    let child = parent.GetWidgetByIndex(i);
    if IsDefined(child) && Equals(child.GetName(), name) {
      return child;
    }
    i += 1;
  }
  return null;
}

@if(ModuleExists("NCZoning.Api"))
public class NCZDGFastTravelWatcher extends ScriptableSystem {
  private let m_ftCallbackID: ref<CallbackHandle>;
  private let m_menuCallbackID: ref<CallbackHandle>;
  private let m_ftPanel: wref<inkVerticalPanel>;   // current FT panel, removed before the next

  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let reqs = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqs) && reqs.IsPreGame() {
      return;
    }
    let bb = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().FastTRavelSystem);
    if IsDefined(bb) && !IsDefined(this.m_ftCallbackID) {
      this.m_ftCallbackID = bb.RegisterListenerBool(GetAllBlackboardDefs().FastTRavelSystem.FastTravelLoadingScreenFinished, this, n"OnFastTravelFinished");
    }
    // The virtual window this panel lives on does NOT hide under fullscreen menus the way the
    // HUD-hosted banner panel does, so a menu opening inside the panel's 6s life must remove it
    // or it draws over the menu. PLAIN listener, not RegisterDelayedListenerBool: the delayed
    // flush belongs to the ink controller dispatch path, and a delayed listener registered from
    // a ScriptableSystem never fires. The FastTravelLoadingScreenFinished listener above is the
    // same shape and is known to fire from here.
    let uiBB = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_System);
    if IsDefined(uiBB) && !IsDefined(this.m_menuCallbackID) {
      this.m_menuCallbackID = uiBB.RegisterListenerBool(GetAllBlackboardDefs().UI_System.IsInMenu, this, n"OnIsInMenuChanged");
    }
  }

  protected cb func OnIsInMenuChanged(value: Bool) -> Void {
    if !value || !IsDefined(this.m_ftPanel) {
      return;
    }
    // Fires only on the menu-open edge with a live panel - the exact moment the report describes.
    NCZDGLog("ft: menu opened - arrival panel removed");
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkGameNotificationsLayer");
    if IsDefined(layer) {
      let root = layer.GetVirtualWindow();
      if IsDefined(root) {
        root.RemoveChildByName(n"nczdg_panel");
      }
    }
    this.m_ftPanel = null;
  }

  protected cb func OnFastTravelFinished(value: Bool) -> Void {
    if !value {
      return;   // fires false on start; only the finished=true edge matters
    }
    this.ShowFastTravelPanel();
  }

  // Fast travel fires NO district banner (confirmed in-game across many cross-district jumps), so
  // there is nothing to attach to. Build a standalone panel on the game's own notifications
  // layer, at the same screen spot the banner-attached panel uses. Fast travel is a discrete
  // settle, so the LIVE district is correct here - no frozen-value dance needed.
  @if(ModuleExists("NCZoning.Api"))
  private func ShowFastTravelPanel() -> Void {
    let gi = this.GetGameInstance();
    let cfg = NCZDGConfig.Get();
    // Gate on the core being CALLABLE, not on it having data: NCZDG_CoreReady() folds IsReady() in,
    // which would switch off the very panel that reports the missing data. See PopupInject.
    if !IsDefined(cfg) || !cfg.enablePopupToast || !NCZDG_CoreUsable() {
      return;
    }
    // Fast travel shows no game banner, so this panel stands alone. Opt out to leave fast travel
    // entirely to the game.
    if !cfg.enableFastTravelNotice {
      return;
    }
    let here = NCZDG_ResolveCurrent(gi);
    // Off-map with a live registry: show nothing (0-vs-null). With NO registry data the panel
    // still shows, to report that rather than imply the area is empty.
    if !IsDefined(here) && NCZDG_HasData() {
      return;
    }

    // The district-enter banner lives on the inkGameNotificationsLayer; its virtual window is a
    // persistent root to parent into. Place at the banner's usual position (4K reference).
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkGameNotificationsLayer");
    if !IsDefined(layer) {
      NCZDGError("ft: no notifications layer - the arrival panel cannot be shown");
      return;
    }
    let root = layer.GetVirtualWindow();
    if !IsDefined(root) {
      NCZDGError("ft: no virtual window - the arrival panel cannot be shown");
      return;
    }

    // Walking the banner panel's parent chain in-game (nczdg_panel -> New_Quest_canvas -> Root ->
    // Root -> HUDSlotMiddleWidget -> LeftCenter -> Root -> Base Window) showed where the banner
    // block sits, and that ALL of the offset comes from the LeftCenter HUD slot. NOTE the banner
    // does NOT live under BracketsContainer - it hangs off the HUD slots, so parent on Base
    // Window and match the slot.
    //
    // Base Window is the SCREEN size while the content is authored at 4K, so the HUD chain scales
    // the banner by screenH/2160 (0.667 at 1440p). Base Window does not, so apply it explicitly.
    let winSize = root.GetSize();
    let scale = winSize.Y > 1.0 ? (winSize.Y / 2160.0) : 0.667;

    // Remove any previous FT panel. This system persists across fast travels, so without the
    // removal the panels stack up.
    root.RemoveChildByName(n"nczdg_panel");
    this.m_ftPanel = null;

    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    // WHERE THE SLOT IS, ASKED AT RUNTIME - never a remembered number. The slot's position is in
    // SCREEN pixels and it moves with screen height, so the 1440p measurement (56, 653) put the
    // panel a fixed distance from the top of every screen: two thirds of the way down a 1080p
    // one, over the quick-slot HUD.
    //
    // Falls back to that measurement if the slot cannot be found, which keeps a changed HUD tree
    // to a misplaced panel rather than no panel, and says so - silence here reads as "the mod
    // did nothing" and would send the search to the wrong place entirely.
    let slotX = 56.0;
    let slotY = 653.0;
    let rootCanvas = NCZDG_ChildNamed(root, n"Root") as inkCompoundWidget;
    let slot = NCZDG_ChildNamed(rootCanvas, n"LeftCenter");
    if IsDefined(slot) {
      let slotPos = rootCanvas.GetChildPosition(slot);
      slotX = slotPos.X;
      slotY = slotPos.Y;
      // Logged because the fault it replaces was invisible at the resolution it was measured on.
      // The ratio is what to read: it holds across resolutions, the raw Y does not.
      NCZDGLog(s"ft: LeftCenter slot at (\(slotX), \(slotY)) on a \(winSize.X)x\(winSize.Y) window");
    } else {
      NCZDGWarn("ft: LeftCenter HUD slot not found - the arrival panel falls back to its 1440p position");
    }

    // The slot is the TOP of the banner block, so placing there lands where the game banner
    // shows. The banner-path panel sits BELOW that block: it is translated +190 within the banner
    // canvas (4K units), which in Base Window (screen) space is 190 * scale. So add it.
    let panelY = slotY + (190.0 * scale);
    this.m_ftPanel = NCZDG_BuildPanel(root, slotX, panelY, here, player, cfg.showNearest);
    if IsDefined(this.m_ftPanel) {
      this.m_ftPanel.SetRenderTransformPivot(new Vector2(0.0, 0.0));
      this.m_ftPanel.SetScale(new Vector2(scale, scale));
    }

  }
  @if(!ModuleExists("NCZoning.Api"))
  private func ShowFastTravelPanel() -> Void {}
}
