# Plex Ecosystem

Docker Compose stack for grabbing, organizing, and serving a media collection. Services communicate over a shared `media` bridge network managed by Compose. Plex and Atlas use host networking for direct hardware and LAN access.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url> && cd plex-ecosystem

# 2. Configure environment
sops -d secrets.env > .env   # requires the age private key, see Secrets Management below

# 3. Create host directory structure (see below)

# 4. Start the stack
docker compose up -d
```

## Environment Variables

`.env` is gitignored and must be created from `.env.example`. Four variables are required:

| Variable | Description |
|---|---|
| `HOST_MOUNT` | Absolute path to the media drive mount point |
| `LOCAL_MOUNT` | Absolute path to local (internal) storage for config/database data that benefits from faster disk access |
| `HOSTNAME` | Hostname of the server (used by Notifiarr) |
| `NOTIFIARR_API_KEY` | API key from notifiarr.com |

Most service volume paths derive from `HOST_MOUNT`; Plex's and Tdarr's config/database paths derive from `LOCAL_MOUNT` instead (see Directory Structure below).

## Secrets Management

Real values live encrypted in `secrets.env` (committed) via [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age); plaintext `.env` stays gitignored. This means secrets travel with `git clone` — only the age private key needs to move separately. The filename matters: sops infers the dotenv format from the literal `.env` suffix, so don't rename it to something like `.env.enc` (that suffix isn't recognized and breaks both the CLI and editor integrations).

**One-time setup on a new machine:**
```bash
# Install sops and age (single static binaries, e.g. into ~/.local/bin)
# Restore the age private key from your password manager to:
mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
# paste the key into ~/.config/sops/age/keys.txt, then:
chmod 600 ~/.config/sops/age/keys.txt
```

**Recreate `.env`:**
```bash
sops -d secrets.env > .env
```

**Edit a secret** (decrypts to `$EDITOR`, re-encrypts on save — also works via the VS Code "SOPS" extension since the filename is auto-detected):
```bash
sops secrets.env
git add secrets.env && git commit -m "rotate secret"
```

The age *private* key never touches git — back it up in a password manager. `.sops.yaml` holds the corresponding public key so `sops` knows who to encrypt to.

## Directory Structure
Containers expect the following top level directory structure created in the host filesystem. I keep these files outside the container so they persist regardless of the containers' lifecycle.
* backups - Persist backups across container destruction
* config - Persist configuration data across container lifecycle for services that do not provide automated backups
* data - Common root directory enabling media file sharing across containers
```
${HOST_MOUNT}
├── backups
│   ├── prowlarr
│   ├── radarr
│   ├── sabnzbd
│   ├── sonarr
│   └── tautulli
├── config
│   ├── nginx-proxy-manager
│   ├── notifiarr
│   ├── plex-music-ratings-sync
│   ├── prowlarr
│   ├── qbittorrent
│   ├── radarr
│   ├── sabnzbd
│   ├── seerr
│   ├── sonarr
│   └── tautulli
└── data                        # TRaSH Guides folder structure
    ├── media
    │   ├── books
    │   ├── movies
    │   ├── music
    │   └── tv
    ├── plex-transcode-temp
    ├── torrents
    │   ├── books
    │   ├── movies
    │   ├── music
    │   └── tv
    └── usenet
        ├── complete
        │   ├── books
        │   ├── movies
        │   ├── music
        │   └── tv
        └── incomplete
```
Additionally, when running on a linux OS I create a **media** group, assign each of the application users to that group, and set the permissions for any directory the application must access to 2770 including the mount directory. If I were running Ubuntu and my USB drive mounted under /media, I would **sudo chmod 2770 /media/data**.

### Disk Performance

Plex's and Tdarr's config/database directories live under `${LOCAL_MOUNT}` instead of `${HOST_MOUNT}/config` — both do frequent small random I/O for library scans and job tracking, a poor fit for the external USB drive `data/` lives on:
```
${LOCAL_MOUNT}
├── plex
└── tdarr
    ├── configs
    ├── logs
    └── server
