// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapMarker.reds
// Author: Spuddeh
// Description: Gives the guide's marker a NightCorp face on the map, the minimap and in the world.
//
//              The marker is an ordinary POI mappin (WorldActions.reds explains why it must not be a
//              waypoint), so out of the box it wears whatever its variant looks like - an apartment
//              pin with apartment text. The player has to be able to find and TRACK it on the map,
//              and a pin they cannot tell apart from a real apartment is a pin they cannot find.
//
//              The icon is overridden on the mappin CONTROLLERS, not in the mappin data. MappinData
//              has no icon field, and a controller holds an inkImage, which takes any cooked atlas
//              path - so a base-game atlas needs no archive and no TweakXL.
//
//              A mappin carries no user data, so the marker identifies itself through debugCaption -
//              IMappin.GetDisplayName() returns it - encoded as "NCZDG|<title>". A controller hook
//              runs for EVERY mappin on screen, so the tag check has to come first and be cheap.
//
//              Credit: the debugCaption-as-identity and controller-override technique is from the
//              community "custom map marker" template (_resources/Custom_map_marker_template). Its
//              instructions ask for a WolvenKit project, which is only needed to ship a custom atlas -
//              the redscript half stands alone against base-game atlases.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh
// ======================================================================================

// The loading-screen monogram, not the advert logo. It is small and WHITE, and tint MULTIPLIES - so a
// white source is the only one that can be tinted to an arbitrary colour. The advert atlas
// (world\adverts\nightcorp) is a grey wordmark and can only ever be darkened.
public func NCZDG_MarkerAtlas() -> ResRef {
  return r"base\\gameplay\\gui\\fullscreen\\loading\\atlas_loading_screen.inkatlas";
}
public func NCZDG_MarkerPart() -> CName { return n"nc_logo"; }

// The game's mappin icons are 64x64 and SQUARE (mappin_icons.xbm is 1120x792; each part measures
// 0.05714 x 0.07955 UV = 64.0 x 63.0 px). The monogram is NOT square: nc_logo is 35x20 px in a 160x24
// atlas, an aspect of 1.75:1. It can never fill a square box without being stretched.
//
// A landscape emblem fitted to a square icon's WIDTH covers only 57% of its area, and next to square
// icons it reads as small - measured: the world pin's icon box is 64x64, and 64 x 36.6 looked half the
// size of everything around it. Fitting to the icons' HEIGHT instead gives it the same visual weight.
//
// The surfaces do not agree on this. The world map scales its own container (its icon widget measures
// 2x2 before anything touches it), so a width fit reads correctly there. The world pin does not.
public func NCZDG_MarkerAspect() -> Float { return 1.75; }

// Fit to the icons' WIDTH. Correct where the container scales the icon - the world map and minimap.
public func NCZDG_MarkerFitWidth() -> Float { return 64.0; }

// Fit to the icons' HEIGHT. Correct in the world, where the pin sits among unscaled 64x64 icons.
public func NCZDG_MarkerFitHeight() -> Float { return 64.0 * 1.75; }

// Everything below runs inside a hot path shared with every other mappin on screen.
@addMethod(BaseMappinBaseController)
protected final func NCZDG_IsOurMarker() -> Bool {
  let mappin = this.GetMappin();
  if !IsDefined(mappin) {
    return false;
  }
  return StrBeginsWith(mappin.GetDisplayName(), NCZDG_MarkerTag() + "|");
}

// `width` is the emblem's width for that surface. The height always follows the true aspect, so the
// monogram is never stretched.
@addMethod(BaseMappinBaseController)
protected final func NCZDG_BrandIcon(width: Float) -> Void {
  if !this.NCZDG_IsOurMarker() {
    return;
  }
  // DO NOT TINT. The game re-applies a mappin's colour on TRACKED-STATE change, through
  // UpdateTrackedState and not through UpdateIcon - so a tint written here is stomped and restored at
  // random, which reads as the icon flickering between white and coloured. The source monogram is
  // already white and the game already highlights a tracked pin, which is the wanted behaviour anyway.
  // Owning the colour means fighting the game for it and losing.
  inkImageRef.SetAtlasResource(this.iconWidget, NCZDG_MarkerAtlas());
  inkImageRef.SetTexturePart(this.iconWidget, NCZDG_MarkerPart());

  // FitToContent is cleared first or the widget snaps back to the source's own 35x20.
  //
  // Sized from a CONSTANT, never from the widget's current size: this hook runs on every icon update,
  // so a size derived from a size the hook already wrote would compound on itself every frame.
  inkWidgetRef.SetFitToContent(this.iconWidget, false);
  inkWidgetRef.SetSize(this.iconWidget, new Vector2(width, width / NCZDG_MarkerAspect()));
  inkWidgetRef.SetScale(this.iconWidget, new Vector2(1.0, 1.0));
}

// NO Z-ORDER CONTROL HERE, and adding one back does not work.
//
// ink has no z-order: a compound widget draws its children in array order and the last one is on top,
// so ReorderChild is the only lever the API offers. It does land - measured stuck=true, on the minimap
// ('unclampedMappinContainer') and on the world pin ('Root'). It just does not help: on the world map
// the marker sits ALREADY LAST of 107 children and still draws behind the game's apartment pins.
//
// Child order therefore does not decide draw order on the world map. Re-sorting a container the game
// owns, on every icon update of every mappin on screen, buys nothing.

// One hook per SURFACE, and there are four - world map, minimap, the floating world pin, and the
// gameplay-role pin. A marker branded on the map but not in the world reads as two different pins.
//
// wrappedMethod() first and unconditionally, in every one: the game's own mappins must draw exactly
// as they would with this mod absent.
@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(NCZDG_MarkerFitWidth() * 0.8);
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(NCZDG_MarkerFitWidth());
}

@wrapMethod(QuestMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(NCZDG_MarkerFitHeight());
}

// GameplayMappinController extends QuestMappinController and overrides UpdateIcon, so the parent hook
// above does NOT run for it. It is the controller a GameplayRoleMappinData mappin actually gets, and
// its icon box measures 64x64 - the size the emblem has to hold its own against.
@wrapMethod(GameplayMappinController)
private func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(NCZDG_MarkerFitHeight());
}

// The tooltip is what makes the marker trackable in practice. Tracking requires selecting the right
// pin on the map, and an unlabelled pin cannot be told apart from the POI it is standing next to.
@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
  wrappedMethod(data, menu);

  let mappin = Deref(data).mappin;
  if !IsDefined(mappin) {
    return;
  }
  let parts = StrSplit(mappin.GetDisplayName(), "|");
  if ArraySize(parts) < 2 || !UnicodeStringEqual(parts[0], NCZDG_MarkerTag()) {
    return;
  }
  inkTextRef.SetText(this.m_titleText, parts[1]);
  inkTextRef.SetText(this.m_descText, "NC ZONING BOARD");
}
