#!/usr/bin/env python3
"""sherpa-onnx 说话人分离 spike：出 RTTM + 耗时。

用法: diarize_sherpa.py <wav> <out.rttm> [--int8] [--threshold T] [--num-speakers N]
"""
import argparse
import time

import sherpa_onnx
import soundfile as sf

SEG_DIR = "sherpa-onnx-pyannote-segmentation-3-0"

p = argparse.ArgumentParser()
p.add_argument("wav")
p.add_argument("out")
p.add_argument("--int8", action="store_true", help="用 int8 量化的 segmentation 模型")
p.add_argument("--threshold", type=float, default=0.5, help="聚类阈值（越小越容易分成多人）")
p.add_argument("--num-speakers", type=int, default=-1, help="已知说话人数；-1 = 自动")
p.add_argument("--embedding", default="emb.onnx")
args = p.parse_args()

seg_model = f"{SEG_DIR}/model.int8.onnx" if args.int8 else f"{SEG_DIR}/model.onnx"

config = sherpa_onnx.OfflineSpeakerDiarizationConfig(
    segmentation=sherpa_onnx.OfflineSpeakerSegmentationModelConfig(
        pyannote=sherpa_onnx.OfflineSpeakerSegmentationPyannoteModelConfig(model=seg_model),
    ),
    embedding=sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=args.embedding),
    clustering=sherpa_onnx.FastClusteringConfig(
        num_clusters=args.num_speakers, threshold=args.threshold
    ),
    min_duration_on=0.3,
    min_duration_off=0.5,
)

t_init = time.perf_counter()
sd = sherpa_onnx.OfflineSpeakerDiarization(config)
init_s = time.perf_counter() - t_init

samples, sr = sf.read(args.wav, dtype="float32", always_2d=False)
assert sr == sd.sample_rate, f"采样率不符: wav={sr} 模型要求={sd.sample_rate}"
audio_s = len(samples) / sr

t0 = time.perf_counter()
result = sd.process(samples).sort_by_start_time()
proc_s = time.perf_counter() - t0

with open(args.out, "w") as f:
    for seg in result:
        f.write(
            f"SPEAKER meeting 1 {seg.start:.3f} {seg.end - seg.start:.3f} "
            f"<NA> <NA> spk{seg.speaker} <NA> <NA>\n"
        )

speakers = sorted({s.speaker for s in result})
print(f"模型加载   {init_s:.2f}s")
print(f"分离耗时   {proc_s:.2f}s  (音频 {audio_s:.2f}s → {audio_s / proc_s:.1f}x 实时)")
print(f"检出说话人 {len(speakers)} 个: {speakers}")
print(f"段数       {len(result)}")
print(f"→ {args.out}")
