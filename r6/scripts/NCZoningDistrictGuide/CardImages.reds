// ======================================================================================
// Mod Name: NC Zoning District Guide
// File: CardImages.reds
// Author: Spuddeh
// Description: Remote location images through the RedIMGRetriever plugin (DigitalVixen),
//              which lifts ink's "can only draw an archived texture" limit.
//
//              SOFT DEPENDENCY, and it must stay soft. Every reference to the plugin,
//              the import included, sits behind @if(ModuleExists("RedIMGRetriever")).
//              Images are decoration: without the plugin the guide loses thumbnails and
//              nothing else. Same shape as DVRCF_DocImage.reds, which is the reference
//              implementation this was read from.
//
//              THE API IS POLL-UNTIL-READY, NOT A CALLBACK. Prepare() returns "" while
//              the fetch is in flight and an atlas ResRef path once it lands, and it is
//              idempotent - call it again each tick until it answers. Failed() is the
//              give-up case. There is no completion event to subscribe to.
//
//              The registry carries two URLs per location: ThumbnailUrl() for the card
//              and PictureUrl() for the full-size lightbox. 296 of 297 live records have
//              both, so an absent URL is the rare case, not the common one.
// Mod Version: 0.1.0 (Pre-release)
// Credits: DigitalVixen (RedIMGRetriever, and the DVRCF_DocImage pattern)
// ======================================================================================

module NCZoningDistrictGuide.Images

@if(ModuleExists("RedIMGRetriever"))
import RedIMGRetriever.*

public class NCZDG_Img {

  @if(ModuleExists("RedIMGRetriever"))
  public static func Available() -> Bool {
    return RedIMG.IsAvailable();
  }
  @if(!ModuleExists("RedIMGRetriever"))
  public static func Available() -> Bool {
    return false;
  }

  // "" while still fetching; an atlas ResRef path once ready. Safe to call every tick.
  @if(ModuleExists("RedIMGRetriever"))
  public static func Prepare(url: String) -> String {
    return RedIMG.PrepareDocImage(url);
  }
  @if(!ModuleExists("RedIMGRetriever"))
  public static func Prepare(url: String) -> String {
    return "";
  }

  // The image's own proportions, for scaling to fit. Defaulting to 1.0 rather than 0.0
  // matters: these divide, and the caller cannot always tell a missing answer from a
  // square image.
  @if(ModuleExists("RedIMGRetriever"))
  public static func UvWidth(url: String) -> Float {
    return RedIMG.GetDocUvWidth(url);
  }
  @if(!ModuleExists("RedIMGRetriever"))
  public static func UvWidth(url: String) -> Float {
    return 1.0;
  }

  @if(ModuleExists("RedIMGRetriever"))
  public static func UvHeight(url: String) -> Float {
    return RedIMG.GetDocUvHeight(url);
  }
  @if(!ModuleExists("RedIMGRetriever"))
  public static func UvHeight(url: String) -> Float {
    return 1.0;
  }

  @if(ModuleExists("RedIMGRetriever"))
  public static func Failed(url: String) -> Bool {
    return RedIMG.IsDocFailed(url);
  }
  @if(!ModuleExists("RedIMGRetriever"))
  public static func Failed(url: String) -> Bool {
    return false;
  }
}

// One in-flight image. Held by the popup until Prepare() answers or Failed() gives up.
public class NCZDGPendingImage {
  public let url: String;
  public let image: wref<inkImage>;
  // The box to fit inside. The image is scaled to fit WITHIN this, never cropped to fill
  // it: ink has no clip-children facility at all (no clipChildren anywhere in the RTTI
  // dump), so anything larger than its parent draws straight over the rest of the card.
  // Fit-and-letterbox is not a stylistic choice here, it is the only option.
  public let boxW: Float;
  public let boxH: Float;
  public let applied: Bool;
  // -1 for the lightbox, which has no card slot.
  public let slotIdx: Int32;
}
