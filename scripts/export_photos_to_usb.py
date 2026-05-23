#!/usr/bin/env python3
"""
macOS Photos -> USB Exporter
------------------------------
Exports photos AND videos from macOS Photos app to a destination folder.

Features:
  - --since YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss  to filter by capture date
  - RAW files (.ARW etc.) converted to JPG via rawpy
  - Videos converted to H.264/AAC .mp4 via ffmpeg (universally compatible:
    Windows, Android, iPhone, social media upload)
  - Organises output into YYYY-MM-DD folders by capture date
  - Handles ZV-1 II RAW+JPEG pairs (exports both; RAW -> JPG, JPEG copied as-is)
  - Safe to re-run: already-exported files are skipped

Requirements:
    pip3 install pyobjc-framework-Photos Pillow rawpy rich
    brew install ffmpeg          # for video conversion

Usage:
    # Export everything
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB

    # Export only since a date
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --since 2025-03-01
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --since 2025-03-01T14:30:00

    # Preview without writing
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --since 2025-03-01 --dry-run

    # Custom JPEG quality
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --quality 90

    # Export only videos or only images (mutually exclusive)
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --video-only
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --image-only

    # Skip auto-eject (default: ejects USB + sends macOS notification when done)
    python3 export_photos_to_usb.py --dest /Volumes/MY_USB --no-eject
"""

import argparse
import os
import re
import subprocess
import shutil
import sys
import threading
from datetime import datetime, timezone
from pathlib import Path

# ── Optional: rich ────────────────────────────────────────────────────────────
try:
    from rich.progress import Progress, SpinnerColumn, BarColumn, TextColumn, TimeElapsedColumn
    from rich.console import Console
    from rich.panel import Panel
    HAS_RICH = True
    console = Console()
except ImportError:
    HAS_RICH = False

# ── pyobjc Photos framework ───────────────────────────────────────────────────
try:
    import Photos  # type: ignore[import-untyped]
    import Foundation  # type: ignore[import-untyped]
except ImportError:
    print("Missing: pyobjc-framework-Photos")
    print("Install: pip3 install pyobjc-framework-Photos")
    sys.exit(1)

# ── Image libs ────────────────────────────────────────────────────────────────
try:
    from PIL import Image
    import rawpy
except ImportError:
    print("Missing: Pillow or rawpy")
    print("Install: pip3 install Pillow rawpy")
    sys.exit(1)


# ── Constants ─────────────────────────────────────────────────────────────────
RAW_EXTENSIONS = {
    ".arw", ".cr2", ".cr3", ".crw", ".dng", ".erf", ".kdc", ".mef",
    ".mrw", ".nef", ".nrw", ".orf", ".pef", ".raf", ".raw", ".rw2",
    ".rwl", ".sr2", ".srf", ".srw", ".x3f",
}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v", ".avi", ".mts", ".m2ts", ".3gp"}

# PHAssetResourceType constants
RES_TYPE_PHOTO        = 1   # PHAssetResourceTypePhoto
RES_TYPE_VIDEO        = 3   # PHAssetResourceTypeVideo
RES_TYPE_PAIRED_VIDEO = 8   # PHAssetResourceTypePairedVideo (Live Photo video)
RES_TYPE_ALT_PHOTO    = 13  # PHAssetResourceTypeAlternatePhoto (JPEG when RAW+JPEG pair)

TMP_DIR = Path("/tmp/photos_export_tmp")


# ── Helpers ───────────────────────────────────────────────────────────────────
def log(msg: str, style: str = ""):
    if HAS_RICH:
        console.print(msg, style=style)
    else:
        print(msg)


def check_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def send_notification(title: str, body: str) -> None:
    """Send a macOS notification via osascript."""
    t = title.replace('"', '\\"')
    b = body.replace('"', '\\"')
    try:
        subprocess.run(
            ["osascript", "-e", f'display notification "{b}" with title "{t}"'],
            check=False, capture_output=True, timeout=10
        )
    except Exception:
        pass


