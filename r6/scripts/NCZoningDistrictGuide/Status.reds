// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Status.reds
// Author: Spuddeh
// Description: One place to ask "does the registry actually have data", so that no surface
//              renders a count it cannot stand behind.
//
//              A ZERO COUNT AND NO-DATA MUST NEVER LOOK THE SAME. "0 registered locations in
//              Kabuki" is a real, resolved answer and an invitation to a modder. "No location
//              data" means the registry never loaded and nothing is known about Kabuki at all.
//              Every count in this mod comes from a query that returns an empty array in BOTH
//              cases, so a surface that does not check IsReady() first will tell the player a
//              district is empty when the truth is that the fetch failed.
//
//              The wording belongs to the core (NCZoning.Api.GetStatusMessage), which owns the
//              single copy that its own red banner also uses. Do not restate it here: two copies
//              drift, and then the mod and the framework blame different things for one failure.
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

@if(ModuleExists("NCZoning.Api"))
import NCZoning.Api.*

// True when the registry holds usable locations. False = the fetch failed, or the core is absent.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_HasData() -> Bool {
  return IsReady();
}

@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_HasData() -> Bool {
  return false;
}

// Usable data that can never refresh (no RedHttpClient, serving a hand-supplied file).
// Informational, NOT an error: counts are valid, so render them and mark them cached.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_IsCached() -> Bool {
  return IsReady() && UnicodeStringEqual(GetStatusReason(), "offline_snapshot");
}

@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_IsCached() -> Bool {
  return false;
}

// The core's player-facing sentence for the current state ("" when live). Explains how to fix it.
@if(ModuleExists("NCZoning.Api"))
public func NCZDG_StatusText() -> String {
  return GetStatusMessage();
}

@if(!ModuleExists("NCZoning.Api"))
public func NCZDG_StatusText() -> String {
  return "";
}

// The short form, for surfaces with no room for a sentence (the map's corner block). It carries no
// reason detail, so it cannot contradict the core's message.
public func NCZDG_NoDataLabel() -> String {
  return "NO LOCATION DATA";
}
