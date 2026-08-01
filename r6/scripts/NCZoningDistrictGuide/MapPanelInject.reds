// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: MapPanelInject.reds
// Author: Spuddeh
// Description: Adds an NC Zoning registry section to the World Map's district info panel (the
//              bottom-right block: time / PRIMARY GANGS / DISTRICT / SUBDISTRICT). Mirrors the
//              stats on the nczoning.net district panel:
//
//                                    NC ZONING:
//                                  34 LOCATIONS
//                 13 NEW LOCATIONS - 21 OVERHAULS
//
//              Text only, right-aligned. No logo: the map's corner block is dense and text-only,
//              and a brand mark in the native district-icon slot crowds it.
//
//              STYLE. Sizes are the native map's own, from world_map.inkwidget - districtName is
//              50 Semi-Bold; subdistrictName and leadingGangsLabel are 42 Medium; all UpperCase.
//              Do not invent sizes here; a smaller tier reads as off-brand next to the native text.
//
//              Category colours map onto the game palette, so nothing is shipped:
//                new-location      #ffb300 (amber)  -> MainColors.Gold
//                location-overhaul #00f0ff (cyan)   -> MainColors.Blue
//                other             #8892b0 (grey)   -> MainColors.Grey
//
//              BADLANDS. The game has no district polygon for the Badlands, so hovering anywhere
//              outside every polygon passes gamedataDistrict.Invalid for BOTH enums, and the native
//              block hides the icon and the gangs and falls back to LocKey#10951 ("BADLANDS") for
//              the name. An unresolved hover therefore reports the whole Badlands district. The map
//              cannot report a Badlands SUBdistrict, so this is always the district total and
//              deliberately ignores matchSubdistrict.
//
//              The web panel's "N recently updated" stat IS reproduced here now: the core exposes the
//              API's server-computed recently_updated bool per location (NCZLocation.RecentlyUpdated()),
//              so this counts it over the district's locations. redscript still has no wall clock - the
//              server did the date math and shipped the answer.
//
//              ADDITIVE ONLY. wrappedMethod() runs first and unconditionally in both wraps, so the
//              vanilla map is byte-identical whether or not this mod is installed. enableMapPanel
//              hides only this widget; it never suppresses the district block, the gangs list, or
//              any native call.
//
//              No Layer-2 resolver is needed: OnUpdateHoveredDistricts supplies the district and
//              subdistrict enums directly, so NCZDG_ResolveFromEnum is enough.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*
@if(ModuleExists("NCZoning.Api"))
import NCZoning.Data.*
@if(ModuleExists("NCZoning.Api"))
import NCZoningDistrictGuide.District.*
import NCZoningDistrictGuide.Config.*
// NCZDG_LocationsHere is a global-scope func in DistrictWatcher.reds (no module), so no import.

// Sizes taken from the native world_map.inkwidget, not invented: districtName is 50 Semi-Bold,
// subdistrictName and leadingGangsLabel ("PRIMARY GANGS:") are both 42 Medium, all UpperCase.
// This section sits one step below the district name: label lines on the native 42 tier, detail
// line at 34.
public func NCZDG_MapLabelSize() -> Int32 { return 42; }
public func NCZDG_MapDetailSize() -> Int32 { return 34; }


// The injected section. Built once; a hover only changes the text and the breakdown row.
@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapPanel: wref<inkVerticalPanel>;

@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapCount: wref<inkText>;

@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapBreakdown: wref<inkHorizontalPanel>;

@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapRecent: wref<inkText>;

// Hover fires on every mouse move over the map, so dedupe like the native ShowGangsInfo does.
// Bool defaults to false, which is what forces the first hover through.
@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapBuilt: Bool;

@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapLastDistrict: gamedataDistrict;

@if(ModuleExists("NCZoning.Api"))
@addField(WorldMapMenuGameController)
let nczdg_mapLastSub: gamedataDistrict;