def eject_volume(path: Path) -> bool:
    """Eject the volume containing path via diskutil. Returns True on success."""
    try:
        result = subprocess.run(
            ["diskutil", "eject", str(path)],
            capture_output=True, text=True, timeout=30
        )
        return result.returncode == 0
    except Exception:
        return False


def parse_since(since_str: str) -> datetime:
    """Parse YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss into a timezone-aware UTC datetime."""
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(since_str, fmt)
            # Treat as local time, convert to UTC for comparison with Photos timestamps
            return dt.astimezone(timezone.utc)
        except ValueError:
            pass
    raise ValueError(f"Cannot parse --since value: '{since_str}'. Use YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss")


def request_photos_access() -> bool:
    status = Photos.PHPhotoLibrary.authorizationStatus()
    if status == 3:
        return True
    Photos.PHPhotoLibrary.requestAuthorization_(lambda s: None)
    import time; time.sleep(2)
    return Photos.PHPhotoLibrary.authorizationStatus() == 3


def fetch_assets(since_utc: "datetime | None" = None,
                 video_only: bool = False, image_only: bool = False) -> list:
    """
    Fetch image and/or video assets, optionally filtered to creationDate >= since_utc.
    Returns a combined sorted list of PHAsset objects.
    """
    fetch_options = Photos.PHFetchOptions.alloc().init()
    fetch_options.setSortDescriptors_([
        Foundation.NSSortDescriptor.sortDescriptorWithKey_ascending_("creationDate", True)
    ])

    if since_utc is not None:
        # Build NSPredicate for creationDate >= since
        ns_since = Foundation.NSDate.dateWithTimeIntervalSince1970_(since_utc.timestamp())
        predicate = Foundation.NSPredicate.predicateWithFormat_argumentArray_(
            "creationDate >= %@", [ns_since]
        )
        fetch_options.setPredicate_(predicate)

    if video_only:
        media_types = (Photos.PHAssetMediaTypeVideo,)
    elif image_only:
        media_types = (Photos.PHAssetMediaTypeImage,)
    else:
        media_types = (Photos.PHAssetMediaTypeImage, Photos.PHAssetMediaTypeVideo)

    assets = []
    for media_type in media_types:
        result = Photos.PHAsset.fetchAssetsWithMediaType_options_(media_type, fetch_options)
        for i in range(result.count()):
            assets.append(result.objectAtIndex_(i))

    # Sort combined list by creation date
    def creation_ts(a):
        d = a.creationDate()
        return d.timeIntervalSince1970() if d else 0.0
    assets.sort(key=creation_ts)
    return assets


def get_capture_date(asset) -> str:
    ns_date = asset.creationDate()
    if ns_date is None:
        return "unknown-date"
    return datetime.fromtimestamp(ns_date.timeIntervalSince1970()).strftime("%Y-%m-%d")


def get_resources(asset) -> list:
    """Return list of (resource, type_int, filename) tuples for an asset."""
    resources = Photos.PHAssetResource.assetResourcesForAsset_(asset)
    out = []
    for i in range(resources.count()):
        r = resources.objectAtIndex_(i)
        out.append((r, r.type(), r.originalFilename()))
    return out


def write_resource_to_tmp(resource) -> "Path | None":
    """Write a single PHAssetResource to TMP_DIR, return path or None."""
    filename = resource.originalFilename()
    tmp_path = TMP_DIR / filename
    if tmp_path.exists():
        tmp_path.unlink()

    resource_manager = Photos.PHAssetResourceManager.defaultManager()
    req_options = Photos.PHAssetResourceRequestOptions.alloc().init()
    file_url = Foundation.NSURL.fileURLWithPath_(str(tmp_path))

    done_event = threading.Event()
    err_holder = [None]

    def completion(error):
        err_holder[0] = error
        done_event.set()

    resource_manager.writeDataForAssetResource_toFile_options_completionHandler_(
        resource, file_url, req_options, completion
    )

    if not done_event.wait(timeout=120):
        return None
    error = err_holder[0]
    if error is not None and str(error) != "None":
        return None
    return tmp_path if tmp_path.exists() else None


