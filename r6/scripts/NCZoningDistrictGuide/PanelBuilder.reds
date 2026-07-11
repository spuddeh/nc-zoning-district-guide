// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: PanelBuilder.reds
// Author: Spuddeh
// Description: The single source of truth for the "NC ZONING BOARD" panel widget - its look,
//              content and 6s lifetime. Two hosts reuse it:
//                - the district-enter banner (PopupInject.reds), parenting into the banner's
//                  own canvas at the banner's position;
//                - fast-travel arrival (FastTravelWatcher.reds), parenting into a persistent
//                  HUD layer at the same screen spot (fast travel fires NO banner - confirmed
//                  in-game - so there is nothing to attach to).
//
//              Keeping the widget build here means both surfaces stay visually identical and
//              only the parent + placement differ per host.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

module NCZoningDistrictGuide.Panel

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*
import NCZoningDistrictGuide.Config.*

// Builds the panel tree under `parent` at local (posX, posY), fills it for `here`/`player`, and
// plays the fade in/hold/out lifetime. Returns the panel root (or null if nothing to show).
// `here` non-null is the caller's responsibility (off-map = caller shows nothing).
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_BuildPanel(parent: wref<inkCompoundWidget>, posX: Float, posY: Float,
                             here: ref<NCZDistrictName>, player: ref<GameObject>,
                             showNearest: Bool) -> ref<inkVerticalPanel> {
  if !IsDefined(parent) || !IsDefined(here) {
    return null;
  }
  let count = NCZDG_CountHere(here);
  let area = NCZDG_AreaName(here);

  let panel = new inkVerticalPanel();
  panel.SetName(n"nczdg_panel");
  panel.SetChildOrder(inkEChildOrder.Forward);
  panel.SetFitToContent(true);
  panel.Reparent(parent);
  panel.SetTranslation(new Vector2(posX, posY));

  // Header row: logo + "NC ZONING BOARD"
  let header = new inkHorizontalPanel();
  header.SetName(n"nczdg_header");
  header.SetChildOrder(inkEChildOrder.Forward);
  header.SetFitToContent(true);
  header.Reparent(panel);

  // Logo aspect 573x371 (1.54:1). SetTintColor MULTIPLIES, so it only darkens: white is a no-op,
  // and a dark navy reads black - push the blue bright + saturated so the grey source reads blue.
  let logo = new inkImage();
  logo.SetName(n"nczdg_logo");
  logo.SetAtlasResource(r"base\\gameplay\\gui\\world\\adverts\\nightcorp\\nightcorp.inkatlas");
  logo.SetTexturePart(n"logo");
  logo.SetTintColor(new Color(Cast<Uint8>(45u), Cast<Uint8>(120u), Cast<Uint8>(230u), Cast<Uint8>(255u)));
  logo.SetSize(new Vector2(108.0, 70.0));
  logo.SetVAlign(inkEVerticalAlign.Center);
  logo.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
  logo.Reparent(header);

  let title = new inkText();
  title.SetName(n"nczdg_title");
  title.SetText("NC ZONING BOARD");
  title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  title.SetFontStyle(n"Bold");
  title.SetFontSize(52);
  title.SetLetterCase(textLetterCase.UpperCase);
  title.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  title.BindProperty(n"tintColor", n"MainColors.Blue");
  title.SetVAlign(inkEVerticalAlign.Center);
  title.Reparent(header);

  // Count line. 0 is a real resolved area (off-map is handled by the caller), so show it framed
  // as an opportunity, not a bug.
  let countTxt = new inkText();
  countTxt.SetName(n"nczdg_count");
  if count <= 0 {
    countTxt.SetText(s"No registered locations in \(area) yet");
  } else {
    let plural = count == 1 ? " location" : " locations";
    countTxt.SetText(s"\(count) registered\(plural) in \(area)");
  }
  countTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  countTxt.SetFontStyle(n"Regular");
  countTxt.SetFontSize(32);
  countTxt.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  countTxt.BindProperty(n"tintColor", n"MainColors.White");
  countTxt.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
  countTxt.Reparent(panel);

  // Nearest line: only when enabled and there is something to be near.
  if showNearest && count > 0 {
    let closest = NCZDG_ClosestInArea(NCZDG_LocationsHere(here), player.GetWorldPosition());
    if IsDefined(closest) {
      let nearest = new inkText();
      nearest.SetName(n"nczdg_nearest");
      nearest.SetText(s"Nearest: \(closest.Name())");
      nearest.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
      nearest.SetFontStyle(n"Regular");
      nearest.SetFontSize(26);
      nearest.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
      nearest.BindProperty(n"tintColor", n"MainColors.Gold");
      nearest.SetMargin(new inkMargin(0.0, 2.0, 0.0, 0.0));
      nearest.Reparent(panel);
    }
  }

  NCZDG_PlayPanelLifetime(panel);
  return panel;
}

// Fade in, hold, fade out over the banner's 6s showDuration (read from the notification widget).
// A code-built widget cannot replay a library animation, so reproduce the character with two
// inkAnimTransparency interpolators in one inkAnimDef (SetStartDelay stages them).
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_PlayPanelLifetime(target: wref<inkWidget>) -> Void {
  let def = new inkAnimDef();

  let fadeIn = new inkAnimTransparency();
  fadeIn.SetStartTransparency(0.0);
  fadeIn.SetEndTransparency(1.0);
  fadeIn.SetStartDelay(0.0);
  fadeIn.SetDuration(0.4);
  def.AddInterpolator(fadeIn);

  let fadeOut = new inkAnimTransparency();
  fadeOut.SetStartTransparency(1.0);
  fadeOut.SetEndTransparency(0.0);
  fadeOut.SetStartDelay(5.4);
  fadeOut.SetDuration(0.6);
  def.AddInterpolator(fadeOut);

  target.PlayAnimation(def);
}
