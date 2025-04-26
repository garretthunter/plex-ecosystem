# Plex Ecosystem
Services that grab, sort, organize, and monitor your Music, Movie, E-Book, or TV Show collections along with indexer to keep them in sync
## Environment Setup
Container folders need to be defined for this build to work as designed.

In the **.env** file, configure the following variables:
* **PLEX_ROOT** - This is the host mount point used for all container mount points
* **SERVARR_BACKUP** - External to the containers, this directory stores backups for Sonarr, Radarr, Prowlarr, and Tautulli. If a container is destroyed the data and configurations can be restored from one of these backups
* **PLEX_MEDIA** - Root directory for all plex media
* **PLEX_TRANSCODE_TEMP** - Used by Plex to transcode media on the fly
## Folder Structure
Containers expect the following top level directory structure created in the host filesystem. I keep these files outside the container so they persist regardless of the containers' lifecycle.
* backups - Used by Radarr, Sonarr,  Prowlarr, and SABnzbd to persist backups across container destruction
* config - Persist configuration data across container lifecycle for services that do not provide automated backups
* data - Common root directory enabling media file sharing across containers
```
<host_path_to_data>
├──backups
├──data
├──config
   ├── plex
   ├── qbitorrent
```
I follow TRaSH Guides for the media folder structure as described here https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/
```
data
├── torrents
│   ├── books
│   ├── movies
│   ├── music
│   └── tv
├── usenet
│   ├── incomplete
│   └── complete
│       ├── books
│       ├── movies
│       ├── music
│       └── tv
└── media
    ├── books
    ├── movies
    ├── music
    └── tv
```
Additionally, when running on a linux OS I create a **media** group, assign each of the application users to that group, and set the permissions for any directory the application must access to 2770 including the mount directory. If I were running Ubuntu and my USB drive mounted under /media, I would:
```
$ sudo chgrp media /media
$ sudo chgrp -R media /media/data
$ sudo chmod -R 2770 /media/data
```
# Media Server
## Plex Media Server
Media streaming application https://www.plex.tv/. I run my stack on a Windows 11 Pro install and chose to run the native Plex server application. I ran Plex in a docker container and it was wayyyy sloowwwwwww and did not connect directly to plex clients. I've left the docker files in the repo for historical purposes
### Audiobook Configuration
I used [Prologue](https://prologue.audio/) (iPhone only, booo) for my audiobooks. I wanted to serve audiobooks directly through Plex so I started with [Plex Audiobook Guide](https://github.com/seanap/Plex-Audiobook-Guide) which lead me to installing the agent [Audnexus.bundle](https://github.com/djdembeck/Audnexus.bundle) so that I can serve audiobooks through Plex 
# Media Request Management
## Overseer
Plex media discovery and request management service. https://overseerr.dev/
# Servarr Applications
These **Index** (find where media is hosted), **Request** (send request to download client), and **Monitor** (search for new versions and media not yet released)
## Prowlarr
Prowlarr is an indexer manager/proxy built on the popular arr .net/reactjs base stack to integrate with your various PVR apps. Prowlarr supports management of both Torrent Trackers and Usenet Indexers. https://wiki.servarr.com/en/prowlarr
## Sonarr
Sonarr is a PVR for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new episodes of your favorite shows and will grab, sort and rename them. It can also be configured to automatically upgrade the quality of files already downloaded when a better quality format becomes available. https://wiki.servarr.com/en/sonarr
## Radarr
Radarr is a movie collection manager for Usenet and BitTorrent users. It can monitor multiple RSS feeds for new movies and will interface with clients and indexers to grab, sort, and rename them. It can also be configured to automatically upgrade the quality of existing files in the library when a better quality format becomes available. https://wiki.servarr.com/en/radarr
# Download Clients
These take requests from a Servarr application and dowload the media to local storage
## SABnzbd
Usenet download service. https://sabnzbd.org/
## qBittorrent
Torrent download service. https://www.qbittorrent.org/
# Notification Applications
Passes messages from applications to various services such as email and Discord
## Apprise
Push Notifications that work with just about every platform. https://hub.docker.com/r/caronc/apprise
## Notifiarr
Client of Notifiarr.com notification service https://notifiarr.com/
# Usage Montoring
## Tautulli
Plex usage and monitoring service. https://tautulli.com/
# Reverse Proxy Server
## Nginx Proxy Manager
I put all docker containres behind an Nginx Proxy Manager. I like the image provided here https://nginxproxymanager.com/guide/. It provides seemless Let's Encrypt support and a friendly UI. I spin this up in a separate container group in case I want to use it for other services.
# Docker Image Maintenance
## Watchtower
Watchtower will pull down your new image, gracefully shut down your existing container and restart it with the same options that were used when it was deployed initially. Ref https://github.com/containrrr/watchtower and https://hub.docker.com/r/containrrr/watchtower
# References
https://docs.saltbox.dev/saltbox/basics/basics/ (possible solution to unify all applications under SSO)
https://www.reddit.com/r/homelab/comments/1b3kfcd/media_management_servarr_diagram_plex_prowlarr/ (great diagram)
