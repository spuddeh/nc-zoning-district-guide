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
// Mod Version: 1.1.1
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
        // Both hosts, for the reason given where the panel is built.
        let rootCanvas = NCZDG_ChildNamed(root, n"Root") as inkCompoundWidget;
        let brackets = NCZDG_ChildNamed(rootCanvas, n"BracketsContainer") as inkCompoundWidget;
        if IsDefined(brackets) {
          brackets.RemoveChildByName(n"nczdg_panel");
        }
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

    // POSITION IN 4K DESIGN UNITS, INSIDE A CANVAS THAT ALREADY SCALES.
    //
    // `Base Window` is the SCREEN (1920x1080, 2560x1440, ...) at scale 1, so a coordinate given
    // against it is a screen pixel and suits exactly one monitor. Its child `Root` holds
    // `BracketsContainer`, a 3840x2160 canvas whose scale IS screenH/2160 - measured 0.5 at 1080p
    // and 0.667 at 1440p. A child placed in there is positioned AND scaled by the game, so the
    // panel needs no arithmetic of its own and no resolution ever appears in this file.
    //
    // The two constants come from the 1440p rendering that was confirmed correct on screen:
    //   x  56 / 0.667 =   84
    //   y 780 / 0.667 = 1169.5   (the banner block's top, 653, plus the panel's own 190 below it)
    // so 1440p is reproduced exactly and every other resolution lands on the same FRACTION of the
    // screen rather than the same pixel.
    let winSize = root.GetSize();
    let scale = winSize.Y > 1.0 ? (winSize.Y / 2160.0) : 0.667;
    let rootCanvas = NCZDG_ChildNamed(root, n"Root") as inkCompoundWidget;
    let brackets = NCZDG_ChildNamed(rootCanvas, n"BracketsContainer") as inkCompoundWidget;

    // Remove any previous FT panel, from both possible hosts: this system persists across fast
    // travels, so without the removal the panels stack up. Naming both means a build that
    // parented to the window before a tree change is still cleaned up after it.
    if IsDefined(brackets) {
      brackets.RemoveChildByName(n"nczdg_panel");
    }
    root.RemoveChildByName(n"nczdg_panel");
    this.m_ftPanel = null;

    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if IsDefined(brackets) {
      this.m_ftPanel = NCZDG_BuildPanel(brackets, 84.0, 1169.5, here, player, cfg.showNearest);
      // No SetScale here on purpose - BracketsContainer carries screenH/2160 already, and setting
      // it again would square it.
    } else {
      // The tree has changed shape. Fall back to the screen-pixel placement, which is wrong
      // anywhere but 1440p but is still a visible panel, and say so - silence reads as "the mod
      // did nothing" and sends the next search somewhere else entirely.
      NCZDGWarn("ft: BracketsContainer not found - the arrival panel falls back to its 1440p position");
      this.m_ftPanel = NCZDG_BuildPanel(root, 56.0, 653.0 + (190.0 * scale), here, player, cfg.showNearest);
      if IsDefined(this.m_ftPanel) {
        this.m_ftPanel.SetRenderTransformPivot(new Vector2(0.0, 0.0));
        this.m_ftPanel.SetScale(new Vector2(scale, scale));
      }
    }

  }
  @if(!ModuleExists("NCZoning.Api"))
  private func ShowFastTravelPanel() -> Void {}
}
