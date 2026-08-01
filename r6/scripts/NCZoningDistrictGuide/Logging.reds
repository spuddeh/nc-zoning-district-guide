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
//              RedLog.Append takes no level; encode any level in the line text.
//              [[CP2077-Mods/wiki/decisions/redlogger-is-the-shipping-logging-path]]
// Mod Version: 0.1.0 (Pre-release)
// Credits: DigitalVixen (RedLogger)
// ======================================================================================

import RedLogger.*

public func NCZDGLog(value: script_ref<String>) -> Void {
  RedLog.Append("NCZoningDistrictGuide", s"\(value)");
}