```
No group/permission setup needed here the way `${HOST_MOUNT}` requires — this lives under the invoking user's own home directory, already owned correctly.
# Plex Media Server
Media streaming application https://www.plex.tv/. I run my stack on a Windows 11 Pro install and chose to run the native Plex server application. I ran Plex in a docker container and it was wayyyy sloowwwwwww and did not connect directly to plex clients. I've left the docker files in the repo for historical purposes
## Audiobook Support
Plex is built from a custom Dockerfile that installs the [Audnexus.bundle](https://github.com/djdembeck/Audnexus.bundle) plugin at container startup via an init script. The plugin is cloned into the `/config` volume so it persists across container rebuilds.
## Audiobook Playback
For audiobook playback use either
* iOS: [Prologue](https://prologue.audio/)
* Android: [Chronicle Epilogue](https://www.chronicleapp.net/)
## Music Ratins Sync
* [Plex Music Ratings Sync](https://github.com/rfgamaral/plex-music-ratings-sync) - Sync ratings between Plex and music file metadata (scheduled daily)
## Usage Montoring
* [Tautulli](https://tautulli.com/) for Plex usage stats. 
## Transcoding
* [Tdarr](https://docs.tdarr.io/) - Automated media transcoding and library health management, so files land in a consistent codec/container before Plex ever has to transcode on the fly. 
# Media Request Management
* [Seer](https://seerr.dev/) - Plex media discovery and request management service. 
# Servarr Applications
These **Index** (find where media is hosted), **Request** (send request to download client), and **Monitor** (search for new versions and media not yet released)
* [Prowlarr](https://wiki.servarr.com/en/prowlarr) - Indexer manager/proxy built on the popular arr .net/reactjs base stack to integrate with your various PVR apps. Prowlarr supports management of both Torrent Trackers and Usenet Indexers. 
* [Sonarr](https://wiki.servarr.com/en/sonarr) - PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available. 
* [Radarr](https://wiki.servarr.com/en/radarr) - Movie collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new movies and will interface with clients and indexers to grab, sort, and rename them. It can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available. 
# Download Clients
These take requests from a Servarr application and dowload the media to local storage
* [SABnzbd](https://sabnzbd.org/) - Usenet download service. 
* [qBittorrent](https://www.qbittorrent.org/) - Torrent download service. 
# Notification Applications
Passes messages from applications to various services such as email and Discord
* [Apprise](https://hub.docker.com/r/caronc/apprise) - Push Notifications that work with just about every platform. 
* [Notifiarr](https://notifiarr.com/) - Client of Notifiarr.com notification service 
# Reverse Proxy Server
* [Nginx Proxy Manager](https://nginxproxymanager.com/guide/) - I put all docker containres behind an Nginx Proxy Manager. It provides seemless Let's Encrypt support for SSL and a friendly UI that allows me to customize URLs.

# Docker Image Maintenance
[`update.sh`](update.sh) keeps the stack current: it pulls the latest images for every service, rebuilds the Plex image from its base (`--pull`), and recreates any containers with changed images via `docker compose up -d`, then prunes dangling images to reclaim disk space. Progress and errors are sent as Discord notifications through Apprise (start, success, or failure with the last few lines of output as the reason). It's meant to be run on a schedule (e.g. cron) or manually, and exits non-zero on failure so it can be monitored.

## Networking

All services join the `media` bridge network (created automatically by Compose) for container-to-container communication using container names (e.g. `http://sonarr:8989`).

Plex uses `network_mode: host` for DLNA/GDM discovery and direct LAN access.

## References

