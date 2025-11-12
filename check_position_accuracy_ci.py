#!/usr/bin/env python3
"""CI-oriented position accuracy checker.

Loads the newest CSV from Logs/PositionAccuracy (unless overridden),
computes the mean PositionError per vehicle, and exits with a non-zero
code if any vehicle exceeds the configured accuracy threshold.
"""

from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
import re

DEFAULT_LOG_DIR = Path("Logs/PositionAccuracy")
DEFAULT_CSV_GLOB = "position_accuracy_*.csv"
DEFAULT_SUMMARY_GLOB = "statistics_summary_*.txt"
DEFAULT_THRESHOLD = 1.5


@dataclass
class VehicleStats:
    vehicle_id: str
    mean_error: float
    sample_count: int


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate position accuracy metrics from CSV logs."
    )
    parser.add_argument(
        "--log-file",
        type=Path,
        help="Explicit CSV log file to analyze. Defaults to the most recent file in Logs/PositionAccuracy.",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=DEFAULT_LOG_DIR,
        help="Directory to search when --log-file is omitted (default: %(default)s).",
    )
    parser.add_argument(
        "--pattern",
        help=(
            "Filename glob to locate logs when --log-file is omitted. "
            "Defaults to searching summary text files first, then CSV logs."
        ),
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD,
        help="Maximum allowed mean position error per vehicle in meters (default: %(default)s).",
    )
    return parser.parse_args(list(argv))


def debug(message: str) -> None:
    print(f"[DEBUG] {message}")


def find_latest_log(log_dir: Path, pattern: Optional[str]) -> Path:
    if not log_dir.exists():
        raise FileNotFoundError(f"Log directory not found: {log_dir}")

    search_patterns: List[str]
    if pattern:
        search_patterns = [pattern]
    else:
        search_patterns = [DEFAULT_SUMMARY_GLOB, DEFAULT_CSV_GLOB]

    for glob_pattern in search_patterns:
        matches = sorted(log_dir.glob(glob_pattern), key=lambda p: p.stat().st_mtime)
        if matches:
            chosen = matches[-1]
            debug(
                f"find_latest_log matched {len(matches)} file(s) with pattern '{glob_pattern}'; "
                f"selected '{chosen}'"
            )
            return chosen
        else:
            debug(f"find_latest_log found no files for pattern '{glob_pattern}'")

    raise FileNotFoundError(
        f"No log files found in {log_dir} using patterns: {', '.join(search_patterns)}"
    )


def load_vehicle_errors(csv_path: Path) -> Dict[str, List[float]]:
    with csv_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if "VehicleID" not in reader.fieldnames or "PositionError" not in reader.fieldnames:
            raise ValueError(
                "CSV missing required columns 'VehicleID' and/or 'PositionError'"
            )

        errors: Dict[str, List[float]] = defaultdict(list)
        for row in reader:
            vid = row.get("VehicleID")
            err_text = row.get("PositionError")
            if not vid or err_text is None:
                continue
            try:
                error = float(err_text)
            except ValueError:
                # Skip malformed entries but keep scanning.
                continue
            errors[vid].append(error)

        if not errors:
            raise ValueError(f"No usable data rows found in {csv_path}")

        return errors


def compute_stats(errors: Dict[str, List[float]]) -> List[VehicleStats]:
    stats: List[VehicleStats] = []
    for vid, samples in sorted(errors.items()):
        mean_error = sum(samples) / len(samples)
        stats.append(VehicleStats(vehicle_id=vid, mean_error=mean_error, sample_count=len(samples)))
    return stats


@dataclass
class SummaryMetadata:
    generated_at: Optional[str] = None
    total_entries: Optional[int] = None
    active_vehicles: Optional[int] = None
    overall_mean: Optional[float] = None
    overall_max: Optional[float] = None


def parse_decimal(text: str) -> float:
    cleaned = text.strip().replace(" m", "").replace("cm", "").replace(" ", "")
    cleaned = cleaned.replace("%", "")
    cleaned = cleaned.replace(",", ".")
    return float(cleaned)


def parse_integer(text: str) -> int:
    digits = ''.join(ch for ch in text if ch.isdigit())
    if not digits:
        raise ValueError(f"Could not parse integer from '{text}'")
    return int(digits)


def load_vehicle_stats_from_summary(path: Path) -> Tuple[List[VehicleStats], SummaryMetadata]:
    if not path.exists():
        raise FileNotFoundError(path)

    size = path.stat().st_size
    debug(f"Summary file '{path}' size: {size} bytes")

    with path.open(encoding="utf-8") as handle:
        lines = handle.readlines()

    if lines:
        preview = ''.join(line.rstrip('\n') + '\n' for line in lines[:10]).rstrip()
        debug(f"Summary preview (first lines):\n{preview}")
    else:
        debug(f"Summary file '{path}' is empty")

    stats: List[VehicleStats] = []
    metadata = SummaryMetadata()

    vehicle_id: Optional[str] = None
    samples: Optional[int] = None

    vehicle_pattern = re.compile(r"^Vehicle:\s*(.+)$", re.IGNORECASE)

    for raw_line in lines:
        line = raw_line.strip()
        if not line:
            continue

        if line.lower().startswith("generated:"):
            metadata.generated_at = line.split(":", 1)[1].strip()
            continue

        if line.lower().startswith("total entries logged:"):
            metadata.total_entries = parse_integer(line.split(":", 1)[1])
            continue

        if line.lower().startswith("active vehicles:"):
            metadata.active_vehicles = parse_integer(line.split(":", 1)[1])
            continue

        if line.lower().startswith("average position error:"):
            metadata.overall_mean = parse_decimal(line.split(":", 1)[1])
            continue

        if line.lower().startswith("maximum position error:"):
            metadata.overall_max = parse_decimal(line.split(":", 1)[1])
            continue

        vehicle_match = vehicle_pattern.match(line)
        if vehicle_match:
            vehicle_id = vehicle_match.group(1).strip()
            samples = None
            continue

        if vehicle_id and line.lower().startswith("samples:"):
            samples = parse_integer(line.split(":", 1)[1])
            continue

        if vehicle_id and line.lower().startswith("avg error:"):
            mean_error = parse_decimal(line.split(":", 1)[1])
            stats.append(
                VehicleStats(
                    vehicle_id=vehicle_id,
                    mean_error=mean_error,
                    sample_count=samples or 0,
                )
            )
            vehicle_id = None
            samples = None

    if not stats:
        raise ValueError(f"No vehicle statistics found in summary file '{path}'")

    if metadata.active_vehicles is None:
        metadata.active_vehicles = len(stats)

    return stats, metadata


