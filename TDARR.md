# Tdarr Transcode Flow — DIY Setup Guide

How to configure [Tdarr](https://docs.tdarr.io/) (webUI at `http://<host>:8265`) to transcode a Movies/TV library down to one consistent, broadly-compatible format. This is all app-side configuration built in the Tdarr Flow editor — none of it lives in a config file, so nothing here is applied automatically. You recreate it by hand in the UI (or import a flow export).

## Target Spec

What a compliant file looks like once the flow is done with it:

- **Container:** MKV
- **Video:** H264, QSV hardware encode, preset `medium`, ≤1080p, ≤5500kbps (`maxrate` 6600k, `bufsize` 11000k)
- **Audio:** AC3, evaluated and corrected per stream independently — mono/stereo ≤224kbps, 3+ channels ≤640kbps
- **Subtitles:** ASS/SSA streams converted to plain-text SRT with inline styling tags stripped; other subtitle formats left untouched

Why these specific targets, rather than something like HEVC/CRF encoding, is covered in "Design Notes" below.

## Building the Flow

Steps, in order, as a Tdarr Flow:

1. **`Input File` → `Start`** — a Begin Command node; runs unconditionally, before any check.
2. **Strip incompatible streams** (Custom JS Function) — drops any stream with `codec_type === 'data'` (e.g. binary/timecode tracks some sources carry).
3. **Strip extra PGS/VobSub subtitles** (Custom JS Function) — if a file has 2+ image-based subtitle streams (`hdmv_pgs_subtitle` / `dvd_subtitle` / `dvb_subtitle`), keeps the `eng`-tagged one (falls back to the first stream if none is tagged `eng`) and marks the rest `removed`, then forces `needsTranscode` so the removal actually gets applied instead of being skipped as "nothing to do." No-op on every other file.
4. **Check File Extension** (mkv?) — fail: mark `needsTranscode`, `Set Container`.
5. **Check if h264** — fail: mark `needsTranscode`, pixel-format fix (`vpp_qsv=format=nv12`), `Set Video Encoder` (h264_qsv, preset medium).
6. **Check Streams Count** (audio) — 0–1 streams: continue to step 7. 2+ streams: mark `needsTranscode` → **Handle multiple audio streams** (Custom JS Function: per-stream AC3 + per-channel-count bitrate correction, same 224k/640k targets as step 8, applied independently to each audio stream) → send a warning notification → merge back into step 9.
7. **Check if AC3** — fail: mark `needsTranscode`, `Set audio codec AC3`.
8. **Channel Count = 1** / **Channel Count = 2** (mono/stereo, shared path) → is audio under 250kbps?; anything else (surround) → is audio under 680kbps? Over ceiling: mark `needsTranscode`, set bitrate (224k or 640k).
9. **Check Video Resolution** — over 1080p: mark `needsTranscode`, `Set Video to 1080p`, re-assert `Set Video Encoder` (h264_qsv, preset medium).
10. **Check Video Bitrate** (<5500kbps) — over: mark `needsTranscode`, re-assert `Set Video Encoder` (h264_qsv, preset medium), `Set video bitrate ~5500kbps`.
11. **Check Stream Property** (subtitle ass/ssa) — match: mark `hadStyledSubs`, `Set subtitles to SRT` (`-c:s srt`) → **Fix 10-bit H264 QSV decode** → step 12. No match: check `needsTranscode` — set: same fix node → step 12; unset: a lightweight health check → success notification ("nothing to do"), skipping the actual transcode entirely.
12. **Transcoding Pass 1** (Execute — Tdarr's own ffmpeg command builder runs here, using everything staged by the nodes above).
13. Check `hadStyledSubs` — set: send a warning notification (flags that a second pass is coming) → **Transcoding Pass 2** (Custom JS Function: extracts the subtitle Pass 1 produced, strips every inline styling tag via regex, then a hand-written ffmpeg remux of video/audio + the stripped subtitle — font attachments intentionally dropped, not carried through — preserving Pass 1's filename) → Run Health Check. Unset: Run Health Check directly.
14. **Run Health Check** → **Replace Original File**.
15. **Is Movie library?** → branch Radarr/Sonarr: notify the *arr app → wait ~60 sec (give it time to settle) → apply your naming policy → notify again → send a success notification.

**Notifications:** two webhook endpoints (e.g. via [Apprise](https://github.com/caronc/apprise)) — one for success/warning events, one for failures. Give every notification node a status-code allowlist like `output2StatusCodes: 424,429,500-599` so a failed notification never blocks the actual file processing.

## Library & Node Settings

Per library (Movies and TV, configured the same way):

- Transcode mode: **Flow** (not Classic)
- `scheduledScanFindNew`: on, `scanOnStart`: on
- `folderWatching` / `useFsEvents`: on
- `holdNewFiles`: on, ~5 min — see "Why Hold New Files is required" below

**Node worker schedule** (Tdarr dashboard, on the transcode node): if you're sharing a GPU with something latency-sensitive (like a media server actively serving playback), disable `transcodegpu`/`healthcheckgpu` during your peak usage hours and leave them enabled the rest of the day. Leave the CPU-based workers off entirely if you want all transcoding to go through hardware encode.

## Design Notes

Reasoning that would actually get re-broken if this flow were "simplified" without knowing why.

**Custom JS Functions replace Tdarr's built-in bitrate checks (`checkAudioBitrate`/`checkVideoBitrate`).** Both built-in nodes throw a hard error (`Audio/Video bitrate not found`) and fail the whole job if a stream has no explicit `bit_rate` field in Tdarr's scan — not rare on WEBDL sources, which frequently omit per-stream bitrate metadata entirely. The custom replacements read `ffProbeData` directly, fall back to estimating bitrate from container size ÷ duration minus known audio bits when the direct field is missing, and only treat a file as compliant when it's genuinely unknowable (no size/duration either) — they never throw. Reverting to the built-in nodes reintroduces real job failures on any library with WEBDL sources, not a theoretical edge case.

**Subtitle stripping (`Transcoding Pass 2`) is a fully separate, hand-written ffmpeg command — never fold it into Tdarr's own command builder.** Tdarr's `ffmpegCommandExecute` splices anything in `overallInputArguments` in *before* the main file's `-i` flag (confirmed by reading the plugin source directly). Injecting a second input there — e.g. a stripped subtitle file — would make it input 0 and silently shift every stream's `-map 0:N` mapping onto the wrong file. There's no safe built-in extension point for a second input file. Pass 2 sidesteps this by not using Tdarr's command builder at all: a standalone `child_process` ffmpeg call with manually controlled input ordering, run after Pass 1 finishes.

**Pass 2's remux drops font attachments instead of carrying them through.** TTF/OTF `attachment` streams exist to render a styled ASS track; once that track has been converted to plain SRT (which doesn't reference fonts at all), those attachments are dead weight. Since Pass 2 only ever runs on the `hadStyledSubs` branch, it's safe to just not map the attachment streams in the remux — no need to detect whether any are present first, omitting a stream from the `-map` list already excludes it.

**QSV (`h264_qsv`) needs an explicit pixel-format fix on non-H264 sources.** `-vf vpp_qsv=format=nv12` before `Set Video Encoder`, only on the "not already H264" branch. Without it, any 10-bit source (`yuv420p10le`) fails outright — QSV's H264 encoder only accepts 8-bit input.

**QSV can't hardware-decode 10-bit H264 (`High 10` profile) on some iGPUs at all, even when it hardware-encodes to `h264_qsv` fine and hardware-decodes 10-bit HEVC fine.** A source that's already H264 but 10-bit, needing only a bitrate/resolution fix, skips the "not H264" branch above entirely — so the `vpp_qsv=format=nv12` fix never runs for it, and it wouldn't have helped anyway, since decode fails before any filter runs: `[dec:h264_qsv] Error submitting packet to decoder: Function not implemented`, once per video packet, ending in `transcodeError`. If you hit this on 10-bit-tagged sources, the fix is a `customFunction` node (`Fix 10-bit H264 QSV decode`) placed right before Transcoding, on the path every branch converges through — it strips `-hwaccel qsv -hwaccel_output_format qsv` and adds `-vf format=nv12` only when `codec_name === 'h264' && bits_per_raw_sample === '10' && outputArgs.includes('h264_qsv')`, so it can't touch the already-working not-H264/HEVC branch or files that don't need video re-encoding at all.

**AC3, not EAC3 or "copy," for audio; H264, not HEVC, for video.** Both driven by the same constraint: pick codecs that every device on your client list can direct-play natively (older game consoles, browsers, and smart TVs are the usual holdouts). If any client in your target list can't decode HEVC or EAC3, the playback server ends up doing a server-side transcode anyway — the exact ongoing cost this whole normalization pass exists to avoid.

**Bitrate ceiling, not quality-based (CRF) encoding.** One flat target across the whole library is simpler to reason about than per-library quality settings, at the cost of not adapting to content complexity. If a chunk of your library is silently exceeding whatever ceiling you pick (common with WEBDL sources that run several Mbps higher than you'd expect), you'll want to re-scan and raise it rather than assume the flow is enforcing it correctly.

**Subtitle stripping only works on text-based formats (ASS/SSA/mov_text).** Image-based subtitles (PGS, VobSub) can't be converted to SRT by ffmpeg and would fail the job outright. The `Check Stream Property` gate (matching `ass,ssa`) keeps PGS-only files from ever reaching that path, but a file with *both* an ASS track and a PGS track would still route in and fail on the PGS stream.

**`Strip extra PGS/VobSub subtitles` only dedupes image-based subtitle *count*, never converts them.** Bluray-sourced files can carry a full set of PGS tracks — one per language — which is pure overhead if you only ever watch one language. This node is deliberately narrow: it only fires when a file actually has multiple image-based subtitle tracks (plain-text subtitle tracks are cheap enough that deduping them isn't worth the complexity), and it only removes streams (fast, no re-encode) — it never attempts a PGS→SRT conversion.

**Aspect-ratio caveat:** Tdarr has a known bug ([Tdarr_Plugins#711](https://github.com/HaveAGitGat/Tdarr_Plugins/issues/711)) where non-16:9 files can get misidentified by resolution-tier detection, potentially causing an infinite downscale loop. Watch history for repeat processing on any non-standard-aspect content.

**Why Hold New Files is required, not optional, once `folderWatching`/`useFsEvents` are on:** real-time filesystem events fire the instant a path changes — including a downstream app's own post-transcode rename — which can queue a file mid-write before the OS-level operation has settled, producing spurious health-check/transcode errors on a file that's actually fine. A few minutes' hold comfortably covers the gap between `Replace Original File` and any naming-policy step finishing afterward. If this error pattern recurs on an unusually large file, raise the hold time.
