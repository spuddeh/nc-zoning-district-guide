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
// Mod Version: 1.0.0
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
//
// When the registry has NO data the panel still renders, carrying the core's message instead of a
// count. Rendering "no registered locations in Kabuki" in that state would be a lie: nothing is
// known about Kabuki. District resolution is static, so `here` is still valid here - only the
// counts are unavailable.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_BuildPanel(parent: wref<inkCompoundWidget>, posX: Float, posY: Float,
                             here: ref<NCZDistrictName>, player: ref<GameObject>,
                             showNearest: Bool) -> ref<inkVerticalPanel> {
  if !IsDefined(parent) {
    return null;
  }
  let hasData = NCZDG_HasData();
  if hasData && !IsDefined(here) {
    return null;                      // off-map with a live registry: nothing to say
  }
  let count = hasData ? NCZDG_CountHere(here) : 0;
  let area = IsDefined(here) ? NCZDG_AreaName(here) : "";

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
  title.SetText(NCZDG_T("NCZDG.title"));
  title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  title.SetFontStyle(n"Bold");
  title.SetFontSize(52);
  title.SetLetterCase(textLetterCase.UpperCase);
  title.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  title.BindProperty(n"tintColor", n"MainColors.Blue");
  title.SetVAlign(inkEVerticalAlign.Center);
  title.Reparent(header);

  // The headline. With no data this is an error, not a count: a district is not empty just
  // because nothing loaded. 0 WITH data is a real resolved answer, framed as an opportunity.
  let countTxt = new inkText();
  countTxt.SetName(n"nczdg_count");
  countTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  countTxt.SetFontStyle(n"Regular");
  countTxt.SetFontSize(32);
  countTxt.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  countTxt.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
  if !hasData {
    countTxt.SetText(NCZDG_NoDataLabel());
    countTxt.BindProperty(n"tintColor", n"MainColors.Red");
  } else {
    if count <= 0 {
      countTxt.SetText(NCZDG_T1("NCZDG.panelEmpty", "{area}", area));
    } else {
      // Whole sentence per plural form, not a stem plus a suffix: the count and the area
      // can then swap places, and a language with more than two forms has somewhere to put
      // them.
      let key = count == 1 ? "NCZDG.panelCountOne" : "NCZDG.panelCountMany";
      countTxt.SetText(NCZDG_T2(key, "{n}", IntToString(count), "{area}", area));
    }
    countTxt.BindProperty(n"tintColor", n"MainColors.White");
  }
  countTxt.Reparent(panel);

  // No data: the core owns the sentence that says how to fix it, so the panel and the core's own
  // red banner cannot disagree. Wrapped, because it is a sentence and this panel is narrow.
  if !hasData {
    let why = new inkText();
    why.SetName(n"nczdg_why");
    why.SetText(NCZDG_StatusText());
    why.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    why.SetFontStyle(n"Regular");
    why.SetFontSize(26);
    why.SetWrappingAtPosition(900.0);
    why.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    why.BindProperty(n"tintColor", n"MainColors.Grey");
    why.SetMargin(new inkMargin(0.0, 2.0, 0.0, 0.0));
    why.Reparent(panel);
    NCZDG_PlayPanelLifetime(panel);
    return panel;
  }

  // Nearest line: only when enabled and there is something to be near.
  if showNearest && count > 0 {
    let closest = NCZDG_ClosestInArea(NCZDG_LocationsHere(here), player.GetWorldPosition());
    if IsDefined(closest) {
      let nearest = new inkText();
      nearest.SetName(n"nczdg_nearest");
      nearest.SetText(NCZDG_T1("NCZDG.panelNearest", "{name}", closest.Name()));
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