# ── Conversion ────────────────────────────────────────────────────────────────
def convert_raw_to_jpg(raw_path: Path, jpg_path: Path, quality: int) -> bool:
    try:
        with rawpy.imread(str(raw_path)) as raw:
            rgb = raw.postprocess(use_camera_wb=True, half_size=False,
                                  no_auto_bright=False, output_bps=8)
        Image.fromarray(rgb).save(str(jpg_path), "JPEG", quality=quality, optimize=True)
        return True
    except Exception as e:
        log(f"    [yellow]RAW conversion failed {raw_path.name}: {e}[/yellow]" if HAS_RICH
            else f"    RAW conversion failed {raw_path.name}: {e}")
        return False


def convert_video_to_mp4(src: Path, dest: Path) -> bool:
    """
    Re-encode video to H.264 + AAC in a .mp4 container.
    - H.264 high profile + yuv420p: plays on Windows, Android, iPhone, social media
    - CRF 23 + preset fast: good quality/size, faster than 'slow' for large ZV-1 II files
    - faststart: moov atom at front for streaming/social upload
    - AAC stereo 192k audio
    Timeout is dynamic: 60s base + 10s per MB (ZV-1 II XAVC-S files can be 1-4 GB).
    """
    size_mb = src.stat().st_size / (1024 * 1024)
    # 60s base + 10s/MB — a 1 GB file gets ~170 min, a 4 GB file gets ~680 min
    timeout = int(60 + size_mb * 10)

    log(f"    Converting {src.name} ({size_mb:.0f} MB), timeout {timeout//60}m {timeout%60}s ...")

    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-c:v", "libx264",
        "-profile:v", "high", "-level", "4.1",
        "-crf", "23",
        "-preset", "fast",          # faster than 'slow'; still much better than copy
        "-pix_fmt", "yuv420p",      # required for Windows Media Player / Android
        "-movflags", "+faststart",  # move moov atom to front for streaming
        "-c:a", "aac",
        "-b:a", "192k",
        "-ac", "2",                 # stereo
        str(dest),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if result.returncode != 0:
            log(f"    ffmpeg error: {result.stderr[-400:]}")
            # Clean up partial output
            if dest.exists():
                dest.unlink()
            return False
        return True
    except subprocess.TimeoutExpired:
        log(f"    ffmpeg timed out for {src.name} after {timeout//60}m — file may be very large.")
        log(f"    Tip: run manually: ffmpeg -i {src} -c:v libx264 -crf 23 -preset fast -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 192k {dest}")
        if dest.exists():
            dest.unlink()
        return False
    except Exception as e:
        log(f"    ffmpeg exception: {e}")
        if dest.exists():
            dest.unlink()
        return False