// --------------------------------------------------------------------------------------
// Hook: the map's live hover callback (scripted cb func, dump flags 33032 - confirmed
// wrappable). It carries both enums and is the same call that drives the native district name,
// icon and gangs list, so this section updates in lockstep with them.
// --------------------------------------------------------------------------------------
@if(ModuleExists("NCZoning.Api"))
@wrapMethod(WorldMapMenuGameController)
protected cb func OnUpdateHoveredDistricts(district: gamedataDistrict, subdistrict: gamedataDistrict) -> Bool {
  let result = wrappedMethod(district, subdistrict);   // always, first, unconditional
  this.NCZDG_UpdateMapSection(district, subdistrict);
  return result;
}

// The world map is the ONLY thing that can adopt a script-registered pin as the player's tracked
// waypoint, so a waypoint set from the guide draws no route until the map has been opened. That is
// a game limitation, and every script-side workaround has been tried and measured:
// [[CP2077-Mods/wiki/learnings/a-script-registered-waypoint-cannot-route-itself]].
//
// NEVER call TrackCustomPositionMappin() from a hook here. It does not adopt an existing pin - it
// CREATES a new waypoint at the current MAP CURSOR, so on map open it plants one at roughly the
// world origin (Charter Hill).

// Nulls the refs when the map closes; the widgets die with the menu.
@if(ModuleExists("NCZoning.Api"))
@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let result = wrappedMethod();
  this.nczdg_mapPanel = null;
  this.nczdg_mapCount = null;
  this.nczdg_mapBreakdown = null;
  this.nczdg_mapBuilt = false;
  return result;
}

