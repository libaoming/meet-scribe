#!/bin/bash
# pipeline.sh — meet-scribe 唯一接缝
# 用法:
#   pipeline.sh <音频>                 全链路: 转写(+分离)→纪要→落 vault→通知→归档
#   pipeline.sh --transcribe-only <音频>   只到转写 JSON（work/<名>.json）
#   pipeline.sh --minutes-only <JSON>      只跑纪要（复用已有转写，prompt 迭代用）
#   pipeline.sh --scan                     扫 inbox 处理所有待办（launchd 入口）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
VENV="$ROOT/venv"
PROMPT="$ROOT/prompts/minutes.md"
INBOX="$HOME/Meetings/inbox"
ICLOUD_INBOX="$HOME/Library/Mobile Documents/com~apple~CloudDocs/MeetInbox"
PROCESSING="$HOME/Meetings/processing"
ARCHIVE="$HOME/Meetings/archive"
ERRDIR="$HOME/Meetings/error"
VAULT_OUT="$HOME/ObsidianVault/meetings"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"

export HF_ENDPOINT="https://hf-mirror.com"
# HF_TOKEN（说话人分离用）从配置读，没有则降级为不分离
ENV_FILE="$HOME/.config/meet-scribe/env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

mkdir -p "$WORK" "$INBOX" "$PROCESSING" "$ARCHIVE" "$ERRDIR" "$VAULT_OUT"

log() { echo "[$(date +%H:%M:%S)] $*"; }

notify() { # $1=标题 $2=正文
  /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null || true
}

transcribe() { # $1=音频绝对路径 → 产出 $WORK/<base>.json（whisperx 原生格式）
  local audio="$1" base wav
  base="$(basename "$audio")"; base="${base%.*}"
  wav="$WORK/$base.16k.wav"
  ffmpeg -y -v error -i "$audio" -ar 16000 -ac 1 "$wav"
  # 说话人分离：pyannote 权重已固化在 models/（ModelScope 镜像），无需 HF token
  local diar_args=(--diarize --diarize_model "$ROOT/models/community-1")
  if [[ "${MEET_NO_DIARIZE:-0}" == "1" ]]; then diar_args=(); log "MEET_NO_DIARIZE=1，跳过说话人分离"; fi
  "$VENV/bin/whisperx" "$wav" \
    --model "$ROOT/models/faster-whisper-large-v3-turbo" --language zh \
    --device cpu --compute_type int8 --align_model "$ROOT/models/wav2vec2-zh" \
    --output_dir "$WORK" --output_format json \
    ${diar_args[@]+"${diar_args[@]}"} >> "$WORK/$base.whisperx.log" 2>&1
  mv "$WORK/$base.16k.json" "$WORK/$base.json" 2>/dev/null || true
  test -s "$WORK/$base.json"
  rm -f "$wav"
  log "转写完成: work/$base.json"
}

render_transcript() { # $1=json → stdout 逐字稿文本 [mm:ss] [说话人] 文本
  "$VENV/bin/python" - "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))

def zh(spk):
    if not spk: return "说话人?"
    return spk.replace("SPEAKER_0", "说话人").replace("SPEAKER_", "说话人")

words = d.get("word_segments") or []
if any(w.get("speaker") for w in words):
    # 词级对齐可用：按说话人变化切 turn（比 whisper 粗段准得多）
    turns, cur = [], None
    for w in words:
        spk = w.get("speaker") or (cur["speaker"] if cur else None)
        if cur is None or spk != cur["speaker"]:
            cur = {"speaker": spk, "start": w.get("start") or 0, "text": ""}
            turns.append(cur)
        cur["text"] += w["word"]
    for t in turns:
        s = int(t["start"])
        print(f"[{s//60:02d}:{s%60:02d}] [{zh(t['speaker'])}] {t['text'].strip()}")
else:
    for seg in d["segments"]:
        s = int(seg.get("start") or 0)
        print(f"[{s//60:02d}:{s%60:02d}] [{zh(seg.get('speaker'))}] {seg['text'].strip()}")
PY
}

