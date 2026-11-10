#!/usr/bin/env python3
"""Shorten frozen stretches (loading, waiting between taps) in a screen recording.

usage: tighten.py IN.mp4 OUT.mp4 [--hold 0.35] [--last-hold 1.5] [--min-freeze 0.45] [--noise 0.0004]
                  [--lead 0.4] [--action-scene 0.05]

The idle lead-in before the first tap or scroll is cut so the clip starts --lead seconds before
the first real action (the first frame whose scene change exceeds --action-scene). Freezedetect
alone misses that lead-in: right after recording starts the encoder sharpens the picture and a
text cursor may blink, so the screen is never perfectly still.

A stretch where the picture does not change for at least --min-freeze seconds is cut down
to --hold seconds, so taps follow each other the way a person would use the app.
The final freeze (usually a result screen) keeps --last-hold seconds so viewers can read it.

--noise is ffmpeg freezedetect's difference threshold. Keep it small: a larger value treats
small changes (typing a digit, toggling a chip) as "frozen" and cuts them out.
"""
import argparse
import re
import subprocess


def probe_duration(path):
    out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]
    )
    return float(out.strip())


def freezes(path, noise, min_freeze, duration):
    log = subprocess.run(
        ["ffmpeg", "-i", path, "-vf", f"freezedetect=n={noise}:d={min_freeze}", "-map", "0:v", "-f", "null", "-"],
        capture_output=True,
        text=True,
    ).stderr
    starts = [float(x) for x in re.findall(r"freeze_start: ([\d.]+)", log)]
    ends = [float(x) for x in re.findall(r"freeze_end: ([\d.]+)", log)]
    if len(ends) < len(starts):
        ends.append(duration)
    return list(zip(starts, ends))


def first_action(path, threshold):
    log = subprocess.run(
        ["ffmpeg", "-i", path, "-vf", f"select='gt(scene,{threshold})',metadata=print:key=lavfi.scene_score",
         "-an", "-f", "null", "-"],
        capture_output=True,
        text=True,
    ).stderr
    times = [float(x) for x in re.findall(r"pts_time:([\d.]+)", log)]
    return times[0] if times else 0.0


def keep_segments(frozen, duration, hold, last_hold, start=0.0):
    keep, cur = [], 0.0
    for i, (s, e) in enumerate(frozen):
        is_last = i == len(frozen) - 1 and e >= duration - 0.1
        h = last_hold if is_last else hold
        if s > cur:
            keep.append((cur, s))
        keep.append((s, min(e, s + h)))
        cur = e
    if cur < duration - 0.05:
        keep.append((cur, duration))
    keep = [(max(a, start), b) for a, b in keep if b > start]
    merged = []
    for a, b in keep:
        if b - a < 0.02:
            continue
        if merged and abs(merged[-1][1] - a) < 0.01:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    return merged


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--hold", type=float, default=0.35)
    p.add_argument("--last-hold", type=float, default=1.5)
    p.add_argument("--min-freeze", type=float, default=0.45)
    p.add_argument("--noise", type=float, default=0.0004)
    p.add_argument("--lead", type=float, default=0.4)
    p.add_argument("--action-scene", type=float, default=0.05)
    a = p.parse_args()

    duration = probe_duration(a.src)
    frozen = freezes(a.src, a.noise, a.min_freeze, duration)
    start = max(0.0, first_action(a.src, a.action_scene) - a.lead)
    segs = keep_segments(frozen, duration, a.hold, a.last_hold, start)
    graph = "".join(
        f"[0:v]trim={s:.3f}:{e:.3f},setpts=PTS-STARTPTS[v{i}];" for i, (s, e) in enumerate(segs)
    ) + "".join(f"[v{i}]" for i in range(len(segs))) + f"concat=n={len(segs)}:v=1:a=0[out]"
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", a.src, "-filter_complex", graph, "-map", "[out]",
         "-r", "30", "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", a.dst],
        check=True,
    )
    print(f"{a.dst}: {duration:.1f}s -> {sum(e - s for s, e in segs):.1f}s ({len(frozen)} waits shortened, idle lead-in {start:.1f}s cut)")


if __name__ == "__main__":
    main()
