// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: PopupInject.reds
// Author: Spuddeh
// Description: The Nearby Notice. Injects a small branded panel below the game's native
//              district-enter banner (NewLocationNotification), reading how many registry
//              location mods are in the district just entered:
//
//                  [NC logo]  NC ZONING BOARD
//                             12 registered locations in your area
//                             Nearest: Lizzie's Bar
//
//              ADDITIVE ONLY. wrappedMethod() runs first and unconditionally, so the vanilla
//              banner is byte-identical whether or not this mod is installed. The setting only
//              skips OUR widget; it never suppresses the banner (see the mod CLAUDE.md rule).
//
//              Logo: the base-game NightCorp advert atlas, tinted to the NC brand colour.
//              Nothing is shipped; SetAtlasResource references a base path. Text uses the
//              raj font + main_colors.inkstyle, the same as RAMpocalypse HUD.reds.
// Mod Version: 0.1.0 (Pre-release)
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
import NCZoningDistrictGuide.Config.*
// NCZDG_CountHere is a global-scope func in DistrictWatcher.reds (no module), so no import.

// Our injected container, so we can find and refresh (or avoid double-adding) it.
@if(ModuleExists("NCZoning.Api"))
@addField(NewLocationNotification)
let nczdg_panel: wref<inkVerticalPanel>;

// Wrap OnInitialize, NOT SetNotificationData. In the current game SetNotificationData is a
// NATIVE method (dump flags 34304) and @wrapMethod cannot hook a native; the decompiled
// scripts show a scripted override, but they are stale. OnInitialize is a scripted cb func
// (flags 33032, the same shape we wrap on PlayerPuppet), so it hooks cleanly. It fires as the
// banner widget is built, by which point the player has already crossed the boundary, so the
// live DistrictManager (which we resolve from, not the notification data) is already current.
@if(ModuleExists("NCZoning.Api"))
@wrapMethod(NewLocationNotification)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();   // native banner first, always, untouched
  this.NCZDG_UpdatePanel();
  return result;
}

@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_UpdatePanel() -> Void {
  let cfg = NCZDGConfig.Get();
  if !IsDefined(cfg) || !cfg.enablePopupToast {
    return;   // feature off: add nothing
  }
  if !NCZDG_CoreReady() {
    return;
  }

  // inkGameController gives us the player; the GameInstance comes off it. GetGameInstance()
  // is not exposed at this controller level, but GetPlayerControlledObject() is.
  let player = this.GetPlayerControlledObject();
  if !IsDefined(player) {
    return;
  }
  let gi = player.GetGame();

  // The banner fires for the district just entered. Resolve where the player now is and count
  // the registry locations in that (sub)district. 0 is legitimate (e.g. Morro Rock) -> nothing.
  let here = NCZDG_ResolveCurrent(gi);
  if !IsDefined(here) {
    return;
  }
  let count = NCZDG_CountHere(here);
  if count <= 0 {
    return;
  }

  this.NCZDG_EnsurePanel();
  if !IsDefined(this.nczdg_panel) {
    return;
  }

  let countText = this.nczdg_panel.GetWidgetByPathName(n"nczdg_count") as inkText;
  if IsDefined(countText) {
    let plural = count == 1 ? " location" : " locations";
    countText.SetText(s"\(count) registered\(plural) in your area");
  }

  if cfg.showNearest {
    this.NCZDG_SetNearestLine(player, cfg.nearestRadius);
  }
}