def find_matching_csv(summary_path: Path) -> Optional[Path]:
    timestamp = summary_path.stem.replace("statistics_summary_", "", 1)
    if timestamp and timestamp != summary_path.stem:
        candidate = summary_path.with_name(f"position_accuracy_{timestamp}.csv")
        if candidate.exists():
            return candidate

    csv_files = sorted(summary_path.parent.glob(DEFAULT_CSV_GLOB), key=lambda p: p.stat().st_mtime)
    if csv_files:
        return csv_files[-1]
    return None


def load_vehicle_stats(path: Path) -> Tuple[Path, List[VehicleStats], SummaryMetadata]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        errors_by_vehicle = load_vehicle_errors(path)
        stats = compute_stats(errors_by_vehicle)
        metadata = SummaryMetadata(
            total_entries=sum(len(samples) for samples in errors_by_vehicle.values()),
            active_vehicles=len(errors_by_vehicle),
        )
        # Compute aggregate metrics.
        all_errors = [err for samples in errors_by_vehicle.values() for err in samples]
        if all_errors:
            metadata.overall_mean = sum(all_errors) / len(all_errors)
            metadata.overall_max = max(all_errors)
        return path, stats, metadata

    if suffix == ".txt":
        try:
            stats, metadata = load_vehicle_stats_from_summary(path)
            return path, stats, metadata
        except ValueError as exc:
            debug(f"Failed to parse summary '{path}': {exc}")
            csv_fallback = find_matching_csv(path)
            if csv_fallback:
                debug(f"Attempting CSV fallback: '{csv_fallback}'")
                debug(f"CSV fallback size: {csv_fallback.stat().st_size} bytes")
                errors_by_vehicle = load_vehicle_errors(csv_fallback)
                stats = compute_stats(errors_by_vehicle)
                metadata = SummaryMetadata(
                    total_entries=sum(len(samples) for samples in errors_by_vehicle.values()),
                    active_vehicles=len(errors_by_vehicle),
                )
                all_errors = [err for samples in errors_by_vehicle.values() for err in samples]
                if all_errors:
                    metadata.overall_mean = sum(all_errors) / len(all_errors)
                    metadata.overall_max = max(all_errors)
                debug("CSV fallback succeeded.")
                return csv_fallback, stats, metadata
            debug("No CSV fallback available.")
            raise

    raise ValueError(f"Unsupported file format: {path}")


def print_report(csv_path: Path, stats: List[VehicleStats], threshold: float, metadata: SummaryMetadata) -> None:
    print("=" * 60)
    print(f"Analyzed log: {csv_path}")
    print(f"Threshold (mean error per vehicle): {threshold:.3f} m")
    print("=" * 60)
    if metadata.generated_at:
        print(f"Generated: {metadata.generated_at}")
    if metadata.total_entries is not None:
        print(f"Total entries: {metadata.total_entries}")
    if metadata.active_vehicles is not None:
        print(f"Active vehicles: {metadata.active_vehicles}")
    if metadata.overall_mean is not None:
        print(f"Overall mean error: {metadata.overall_mean:.4f} m")
    if metadata.overall_max is not None:
        print(f"Maximum error: {metadata.overall_max:.4f} m")
    print(f"Vehicles analyzed: {len(stats)}")
    print()
    print(f"{'Vehicle':<25}{'Samples':>12}{'Mean Error (m)':>18}")
    print("-" * 60)
    for item in stats:
        marker = "OK" if item.mean_error < threshold else "FAIL"
        print(f"{item.vehicle_id:<25}{item.sample_count:>12}{item.mean_error:>14.4f}  {marker}")
    print("=" * 60)


def main(argv: Iterable[str]) -> int:
    args = parse_args(argv)

    try:
        candidate_path = args.log_file or find_latest_log(args.log_dir, args.pattern)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    if args.log_file:
        debug(f"Using explicit log file '{candidate_path}'")
    else:
        debug(f"Using discovered log file '{candidate_path}'")

    try:
        log_path, stats, metadata = load_vehicle_stats(candidate_path)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    print_report(log_path, stats, args.threshold, metadata)

    failing = [item for item in stats if item.mean_error >= args.threshold]
    if failing:
        print("Failing vehicles:")
        for item in failing:
            print(f"  {item.vehicle_id}: mean error {item.mean_error:.4f} m (samples={item.sample_count})")
        print("Result: FAIL")
        return 1

    print("Result: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
