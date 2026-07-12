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
//              skips this widget; it never suppresses the banner.
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
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.Panel.*
import NCZoningDistrictGuide.Config.*
// NCZDG_CountHere is a global-scope func in DistrictWatcher.reds (no module), so no import.

// The injected container. Held so it can be found, refreshed, and not added twice.
@if(ModuleExists("NCZoning.Api"))
@addField(NewLocationNotification)
let nczdg_panel: wref<inkVerticalPanel>;

// Wrap OnInitialize, NOT SetNotificationData. In the current game SetNotificationData is a
// NATIVE method (dump flags 34304) and @wrapMethod cannot hook a native; the decompiled
// scripts show a scripted override, but they are stale. OnInitialize is a scripted cb func
// (flags 33032, the same shape as the PlayerPuppet wraps), so it hooks cleanly. It fires as the
// banner widget is built, by which point the player has already crossed the boundary, so the
// live DistrictManager (the Layer-2 source, not the notification data) is already current.
// Defers the build past OnInitialize so the banner's own SetNotificationData (native, runs
// after OnInitialize) has frozen its district into m_questNotificationData.text. The callback
// STRONG ref to the notification so the callback cannot be collected before it fires (an
// holds a STRONG ref (a wref is collected before the delay elapses and never fires). Reading
// the banner's OWN frozen district rather than the live one keeps the count in agreement with
// only build inside the banner's lifecycle, so the game's own debounce (it suppresses repeat
// the banner text above it, and inherits the game's banner debounce for free.
@if(ModuleExists("NCZoning.Api"))
public class NCZDGBuildPanel extends DelayCallback {
  public let m_notification: ref<NewLocationNotification>;
  public func Call() -> Void {
    if IsDefined(this.m_notification) {
      this.m_notification.NCZDG_UpdatePanel();
    }
  }
}

@if(ModuleExists("NCZoning.Api"))
@wrapMethod(NewLocationNotification)
protected cb func OnInitialize() -> Bool {
  let result = wrappedMethod();   // native banner first, always, untouched
  let player = this.GetPlayerControlledObject();
  if IsDefined(player) {
    let build = new NCZDGBuildPanel();
    build.m_notification = this;
    GameInstance.GetDelaySystem(player.GetGame()).DelayCallback(build, 0.1);
  }
  return result;
}

// The notification controller instance is reused across banners, so clear the reference when
// it tears down; the next banner rebuilds a fresh panel. (The panel's own fade-out handles the
// normal case; this covers an early teardown.)
@if(ModuleExists("NCZoning.Api"))
@wrapMethod(NewLocationNotification)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.nczdg_panel) {
    this.nczdg_panel = null;
  }
  return wrappedMethod();
}

@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
public func NCZDG_UpdatePanel() -> Void {
  NCZDGLog("popup: UpdatePanel fired");
  let cfg = NCZDGConfig.Get();
  if !IsDefined(cfg) || !cfg.enablePopupToast {
    NCZDGLog("popup: bail - no cfg or toast off");
    return;   // feature off: add nothing
  }
  if !NCZDG_CoreReady() {
    NCZDGLog("popup: bail - core not ready");
    return;
  }

  // inkGameController exposes the player; the GameInstance comes off it. GetGameInstance()
  // is not exposed at this controller level, but GetPlayerControlledObject() is.
  let player = this.GetPlayerControlledObject();
  if !IsDefined(player) {
    NCZDGLog("popup: bail - no player");
    return;
  }

  // Resolve from the district THIS BANNER froze, not the live one. m_questNotificationData.text
  // is the district enum name (District_Record.EnumName) captured when the banner was queued.
  // The blackboard version can advance if the player flies on before the banner shows (the game
  // debounces banners), so reading the banner's OWN frozen copy is what keeps the count matching
  // the banner text above it. Hence the +0.1s defer: the field is set in the native
  // SetNotificationData, which runs after OnInitialize.
  let gi = player.GetGame();
  let enumName: String = "";
  if IsDefined(this.m_questNotificationData) {
    enumName = this.m_questNotificationData.text;
  }
  NCZDGLog(s"popup: banner enumName='\(enumName)'");

  let here = NCZDG_ResolveFromEnumName(enumName);
  if !IsDefined(here) {
    NCZDGLog("popup: enum-name resolve missed, trying live");
    here = NCZDG_ResolveCurrent(gi);
  }
  if !IsDefined(here) {
    NCZDGLog("popup: bail - off-map");
    return;
  }
  NCZDGLog(s"popup: resolved \(here.district)");
  this.NCZDG_EnsurePanel(here, player, cfg.showNearest);
}

