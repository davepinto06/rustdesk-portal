#!/usr/bin/env bash
# Build the site and publish it to the directory Caddy serves.
#
#   scripts/deploy.sh             build from a clean checkout and publish
#   scripts/deploy.sh --rollback  republish the most recent backup
#
# Caddy's container bind-mounts $DEPLOY_DIR read-only at /srv/site and serves it with
# file_server, so publishing is just updating files on disk: no reload, no restart.
# Files are updated in place (never the directory itself, which would break the bind mount):
#   1. new content-hashed assets in _astro/ are added first, so no page ever references a
#      file that is not there yet;
#   2. every other file is replaced by an atomic rename;
#   3. files no longer in the build are removed, except old _astro/ assets, which are kept for
#      KEEP_ASSET_DAYS so pages still cached in a browser keep their CSS.
# The previous contents are saved to $BACKUP_DIR first (last 5 kept).
set -euo pipefail

cd "$(dirname "$0")/.."

DEPLOY_DIR="${DEPLOY_DIR:-$HOME/docker/rustdesk/site/dist}"
BACKUP_DIR="${BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/rustdesk-portal/backups}"
KEEP_ASSET_DAYS="${KEEP_ASSET_DAYS:-7}"

die() { echo "deploy: $*" >&2; exit 1; }

case "${1:-}" in
  "" | --rollback) ;;
  -h | --help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown argument '$1' (use --rollback or --help)" ;;
esac

[ -d "$DEPLOY_DIR" ] || die "$DEPLOY_DIR does not exist"

backup() {
  mkdir -p "$BACKUP_DIR"
  local file="$BACKUP_DIR/site-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
  tar -czf "$file" -C "$DEPLOY_DIR" .
  echo "backed up current site to $file"
  ls -1t "$BACKUP_DIR"/site-*.tar.gz | tail -n +6 | xargs -r rm -f
}

publish() {
  local src="$1"
  for f in index.html 404.html; do
    [ -s "$src/$f" ] || die "$src/$f is missing or empty; refusing to publish"
  done

  mkdir -p "$DEPLOY_DIR/_astro"
  if [ -d "$src/_astro" ]; then
    cp -an "$src/_astro/." "$DEPLOY_DIR/_astro/"
  fi

  (cd "$src" && find . -path ./_astro -prune -o -type f -print) | while read -r f; do
    mkdir -p "$DEPLOY_DIR/$(dirname "$f")"
    cp -p "$src/$f" "$DEPLOY_DIR/$f.deploy-tmp"
    mv -f "$DEPLOY_DIR/$f.deploy-tmp" "$DEPLOY_DIR/$f"
  done

  (cd "$DEPLOY_DIR" && find . -path ./_astro -prune -o -type f -print) | while read -r f; do
    [ -e "$src/$f" ] || rm -f "$DEPLOY_DIR/$f"
  done

  find "$DEPLOY_DIR/_astro" -type f -mtime +"$KEEP_ASSET_DAYS" | while read -r f; do
    [ -e "$src/_astro/$(basename "$f")" ] || rm -f "$f"
  done
}

if [ "${1:-}" = "--rollback" ]; then
  latest=$(ls -1t "$BACKUP_DIR"/site-*.tar.gz 2>/dev/null | head -1)
  [ -n "$latest" ] || die "no backups in $BACKUP_DIR"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  tar -xzf "$latest" -C "$tmp"
  publish "$tmp"
  echo "rolled back to $latest"
  exit 0
fi

if [ -n "$(git status --porcelain)" ] && [ "${ALLOW_DIRTY:-}" != 1 ]; then
  die "working tree has uncommitted changes; commit them (or set ALLOW_DIRTY=1)"
fi

node scripts/check-config.mjs
corepack pnpm install --frozen-lockfile
corepack pnpm build

backup
publish dist
echo "deployed $(git rev-parse --short HEAD) to $DEPLOY_DIR"
