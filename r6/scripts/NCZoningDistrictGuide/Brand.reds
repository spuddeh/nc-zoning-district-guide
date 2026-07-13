// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Brand.reds
// Author: Spuddeh
// Description: The NC Zoning Board / Night Corp brand, mapped onto the game's own palette.
//              One place, so the guide, the banner and the map panel cannot drift apart.
//              Source of truth: cp2077-location-mods-map/docs/branding.md.
//
//              The game's palette is already on-brand, which is not a coincidence: the guide
//              names Zoning Cyan as "the classic Cyberpunk UI cyan", and MainColors.Blue
//              measures #5EF6FF. Prefer these style binds over a raw Color: a bind follows the
//              player's UI colour settings and reads correctly under bloom, while a hardcoded
//              Color does neither.
//
//                Brand                    Hex        Game style              Measured
//                Zoning Cyan (accent)     #00f0ff    MainColors.Blue         #5EF6FF
//                Warning Amber (alerts)   #ffb300    MainColors.Gold         #FFD741
//                Concrete Gray (2nd)      #8a8d91    MainColors.Grey         #9F9996
//                Archival White (text)    #e6f1ff    MainColors.White        #FFFFFF
//                Approval Green (ok)      #00ff9d    MainColors.Green
//                Corporate Navy (bg)      #0a192f    (no game equivalent - see NCZDG_NavyColor)
//
//              TYPOGRAPHY. The brand's body face is Rajdhani, and the game ships it as
//              `raj.inkfontfamily` - so body copy is on-brand for free. The brand's heading face
//              is Orbitron, which the game does not have and this mod cannot ship (pure redscript,
//              no archive). Headings therefore use raj Bold / Semi-Bold, which is the closest the
//              game offers. Do not attempt to reference a font that is not cooked into the game.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NC Zoning Board brand)
// ======================================================================================

// --- palette (style property paths, for BindProperty) ---------------------------------
public func NCZDG_Cyan() -> CName { return n"MainColors.Blue"; }
public func NCZDG_Amber() -> CName { return n"MainColors.Gold"; }
public func NCZDG_Gray() -> CName { return n"MainColors.Grey"; }
public func NCZDG_White() -> CName { return n"MainColors.White"; }
public func NCZDG_Green() -> CName { return n"MainColors.Green"; }
public func NCZDG_Red() -> CName { return n"MainColors.Red"; }

// The darkest panel background the game has. Not the brand's Corporate Navy, but the closest
// bind available; the navy proper is only reachable as a raw Color (below).
public func NCZDG_PanelBg() -> CName { return n"MainColors.Fullscreen_PrimaryBackgroundDarkest"; }

public func NCZDG_StylePath() -> ResRef {
  return r"base\\gameplay\\gui\\common\\main_colors.inkstyle";
}

// --- palette (raw colours, where a bind cannot express the brand) ----------------------
// The game has no navy, so the surfaces come from the site's theme.css verbatim. Color's fields
// are Uint8, so every literal needs a Cast.
//
//   --primary      #0a192f   Corporate Navy, the panel surface (site uses it at 0.95 alpha)
//   --dark-accent  #112240   the card / raised surface
//   --white        #e6f1ff   Archival White; deliberately not pure white, to cut eye strain
public func NCZDG_NavyColor() -> Color {
  return new Color(Cast<Uint8>(10u), Cast<Uint8>(25u), Cast<Uint8>(47u), Cast<Uint8>(255u));
}

public func NCZDG_CardBgColor() -> Color {
  return new Color(Cast<Uint8>(17u), Cast<Uint8>(34u), Cast<Uint8>(64u), Cast<Uint8>(255u));
}

public func NCZDG_TextColor() -> Color {
  return new Color(Cast<Uint8>(230u), Cast<Uint8>(241u), Cast<Uint8>(255u), Cast<Uint8>(255u));
}

// Zoning Cyan as a raw colour, for widgets a style bind cannot hold.
//
// An INTERACTIVE widget gets widget states applied (Default / Hover / Press), and a state overrides
// a style-BOUND tintColor while leaving a direct SetTintColor alone. Tint interactive chrome
// directly, or it renders in the state's colour at rest and in yours only on hover.
public func NCZDG_CyanColor() -> Color {
  return new Color(Cast<Uint8>(0u), Cast<Uint8>(240u), Cast<Uint8>(255u), Cast<Uint8>(255u));
}

// The site renders its panels at 0.95 so the map stays faintly visible beneath.
public func NCZDG_PanelOpacity() -> Float { return 0.95; }

