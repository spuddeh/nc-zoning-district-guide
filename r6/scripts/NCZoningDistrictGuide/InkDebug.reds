// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: InkDebug.reds
// Author: Spuddeh
// Description: DEV ONLY. A recursive ink-widget tree dumper, used to understand the notification
//              layer so we can position/scale our fast-travel panel to match the banner one.
//              Logs each widget's class, name, size, scale, translation, anchor, margin and child
//              count. Strip with the rest of the logging before release.
//
//              This is the same information RedHotTools' InkInspector shows, dumped to the log so
//              it is captured for future reference (understanding the banner vs virtual-window
//              coordinate spaces, whether a parent applies scale/margin, etc.).
// Mod Version: 0.1.0 (Pre-release)
// Credits: Spuddeh (NCZoningCore)
// ======================================================================================

// Walks `w` and its descendants, logging geometry at each node. `depth` indents; `maxDepth`
// bounds it. Global scope (no module) so any file can call it.
public func NCZDG_DumpWidget(w: wref<inkWidget>, depth: Int32, maxDepth: Int32) -> Void {
  if !IsDefined(w) || depth > maxDepth {
    return;
  }
  let indent = "";
  let i = 0;
  while i < depth {
    indent += "  ";
    i += 1;
  }

  let size = w.GetSize();
  let scale = w.GetScale();
  let trans = w.GetTranslation();
  let margin = w.GetMargin();
  let cls = NameToString(w.GetClassName());
  let name = NameToString(w.GetName());

  let childCount = 0;
  let comp = w as inkCompoundWidget;
  if IsDefined(comp) {
    childCount = comp.GetNumChildren();
  }

  NCZDGLog(s"\(indent)[\(cls)] '\(name)' size=(\(size.X),\(size.Y)) scale=(\(scale.X),\(scale.Y)) trans=(\(trans.X),\(trans.Y)) margin=(\(margin.left),\(margin.top)) kids=\(childCount)");

  if IsDefined(comp) {
    let c = 0;
    while c < childCount {
      NCZDG_DumpWidget(comp.GetWidgetByIndex(c), depth + 1, maxDepth);
      c += 1;
    }
  }
}
