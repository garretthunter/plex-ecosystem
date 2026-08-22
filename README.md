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

## Access Architecture

A pattern for exposing a set of self-hosted services under one domain, with a single reverse proxy, split-horizon DNS, one wildcard certificate, and a minimal public attack surface.

### Network

Every container reaches the outside world through one reverse proxy (e.g. Nginx Proxy Manager) on a dedicated Docker network. No service publishes a web-UI port directly on the host — only ports that are genuinely not a web UI (e.g. a BitTorrent swarm port) are host-published, since those aren't something a proxy can front anyway.

Anything that needs host networking for LAN discovery or its own vendor relay (e.g. a media server's native remote-access feature) is a deliberate exception to the "everything through the proxy" rule, not an oversight.

### DNS

- **On the LAN**: run a local DNS resolver (e.g. AdGuard Home or Pi-hole) on a small always-on device. Point your router's DHCP-advertised DNS server at it (most consumer routers have a "custom DNS" or "upstream DNS" setting), and add a wildcard rewrite: `*.yourdomain.com` → the reverse proxy's LAN IP. This lets LAN clients resolve every subdomain locally instead of round-tripping out to the internet and back for a domain that's already yours.
- **Off the LAN**: use a mesh VPN (e.g. Tailscale) on the same resolver device. Advertise a subnet route for your LAN's CIDR so VPN-connected devices can reach the whole network, and configure a split-DNS nameserver entry (in the VPN provider's admin console) restricted to your domain, pointing at the resolver's VPN IP. This gives VPN clients the same wildcard resolution as LAN clients, wherever they physically are.
- **From the public internet**: only the subdomain(s) you actually want public get a real public DNS record (e.g. a Cloudflare-proxied A record). Everything else has no public DNS entry at all.
- Configure each internal proxy host with two names: a short bare name for local convenience over plain HTTP, and the full subdomain for everything else, including all HTTPS access. **Always use the full subdomain form** — a bare single-label name has no TLS coverage and depends on an unreliable DNS search-domain suffix that doesn't work consistently across platforms.

### TLS

Issue one wildcard certificate (`*.yourdomain.com` + the bare apex domain) via a DNS-01 challenge through your DNS provider's API (e.g. Cloudflare, using an API token scoped to DNS-edit on that zone only — not a full-account token). DNS-01 doesn't require any inbound port to be open, which is what makes it usable for internal-only hosts. Attach that one certificate, with the proxy's "force SSL" option enabled, to every internal-only host, plus the reverse proxy's own admin UI.

Any service you deliberately expose to the public internet can keep its own separate certificate issued the normal way (HTTP-01), since it's already reachable on the open internet for the challenge to complete.

### Public exposure

Default to nothing being public. Pick the smallest possible set of services that need to be reachable by people without VPN access (e.g. a family-facing request/discovery app), and give only those a public DNS record. Gate each public host with real authentication — either the app's own login if it has one you trust, or an access list / basic-auth layer at the reverse proxy if it doesn't.

Everything else stays reachable only via the LAN or the mesh VPN, by subdomain, with no public DNS record and no path in from the open internet.

### Remote access

A mesh VPN client on the DNS/VPN device is the only way to reach LAN-only services from off the network. Any VPN-connected device gets full LAN subnet access plus correct wildcard-subdomain resolution via the split-DNS entry above — no separate VPN server, no router port-forwarding, no manual keypair management.

### Keeping the public record current

If your public IP isn't static, run a small DDNS updater container on a cron schedule (e.g. every 5 minutes) that checks your current public IP and updates the DNS record for your public host(s) via your DNS provider's API when it changes. Cap its resources tightly — it's a trivial workload. Without this, an ISP-forced IP change (e.g. after a router reboot) silently breaks public access until someone notices and fixes the DNS record by hand.