# ── Per-asset export logic ────────────────────────────────────────────────────
def export_photo_asset(asset, dest_dir: Path, quality: int, dry_run: bool,
                       has_ffmpeg: bool) -> list[tuple[str, str]]:
    """
    Export a photo asset. Handles three cases:
      1. RAW-only shot           -> convert to JPG
      2. RAW+JPEG pair (ZV-1 II) -> copy JPEG + convert RAW to JPG (named _raw.jpg)
      3. Plain JPEG/HEIC/PNG     -> copy as-is
    Returns list of (status, filename) pairs.
    """
    resources = get_resources(asset)
    if not resources:
        return [("error", "?")]

    results = []

    # Categorise resources
    raw_res    = next(((r, t, f) for r, t, f in resources if Path(f).suffix.lower() in RAW_EXTENSIONS), None)
    # ALT_PHOTO (13) = the embedded JPEG in a RAW+JPEG pair
    # plain PHOTO (1) = regular photo
    jpeg_res   = next(((r, t, f) for r, t, f in resources if t == RES_TYPE_ALT_PHOTO), None)
    if jpeg_res is None:
        jpeg_res = next(((r, t, f) for r, t, f in resources if t == RES_TYPE_PHOTO
                         and Path(f).suffix.lower() not in RAW_EXTENSIONS), None)

    # ── Case: has RAW ──
    if raw_res:
        raw_r, _, raw_fname = raw_res
        raw_jpg_name = Path(raw_fname).stem + "_raw.jpg"
        dest_raw_jpg = dest_dir / raw_jpg_name

        if dest_raw_jpg.exists():
            results.append(("skipped", raw_jpg_name))
        elif dry_run:
            results.append(("dry-raw", raw_jpg_name))
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)
            tmp = write_resource_to_tmp(raw_r)
            if tmp:
                ok = convert_raw_to_jpg(tmp, dest_raw_jpg, quality)
                results.append(("converted" if ok else "error", raw_jpg_name))
                tmp.unlink(missing_ok=True)
            else:
                results.append(("error", raw_jpg_name))

    # ── Case: has companion JPEG (or standalone JPEG) ──
    if jpeg_res:
        _, _, jpg_fname = jpeg_res
        dest_jpg = dest_dir / jpg_fname

        if dest_jpg.exists():
            results.append(("skipped", jpg_fname))
        elif dry_run:
            results.append(("dry-copy", jpg_fname))
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)
            tmp = write_resource_to_tmp(jpeg_res[0])
            if tmp:
                shutil.copy2(str(tmp), str(dest_jpg))
                results.append(("copied", jpg_fname))
                tmp.unlink(missing_ok=True)
            else:
                results.append(("error", jpg_fname))

    # ── Case: no RAW and no identified JPEG -> fall back to first resource ──
    if not raw_res and not jpeg_res and resources:
        r, _, fname = resources[0]
        ext = Path(fname).suffix.lower()
        dest_path = dest_dir / fname

        if dest_path.exists():
            results.append(("skipped", fname))
        elif dry_run:
            results.append(("dry-copy", fname))
        else:
            dest_dir.mkdir(parents=True, exist_ok=True)
            tmp = write_resource_to_tmp(r)
            if tmp:
                shutil.copy2(str(tmp), str(dest_path))
                results.append(("copied", fname))
                tmp.unlink(missing_ok=True)
            else:
                results.append(("error", fname))

    return results or [("error", "?")]


def export_video_asset(asset, dest_dir: Path, dry_run: bool,
                       has_ffmpeg: bool) -> list[tuple[str, str]]:
    """
    Export a video asset, converting to H.264/AAC mp4.
    """
    resources = get_resources(asset)
    # Prefer RES_TYPE_VIDEO (3); skip paired video (Live Photo sidecars, type 8)
    video_res = next(((r, t, f) for r, t, f in resources if t == RES_TYPE_VIDEO), None)
    if video_res is None:
        video_res = next(((r, t, f) for r, t, f in resources
                          if Path(f).suffix.lower() in VIDEO_EXTENSIONS
                          and t != RES_TYPE_PAIRED_VIDEO), None)
    if video_res is None:
        return [("error", "no-video-resource")]

    r, _, fname = video_res
    dest_name = Path(fname).stem + ".mp4"
    dest_path = dest_dir / dest_name

    if dest_path.exists():
        return [("skipped", dest_name)]
    if dry_run:
        return [("dry-vid" if has_ffmpeg else "dry-vid-copy", dest_name)]

    dest_dir.mkdir(parents=True, exist_ok=True)
    tmp = write_resource_to_tmp(r)
    if tmp is None:
        return [("error", dest_name)]

    if has_ffmpeg:
        ok = convert_video_to_mp4(tmp, dest_path)
        tmp.unlink(missing_ok=True)
        return [("vid-converted" if ok else "error", dest_name)]
    else:
        # ffmpeg not available: just copy original
        shutil.copy2(str(tmp), str(dest_path))
        tmp.unlink(missing_ok=True)
        return [("copied", dest_name)]


