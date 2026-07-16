#!/bin/bash
# 生成双说话人中文会议 fixture：macOS say 双音色（Tingting=说话人A，Meijia=说话人B）
# 产物：fixtures/meeting-2spk.wav（16kHz mono，>20s，含关键词「下周三」与明确待办）
set -euo pipefail
cd "$(dirname "$0")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

lines=(
  "Tingting|各位，今天我们讨论妙招小程序的发布计划。当前版本还有两个问题没有解决。"
  "Meijia|我认为语音通话的稳定性是最大的风险，上周真机测试的时候掉线了三次。"
  "Tingting|好，那这个问题由你负责排查，下周三之前给出结论。"
  "Meijia|没问题。另外我建议把新用户引导页挪到下一个版本，这个版本先聚焦稳定性。"
  "Tingting|同意。那我们定一下，本周五完成内部测试，下周一提交审核。"
  "Meijia|好的，我会在周四之前把测试报告发给大家。"
)

i=0
inputs=()
for l in "${lines[@]}"; do
  voice="${l%%|*}"; text="${l#*|}"
  say -v "$voice" -o "$TMP/$i.raw.aiff" "$text"
  if [[ "$voice" == "Meijia" ]]; then
    # 说话人 B 降 4 半音模拟男声——两个 say 音色都偏女声，embedding 距离不够会被聚成一人
    ffmpeg -y -v error -i "$TMP/$i.raw.aiff" -af "asetrate=22050*0.794,aresample=22050,atempo=1.26" "$TMP/$i.aiff"
  else
    mv "$TMP/$i.raw.aiff" "$TMP/$i.aiff"
  fi
  # 句间 1.3s 静音，帮助 whisper 断段 + 分离器切段
  ffmpeg -y -v error -f lavfi -i anullsrc=r=22050:cl=mono -t 1.3 "$TMP/${i}_sil.aiff"
  inputs+=("$TMP/$i.aiff" "$TMP/${i}_sil.aiff")
  i=$((i+1))
done

# 拼接 → 16kHz mono wav
for f in "${inputs[@]}"; do echo "file '$f'"; done > "$TMP/list.txt"
ffmpeg -y -v error -f concat -safe 0 -i "$TMP/list.txt" -ar 16000 -ac 1 meeting-2spk.wav
ffprobe -v error -show_entries format=duration -of csv=p=0 meeting-2spk.wav
