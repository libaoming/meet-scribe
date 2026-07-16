# meet-scribe

> 🌏 **English** | [中文](README.zh-CN.md)

Automatic meeting minutes for offline (in-person) meetings: record → local WhisperX transcription + pyannote speaker diarization → `claude -p` generates structured minutes → saved to your Obsidian vault. Fully local models, zero marginal cost, unattended via launchd.

- **No cloud ASR** — Whisper large-v3-turbo (CT2) and pyannote community-1 run locally; audio never leaves your machine.
- **No daemon, no database** — directories are the state machine (`inbox/processing/archive/error`), launchd `WatchPaths` is the trigger.
- **Single seam** — launchd, CLI, and manual runs all converge on `bin/pipeline.sh`; one command to verify everything.

## Full call chain

Every step is marked `[auto]` (machine) or `👤` (human).

```
Entry A · Mac present                 Entry B · iPhone (primary)
┌───────────────────────┐            ┌────────────────────────────┐
│ 👤 meet start <title>  │            │ 👤 Voice Memos: record      │
│ [auto] ffmpeg records  │            │ 👤 Save to Files →          │
│        built-in mic    │            │    iCloud Drive/MeetInbox  │
│ 👤 meet stop           │            │ [auto] iCloud sync to Mac  │
└──────────┬────────────┘            └─────────────┬──────────────┘
           │ [auto] mv                             │
           ▼                                       ▼
┌──────────────────────────────────────────────────────────┐
│ ~/Meetings/inbox/   ◀── [auto] launchd WatchPaths fires  │
└───────────────────────────┬──────────────────────────────┘
                            ▼  [auto] wait until file size is stable,
                            │         then mv to processing/ (atomic, no double-run)
┌──────────────────────────────────────────────────────────┐
│ bin/pipeline.sh                                          │
│ ① [auto] ffmpeg → 16 kHz mono wav                        │
│ ② [auto] whisperx (project venv, local models/)          │
│          zh transcription + pyannote diarization          │
│          → word-level speaker turns → JSON                │
│ ③ [auto] fill prompts/minutes.md → claude -p → minutes   │
│ ④ [auto] write ~/ObsidianVault/meetings/ + archive audio │
└───────┬──────────────────────────────┬───────────────────┘
        ▼ success                      ▼ failure
[auto] macOS notification       [auto] move to error/ + log
       + open the minutes              + failure notification
        │
        ▼
👤 Read, correct speaker names, act on TODOs
```

**Where humans are irreplaceable:**

| Step | Why the machine can't do it |
|---|---|
| Start/stop recording, name the meeting | Only you know a meeting is happening and what it's about |
| Review minutes, fix speaker labels | Diarization gives `[Speaker 1]`; mapping to real names needs context |
| Act on the TODO list | The pipeline extracts action items; execution is yours |

## Usage

- **Mac present**: `bin/meet start <title>` to record, `bin/meet stop` to finish — everything after is automatic.
- **iPhone**: record with Voice Memos → "Save to Files" → iCloud Drive/MeetInbox (setup: `docs/iphone-setup.md`).

Any audio file landing in `~/Meetings/inbox/` triggers the pipeline; minutes land in `~/ObsidianVault/meetings/` with a system notification when done.

## Setup / restore (models/ and venv/ are not in the repo)

1. **venv**: `uv venv venv --python 3.11 && uv pip install --python venv/bin/python whisperx`
2. **Models** (all fetched from **ModelScope**; in mainland-China networks hf-mirror is dead and HF is unreachable — HuggingFace also works if you can reach it):
   - `models/faster-whisper-large-v3-turbo/` ← ModelScope `pengzhendong/faster-whisper-large-v3-turbo` (1.5 GB)
   - `models/community-1/` ← pyannote community-1, full repo incl. `plda/plda.npz` (no HF token needed)
   - `models/wav2vec2-zh/` ← Chinese word-level alignment model (1.2 GB)
   - `models/segmentation-3.0/`, `models/wespeaker-voxceleb-resnet34-LM/` ← pyannote dependency weights
   - `models/*.yaml` (diarization local-path configs) are committed — no rebuild needed
3. **Self-check**: run `M1/init.sh`; FAIL=0 means ready.
4. **launchd**: load `launchd/com.baoming.meet-scribe.plist` into `~/Library/LaunchAgents/`.

## Project status

Built with the [harness methodology](https://github.com/libaoming/harness-kit): progress in `STATUS.md` / `features.json`; specs in `docs/PRD.md`, `docs/SPEC.md`, `docs/architecture.md` (Chinese).

## License

[MIT](LICENSE)
