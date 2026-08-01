// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Logging.reds
// Author: Spuddeh
// Description: SHIPPED. Global-scope log wrapper (no module, so every file can call it
//              without an import). Writes through RedLogger, a hard dependency, into
//              r6/logs/mods/NCZoningDistrictGuide__<date_time>.log - one file per mod per
//              session, five sessions kept, oldest pruned. A user reporting a bug can be
//              asked for that one file instead of a shared log or a debug build.
//
//              THIS FILE IS NOT Logs.reds AND MUST NEVER BECOME IT. Logs.reds carries a
//              `native func` declaration, and redscript compiles every installed mod into
//              ONE unit, so two mods each shipping one is a duplicate declaration that
//              breaks every redscript mod on the machine. RedLogger's signature ships once
//              inside the plugin, so no number of callers can collide. That difference is
//              the entire reason these calls may ship.
//
//              STILL STRIPPED BEFORE RELEASE: FTLog, Log, LogChannel*, LogWarning,
//              LogError. The dev instruments that were stripped alongside them
//              (InkDebug.reds, MapWakeProbe.reds) are gone as of 1.0.0 - they were
//              instruments, not logging, and the distinction is why this file stayed.
//
//              RedLog.Append takes no level, so the level lives in the line text - but at
//              a wrapper, never at the call site. Three functions instead of a level
//              argument, because a literal prefix typed 26 times is a prefix that will be
//              typed wrong once and never grep the same again.
//
//              THE LOG IS USER-VISIBLE IN-GAME, not just on disk: RCF's hub reads
//              RedLogger's files and renders each line as a plain label (truncated at 600
//              chars, DVRCF_LogsProvider). So a line is read by a person, in a list, with
//              no filtering - which is the whole argument for the fixed-width prefix, and
//              for there being ~26 lines rather than ~54.
//              [[CP2077-Mods/wiki/decisions/redlogger-is-the-shipping-logging-path]]
// Mod Version: 0.1.0 (Pre-release)
// Credits: DigitalVixen (RedLogger)
// ======================================================================================

import RedLogger.*

// The prefixes are padded to one width on purpose: the levels then line up in RCF's viewer,
// where the lines are read as a column and there is nothing to filter with.

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