// Builds the container once. Idempotent: a second banner reuses it.
//
// Ink is a scene graph like HTML/CSS. The banner's district text (QuestTxt) lives inside a
// vertical flow panel (verified live: QuestTxt -> inkVerticalPanelWidget11 -> New_Quest_canvas
// -> ...). Reparenting this panel into that SAME flow container makes it stack below the
// banner automatically, with no hardcoded margins, and it stays correct across resolutions and
// UI scale. @addMethod compiles into the class, so the private districtName ref is reachable.
// Banner path: position by reading the banner's own block geometry, then delegate the widget
// build to the shared NCZDG_BuildPanel. Verified tree: districtName(QuestTxt) ->
// flow(inkVerticalPanelWidget11) -> canvas(New_Quest_canvas). Parent into the CANVAS (absolute
// layout - children keep their translation and never reflow), positioned just below the flow
// block. Flow-parenting was wrong: spacer content gave a gap, and the flow repacked at
// end-of-life, which moved the panel. @addMethod reaches the private districtName ref.
@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_EnsurePanel(here: ref<NCZDistrictName>, player: ref<GameObject>, showNearest: Bool) -> Void {
  if IsDefined(this.nczdg_panel) {
    return;
  }
  let districtWidget: wref<inkWidget> = inkWidgetRef.Get(this.districtName);
  if !IsDefined(districtWidget) {
    return;
  }
  let flow = districtWidget.parentWidget as inkCompoundWidget;
  if !IsDefined(flow) {
    return;
  }
  let canvas = flow.parentWidget as inkCompoundWidget;
  if !IsDefined(canvas) {
    return;
  }

  let flowPos = canvas.GetChildPosition(flow);
  let flowSize = flow.GetSize();
  // The fit-to-content flow may be unmeasured at build time (text set later), so GetSize().Y can
  // read 0. Fall back to the banner block's known height, or the panel lands on top of it.
  let blockHeight = flowSize.Y > 1.0 ? flowSize.Y : 150.0;

  this.nczdg_panel = NCZDG_BuildPanel(canvas, flowPos.X, flowPos.Y + blockHeight + 40.0,
                                      here, player, showNearest);
  if IsDefined(this.nczdg_panel) {
    NCZDGLog("popup: panel built");
  }
}

// Walks up from `w` to the 'BracketsContainer' ancestor, summing GetChildPosition at each step, and
// logs the total. Gives the widget's position in the container's 4K coordinate space.
@if(ModuleExists("NCZoning.Api"))
@addMethod(NewLocationNotification)
private func NCZDG_LogPosInBrackets(w: wref<inkWidget>) -> Void {
  let totalX: Float = 0.0;
  let totalY: Float = 0.0;
  let node: wref<inkWidget> = w;
  let steps = 0;
  while IsDefined(node) && steps < 12 {
    let parent = node.parentWidget as inkCompoundWidget;
    if !IsDefined(parent) {
      break;
    }
    let p = parent.GetChildPosition(node);
    totalX += p.X;
    totalY += p.Y;
    let pname = NameToString(parent.GetName());
    NCZDGLog(s"pos: step\(steps) parent='\(pname)' childPos=(\(p.X),\(p.Y)) running=(\(totalX),\(totalY))");
    if UnicodeStringEqual(pname, "BracketsContainer") {
      NCZDGLog(s"pos: >>> banner panel in BracketsContainer space = (\(totalX),\(totalY)) <<<");
      return;
    }
    node = parent;
    steps += 1;
  }
  NCZDGLog(s"pos: did not reach BracketsContainer (ran \(steps) steps, total=(\(totalX),\(totalY)))");
}
