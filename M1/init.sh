#!/bin/bash
# M1/init.sh — 环境自检（6 段，走完统一报告，不用 set -e）
# fixture 缺失只 WARN，依赖/env 缺失记 FAIL。
cd "$(dirname "$0")/.."

WARN=0; FAIL=0
ok(){ echo "  ✅ $1"; }
warn(){ echo "  ⚠️  $1"; WARN=$((WARN+1)); }
fail(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "== 1. 依赖 =="
command -v ffmpeg >/dev/null && ok "ffmpeg" || fail "ffmpeg 缺失（brew install ffmpeg）"
[ -x venv/bin/whisperx ] && ok "venv/whisperx" || fail "venv 缺 whisperx（uv venv venv --python 3.11 && uv pip install --python venv/bin/python whisperx）"
command -v claude >/dev/null || [ -x "$HOME/.local/bin/claude" ] && ok "claude CLI" || fail "claude CLI 缺失"

echo "== 2. 模型（本地固化，ModelScope 来源） =="
[ -s models/faster-whisper-large-v3-turbo/model.bin ] && ok "whisper large-v3-turbo" || fail "whisper 模型缺失（见 SPEC·环境契约）"
[ -s models/community-1/config.yaml ] && [ -s models/community-1/plda/plda.npz ] && ok "pyannote community-1（含 PLDA）" || fail "pyannote community-1 模型缺失"

echo "== 3. 目录状态机 =="
for d in inbox processing archive error; do
  [ -d "$HOME/Meetings/$d" ] && ok "~/Meetings/$d" || fail "~/Meetings/$d 缺失"
done
[ -d "$HOME/ObsidianVault/meetings" ] && ok "vault meetings/" || warn "~/ObsidianVault/meetings 缺失（管线会自建）"

echo "== 4. schema =="
[ -f features.json ] && python3 -c "import json;json.load(open('features.json'))" 2>/dev/null && ok "features.json 合法" || fail "features.json 非法"

echo "== 5. fixtures =="
[ -s fixtures/meeting-2spk.wav ] && ok "meeting-2spk.wav" || warn "fixture 缺失（跑 fixtures/gen_fixture.sh 重生成）"

echo "== 6. 自动化 =="
launchctl list 2>/dev/null | grep -q com.baoming.meet-scribe && ok "launchd 已装载" || warn "launchd 未装载（S5 收尾时装）"

echo ""
echo "== 自检结果：FAIL=$FAIL WARN=$WARN =="
[ "$FAIL" -gt 0 ] && echo "🔴 有阻塞项，先修 FAIL 再开工" || echo "🟢 可开工（WARN 不阻塞）"