- [TRaSH Guides](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/) — folder structure and quality profiles
- [Servarr Wiki](https://wiki.servarr.com/) — Sonarr, Radarr, Prowlarr documentation
- [Plex Audiobook Guide](https://github.com/seanap/Plex-Audiobook-Guide)

# Access Architecture

A pattern for exposing a set of self-hosted services under one domain, with a single reverse proxy, split-horizon DNS, one wildcard certificate, and a minimal public attack surface.

## Network

Every container reaches the outside world through one reverse proxy (e.g. Nginx Proxy Manager) on a dedicated Docker network. No service publishes a web-UI port directly on the host — only ports that are genuinely not a web UI (e.g. a BitTorrent swarm port) are host-published, since those aren't something a proxy can front anyway.

Anything that needs host networking for LAN discovery or its own vendor relay (e.g. a media server's native remote-access feature) is a deliberate exception to the "everything through the proxy" rule, not an oversight.

## DNS

- **On the LAN**: run a local DNS resolver (e.g. AdGuard Home or Pi-hole) on a small always-on device. Point your router's DHCP-advertised DNS server at it (most consumer routers have a "custom DNS" or "upstream DNS" setting), and add a wildcard rewrite: `*.yourdomain.com` → the reverse proxy's LAN IP. This lets LAN clients resolve every subdomain locally instead of round-tripping out to the internet and back for a domain that's already yours.
- **Off the LAN**: use a mesh VPN (e.g. Tailscale) on the same resolver device. Advertise a subnet route for your LAN's CIDR so VPN-connected devices can reach the whole network, and configure a split-DNS nameserver entry (in the VPN provider's admin console) restricted to your domain, pointing at the resolver's VPN IP. This gives VPN clients the same wildcard resolution as LAN clients, wherever they physically are.
- **From the public internet**: only the subdomain(s) you actually want public get a real public DNS record (e.g. a Cloudflare-proxied A record). Everything else has no public DNS entry at all.
- Configure each internal proxy host with two names: a short bare name for local convenience over plain HTTP, and the full subdomain for everything else, including all HTTPS access. **Always use the full subdomain form** — a bare single-label name has no TLS coverage and depends on an unreliable DNS search-domain suffix that doesn't work consistently across platforms.

## TLS

Issue one wildcard certificate (`*.yourdomain.com` + the bare apex domain) via a DNS-01 challenge through your DNS provider's API (e.g. Cloudflare, using an API token scoped to DNS-edit on that zone only — not a full-account token). DNS-01 doesn't require any inbound port to be open, which is what makes it usable for internal-only hosts. Attach that one certificate, with the proxy's "force SSL" option enabled, to every internal-only host, plus the reverse proxy's own admin UI.

Any service you deliberately expose to the public internet can keep its own separate certificate issued the normal way (HTTP-01), since it's already reachable on the open internet for the challenge to complete.

## Public exposure

Default to nothing being public. Pick the smallest possible set of services that need to be reachable by people without VPN access (e.g. a family-facing request/discovery app), and give only those a public DNS record. Gate each public host with real authentication — either the app's own login if it has one you trust, or an access list / basic-auth layer at the reverse proxy if it doesn't.

Everything else stays reachable only via the LAN or the mesh VPN, by subdomain, with no public DNS record and no path in from the open internet.

## Remote access

A mesh VPN client on the DNS/VPN device is the only way to reach LAN-only services from off the network. Any VPN-connected device gets full LAN subnet access plus correct wildcard-subdomain resolution via the split-DNS entry above — no separate VPN server, no router port-forwarding, no manual keypair management.

## Keeping the public record current

If your public IP isn't static, run a small DDNS updater container on a cron schedule (e.g. every 5 minutes) that checks your current public IP and updates the DNS record for your public host(s) via your DNS provider's API when it changes. Cap its resources tightly — it's a trivial workload. Without this, an ISP-forced IP change (e.g. after a router reboot) silently breaks public access until someone notices and fixes the DNS record by hand.

# Tdarr Transcode Flow

How to configure [Tdarr](https://docs.tdarr.io/) (webUI at `http://<host>:8265`) to transcode a Movies/TV library down to one consistent, broadly-compatible format. This is all app-side configuration built in the Tdarr Flow editor — none of it lives in a config file, so nothing here is applied automatically. You recreate it by hand in the UI (or import a flow export).

## Target Spec

What a compliant file looks like once the flow is done with it:

- **Container:** MKV
- **Video:** H264, QSV hardware encode, preset `medium`, ≤1080p, ≤5500kbps (`maxrate` 6600k, `bufsize` 11000k)
- **Audio:** AC3, evaluated and corrected per stream independently — mono/stereo ≤224kbps, 3+ channels ≤640kbps, loudness-normalized (`loudnorm=I=-24:LRA=13:TP=-2.0`) whenever a stream is re-encoded
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

**Loudnorm only runs on audio streams that are already being re-encoded for codec/bitrate reasons — never on streams taking the `-c:a copy` path.** Some wide-dynamic-range sources (already AC3, already under the bitrate ceiling) played back too quiet. Loudnorm fixes that, but it requires re-encoding — it can't be applied to a stream that's being stream-copied. Forcing every audio stream through loudnorm regardless of compliance was considered and rejected: ffprobe has no way to tell "already normalized" from "never touched," so that would defeat the step 11 shortcut that skips the whole transcode when a file needs nothing — every already-compliant file would get reprocessed on every scan, forever, for no benefit past the first pass. The accepted tradeoff: a source that's already AC3 and within the bitrate ceiling but happens to be quiet stays quiet, since nothing else about it ever triggers a re-encode.

**AC3, not EAC3 or "copy," for audio; H264, not HEVC, for video.** Both driven by the same constraint: pick codecs that every device on your client list can direct-play natively (older game consoles, browsers, and smart TVs are the usual holdouts). If any client in your target list can't decode HEVC or EAC3, the playback server ends up doing a server-side transcode anyway — the exact ongoing cost this whole normalization pass exists to avoid.

**Bitrate ceiling, not quality-based (CRF) encoding.** One flat target across the whole library is simpler to reason about than per-library quality settings, at the cost of not adapting to content complexity. If a chunk of your library is silently exceeding whatever ceiling you pick (common with WEBDL sources that run several Mbps higher than you'd expect), you'll want to re-scan and raise it rather than assume the flow is enforcing it correctly.

**Subtitle stripping only works on text-based formats (ASS/SSA/mov_text).** Image-based subtitles (PGS, VobSub) can't be converted to SRT by ffmpeg and would fail the job outright. The `Check Stream Property` gate (matching `ass,ssa`) keeps PGS-only files from ever reaching that path, but a file with *both* an ASS track and a PGS track would still route in and fail on the PGS stream.

**`Strip extra PGS/VobSub subtitles` only dedupes image-based subtitle *count*, never converts them.** Bluray-sourced files can carry a full set of PGS tracks — one per language — which is pure overhead if you only ever watch one language. This node is deliberately narrow: it only fires when a file actually has multiple image-based subtitle tracks (plain-text subtitle tracks are cheap enough that deduping them isn't worth the complexity), and it only removes streams (fast, no re-encode) — it never attempts a PGS→SRT conversion.

**Aspect-ratio caveat:** Tdarr has a known bug ([Tdarr_Plugins#711](https://github.com/HaveAGitGat/Tdarr_Plugins/issues/711)) where non-16:9 files can get misidentified by resolution-tier detection, potentially causing an infinite downscale loop. Watch history for repeat processing on any non-standard-aspect content.

**Why Hold New Files is required, not optional, once `folderWatching`/`useFsEvents` are on:** real-time filesystem events fire the instant a path changes — including a downstream app's own post-transcode rename — which can queue a file mid-write before the OS-level operation has settled, producing spurious health-check/transcode errors on a file that's actually fine. A few minutes' hold comfortably covers the gap between `Replace Original File` and any naming-policy step finishing afterward. If this error pattern recurs on an unusually large file, raise the hold time.
