"""Prepare mono prototype foley from Godot-decoded Kenney Impact Sounds.

Usage: python prepare_audio.py DECODED_SOURCE_DIR OUTPUT_AUDIO_DIR
Requires NumPy; source .ogg and .ogg.f32 files are produced by decode_kenney.gd.
"""
from pathlib import Path
import hashlib
import json
import sys
import wave
import numpy as np

source, output = map(Path, sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
metadata = json.loads((source / "decode.json").read_text(encoding="utf-8"))
rate = 22050
report = {}


def decode(name):
    original = np.fromfile(source / (name + ".f32"), dtype="<f4").astype(np.float64)
    source_rate = metadata[name]["mix_rate"]
    # The fixed Godot decoder uses 44100Hz. Lowpass before 2:1 decimation.
    assert source_rate == rate * 2, source_rate
    filtered = np.convolve(original, np.array([.25, .5, .25]), mode="same")
    return filtered[::2]


def trim_and_fade(samples):
    active = np.flatnonzero(np.abs(samples) > .00015)
    assert len(active), "Empty decoded source"
    start = max(0, int(active[0]) - int(rate * .002))
    end = min(len(samples), int(active[-1]) + int(rate * .008))
    samples = samples[start:end].copy()
    samples -= samples.mean()
    attack, release = min(int(rate * .003), len(samples)), min(int(rate * .008), len(samples))
    samples[:attack] *= np.linspace(0, 1, attack)
    samples[-release:] *= np.linspace(1, 0, release)
    return samples


def write(name, samples, sources, target_db=-22.0, looping=False):
    rms = np.sqrt(np.mean(samples ** 2))
    assert rms > .00001
    gain = min(10 ** (target_db / 20) / rms, .501 / np.max(np.abs(samples)))
    samples = samples * gain
    pcm = np.rint(samples * 32767).astype("<i2")
    target = output / name
    with wave.open(str(target), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())
    delta = float(abs(samples[0] - samples[-1]))
    report[name] = {
        "sources": {s: hashlib.sha256((source / s).read_bytes()).hexdigest() for s in sources},
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "rate_hz": rate, "channels": 1, "bits": 16,
        "duration_seconds": round(len(pcm) / rate, 6),
        "peak_dbfs": round(float(20 * np.log10(np.max(np.abs(samples)))), 3),
        "rms_dbfs": round(float(20 * np.log10(np.sqrt(np.mean(samples ** 2)))), 3),
        "loop": looping, "boundary_delta": round(delta, 8),
    }
    assert np.max(np.abs(pcm)) < 32767, name


for index in range(5):
    name = f"footstep_concrete_{index:03d}.ogg"
    write(f"footstep_concrete_{index:03d}.wav", trim_and_fade(decode(name)), [name])
for index, source_index in enumerate([0, 1, 3]):
    name = f"footstep_carpet_{source_index:03d}.ogg"
    write(f"low_contact_carpet_{index:03d}.wav", trim_and_fade(decode(name)), [name], -24.0)
for index in range(2):
    name = f"impactSoft_medium_{index:03d}.ogg"
    write(f"jump_soft_{index:03d}.wav", trim_and_fade(decode(name)), [name])
    name = f"impactSoft_heavy_{index:03d}.ogg"
    write(f"landing_soft_{index:03d}.wav", trim_and_fade(decode(name)), [name], -20.0)

# Circular overlap of real soft-contact textures, with attacks removed. The
# resulting quiet rub is a derived prototype layer, not a recorded slide.
names = [f"footstep_carpet_{i:03d}.ogg" for i in [0, 1, 3]]
textures = [trim_and_fade(decode(name)) for name in names]
grain_size = int(rate * .09)
window = np.hanning(grain_size)
size = int(rate * .8)
scrape = np.zeros(size)
weights = np.zeros(size)
rng = np.random.default_rng(20261012)
for position in range(0, size, int(rate * .032)):
    texture = textures[int(rng.integers(0, len(textures)))]
    start = min(int(rate * .035), max(0, len(texture) - grain_size))
    grain = texture[start:start + grain_size].copy()
    if len(grain) < grain_size:
        grain = np.pad(grain, (0, grain_size - len(grain)))
    # Reduce the isolated low-frequency footplant; retain friction texture.
    grain -= np.convolve(grain, np.ones(89) / 89, mode="same")
    if rng.integers(0, 2):
        grain = grain[::-1]
    indices = (position + np.arange(grain_size)) % size
    scrape[indices] += grain * window
    weights[indices] += window
scrape /= np.maximum(weights, .001)
scrape -= scrape.mean()
# Join at a zero crossing; first and last samples then agree without a click.
crossings = np.flatnonzero(np.signbit(scrape[:-1]) != np.signbit(scrape[1:]))
assert len(crossings)
join = int(crossings[np.argmin(np.abs(scrape[crossings]) + np.abs(scrape[crossings + 1]))]) + 1
scrape = np.roll(scrape, -join)
scrape[0] = scrape[-1] = 0.0
write("slide_scrape_loop.wav", scrape, names, -24.0, looping=True)
(output / "PREPARATION.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
for name, stats in report.items():
    print(f"{name}: {stats['duration_seconds']:.3f}s, peak {stats['peak_dbfs']:.1f}dBFS, RMS {stats['rms_dbfs']:.1f}dBFS")