// --------------------------------------------------------------------------------------
// Content - mirrors district-info.js show()
// --------------------------------------------------------------------------------------
@if(ModuleExists("NCZoning.Api"))
@addMethod(WorldMapMenuGameController)
private final func NCZDG_UpdateMapSection(district: gamedataDistrict, subdistrict: gamedataDistrict) -> Void {
  let cfg = NCZDGConfig.Get();

  // Setting off: hide this widget only. The native block is untouched either way.
  if !IsDefined(cfg) || !cfg.enableMapPanel {
    if IsDefined(this.nczdg_mapPanel) {
      this.nczdg_mapPanel.SetVisible(false);
    }
    return;
  }

  // Same area as the last hover: nothing to redo (hover fires on every mouse move).
  if this.nczdg_mapBuilt
     && Equals(district, this.nczdg_mapLastDistrict)
     && Equals(subdistrict, this.nczdg_mapLastSub) {
    return;
  }
  this.nczdg_mapLastDistrict = district;
  this.nczdg_mapLastSub = subdistrict;

  if !this.NCZDG_EnsureMapSection() {
    return;
  }
  this.nczdg_mapBuilt = true;

  // No registry data: say so. Every count below would read 0, and "NO REGISTERED LOCATIONS" for a
  // district nothing is known about is a lie. The core's own banner carries the fix; the short
  // label is used here because this block has no room for a sentence.
  if !NCZDG_HasData() {
    this.nczdg_mapPanel.SetVisible(true);
    this.nczdg_mapCount.SetText(NCZDG_NoDataLabel());
    this.nczdg_mapCount.BindProperty(n"tintColor", n"MainColors.Red");
    this.nczdg_mapBreakdown.RemoveAllChildren();
    this.nczdg_mapBreakdown.SetVisible(false);
    this.nczdg_mapRecent.SetVisible(false);
    NCZDGWarn("[MAP] no registry data - showing the no-data label");
    return;
  }

  // Prefer the subdistrict (the most specific area the map reports); fall back to the district.
  // NCZDG_ResolveFromEnum walks parents, so an unmapped record still resolves.
  let here: ref<NCZDistrictName>;
  if NotEquals(subdistrict, gamedataDistrict.Invalid) {
    here = NCZDG_ResolveFromEnum(subdistrict);
  }
  if !IsDefined(here) && NotEquals(district, gamedataDistrict.Invalid) {
    here = NCZDG_ResolveFromEnum(district);
  }

  // Nothing resolved = the cursor is outside every district polygon. The game's own default for
  // that is the Badlands (which has no polygon at all), so mirror it rather than hiding: report
  // the whole Badlands district. The map cannot report a Badlands SUBdistrict, so this is always
  // the district total.
  let badlandsDefault = false;
  if !IsDefined(here) {
    here = NCZDG_ResolveFromEnum(gamedataDistrict.Badlands);
    badlandsDefault = true;
  }

  // Only if that also fails (core data not ready) does the panel hide.
  if !IsDefined(here) {
    this.nczdg_mapPanel.SetVisible(false);
    return;
  }
  this.nczdg_mapPanel.SetVisible(true);

  // The Badlands default must ignore matchSubdistrict and count the whole district.
  let locs: array<ref<NCZLocation>>;
  if badlandsDefault {
    locs = GetLocationsByDistrict("Badlands");
  } else {
    locs = NCZDG_LocationsHere(here);
  }
  // Not logged: the hover callback fires continuously as the cursor crosses the map, so a line
  // here buries a whole session's worth of everything else.
  let count = ArraySize(locs);

  this.nczdg_mapBreakdown.RemoveAllChildren();

  // 0 is a real, resolved answer - say so rather than hiding, which reads as broken. The web
  // panel hides the breakdown line in this case too.
  if count <= 0 {
    this.nczdg_mapCount.SetText("NO REGISTERED LOCATIONS");
    this.nczdg_mapCount.BindProperty(n"tintColor", n"MainColors.Grey");
    this.nczdg_mapBreakdown.SetVisible(false);
    this.nczdg_mapRecent.SetVisible(false);
    return;
  }

  let plural = count == 1 ? " LOCATION" : " LOCATIONS";
  this.nczdg_mapCount.SetText(s"\(count)\(plural)");
  this.nczdg_mapCount.BindProperty(n"tintColor", n"MainColors.White");

  // Category breakdown, in the web panel's order: new -> overhaul -> other.
  let newCount: Int32 = 0;
  let overhaulCount: Int32 = 0;
  let otherCount: Int32 = 0;
  let i = 0;
  while i < count {
    let cat = locs[i].Category();
    if UnicodeStringEqual(cat, "new-location") {
      newCount += 1;
    } else {
      if UnicodeStringEqual(cat, "location-overhaul") {
        overhaulCount += 1;
      } else {
        otherCount += 1;   // unknown categories bucket to "other", as the web does
      }
    }
    i += 1;
  }

  let first = true;
  first = this.NCZDG_AddBreakdown(newCount, "NEW LOCATION", n"MainColors.Gold", first);
  first = this.NCZDG_AddBreakdown(overhaulCount, "OVERHAUL", n"MainColors.Blue", first);
  first = this.NCZDG_AddBreakdown(otherCount, "OTHER", n"MainColors.Grey", first);
  this.nczdg_mapBreakdown.SetVisible(true);

  // Recency, mirroring the web district panel's "N recently updated". A sum over the server's
  // per-location bool, not a date comparison - redscript has no clock. Hidden when none are recent.
  let recentCount: Int32 = 0;
  let ri = 0;
  while ri < count {
    if locs[ri].RecentlyUpdated() {
      recentCount += 1;
    }
    ri += 1;
  }
  if recentCount > 0 {
    this.nczdg_mapRecent.SetText(s"\(recentCount) RECENTLY UPDATED");
    this.nczdg_mapRecent.SetVisible(true);
  } else {
    this.nczdg_mapRecent.SetVisible(false);
  }
}

// Append "N LABEL(S)" to the breakdown row, preceded by a separator dot unless it is the first
// segment. Zero-count categories are omitted (as the web does). Returns the new `first` state.
@if(ModuleExists("NCZoning.Api"))
@addMethod(WorldMapMenuGameController)
private final func NCZDG_AddBreakdown(count: Int32, label: String, colour: CName, first: Bool) -> Bool {
  if count <= 0 {
    return first;
  }
  if !first {
    let dot = this.NCZDG_MakeMapText(" - ", n"MainColors.Grey", NCZDG_MapDetailSize());
    dot.Reparent(this.nczdg_mapBreakdown);
  }
  let plural = count == 1 ? "" : "S";
  let seg = this.NCZDG_MakeMapText(s"\(count) \(label)\(plural)", colour, NCZDG_MapDetailSize());
  seg.Reparent(this.nczdg_mapBreakdown);
  return false;
}