// Builds the container once, under the notification root. Idempotent: a second banner reuses it.
@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_EnsurePanel() -> Void {
  if IsDefined(this.nczdg_panel) {
    return;
  }
  let root = this.GetRootCompoundWidget();
  if !IsDefined(root) {
    return;
  }

  let panel = new inkVerticalPanel();
  panel.SetName(n"nczdg_panel");
  panel.SetAnchor(inkEAnchor.BottomLeft);
  panel.SetAnchorPoint(new Vector2(0.0, 0.0));
  panel.SetMargin(new inkMargin(60.0, 12.0, 0.0, 0.0));
  panel.SetChildOrder(inkEChildOrder.Forward);
  panel.SetFitToContent(true);
  panel.Reparent(root);
  this.nczdg_panel = panel;

  // Header row: logo + "NC ZONING BOARD"
  let header = new inkHorizontalPanel();
  header.SetName(n"nczdg_header");
  header.SetChildOrder(inkEChildOrder.Forward);
  header.SetFitToContent(true);
  header.Reparent(panel);

  let logo = new inkImage();
  logo.SetName(n"nczdg_logo");
  logo.SetAtlasResource(r"base\\gameplay\\gui\\world\\adverts\\nightcorp\\nightcorp.inkatlas");
  logo.SetTexturePart(n"logo");
  logo.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  logo.BindProperty(n"tintColor", n"MainColors.Blue");
  logo.SetSize(new Vector2(48.0, 48.0));
  logo.SetVAlign(inkEVerticalAlign.Center);
  logo.SetMargin(new inkMargin(0.0, 0.0, 12.0, 0.0));
  logo.Reparent(header);

  let title = new inkText();
  title.SetName(n"nczdg_title");
  title.SetText("NC ZONING BOARD");
  title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  title.SetFontStyle(n"Bold");
  title.SetFontSize(30);
  title.SetLetterCase(textLetterCase.UpperCase);
  title.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  title.BindProperty(n"tintColor", n"MainColors.Blue");
  title.SetVAlign(inkEVerticalAlign.Center);
  title.Reparent(header);

  // Count line
  let count = new inkText();
  count.SetName(n"nczdg_count");
  count.SetText("");
  count.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  count.SetFontStyle(n"Regular");
  count.SetFontSize(22);
  count.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  count.BindProperty(n"tintColor", n"MainColors.White");
  count.SetMargin(new inkMargin(0.0, 2.0, 0.0, 0.0));
  count.Reparent(panel);

  // Nearest line (populated only when showNearest is on and one is in range)
  let nearest = new inkText();
  nearest.SetName(n"nczdg_nearest");
  nearest.SetText("");
  nearest.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  nearest.SetFontStyle(n"Regular");
  nearest.SetFontSize(18);
  nearest.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  nearest.BindProperty(n"tintColor", n"MainColors.MildBlue");
  nearest.SetVisible(false);
  nearest.Reparent(panel);
}

// The single closest registry location to the player, if within radius, by name.
@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_SetNearestLine(player: ref<GameObject>, radius: Float) -> Void {
  let nearestText = this.nczdg_panel.GetWidgetByPathName(n"nczdg_nearest") as inkText;
  if !IsDefined(nearestText) {
    return;
  }

  let pos = player.GetWorldPosition();
  // rvalue-array gotcha: bind the array return before ArraySize / index.
  let near = GetLocationsNear(pos, radius);
  if ArraySize(near) <= 0 {
    nearestText.SetVisible(false);
    return;
  }

  let closest = this.NCZDG_Closest(near, pos);
  if !IsDefined(closest) {
    nearestText.SetVisible(false);
    return;
  }
  nearestText.SetText(s"Nearest: \(closest.Name())");
  nearestText.SetVisible(true);
}

// GetLocationsNear does not promise sort order, so pick the minimum by squared distance.
@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_Closest(locs: array<ref<NCZLocation>>, from: Vector4) -> ref<NCZLocation> {
  let best: ref<NCZLocation>;
  let bestSq: Float = 0.0;
  let i = 0;
  while i < ArraySize(locs) {
    let loc = locs[i];
    if IsDefined(loc) {
      let d = Vector4.DistanceSquared(from, loc.Pos());
      if !IsDefined(best) || d < bestSq {
        best = loc;
        bestSq = d;
      }
    }
    i += 1;
  }
  return best;
}
