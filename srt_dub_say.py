#!/usr/bin/env python3


# Ein einzelnes Video: nutzt "Video.de.srt" und Stimme "Anna", ersetzt Originalspur
# ./srt_dub_say.py "/Pfad/Video.mp4"
# 
# Ordnerweise, Originalspur zusätzlich drin lassen und als Default die deutsche setzen
# ./srt_dub_say.py "/Pfad/Videos" --keep-original
# 
# Andere Stimme / Sprechtempo
# ./srt_dub_say.py "/Pfad/Videos" --voice Markus --wpm 185



import argparse, subprocess, tempfile, shutil, sys, os
from pathlib import Path
from dataclasses import dataclass
from pydub import AudioSegment

@dataclass
class Cue:
    start: float
    end: float
    text: str

def parse_srt(path: Path):
    cues = []
    with path.open("r", encoding="utf-8") as f:
        block = []
        for line in f:
            if line.strip() == "":
                if block:
                    cues.append(_parse_block(block))
                    block = []
            else:
                block.append(line.rstrip("\n"))
        if block:
            cues.append(_parse_block(block))
    return cues

def _parse_block(lines):
    # lines: [index, "HH:MM:SS,mmm --> HH:MM:SS,mmm", text...]
    if len(lines) < 2:
        raise ValueError("Invalid SRT block")
    time_line = lines[1]
    start_s, end_s = [t.strip() for t in time_line.split("-->")]
    return Cue(_to_seconds(start_s), _to_seconds(end_s), "\n".join(lines[2:]).strip())

def _to_seconds(t):
    hh, mm, rest = t.split(":")
    ss, ms = rest.split(",")
    return int(hh)*3600 + int(mm)*60 + int(ss) + int(ms)/1000

def synth_with_say(text: str, voice: str, out_aiff: Path, wpm: int):
    # Schreibe Text in Tempdatei (say liest zuverlässig aus Datei)
    tmp = out_aiff.with_suffix(".txt")
    tmp.write_text(text, encoding="utf-8")
    cmd = ["say", "-v", voice, "-r", str(wpm), "-o", str(out_aiff), "-f", str(tmp)]
    subprocess.run(cmd, check=True)
    tmp.unlink(missing_ok=True)

def build_dub_wav_from_srt(srt_path: Path, voice: str, sr: int, wpm: int) -> Path:
    cues = parse_srt(srt_path)
    if not cues:
        raise RuntimeError("Leeres SRT.")
    out_dir = srt_path.parent
    dub_wav = out_dir / (srt_path.stem + ".wav")

    # Gesamtlänge = letztes Ende
    total_ms = int(max(c.end for c in cues) * 1000) + 1000
    timeline = AudioSegment.silent(duration=total_ms, frame_rate=sr)

    with tempfile.TemporaryDirectory() as tmpd:
        tmpd = Path(tmpd)
        for i, c in enumerate(cues, 1):
            ai = tmpd / f"seg_{i:04d}.aiff"
            try:
                synth_with_say(c.text, voice, ai, wpm)
                seg = AudioSegment.from_file(ai)
                # ggf. auf Ziel-SR konvertieren, Mono
                seg = seg.set_frame_rate(sr).set_channels(1)
            except subprocess.CalledProcessError as e:
                print(f"[WARN] say fehlgeschlagen bei Segment {i}: {e}", file=sys.stderr)
                continue
            start_ms = int(c.start * 1000)
            timeline = timeline.overlay(seg, position=start_ms)

    timeline.export(dub_wav, format="wav")
    return dub_wav

def mux_into_video(video: Path, dub_wav: Path, keep_original: bool):
    out_path = video.with_name(video.stem + ".de" + video.suffix)
    # Map: Video 0:v, neue Spur 1:a, optional alte 0:a?
    if keep_original:
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(video), "-i", str(dub_wav),
            "-map", "0:v:0", "-map", "1:a:0", "-map", "0:a?",  # neue Spur zuerst
            "-c:v", "copy", "-c:a", "aac", "-shortest",
            "-metadata:s:a:0", "language=de", "-disposition:a:0", "default",
            "-movflags", "+faststart", str(out_path)
        ]
    else:
        cmd = [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(video), "-i", str(dub_wav),
            "-map", "0:v:0", "-map", "1:a:0",
            "-c:v", "copy", "-c:a", "aac", "-shortest",
            "-metadata:s:a:0", "language=de", "-disposition:a:0", "default",
            "-movflags", "+faststart", str(out_path)
        ]
    subprocess.run(cmd, check=True)
    return out_path

def find_matching_srt(video: Path, srt_suffix: str):
    # z.B. Video "foo.mkv" → "foo.de.srt" wenn suffix=".de"
    cand = video.with_suffix("")  # entfernt .mkv
    srt = Path(str(cand) + srt_suffix + ".srt")
    return srt if srt.exists() else None

def iter_videos(path: Path):
    exts = {".mp4", ".mkv", ".mov", ".m4v", ".webm", ".avi"}
    if path.is_file() and path.suffix.lower() in exts:
        yield path
    elif path.is_dir():
        for p in sorted(path.iterdir()):
            if p.is_file() and p.suffix.lower() in exts:
                yield p

def main():
    ap = argparse.ArgumentParser(description="Erzeugt eine deutsche Tonspur aus .de.srt (macOS 'say') und muxed sie ins Video.")
    ap.add_argument("input", help="Video-Datei oder Ordner")
    ap.add_argument("--srt-suffix", default=".de", help="Suffix der SRT-Datei (Default: .de → foo.de.srt)")
    ap.add_argument("--voice", default="Anna", help="macOS Stimme (z. B. Anna, Markus)")
    ap.add_argument("--sr", type=int, default=24000, help="Samplerate der Dub-Spur (Hz)")
    ap.add_argument("--wpm", type=int, default=200, help="Sprechgeschwindigkeit (Wörter/min) für 'say'")
    ap.add_argument("--keep-original", action="store_true", help="Originale Tonspur zusätzlich behalten")
    args = ap.parse_args()

    base = Path(args.input)
    if not base.exists():
        print("Pfad nicht gefunden.", file=sys.stderr); sys.exit(2)

    for video in iter_videos(base):
        srt = find_matching_srt(video, args.srt_suffix)
        if not srt:
            print(f"[SKIP] Keine SRT gefunden für {video.name}", file=sys.stderr)
            continue
        print(f"▶ Erzeuge Dub aus {srt.name} für {video.name} …")
        dub_wav = build_dub_wav_from_srt(srt, args.voice, args.sr, args.wpm)
        out_vid = mux_into_video(video, dub_wav, args.keep_original)
        print(f"   ✅ Fertig: {out_vid}")

if __name__ == "__main__":
    main()

