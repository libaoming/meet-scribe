#!/bin/bash
# 重建 meeting-2spk.wav 的 ground truth 说话人时间轴（RTTM）
# 完全复刻 meet-scribe/fixtures/gen_fixture.sh 的合成流程，逐段量真实时长
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

cursor=0
i=0
: > gt.rttm
for l in "${lines[@]}"; do
  voice="${l%%|*}"; text="${l#*|}"
  say -v "$voice" -o "$TMP/$i.raw.aiff" "$text"
  if [[ "$voice" == "Meijia" ]]; then
    ffmpeg -y -v error -i "$TMP/$i.raw.aiff" \
      -af "asetrate=22050*0.794,aresample=22050,atempo=1.26" "$TMP/$i.aiff"
    spk=B
  else
    mv "$TMP/$i.raw.aiff" "$TMP/$i.aiff"
    spk=A
  fi
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/$i.aiff")
  printf 'SPEAKER meeting 1 %.3f %.3f <NA> <NA> %s <NA> <NA>\n' "$cursor" "$dur" "$spk" >> gt.rttm
  cursor=$(awk -v c="$cursor" -v d="$dur" 'BEGIN{printf "%.3f", c+d+1.3}')
  i=$((i+1))
done

echo "重建总时长: ${cursor}s"
echo "fixture 实际: $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$HOME/meet-scribe/fixtures/meeting-2spk.wav")s"
cat gt.rttm
