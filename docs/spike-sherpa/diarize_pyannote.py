#!/usr/bin/env python3
"""pyannote community-1 分离基线：出 RTTM + 耗时（只测分离这一环，不含 ASR）。

用 meet-scribe 已固化的本地权重（ModelScope 来源，无需 HF token）。
用法: meet-scribe/venv/bin/python diarize_pyannote.py <wav> <out.rttm>
"""
import os
import sys
import time

MODEL = os.path.expanduser("~/meet-scribe/models/community-1")

wav, out = sys.argv[1], sys.argv[2]

t0 = time.perf_counter()
from pyannote.audio import Pipeline  # noqa: E402  (计入加载耗时)

pipeline = Pipeline.from_pretrained(f"{MODEL}/config.yaml")
init_s = time.perf_counter() - t0

# pyannote 4.x 读文件要 torchcodec（本机 dylib 坏了）；直接喂波形可绕开，
# 且不必为一次 spike 往 meet-scribe 的 venv 里装东西。用标准库 wave 读，零新依赖。
import wave  # noqa: E402

import numpy as np  # noqa: E402
import torch  # noqa: E402

with wave.open(wav, "rb") as w:
    sr = w.getframerate()
    n_frames = w.getnframes()
    assert w.getsampwidth() == 2 and w.getnchannels() == 1, "预期 16-bit mono"
    pcm = np.frombuffer(w.readframes(n_frames), dtype=np.int16)
samples = (pcm.astype(np.float32) / 32768.0).copy()
audio_s = n_frames / sr
waveform = torch.from_numpy(samples).unsqueeze(0)  # (channel, time)

t1 = time.perf_counter()
diarization = pipeline({"waveform": waveform, "sample_rate": sr})
proc_s = time.perf_counter() - t1

# pyannote 4.x 返回 DiarizeOutput（包了一层），3.x 直接返回 Annotation
ann = diarization
if not hasattr(ann, "itertracks"):
    ann = next(
        getattr(ann, a) for a in ("speaker_diarization", "diarization", "annotation")
        if hasattr(ann, a) and hasattr(getattr(ann, a), "itertracks")
    )
segs = [(t.start, t.end, spk) for t, _, spk in ann.itertracks(yield_label=True)]
segs.sort()

with open(out, "w") as f:
    for start, end, spk in segs:
        f.write(f"SPEAKER meeting 1 {start:.3f} {end - start:.3f} <NA> <NA> {spk} <NA> <NA>\n")

print(f"模型加载   {init_s:.2f}s")
print(f"分离耗时   {proc_s:.2f}s  (音频 {audio_s:.2f}s → {audio_s / proc_s:.1f}x 实时)")
print(f"检出说话人 {len({s for _, _, s in segs})} 个")
print(f"段数       {len(segs)}")
print(f"→ {out}")
