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

import NCZoningDistrictGuide.MapFocus.*

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

// The world/HUD pin, which sits among unscaled 64x64 icons.
//
// A full height fit (64 * 1.75 = 112 wide) matches their height but is 1.75x their WIDTH, and reads
// as oversized next to them - measured in game. A pure width fit (64 wide, 36.6 tall) reads as
// half-size. 88 is between the two: wider than a vanilla icon, visibly shorter than one.
public func NCZDG_MarkerFitHeight() -> Float { return 88.0; }

// CACHED IDENTITY, AND IT EXISTS TO AVOID A CRASH - do not "simplify" it back to a live lookup.
//
// Asking the mappin who it is is only safe while the mappin is bound, which is true in UpdateIcon
// and NOT true in UpdateTrackedState: vanilla's own UpdateTrackedState returns at
// `ArraySize(m_taggedWidgets) == 0` before touching the mappin, and it is also called while mappins
// are being destroyed. GetMappin() hands back a wref, a wref to a destroyed mappin is not null, so
// IsDefined() passes it through and GetDisplayName() takes the game down. Measured: CTD on every
// world-map open, 2026-08-02.
//
// So identity is resolved once in the icon path, where the mappin is guaranteed live, and every
// other hook reads this Bool instead. Controllers are pooled, so a recycled one can carry a stale
// value until its next icon update - that is a wrong tint for one frame, not a crash.
@addField(BaseMappinBaseController)
let nczdg_isOurs: Bool;

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
  // The one place identity is resolved live. Cached for the hooks that cannot ask safely.
  this.nczdg_isOurs = this.NCZDG_IsOurMarker();
  if !this.nczdg_isOurs {
    return;
  }
  inkImageRef.SetAtlasResource(this.iconWidget, NCZDG_MarkerAtlas());
  inkImageRef.SetTexturePart(this.iconWidget, NCZDG_MarkerPart());
  this.NCZDG_TintIcon();

  // FitToContent is cleared first or the widget snaps back to the source's own 35x20.
  //
  // Sized from a CONSTANT, never from the widget's current size: this hook runs on every icon update,
  // so a size derived from a size the hook already wrote would compound on itself every frame.
  inkWidgetRef.SetFitToContent(this.iconWidget, false);
  inkWidgetRef.SetSize(this.iconWidget, new Vector2(width, width / NCZDG_MarkerAspect()));
  inkWidgetRef.SetScale(this.iconWidget, new Vector2(1.0, 1.0));
}

// Cyan at rest, gold once tracked. The monogram is WHITE in its atlas and tint MULTIPLIES, so it can
// be driven to any colour - the same property that made it the right source in the first place.
//
// UNBIND FIRST, THEN TINT DIRECTLY. A style-BOUND tintColor is re-evaluated every time the widget's
// state changes, and UpdateRootState calls SetState on the root on every icon update; a direct tint
// survives that, a bound one does not (Brand.reds carries the same rule for the guide's chrome).
// Unbinding is what stops the two fighting: without it the bind is still live and wins on the next
// state change.
@addMethod(BaseMappinBaseController)
protected final func NCZDG_TintIcon() -> Void {
  let icon = inkWidgetRef.Get(this.iconWidget);
  if !IsDefined(icon) {
    return;
  }
  icon.UnbindProperty(n"tintColor");

  // IsPlayerTracked is native on the CONTROLLER (gameuiMappinBaseController) as well as on IMappin.
  // Read it from the controller: it answers the same question without dereferencing a mappin that
  // may already be gone.
  icon.SetTintColor(this.IsPlayerTracked() ? NCZDG_MarkerTrackedColor() : NCZDG_MarkerColor());
}

// ARRIVAL, WITHOUT A POLL.
//
// The waypoint clears itself once the player reaches it. A mappin fires no proximity event, so the
// distance has to be ASKED for - but it does not have to be asked for on a timer. These controller
// hooks already run as the player moves, and `GetDistanceToPlayer()` is native on the CONTROLLER
// (gameuiMappinBaseController), not on the mappin, so it can be read from the tracked hook without
// the dereference that crashes there.
//
// ADAPTED FROM MapWaypointBugFixes/ArrivalPhantomFix, WHICH CANNOT BE COPIED DIRECTLY. That mod
// notices arrival by watching the manually-tracked SLOT empty itself, which the game does for
// CustomPositionVariant (21). This marker is deliberately ApartmentVariant - the whole reason it is
// not variant 21 is that the game writes to whatever holds that role - so the game never clears the
// slot for it and there is no slot change to watch. The distance is what is left.
//
// An unowned pin costs one cached field read and returns, which is what keeps this off the hot path.
@addMethod(BaseMappinBaseController)
protected final func NCZDG_CheckArrival() -> Void {
  if !this.nczdg_isOurs {
    return;
  }
  let gi = GetGameInstance();
  let actions = NCZDGWorldActions.Get(gi);
  if IsDefined(actions) {
    // The distance is reported, not judged, here. Arming and the radius test belong with the
    // waypoint's state, not on a pooled controller that may not be the one that saw it set.
    actions.NotifyMarkerDistance(gi, this.GetDistanceToPlayer());
  }
}

