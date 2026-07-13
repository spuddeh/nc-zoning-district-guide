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

// The emblem, not the wordmark. It is grey in the source and tint MULTIPLIES, so it can be darkened
// or hue-shifted but never brightened - a light tint is the only way to keep it legible.
public func NCZDG_MarkerAtlas() -> ResRef {
  return r"base\\gameplay\\gui\\world\\adverts\\nightcorp\\nightcorp.inkatlas";
}
public func NCZDG_MarkerPart() -> CName { return n"logo"; }

// Everything below runs inside a hot path shared with every other mappin on screen.
@addMethod(BaseMappinBaseController)
protected final func NCZDG_IsOurMarker() -> Bool {
  let mappin = this.GetMappin();
  if !IsDefined(mappin) {
    return false;
  }
  return StrBeginsWith(mappin.GetDisplayName(), NCZDG_MarkerTag() + "|");
}

@addMethod(BaseMappinBaseController)
protected final func NCZDG_BrandIcon(scale: Float) -> Void {
  if !this.NCZDG_IsOurMarker() {
    return;
  }
  inkImageRef.SetAtlasResource(this.iconWidget, NCZDG_MarkerAtlas());
  inkImageRef.SetTexturePart(this.iconWidget, NCZDG_MarkerPart());
  inkImageRef.SetTintColor(this.iconWidget, NCZDG_CyanColor());
  inkWidgetRef.SetScale(this.iconWidget, new Vector2(scale, scale));
}

// wrappedMethod() first and unconditionally, in every hook: the game's own mappins must draw exactly
// as they would with this mod absent.
@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(0.8);
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(1.0);
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
