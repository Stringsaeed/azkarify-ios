"""Generate original sound-design sketches, not mastered release audio."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 48000
OUT = Path(__file__).resolve().parent
rng = random.Random(42)


def render(name, duration, events, peak):
    samples = [0.0] * round(duration * RATE)
    for start, frequency, decay, gain, material in events:
        offset = round(start * RATE)
        for i in range(offset, len(samples)):
            t = (i-offset) / RATE
            attack = min(1.0, t / 0.004)
            tail = math.exp(-t / decay)
            if material == 'wood':
                tone = (math.sin(2*math.pi*frequency*t)*0.65
                        + math.sin(2*math.pi*frequency*1.63*t)*0.24
                        + math.sin(2*math.pi*frequency*2.41*t)*0.11)
                tone += rng.uniform(-1,1)*0.13*math.exp(-t/0.012)
            else:
                tone = (math.sin(2*math.pi*frequency*t)*0.8
                        + math.sin(2*math.pi*frequency*2.01*t)*0.14
                        + math.sin(2*math.pi*frequency*3.98*t)*0.06)
            samples[i] += tone*gain*attack*tail
    maximum = max(abs(v) for v in samples)
    samples = [v*peak/maximum for v in samples]
    # End fades avoid a discontinuity even on the short previews.
    for i in range(min(2400,len(samples))):
        samples[-i-1] *= i/2400
    pcm = b''.join(struct.pack('<h',round(v*32767)) for v in samples)
    with wave.open(str(OUT/name),'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm)
    assert max(abs(v) for v in samples) < 1
    rms = math.sqrt(sum(v*v for v in samples)/len(samples))
    print(f'{name}: {duration:.2f}s, peak {20*math.log10(peak):.1f} dBFS, RMS {20*math.log10(rms):.1f} dBFS')


render('routine-complete.wav',0.46,[(0.025,610,0.042,1,'wood'),(0.125,810,0.06,0.55,'wood')],0.19)
render('collectible-unlock.wav',0.82,[(0.025,880,0.12,0.8,'glass'),(0.155,1320,0.16,0.55,'glass')],0.18)
render('level-up.wav',1.08,[(0.025,660,0.11,0.8,'glass'),(0.18,880,0.14,0.72,'glass'),(0.34,1320,0.19,0.5,'glass')],0.18)
