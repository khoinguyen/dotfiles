#!/usr/bin/env python3
"""
Camera Cleanup — delete from camera what's already in Photos
-------------------------------------------------------------
Scans a camera / SD card directory for photo and video files, checks each
against the macOS Photos library by original filename, and deletes the ones
that have already been imported.

Matching logic
  Filename match  : camera file "DSC00123.ARW" matches a Photos asset whose
                    PHAssetResource originalFilename == "DSC00123.ARW"
                    (case-insensitive).
  Optional --since: only consider Photos assets captured on or after the
                    given date, so files from an earlier trip are not matched.

Safety
  --dry-run (default) prints what WOULD be deleted without touching anything.
  Pass --confirm to actually delete.
  The script never touches the Photos library itself.

Requirements:
    pip3 install pyobjc-framework-Photos rich

Usage:
    # Preview matches (safe — no files deleted)
    python3 delete_camera_imported.py --camera /Volumes/MY_CAMERA

    # Actually delete matched files
    python3 delete_camera_imported.py --camera /Volumes/MY_CAMERA --confirm

    # Restrict matching to imports since a date
    python3 delete_camera_imported.py --camera /Volumes/MY_CAMERA --since 2025-03-01 --confirm

    # Walk only a sub-folder on the card (e.g. DCIM)
    python3 delete_camera_imported.py --camera /Volumes/MY_CAMERA/DCIM --confirm
"""

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── Optional: rich ────────────────────────────────────────────────────────────
try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
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


# ── Constants ─────────────────────────────────────────────────────────────────
MEDIA_EXTENSIONS = {
    # RAW
    ".arw", ".cr2", ".cr3", ".crw", ".dng", ".erf", ".kdc", ".mef",
    ".mrw", ".nef", ".nrw", ".orf", ".pef", ".raf", ".raw", ".rw2",
    ".rwl", ".sr2", ".srf", ".srw", ".x3f",
    # JPEG / HEIC / PNG
    ".jpg", ".jpeg", ".heic", ".heif", ".png", ".tif", ".tiff",
    # Video
    ".mp4", ".mov", ".m4v", ".avi", ".mts", ".m2ts", ".3gp", ".xavc",
}


# ── Helpers ───────────────────────────────────────────────────────────────────
def log(msg: str, style: str = ""):
    if HAS_RICH:
        console.print(msg, style=style)
    else:
        print(msg)


def parse_since(since_str: str) -> datetime:
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(since_str, fmt).astimezone(timezone.utc)
        except ValueError:
            pass
    raise ValueError(
        f"Cannot parse --since value: '{since_str}'. Use YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss"
    )


def request_photos_access() -> bool:
    status = Photos.PHPhotoLibrary.authorizationStatus()
    if status == 3:
        return True
    Photos.PHPhotoLibrary.requestAuthorization_(lambda s: None)
    import time; time.sleep(2)
    return Photos.PHPhotoLibrary.authorizationStatus() == 3


# ── Build Photos filename index ───────────────────────────────────────────────
def build_imported_filenames(since_utc: "datetime | None") -> set[str]:
    """
    Return a set of lowercase original filenames for every asset in the
    Photos library (optionally filtered by creationDate >= since_utc).
    """
    fetch_options = Photos.PHFetchOptions.alloc().init()
    if since_utc is not None:
        ns_since = Foundation.NSDate.dateWithTimeIntervalSince1970_(since_utc.timestamp())
        predicate = Foundation.NSPredicate.predicateWithFormat_argumentArray_(
            "creationDate >= %@", [ns_since]
        )
        fetch_options.setPredicate_(predicate)

    filenames: set[str] = set()
    for media_type in (Photos.PHAssetMediaTypeImage, Photos.PHAssetMediaTypeVideo):
        result = Photos.PHAsset.fetchAssetsWithMediaType_options_(media_type, fetch_options)
        for i in range(result.count()):
            asset = result.objectAtIndex_(i)
            resources = Photos.PHAssetResource.assetResourcesForAsset_(asset)
            for j in range(resources.count()):
                r = resources.objectAtIndex_(j)
                fname = r.originalFilename()
                if fname:
                    filenames.add(fname.lower())

    return filenames


# ── Scan camera ───────────────────────────────────────────────────────────────
def scan_camera(camera_root: Path) -> list[Path]:
    """Recursively find all media files on the camera/SD card."""
    files = []
    for p in sorted(camera_root.rglob("*")):
        if p.is_file() and p.suffix.lower() in MEDIA_EXTENSIONS:
            files.append(p)
    return files