# ── Main export loop ──────────────────────────────────────────────────────────
def run_export(dest_root: Path, quality: int, dry_run: bool, since_utc: "datetime | None",
               video_only: bool = False, image_only: bool = False, eject: bool = True):
    has_ffmpeg = check_ffmpeg()

    since_label = since_utc.astimezone().strftime("%Y-%m-%d %H:%M:%S local") if since_utc else "all time"
    media_label = "videos only" if video_only else ("images only" if image_only else "all")

    if HAS_RICH:
        ffmpeg_note = "[green]yes[/green]" if has_ffmpeg else "[red]no (videos will be copied as-is)[/red]"
        console.print(Panel.fit(
            f"[bold cyan]macOS Photos -> USB Exporter[/bold cyan]\n"
            f"Destination : [green]{dest_root}[/green]\n"
            f"Since       : {since_label}\n"
            f"Media       : {media_label}\n"
            f"JPG quality : {quality}\n"
            f"ffmpeg      : {ffmpeg_note}\n"
            f"Dry run     : {'[yellow]YES[/yellow]' if dry_run else 'No'}",
            border_style="cyan"
        ))
        if not has_ffmpeg:
            console.print("[yellow]  Install ffmpeg for video conversion: brew install ffmpeg[/yellow]")
    else:
        print(f"\n{'='*52}")
        print(f"  macOS Photos -> USB Exporter")
        print(f"  Destination : {dest_root}")
        print(f"  Since       : {since_label}")
        print(f"  Media       : {media_label}")
        print(f"  JPG quality : {quality}")
        print(f"  ffmpeg      : {'yes' if has_ffmpeg else 'NO - videos copied as-is (brew install ffmpeg)'}")
        print(f"  Dry run     : {'YES' if dry_run else 'No'}")
        print(f"{'='*52}\n")

    if not request_photos_access():
        log("Photos access denied. Go to System Settings -> Privacy -> Photos.", "red")
        sys.exit(1)

    TMP_DIR.mkdir(parents=True, exist_ok=True)

    log("Fetching assets...", "cyan")
    assets = fetch_assets(since_utc, video_only=video_only, image_only=image_only)
    total = len(assets)

    photos_count = sum(1 for a in assets if a.mediaType() == Photos.PHAssetMediaTypeImage)
    videos_count = sum(1 for a in assets if a.mediaType() == Photos.PHAssetMediaTypeVideo)
    log(f"   Found {total:,} assets ({photos_count:,} photos, {videos_count:,} videos).\n", "green")

    if total == 0:
        log("Nothing to export.", "yellow")
        return

    stats: dict[str, int] = {}
    dry_video_secs = 0.0

    def process_asset(asset, progress=None, task=None):
        nonlocal dry_video_secs
        date_str = get_capture_date(asset)
        dest_dir = dest_root / date_str
        is_video = asset.mediaType() == Photos.PHAssetMediaTypeVideo

        if progress:
            label = f"[cyan]{date_str}[/cyan] [{'vid' if is_video else 'img'}]"
            progress.update(task, description=label)

        if is_video:
            pairs = export_video_asset(asset, dest_dir, dry_run, has_ffmpeg)
        else:
            pairs = export_photo_asset(asset, dest_dir, quality, dry_run, has_ffmpeg)

        for status, fname in pairs:
            stats[status] = stats.get(status, 0) + 1
            if dry_run and is_video and status == "dry-vid":
                dry_video_secs += asset.duration() or 0.0

        return date_str, pairs

    try:
        if HAS_RICH:
            cols = [SpinnerColumn(), TextColumn("{task.description}"),
                    BarColumn(), TextColumn("{task.completed}/{task.total}"),
                    TimeElapsedColumn()]
            with Progress(*cols, console=console) as progress:
                task = progress.add_task("Exporting...", total=total)
                for asset in assets:
                    process_asset(asset, progress, task)
                    progress.advance(task)
        else:
            for i, asset in enumerate(assets, 1):
                date_str, pairs = process_asset(asset)
                for status, fname in pairs:
                    print(f"[{i}/{total}] {date_str}  {status:<16} {fname}")
    except KeyboardInterrupt:
        log("\n\n[yellow]Interrupted — showing progress so far...[/yellow]" if HAS_RICH
            else "\n\nInterrupted — showing progress so far...")

    # ── Summary ──
    if dry_run:
        log("\n[yellow]DRY RUN — no files written[/yellow]" if HAS_RICH
            else "\nDRY RUN — no files written")
        log(f"   Copied (dry-run)           : {stats.get('dry-copy', 0):,}")
        log(f"   RAW->JPG (dry-run)         : {stats.get('dry-raw', 0):,}")
        vid_to_convert = stats.get('dry-vid', 0)
        log(f"   Videos to convert (dry-run): {vid_to_convert:,}  (H.264/AAC mp4)")
        if stats.get('dry-vid-copy', 0):
            log(f"   Videos to copy (dry-run)   : {stats.get('dry-vid-copy', 0):,}  (no ffmpeg)")
        log(f"   Already skipped            : {stats.get('skipped', 0):,}")
        if dry_video_secs > 0:
            lo = max(1, int(dry_video_secs / 60))
            hi = max(2, int(dry_video_secs * 3 / 60))
            log(f"   Est. video encode time     : {lo}–{hi} min  (rough; varies by hardware)")
    else:
        log("\nDone!", "bold green")
        log(f"   Photos copied      : {stats.get('copied', 0):,}")
        log(f"   RAW->JPG converted : {stats.get('converted', 0):,}")
        log(f"   Videos converted   : {stats.get('vid-converted', 0):,}  (H.264/AAC mp4)")
        log(f"   Skipped (exist)    : {stats.get('skipped', 0):,}")
        log(f"   Errors             : {stats.get('error', 0):,}", "red" if stats.get('error', 0) else "")

    shutil.rmtree(TMP_DIR, ignore_errors=True)

    errors = stats.get('error', 0)
    exported = stats.get('copied', 0) + stats.get('converted', 0) + stats.get('vid-converted', 0)
    notif_body = f"{exported:,} exported · {stats.get('skipped', 0):,} skipped"
    if errors:
        notif_body += f" · {errors:,} errors"

    if eject and not dry_run:
        log("\nEjecting USB...", "cyan")
        if eject_volume(dest_root):
            log("   USB ejected safely. Safe to unplug.", "bold green")
            send_notification("Photos Export Complete", notif_body + " · USB ejected safely")
        else:
            log("   Could not eject — eject manually before unplugging.", "yellow")
            send_notification("Photos Export Complete", notif_body + " · Eject USB manually!")
    else:
        if not dry_run:
            send_notification("Photos Export Complete", notif_body)


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Export macOS Photos+Videos to USB. RAW->JPG, Video->H264 mp4, by date folders."
    )
    parser.add_argument("--dest", required=True,
        help="Destination path, e.g. /Volumes/MY_USB")
    parser.add_argument("--since",
        help="Only export assets captured on or after this date/time (local time). "
             "Format: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss")
    parser.add_argument("--quality", type=int, default=92,
        help="JPEG quality for RAW conversion (1-100, default: 92)")
    parser.add_argument("--dry-run", action="store_true",
        help="Show what would be done without writing any files")
    media_group = parser.add_mutually_exclusive_group()
    media_group.add_argument("--video-only", action="store_true",
        help="Export only video assets")
    media_group.add_argument("--image-only", action="store_true",
        help="Export only photo/image assets")
    parser.add_argument("--no-eject", action="store_true",
        help="Skip auto-ejecting the USB after export completes")
    args = parser.parse_args()

    since_utc = None
    if args.since:
        try:
            since_utc = parse_since(args.since)
            log(f"Filtering: creationDate >= {since_utc.astimezone().strftime('%Y-%m-%d %H:%M:%S')} (local)")
        except ValueError as e:
            log(str(e), "red")
            sys.exit(1)

    dest = Path(args.dest).expanduser().resolve()
    if not args.dry_run:
        if not dest.exists():
            log(f"'{dest}' does not exist -- creating it...")
            dest.mkdir(parents=True, exist_ok=True)
        if not os.access(dest, os.W_OK):
            log(f"Cannot write to '{dest}'. Check USB permissions.", "red")
            sys.exit(1)

    run_export(dest, args.quality, args.dry_run, since_utc,
               video_only=args.video_only, image_only=args.image_only,
               eject=not args.no_eject)


if __name__ == "__main__":
    main()