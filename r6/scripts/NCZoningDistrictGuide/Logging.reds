// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: Logging.reds
// Author: Spuddeh
// Description: DEV ONLY. Global-scope log wrapper (no module, so every file can call it
//              without an import). Codeware is a hard dependency and provides FTLog
//              globally, so no Logs.reds native-signature file is needed and there is no
//              duplicate native-func clash.
//
//              STRIP THIS FILE and every NCZDGLog call site before a release build
//              (no-shipped-logging rule).
// Mod Version: 0.1.0 (Pre-release)
// Credits: psiberx (Codeware)
// ======================================================================================

public func NCZDGLog(value: script_ref<String>) -> Void {
  FTLog(s"[NCZDistrictGuide] \(value)");
}