# ── Main ──────────────────────────────────────────────────────────────────────
def run(camera_root: Path, since_utc: "datetime | None", confirm: bool):
    since_label = (
        since_utc.astimezone().strftime("%Y-%m-%d %H:%M:%S local")
        if since_utc else "all time"
    )
    action_label = "[bold red]DELETE[/bold red]" if confirm else "[yellow]DRY RUN[/yellow]"

    if HAS_RICH:
        console.print(Panel.fit(
            f"[bold cyan]Camera Cleanup[/bold cyan]\n"
            f"Camera root : [green]{camera_root}[/green]\n"
            f"Since       : {since_label}\n"
            f"Mode        : {action_label}",
            border_style="cyan"
        ))
    else:
        print(f"\n{'='*52}")
        print(f"  Camera Cleanup")
        print(f"  Camera root : {camera_root}")
        print(f"  Since       : {since_label}")
        print(f"  Mode        : {'DELETE' if confirm else 'DRY RUN'}")
        print(f"{'='*52}\n")

    if not request_photos_access():
        log("Photos access denied. Go to System Settings -> Privacy -> Photos.", "red")
        sys.exit(1)

    log("Building Photos filename index...", "cyan")
    imported = build_imported_filenames(since_utc)
    log(f"   {len(imported):,} filenames indexed from Photos library.\n", "green")

    log("Scanning camera...", "cyan")
    camera_files = scan_camera(camera_root)
    log(f"   {len(camera_files):,} media files found on camera.\n", "green")

    if not camera_files:
        log("No media files found on camera — nothing to do.", "yellow")
        return

    matched: list[Path] = []
    unmatched: list[Path] = []

    for f in camera_files:
        if f.name.lower() in imported:
            matched.append(f)
        else:
            unmatched.append(f)

    # ── Report ──
    if HAS_RICH:
        table = Table(title=f"Matched ({len(matched):,} files)", show_lines=False)
        table.add_column("File", style="cyan")
        table.add_column("Size", justify="right")
        for f in matched:
            size_kb = f.stat().st_size / 1024
            size_str = f"{size_kb/1024:.1f} MB" if size_kb > 1024 else f"{size_kb:.0f} KB"
            table.add_row(str(f.relative_to(camera_root)), size_str)
        console.print(table)
    else:
        print(f"\nMatched ({len(matched):,} files to {'delete' if confirm else 'would delete'}):")
        for f in matched:
            size_kb = f.stat().st_size / 1024
            size_str = f"{size_kb/1024:.1f} MB" if size_kb > 1024 else f"{size_kb:.0f} KB"
            print(f"  {f.relative_to(camera_root)}  ({size_str})")

    total_bytes = sum(f.stat().st_size for f in matched)
    total_mb = total_bytes / (1024 * 1024)

    log(f"\n   Matched   : {len(matched):,} files  ({total_mb:.1f} MB would be freed)")
    log(f"   Unmatched : {len(unmatched):,} files  (not yet in Photos — will NOT be touched)")

    if not matched:
        log("\nNothing to delete.", "yellow")
        return

    if not confirm:
        log("\n[yellow]Dry run — no files deleted. Pass --confirm to delete.[/yellow]"
            if HAS_RICH else "\nDry run — no files deleted. Pass --confirm to delete.")
        return

    # ── Delete ──
    log("\nDeleting matched files...", "bold red")
    deleted = 0
    errors = 0
    for f in matched:
        try:
            f.unlink()
            log(f"   deleted  {f.relative_to(camera_root)}")
            deleted += 1
        except OSError as e:
            log(f"   [red]error[/red]  {f.relative_to(camera_root)}: {e}"
                if HAS_RICH else f"   error  {f.relative_to(camera_root)}: {e}")
            errors += 1

    log(f"\nDone!  Deleted {deleted:,} files, {errors:,} errors.", "bold green")


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Delete from a camera/SD card files that are already in the macOS Photos library."
    )
    parser.add_argument("--camera", required=True,
        help="Path to the camera or SD card root, e.g. /Volumes/MY_CAMERA or /Volumes/MY_CAMERA/DCIM")
    parser.add_argument("--since",
        help="Only match Photos assets captured on or after this date (local time). "
             "Format: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss")
    parser.add_argument("--confirm", action="store_true",
        help="Actually delete matched files. Without this flag the script is a dry run.")
    args = parser.parse_args()

    camera_root = Path(args.camera).expanduser().resolve()
    if not camera_root.exists():
        log(f"Camera path does not exist: {camera_root}", "red")
        sys.exit(1)
    if not camera_root.is_dir():
        log(f"Camera path is not a directory: {camera_root}", "red")
        sys.exit(1)

    since_utc = None
    if args.since:
        try:
            since_utc = parse_since(args.since)
        except ValueError as e:
            log(str(e), "red")
            sys.exit(1)

    run(camera_root, since_utc, confirm=args.confirm)


if __name__ == "__main__":
    main()
