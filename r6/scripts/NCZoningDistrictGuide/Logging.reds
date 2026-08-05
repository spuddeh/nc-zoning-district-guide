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
//              The level goes through RedLog.AppendLevel, which writes it as a tag RedLogger
//              owns. The level is set at the wrapper and never at a call site, so it cannot
//              be typed wrong. An unrecognised level string would normalise to INFO rather
//              than being dropped, so a typo could only ever downgrade a line.
//
//              REQUIRES REDLOGGER 1.2.0+, which is where AppendLevel arrives. The stated
//              floor is 1.3.0 because RCF 2.1.0 needs that much, so this adds no new
//              requirement - but it does mean the level tag is not optional dressing, it is
//              the thing an older RedLogger cannot resolve.
//
//              THE LOG IS READ IN-GAME, not just on disk: RCF's hub renders each line as a
//              plain label (truncated at 600 chars, DVRCF_LogsProvider). RCF 2.1.0 colours
//              on the tag - errors red, warnings amber, debug dimmed - and its SHOWING filter
//              selects on it, so a correctly levelled line is findable in a way a prefix
//              written into the text never was. Keep a line short and self-describing.
// Mod Version: 1.0.0
// Credits: DigitalVixen (RedLogger)
// ======================================================================================

import RedLogger.*

// Something happened that a user would recognise. The mod is working.
public func NCZDGLog(value: script_ref<String>) -> Void {
  RedLog.AppendLevel("NCZoningDistrictGuide", "INFO", s"\(value)");
}

// A feature is skipped or degraded, and the player may not have asked for that.
public func NCZDGWarn(value: script_ref<String>) -> Void {
  RedLog.AppendLevel("NCZoningDistrictGuide", "WARN", s"\(value)");
}

// A feature cannot run at all. If a bug report has one of these, it is the answer.
public func NCZDGError(value: script_ref<String>) -> Void {
  RedLog.AppendLevel("NCZoningDistrictGuide", "ERROR", s"\(value)");
}