// The NightCorp mark is grey in its atlas, and SetTintColor MULTIPLIES, so it can only darken.
// A literal navy reads black; the blue has to be pushed bright and saturated to survive.
public func NCZDG_LogoTint() -> Color {
  return new Color(Cast<Uint8>(45u), Cast<Uint8>(120u), Cast<Uint8>(230u), Cast<Uint8>(255u));
}

// --- typography ------------------------------------------------------------------------
public func NCZDG_Font() -> String {
  return "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily";
}

// --- category colours (shared with the map panel and the website) -----------------------
// new-location #ffb300 -> Amber, location-overhaul #00f0ff -> Cyan, anything else -> Gray.
public func NCZDG_CategoryColor(category: String) -> CName {
  if UnicodeStringEqual(category, "new-location") {
    return NCZDG_Amber();
  }
  if UnicodeStringEqual(category, "location-overhaul") {
    return NCZDG_Cyan();
  }
  return NCZDG_Gray();
}

// The website's own labels for the same three categories.
public func NCZDG_CategoryLabel(category: String) -> String {
  if UnicodeStringEqual(category, "new-location") {
    return "NEW LOCATION";
  }
  if UnicodeStringEqual(category, "location-overhaul") {
    return "OVERHAUL";
  }
  return "OTHER";
}

// --- re-skinning a Codeware popup -------------------------------------------------------
// InGamePopupHeader and InGamePopupFooter bind their chrome to MainColors.Red / PanelDarkRed:
// that is Codeware's alert styling, and this panel is not an alert. The parts are named, so they
// can be found and rebound. Names, from the live widget tree:
//
//   header: bar > (bg, bgr, frame), bracketBg, bracketBgr, bracketFg, title, fluffTextL, fluffTextR
//   footer: line, fluffIcon, fluffText
//
// (title is already MainColors.Blue; bg / bracketBg are the dark background and stay.)
public func NCZDG_Rebrand(root: wref<inkWidget>) -> Void {
  NCZDG_Retint(root, n"bgr", NCZDG_Cyan());
  NCZDG_Retint(root, n"frame", NCZDG_Cyan());
  NCZDG_Retint(root, n"bracketBgr", NCZDG_Cyan());
  NCZDG_Retint(root, n"bracketFg", NCZDG_Cyan());
  NCZDG_Retint(root, n"fluffTextL", NCZDG_Cyan());
  NCZDG_Retint(root, n"fluffTextR", NCZDG_Cyan());
  NCZDG_Retint(root, n"line", NCZDG_Cyan());
  NCZDG_Retint(root, n"fluffIcon", NCZDG_Cyan());
  NCZDG_Retint(root, n"fluffText", NCZDG_Cyan());
}

// Codeware's HubTextInput is red in three places, and all three read as an error state on an idle
// search box:
//   frame  MainColors.Fullscreen_SecondaryBackground4, which measures raw(0.41, 0.09, 0.09) - a
//          dark red despite the neutral-sounding name. Do not trust a style name; measure it.
//   hover  MainColors.Red
//   text   MainColors.Red - the TYPED TEXT itself (Parts/TextFlow.reds)
//
// Idle grey, hover amber, focus cyan, text Archival White.
public func NCZDG_RebrandInput(root: wref<inkWidget>) -> Void {
  NCZDG_Retint(root, n"frame", NCZDG_Gray());
  NCZDG_Retint(root, n"hover", NCZDG_Amber());
  NCZDG_Retint(root, n"focus", NCZDG_Cyan());
  NCZDG_Retint(root, n"fill", NCZDG_Cyan());
  NCZDG_Retint(root, n"text", NCZDG_White());
  NCZDG_Retint(root, n"caret", NCZDG_White());
}

public func NCZDG_Retint(root: wref<inkWidget>, name: CName, colour: CName) -> Void {
  let w = NCZDG_FindByName(root, name);
  if IsDefined(w) {
    w.BindProperty(n"tintColor", colour);
  }
}

// First descendant with this name, depth-first. The popup parts are nested inside inkFlex
// containers, so a direct child lookup is not enough.
public func NCZDG_FindByName(root: wref<inkWidget>, name: CName) -> wref<inkWidget> {
  if !IsDefined(root) {
    return null;
  }
  if Equals(root.GetName(), name) {
    return root;
  }
  let comp = root as inkCompoundWidget;
  if !IsDefined(comp) {
    return null;
  }
  let i = 0;
  while i < comp.GetNumChildren() {
    let hit = NCZDG_FindByName(comp.GetWidgetByIndex(i), name);
    if IsDefined(hit) {
      return hit;
    }
    i += 1;
  }
  return null;
}
