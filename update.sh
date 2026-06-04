#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$0")")"

echo "==> Pulling latest images..."
docker compose pull

echo "==> Rebuilding Plex with latest base image..."
docker compose build --pull plex

echo "==> Recreating updated containers..."
docker compose up -d

echo "==> Cleaning up old images..."
docker image prune -f

echo "==> Done."
docker compose ps
