// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Logging.reds
// Author: Spuddeh
// Description: SHIPPED. Global-scope log wrapper (no module, so every file can call it
//              without an import). Writes through RedLogger, a hard dependency, into
//              r6/logs/mods/NCZoningDistrictGuide__<date_time>.log - one file per mod per
//              session, five sessions kept, oldest pruned.
//
//              THIS FILE IS NOT Logs.reds AND MUST NEVER BECOME IT. Logs.reds carries a
//              `native func` declaration, and redscript compiles every installed mod into
//              ONE unit, so two mods each shipping one is a duplicate declaration that
//              breaks every redscript mod on the machine. RedLogger's signature ships once
//              inside the plugin, so callers cannot collide, and these calls are therefore
//              safe to ship.
//
//              STILL STRIPPED BEFORE RELEASE: FTLog, Log, LogChannel*, LogWarning, LogError.
//
//              RedLog.Append takes no level, so the level lives in the line text - written
//              at the wrapper, never at a call site, so it cannot be typed wrong.
//
//              THE LOG IS READ IN-GAME, not just on disk: RCF's hub renders each line as a
//              plain label (truncated at 600 chars, DVRCF_LogsProvider). A line has no
//              filtering behind it, so keep it short and self-describing, and keep the whole
//              log short enough to read as a column.
//              [[CP2077-Mods/wiki/decisions/redlogger-is-the-shipping-logging-path]]
// Mod Version: 1.0.0
// Credits: DigitalVixen (RedLogger)
// ======================================================================================

import RedLogger.*

// The prefixes are padded to one width, so the levels line up in RCF's viewer.

// Something happened that a user would recognise. The mod is working.
public func NCZDGLog(value: script_ref<String>) -> Void {
  RedLog.Append("NCZoningDistrictGuide", s"[INFO ] \(value)");
}

// A feature is skipped or degraded, and the player may not have asked for that.
public func NCZDGWarn(value: script_ref<String>) -> Void {
  RedLog.Append("NCZoningDistrictGuide", s"[WARN ] \(value)");
}

// A feature cannot run at all. If a bug report has one of these, it is the answer.
public func NCZDGError(value: script_ref<String>) -> Void {
  RedLog.Append("NCZoningDistrictGuide", s"[ERROR] \(value)");
}
