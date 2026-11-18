"""Render the existing legacy MIDI timbres to independent BYOND audio voices.

Requires FluidSynth and a legally redistributable GM soundfont supplied by caller.
The game server does not run this tool or require either dependency.
"""

import argparse
from pathlib import Path
import subprocess
import tempfile
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import MidiDependencies as midi


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fluidsynth", required=True)
    parser.add_argument("--soundfont", required=True)
    parser.add_argument("--soundfile-path")
    args = parser.parse_args()
    if args.soundfile_path:
        sys.path.insert(0, args.soundfile_path)
    import soundfile
    import numpy
    root = Path(__file__).resolve().parents[2]
    output = root / "modular_bandastation/music/sound/legacy"
    instruments = ("accordion", "glockenspiel", "harmonica", "recorder", "saxophone", "trombone", "violin", "xylophone")
    with tempfile.TemporaryDirectory(prefix="cp13-midi-") as temp:
        for instrument in instruments:
            destination = output / instrument
            destination.mkdir(parents=True, exist_ok=True)
            for octave in (3, 4, 5):
                source = root / f"sound/runtime/instruments/{instrument}/Cn{octave}.mid"
                score = midi.midi2score(source.read_bytes())
                # Keep the original program/controller setup, but give the sample
                # a sustained body so the runtime can release notes independently.
                for track in score[1:]:
                    for event in track:
                        if event[0] == "note":
                            event[2] = score[0] * 8
                prepared = Path(temp) / "note.mid"
                prepared.write_bytes(midi.score2midi(score))
                rendered = Path(temp) / "note.wav"
                target = destination / f"c{octave}.ogg"
                subprocess.run([
                    args.fluidsynth, "-ni", "-q", "-r", "22050", "-T", "wav",
                    "-O", "s16", "-o", "synth.reverb.active=0", "-o", "synth.chorus.active=0",
                    "-F", str(rendered), args.soundfont, str(prepared),
                ], check=True, capture_output=True)
                audio, rate = soundfile.read(rendered)
                audio = audio[:int(rate * 4)]
                peak = numpy.max(numpy.abs(audio))
                if peak > 0:
                    audio = audio * min(4, 0.8 / peak)
                soundfile.write(target, audio, rate, format="OGG", subtype="VORBIS")
                print(target.relative_to(root), flush=True)


if __name__ == "__main__":
    main()
