# Plex Ecosystem

Docker Compose stack for grabbing, organizing, and serving a media collection. Services communicate over a shared `media` bridge network managed by Compose. Plex and Atlas use host networking for direct hardware and LAN access.

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url> && cd plex-ecosystem

# 2. Configure environment
cp .env.example .env
# Edit .env — set HOST_MOUNT, HOSTNAME, and NOTIFIARR_API_KEY

# 3. Create host directory structure (see below)

# 4. Start the stack
docker compose up -d
```

## Environment Variables

`.env` is gitignored and must be created from `.env.example`. Only three variables are required:

| Variable | Description |
|---|---|
| `HOST_MOUNT` | Absolute path to the media drive mount point |
| `HOSTNAME` | Hostname of the server (used by Notifiarr) |
| `NOTIFIARR_API_KEY` | API key from notifiarr.com |

All service volume paths are derived from `HOST_MOUNT` directly in each compose file.

## Host Directory Structure

Create the following directories on the host before starting the stack:

```
${HOST_MOUNT}
├── backups
│   ├── radarr
│   ├── sabnzbd
│   └── sonarr
├── config
│   ├── nginx-proxy-manager
│   ├── notifiarr
│   ├── plex
│   ├── plex-music-ratings-sync
│   ├── qbittorrent
│   ├── radarr
│   ├── sabnzbd
│   ├── seerr
│   └── sonarr
├── data                        # TRaSH Guides folder structure
│   ├── media
│   │   ├── books
│   │   ├── movies
│   │   ├── music
│   │   └── tv
│   ├── torrents
│   │   ├── books
│   │   ├── movies
│   │   ├── music
│   │   └── tv
│   └── usenet
│       ├── complete
│       │   ├── books
│       │   ├── movies
│       │   ├── music
│       │   └── tv
│       └── incomplete
└── plex-transcode-temp
```

Follows the [TRaSH Guides folder structure](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/) so all services share a common `/data` root.

## Services

### Active

| Service | Port | Description |
|---|---|---|
| [Plex](https://plex.tv) | 32400 | Media streaming server |
| [Seerr](https://seerr.dev) | 5055 | Media discovery and request management |
| [Sonarr](https://wiki.servarr.com/en/sonarr) | 8989 | TV show automation |
| [Radarr](https://wiki.servarr.com/en/radarr) | 7878 | Movie automation |
| [SABnzbd](https://sabnzbd.org) | 8080 | Usenet downloader |
| [qBittorrent](https://qbittorrent.org) | 8282 | Torrent downloader |
| [Notifiarr](https://notifiarr.com) | 5454 | Server notification client |
| [Plex Music Ratings Sync](https://github.com/rfgamaral/plex-music-ratings-sync) | — | Sync ratings between Plex and music file metadata (scheduled daily) |

### Disabled

| Service | Description |
|---|---|
| [Profilarr](https://dictionarry.dev) | Quality profile management for Radarr and Sonarr |
| [Prowlarr](https://wiki.servarr.com/en/prowlarr) | Torrent and Usenet indexer (offloaded to Raspberry Pi) |
| [Tautulli](https://tautulli.com) | Plex usage monitoring (offloaded to Raspberry Pi) |

## Networking

All services join the `media` bridge network (created automatically by Compose) for container-to-container communication using container names (e.g. `http://sonarr:8989`).

Plex and Atlas use `network_mode: host` — Plex for DLNA/GDM discovery, Atlas for full home LAN scanning.

## Plex — Audiobook Support

Plex is built from a custom Dockerfile that installs the [Audnexus.bundle](https://github.com/djdembeck/Audnexus.bundle) plugin at container startup via an init script. The plugin is cloned into the `/config` volume so it persists across container rebuilds. Used with [Prologue](https://prologue.audio/) for audiobook playback.

## External Services

The following services are used by this stack but maintained as separate projects, as they serve multiple applications beyond the plex ecosystem:

| Service | Port | Description |
|---|---|---|
| [Apprise](https://github.com/caronc/apprise) | 8000 | Multi-platform push notifications |
| [Authentik](https://goauthentik.io) | 9100 | SSO identity provider |
| [nginx-proxy-manager](https://nginxproxymanager.com) | 80/443 | Reverse proxy and SSL termination |

## References

- [TRaSH Guides](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/) — folder structure and quality profiles
- [Servarr Wiki](https://wiki.servarr.com/) — Sonarr, Radarr, Prowlarr documentation
- [Plex Audiobook Guide](https://github.com/seanap/Plex-Audiobook-Guide)