minutes() { # $1=转写 json → 落 vault，echo 纪要路径
  local json="$1" base date_str out body transcript duration
  base="$(basename "$json" .json)"
  date_str="$(date +%F)"
  out="$VAULT_OUT/$date_str-$base.md"
  local n=1
  while [[ -e "$out" ]]; do out="$VAULT_OUT/$date_str-$base-$n.md"; n=$((n+1)); done
  transcript="$(render_transcript "$json")"
  duration="$("$VENV/bin/python" -c "
import json
d=json.load(open('$json'))
t=int(max((s.get('end') or 0) for s in d['segments']))
print(f'{t//60:02d}:{t%60:02d}')")"
  body="$(printf '%s\n\n<逐字稿>\n%s\n</逐字稿>\n' "$(cat "$PROMPT")" "$transcript" | "$CLAUDE_BIN" -p --model sonnet)"
  {
    printf -- '---\ntype: meeting-minutes\ndate: %s\nsource_audio: %s\nduration: %s\n---\n\n' \
      "$date_str" "$ARCHIVE/$base" "$duration"
    printf '%s\n\n' "$body"
    printf '<details><summary>逐字稿</summary>\n\n```\n%s\n```\n\n</details>\n' "$transcript"
  } > "$out"
  test -s "$out"
  log "纪要落盘: $out"
  echo "$out"
}

process_one() { # $1=inbox 里的音频 → 全链路
  local audio="$1" base name
  name="$(basename "$audio")"; base="${name%.*}"
  # iCloud/拷贝半成品防护：5 秒内 size 稳定才处理
  local s1 s2
  s1=$(stat -f%z "$audio"); sleep 5; s2=$(stat -f%z "$audio")
  if [[ "$s1" != "$s2" ]]; then log "$name 还在传输中，跳过（下次触发再处理）"; return 0; fi
  mv "$audio" "$PROCESSING/$name"   # 同盘 mv 原子，防重复拾取
  local plog="$WORK/$base.pipeline.log"
  if out=$( { transcribe "$PROCESSING/$name" && minutes "$WORK/$base.json"; } 2>>"$plog" | tail -1 ); then
    mv "$PROCESSING/$name" "$ARCHIVE/$name"
    cp "$WORK/$base.json" "$ARCHIVE/$base.json" 2>/dev/null || true
    notify "meet-scribe 纪要已生成" "$(basename "$out")"
    /usr/bin/open "$out" 2>/dev/null || true
    log "完成: $name → $out"
  else
    mv "$PROCESSING/$name" "$ERRDIR/$name" 2>/dev/null || true
    cp "$plog" "$ERRDIR/$base.log" 2>/dev/null || true
    notify "meet-scribe 处理失败" "$name（详见 error/$base.log）"
    log "失败: $name（error/ 有日志）"; return 1
  fi
}

case "${1:-}" in
  --transcribe-only) transcribe "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")" ;;
  --minutes-only)    minutes "$2" ;;
  --scan)
    shopt -s nullglob
    rc=0
    # iCloud 占位文件（还没下载到本地的）先触发下载，下次扫描再处理
    if [[ -d "$ICLOUD_INBOX" ]]; then
      find "$ICLOUD_INBOX" -name '*.icloud' -exec brctl download {} \; 2>/dev/null || true
      for f in "$ICLOUD_INBOX"/*.{m4a,wav,mp3,aac,flac,aiff,mp4,mov}; do
        process_one "$f" || rc=1
      done
    fi
    for f in "$INBOX"/*.{m4a,wav,mp3,aac,flac,aiff,mp4,mov}; do
      process_one "$f" || rc=1
    done
    exit $rc ;;
  -*|"") sed -n '2,8p' "$0"; exit 1 ;;
  *) process_one "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")" ;;
esac