// Tracking is the state the colour reports, so the colour has to be re-applied when it changes.
// UpdateIcon does not run on a track/untrack - the icon is unchanged, only its meaning is - so
// without these two the marker would go gold on its next icon refresh instead of on the click.
//
// UpdateTrackedState is declared on BaseMappinBaseController and OVERRIDDEN by
// GameplayMappinController, so the base wrap does not reach that one. Same split as UpdateIcon.
@wrapMethod(BaseMappinBaseController)
protected func UpdateTrackedState() -> Void {
  wrappedMethod();
  // Cached flag, NOT a live lookup - see nczdg_isOurs. An unowned pin costs one field read here
  // and no native call, which is what keeps this hook off the destroyed-mappin path.
  if this.nczdg_isOurs {
    this.NCZDG_TintIcon();
  }
  this.NCZDG_CheckArrival();
}

@wrapMethod(GameplayMappinController)
protected func UpdateTrackedState() -> Void {
  wrappedMethod();
  if this.nczdg_isOurs {
    this.NCZDG_TintIcon();
  }
}

// The marker cannot be forced in front of other pins on the world map, and ReorderChild does not do it.
// ink has no z-order - a compound widget draws children in array order, last on top - but the world map
// does not order its pins by child order: the marker sits last of ~107 children and still draws behind.

// One hook per SURFACE, and there are four - world map, minimap, the floating world pin, and the
// gameplay-role pin. A marker branded on the map but not in the world reads as two different pins.
//
// wrappedMethod() first and unconditionally, in every one: the game's own mappins must draw exactly
// as they would with this mod absent.
@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  this.NCZDG_BrandIcon(NCZDG_MarkerFitWidth() * 0.8);
  this.NCZDG_CheckArrival();
}

// Also the capture point for MapFocus. A mappin controller cannot be looked up, but every one the
// map draws passes through here, so the marker's own controller is handed over for free - and this
// is the only place in the mod that ever holds one.
@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();

  // BrandIcon resolves identity and caches it, so it is asked once per icon update and not twice.
  this.NCZDG_BrandIcon(NCZDG_MarkerFitWidth());
  if !this.nczdg_isOurs {
    return;
  }

  let focus = NCZDGMapFocus.Get();
  if !IsDefined(focus) {
    return;
  }
  focus.SetController(this);

  // THIS is the trigger, and it runs SYNCHRONOUSLY. No timer, at any duration.
  //
  // DelaySystem runs on GAME time, and an open world map dilates that to nearly a stop: a 0.25s
  // callback scheduled here fired 9.1 REAL seconds later, by which point the player had closed the
  // map and both handles were released. Measured 2026-08-02. Every earlier timing-based version
  // failed the same way and looked like a different bug each time.
  //
  // Here, both handles are provably live: `this` is the controller being drawn, and the map cannot
  // be mid-draw and closed at once. Consume() first, so the re-entrant UpdateIcon that TrackMappin
  // provokes finds nothing pending.
  if focus.IsPending() {
    let menu = focus.GetMapMenu();
    if IsDefined(menu) {
      focus.Consume();
      menu.NCZDG_FocusMarker(this);
      focus.ClearController();
    }
  }
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
  this.NCZDG_CheckArrival();
}

// The spawn profile decides whether the HUD pin exists at all, and this function assigns it from the
// variant. A map-visible variant lands on MappinUISpawnProfile.MediumRange (spawn 100m, despawn 120m),
// so past 100m the pin is not faded - it is never created. Overriding here frees the variant to be
// chosen for the world map (see WorldActions.reds) while the HUD gets Always.
//
// Same default widget, so the icon hooks above still apply.
//
// wrappedMethod() runs first, and its result is returned untouched for every mappin the mod does not
// own - the game's own pins must be profiled exactly as they would be with this mod absent.
@wrapMethod(WorldMappinsContainerController)
public func CreateMappinUIProfile(mappin: wref<IMappin>, mappinVariant: gamedataMappinVariant,
                                  customData: ref<MappinControllerCustomData>) -> MappinUIProfile {
  let profile = wrappedMethod(mappin, mappinVariant, customData);
  if !IsDefined(mappin) || !StrBeginsWith(mappin.GetDisplayName(), NCZDG_MarkerTag() + "|") {
    return profile;
  }
  // The RUNTIME profile decides where the pin survives. Nearly every world profile is
  // visibleInTier [1,0,0,0,0] - open world only - so the pin blinks out the moment gameplay leaves tier
  // 1: a doorway, a staircase, a scripted beat. Quest is [1,1,0,0,0], visible in braindance and
  // scanning, clamped to the screen edge, and carries a 120 hover radius.
  //
  // A UI profile is not a mappin group: it does not make the mappin quest-TRACKABLE. The player can
  // still track it, which the feature depends on.
  return MappinUIProfile.Create(
    r"base\\gameplay\\gui\\widgets\\mappins\\quest\\default_mappin.inkwidget",
    t"MappinUISpawnProfile.Always",
    t"WorldMappinUIProfile.Quest");
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
  inkTextRef.SetText(this.m_descText, NCZDG_T("NCZDG.title"));
}
