#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path
from typing import Iterable, List, Optional

# ######################################################################
# ######################################################################
#
#
#
# 1) Einzelnes Video transkribieren (Originalsprache), SRT neben Datei
# python3 translate_videos.py "/Pfad/Video.mp4"
# 
# 2) Ordner rekursiv verarbeiten, Ausgaben in eigenen Ordner
# python3 translate_videos.py "/Pfad/Videos" --recursive --outdir "/Pfad/Untertitel"
# 
# 3) Direkt nach Englisch übersetzen (Whisper-Task translate => immer EN)
# python3 translate_videos.py "/Pfad/Video.mp4" --whisper-task translate --suffix ".en"
# 
# 4) Nach Deutsch übersetzen (offline, via Argos – Sprachpaket EN->DE muss installiert sein)
#    a) Erst transkribieren (z.B. Quelle englisch erkannt), dann DE-Übersetzung:
# python3 translate_videos.py "/Pfad/Video.mp4" --target-lang de --suffix ".de"
# 
#    b) oder Whisper->EN + Argos EN->DE in einem Rutsch:
# python3 translate_videos.py "/Pfad/Video.mp4" --whisper-task translate --target-lang de --suffix ".de"
# 
# 5) Modell/Hardware feinjustieren (Apple Silicon: auto/metal ist ok)
# python3 translate_videos.py "/Pfad/Video.mp4" --model small --device auto --compute-type auto
# 
# 6) Existierende SRT überschreiben
# python3 translate_videos.py "/Pfad/Video.mp4" --overwrite
#
#
#
# ######################################################################
# ######################################################################



# Optional: Argos Translate für beliebige Zielsprache
try:
    from argostranslate import translate as argos_translate
except Exception:
    argos_translate = None  # Übersetzung nur mit Whisper->EN möglich, wenn Argos fehlt

from faster_whisper import WhisperModel

VIDEO_EXTS = {".mp4", ".mkv", ".mov", ".m4v", ".avi", ".webm"}

def iter_video_files(p: Path, recursive: bool) -> Iterable[Path]:
    if p.is_file() and p.suffix.lower() in VIDEO_EXTS:
        yield p
    elif p.is_dir():
        if recursive:
            for q in p.rglob("*"):
                if q.is_file() and q.suffix.lower() in VIDEO_EXTS:
                    yield q
        else:
            for q in p.iterdir():
                if q.is_file() and q.suffix.lower() in VIDEO_EXTS:
                    yield q

def sec_to_srt_time(t: float) -> str:
    if t < 0: t = 0.0
    ms = int(round((t - int(t)) * 1000))
    s = int(t) % 60
    m = (int(t) // 60) % 60
    h = int(t) // 3600
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

def write_srt(segments: List[dict], out_path: Path, encoding="utf-8") -> None:
    lines = []
    for idx, seg in enumerate(segments, 1):
        start = sec_to_srt_time(seg["start"])
        end = sec_to_srt_time(seg["end"])
        text = seg["text"].strip()
        lines.append(str(idx))
        lines.append(f"{start} --> {end}")
        lines.append(text)
        lines.append("")  # Leerzeile
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding=encoding)

def get_argos_translator(src_code: str, tgt_code: str):
    if argos_translate is None:
        return None
    installed = argos_translate.get_installed_languages()
    src = next((l for l in installed if l.code == src_code), None)
    tgt = next((l for l in installed if l.code == tgt_code), None)
    if not src or not tgt:
        return None
    return src.get_translation(tgt)

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Transkribiert (und optional übersetzt) Videos zu SRT (offline, faster-whisper)."
    )
    p.add_argument("input", help="Videodatei oder Ordner")
    p.add_argument("--outdir", default="", help="Ausgabeverzeichnis (Default: neben Eingabedatei)")
    p.add_argument("--recursive", action="store_true", help="Ordner rekursiv durchsuchen")
    p.add_argument("--overwrite", action="store_true", help="Vorhandene SRT überschreiben")
    p.add_argument("--model", default="small", help="Whisper-Modell (tiny/base/small/medium/large-v3, etc.)")
    p.add_argument("--device", default="auto", help="auto|cpu|cuda|metal (Apple Silicon nutzt meist metal/auto)")
    p.add_argument("--compute-type", default="auto", help="auto|int8|int8_float16|float16|float32")
    p.add_argument("--language", default="auto", help="Quellsprache (z.B. en, de) oder auto")
    p.add_argument("--whisper-task", default="transcribe", choices=["transcribe","translate"],
                   help="Whisper-Task (translate => immer nach EN!)")
    p.add_argument("--target-lang", default="", help="Zielsprache via Argos (z.B. de). Leer = keine Zusatz-Übersetzung.")
    p.add_argument("--suffix", default="", help="Datei-Suffix für Ausgabe, z.B. '.de' -> foo.de.srt")
    return p

def main():
    args = build_arg_parser().parse_args()
    in_path = Path(args.input).expanduser().resolve()
    outdir = Path(args.outdir).expanduser().resolve() if args.outdir else None

    files = list(iter_video_files(in_path, args.recursive))
    if not files:
        print("Keine passenden Video-Dateien gefunden.", file=sys.stderr)
        sys.exit(2)

    model = WhisperModel(args.model, device=args.device, compute_type=args.compute_type)

    for f in files:
        rel = f.name if outdir is None else f.relative_to(in_path) if in_path.is_dir() and f.is_relative_to(in_path) else f.name
        base_out_dir = (f.parent if outdir is None else (outdir / (rel.parent if isinstance(rel, Path) else "")))
        suffix = args.suffix
        srt_path = base_out_dir / (f.stem + (suffix if suffix else "") + ".srt")
        if srt_path.exists() and not args.overwrite:
            print(f"Skip (existiert): {srt_path}")
            continue

        print(f"▶ Verarbeite: {f}")
        task = args.whisper_task  # translate => EN
        language = None if args.language.lower() == "auto" else args.language

        segments_iter, info = model.transcribe(
            str(f),
            task=task,  # 'translate' => nach EN
            language=language,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500),
            beam_size=5
        )
        detected_lang = info.language
        print(f"   Sprache erkannt: {detected_lang}  |  Whisper-Task: {task}")

        # Sammle Segmente
        segs = [{"start": s.start, "end": s.end, "text": s.text} for s in segments_iter]

        # Optionale Zusatz-Übersetzung (z.B. nach Deutsch)
        # Hinweis: Whisper 'translate' geht nur nach EN. Für andere Zielsprachen => Argos.
        if args.target_lang:
            tgt = args.target_lang.lower()
            # Wenn Whisper bereits nach EN übersetzt hat, ist src=en, sonst src=detected_lang
            src = "en" if task == "translate" else (detected_lang or "auto")
            if src == "auto":
                # falls language=auto & detection fehlte
                print("   Warnung: Quellsprache unbekannt, setze Quelle=detected/en.")
                src = detected_lang or "en"

            translator = get_argos_translator(src, tgt)
            if translator is None:
                print(f"   ⚠️ Keine Argos-Übersetzung {src}->{tgt} installiert. "
                      f"SRT bleibt in '{'en' if task=='translate' else detected_lang}'.")
            else:
                for seg in segs:
                    seg["text"] = translator.translate(seg["text"])

                # Wenn Ziel != EN, Suffix automatisch setzen, falls nicht manuell gesetzt
                if not args.suffix:
                    srt_path = base_out_dir / (f.stem + f".{tgt}.srt")

        write_srt(segs, srt_path)
        print(f"   ✅ SRT geschrieben: {srt_path}")

    print("Fertig.")

if __name__ == "__main__":
    main()

