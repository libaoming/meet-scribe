#!/usr/bin/env python3
"""帧级 DER（Diarization Error Rate）：参考 RTTM vs 假设 RTTM。

DER = (漏检 + 虚警 + 混淆) / 参考语音总时长
说话人标签靠枚举全排列取最优映射（说话人数少时精确等价于匈牙利算法）。

用法: der.py <ref.rttm> <hyp.rttm> [--collar 0.25] [--step 0.01]
"""
import argparse
from itertools import permutations


def load(path):
    segs = []
    with open(path) as f:
        for line in f:
            p = line.split()
            if not p or p[0] != "SPEAKER":
                continue
            start, dur, spk = float(p[3]), float(p[4]), p[7]
            segs.append((start, start + dur, spk))
    return segs


def rasterize(segs, n, step):
    """转成帧级标签数组。"""
    frames = [None] * n
    for start, end, spk in segs:
        for i in range(max(0, int(start / step)), min(n, int(end / step))):
            frames[i] = spk
    return frames


def collar_mask(segs, n, step, collar):
    """标准 DER 的 collar：参考段每个边界 ±collar 的帧从评分中完全排除
    （ref 和 hyp 都不计），而不是只内缩 ref —— 后者会把 collar 区误记成虚警。"""
    ignore = [False] * n
    if collar <= 0:
        return ignore
    for start, end, _ in segs:
        for t in (start, end):
            for i in range(max(0, int((t - collar) / step)), min(n, int((t + collar) / step))):
                ignore[i] = True
    return ignore


ap = argparse.ArgumentParser()
ap.add_argument("ref")
ap.add_argument("hyp")
ap.add_argument("--collar", type=float, default=0.0, help="边界宽容带（秒），学界惯例 0.25")
ap.add_argument("--step", type=float, default=0.01)
args = ap.parse_args()

ref_segs, hyp_segs = load(args.ref), load(args.hyp)
total = max(max(e for _, e, _ in ref_segs), max(e for _, e, _ in hyp_segs))
n = int(total / args.step) + 1

ref = rasterize(ref_segs, n, args.step)
hyp = rasterize(hyp_segs, n, args.step)
ignore = collar_mask(ref_segs, n, args.step, args.collar)
ref = [None if ig else r for r, ig in zip(ref, ignore)]
hyp = [None if ig else h for h, ig in zip(hyp, ignore)]

ref_spks = sorted({s for s in ref if s})
hyp_spks = sorted({s for s in hyp if s})

# 枚举 hyp→ref 的映射，取混淆最小者
best = None
pool = list(hyp_spks) + [None] * max(0, len(ref_spks) - len(hyp_spks))
for perm in set(permutations(pool, len(ref_spks))):
    mapping = {h: r for r, h in zip(ref_spks, perm) if h is not None}
    miss = fa = conf = 0
    for r, h in zip(ref, hyp):
        if r and not h:
            miss += 1
        elif h and not r:
            fa += 1
        elif r and h and mapping.get(h) != r:
            conf += 1
    if best is None or (miss + fa + conf) < best[0]:
        best = (miss + fa + conf, miss, fa, conf, mapping)

_, miss, fa, conf, mapping = best
ref_speech = sum(1 for r in ref if r)
step = args.step

print(f"参考语音总时长  {ref_speech * step:.2f}s   ({len(ref_spks)} 人: {ref_spks})")
print(f"假设检出        {len(hyp_spks)} 人: {hyp_spks}")
print(f"最优映射        {mapping}")
print(f"漏检 miss       {miss * step:6.2f}s  {miss / ref_speech * 100:5.2f}%")
print(f"虚警 false_alarm{fa * step:6.2f}s  {fa / ref_speech * 100:5.2f}%")
print(f"混淆 confusion  {conf * step:6.2f}s  {conf / ref_speech * 100:5.2f}%")
print(f"{'─' * 40}")
print(f"DER (collar={args.collar})   {(miss + fa + conf) / ref_speech * 100:.2f}%")