// One right-aligned text in the map's own style: raj + main_colors + UpperCase, and the native
// "Medium" weight the district block uses (not Regular).
@if(ModuleExists("NCZoning.Api"))
@addMethod(WorldMapMenuGameController)
private final func NCZDG_MakeMapText(label: String, colour: CName, size: Int32) -> ref<inkText> {
  let t = new inkText();
  t.SetText(label);
  t.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  t.SetFontStyle(n"Medium");
  t.SetFontSize(size);
  t.SetLetterCase(textLetterCase.UpperCase);
  t.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  t.BindProperty(n"tintColor", colour);
  t.SetHorizontalAlignment(textHorizontalAlignment.Right);
  t.SetHAlign(inkEHorizontalAlign.Right);
  return t;
}

// --------------------------------------------------------------------------------------
// Build (once)
// --------------------------------------------------------------------------------------
// The district block is a flow stack: appending lays this section out under the subdistrict name,
// so no absolute positioning is needed (unlike the banner, whose block reflows).
// m_locationAndGangsContainer is the block the game shows/hides around the preloader, so parenting
// inside it inherits that visibility.
@if(ModuleExists("NCZoning.Api"))
@addMethod(WorldMapMenuGameController)
private final func NCZDG_EnsureMapSection() -> Bool {
  if IsDefined(this.nczdg_mapPanel) {
    return true;
  }

  let host = inkWidgetRef.Get(this.m_locationAndGangsContainer) as inkCompoundWidget;
  if !IsDefined(host) {
    NCZDGError("[MAP] locationAndGangsContainer is not a compound widget - cannot inject");
    return false;
  }

  // A plain right-aligned text stack. No logo: a brand mark in the native district-icon slot
  // crowds this block. The banner panel carries the logo instead.
  let panel = new inkVerticalPanel();
  panel.SetName(n"nczdg_map_panel");
  panel.SetChildOrder(inkEChildOrder.Forward);
  panel.SetFitToContent(true);
  panel.SetHAlign(inkEHorizontalAlign.Right);
  panel.SetMargin(new inkMargin(0.0, 24.0, 0.0, 0.0));
  panel.Reparent(host);

  let caption = this.NCZDG_MakeMapText("NC ZONING:", n"MainColors.Blue", NCZDG_MapLabelSize());
  caption.SetName(n"nczdg_map_caption");
  caption.Reparent(panel);

  let count = this.NCZDG_MakeMapText("", n"MainColors.White", NCZDG_MapLabelSize());
  count.SetName(n"nczdg_map_count");
  count.SetMargin(new inkMargin(0.0, 2.0, 0.0, 0.0));
  count.Reparent(panel);

  let breakdown = new inkHorizontalPanel();
  breakdown.SetName(n"nczdg_map_breakdown");
  breakdown.SetChildOrder(inkEChildOrder.Forward);
  breakdown.SetFitToContent(true);
  breakdown.SetHAlign(inkEHorizontalAlign.Right);
  breakdown.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
  breakdown.Reparent(panel);

  // Recency line: green (Approval), below the breakdown. Hidden until a hover fills it in.
  let recent = this.NCZDG_MakeMapText("", n"MainColors.Green", NCZDG_MapDetailSize());
  recent.SetName(n"nczdg_map_recent");
  recent.SetMargin(new inkMargin(0.0, 4.0, 0.0, 0.0));
  recent.SetVisible(false);
  recent.Reparent(panel);

  this.nczdg_mapPanel = panel;
  this.nczdg_mapCount = count;
  this.nczdg_mapBreakdown = breakdown;
  this.nczdg_mapRecent = recent;
  NCZDGLog("[MAP] section injected into the district info block");
  return true;
}
