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
// Mod Version: 1.0.0
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

    // Position COMPUTED, not guessed. Walking the banner panel's parent chain in-game
    // (nczdg_panel -> New_Quest_canvas -> Root -> Root -> HUDSlotMiddleWidget -> LeftCenter ->
    // Root -> Base Window) and summing GetChildPosition at each step gives its exact position in
    // 'Base Window' space: (56, 653). NOTE the banner does NOT live under BracketsContainer - it
    // hangs off the HUD slots, so parent on Base Window at the same coords.
    //
    // Base Window is the SCREEN size (2560x1440) while the content is authored at 4K, so the HUD
    // chain scales the banner by screenH/2160 (0.667 at 1440p). Base Window does not, so
    // apply it explicitly - derived live, so it stays correct at any resolution.
    let winSize = root.GetSize();
    let scale = winSize.Y > 1.0 ? (winSize.Y / 2160.0) : 0.667;

    // Remove any previous FT panel. This system persists across fast travels, so without the
    // removal the panels stack up.
    root.RemoveChildByName(n"nczdg_panel");
    this.m_ftPanel = null;

    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    // The measured (56,653) is where the HUD's LeftCenter slot sits - i.e. the TOP of the banner
    // block, so placing there lands where the game banner shows. The banner-path panel
    // sits BELOW that block: it is translated +190 within the banner canvas (4K units), which in
    // Base Window (screen) space is 190 * scale. So add it.
    let panelY = 653.0 + (190.0 * scale);
    this.m_ftPanel = NCZDG_BuildPanel(root, 56.0, panelY, here, player, cfg.showNearest);
    if IsDefined(this.m_ftPanel) {
      this.m_ftPanel.SetRenderTransformPivot(new Vector2(0.0, 0.0));
      this.m_ftPanel.SetScale(new Vector2(scale, scale));
    }

  }
  @if(!ModuleExists("NCZoning.Api"))
  private func ShowFastTravelPanel() -> Void {}
}
