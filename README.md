# rustdesk-portal

The download page for a self-hosted RustDesk server. One static page, no backend,
no analytics, no tracking. Built with Astro and deployed as plain files.

## Running it

```sh
pnpm install
pnpm dev      # http://localhost:4321
pnpm build    # static output in dist/
```

Node 22 or newer. A build takes a couple of seconds.

## How the downloads work

The page reads `/dl/manifest.json` from its own origin and uses it to fill in the
download URLs, file sizes, versions and SHA-256 checksums. That way a new client
build shows up on the page without any change here.

The manifest is written by CI — never edit it by hand. If it cannot be fetched
(running locally, for instance) the page falls back to plain `/dl/...` links and
hides the checksum column rather than showing values it cannot vouch for.

## Deploying

The site is served by the production Caddy container from `~/docker/rustdesk/site/dist`
(bind-mounted read-only at `/srv/site`). Publish from a clean, committed checkout:

```sh
pnpm release                  # check config, build, back up the live copy, publish
bash scripts/deploy.sh --rollback   # republish the most recent backup
```

No Caddy reload is needed. The script updates files in place in a safe order (new hashed
assets first, then atomic replacement of everything else) and keeps the last five backups in
`~/.local/state/rustdesk-portal/backups/`.

## Editing notes

- **Text is bilingual.** Every user-visible string appears twice, tagged
  `data-i18n-es` and `data-i18n-en`; CSS hides the inactive language. Spanish is
  the default and the toggle remembers the visitor's choice.
- **Theme** defaults to light, follows the OS until the visitor picks one, then
  remembers that.
- **Fonts** are imported per subset in `src/styles/global.css`. Only latin
  subsets are imported deliberately — importing `@fontsource/inter/400.css`
  instead would also pull cyrillic, greek and vietnamese files the page never
  uses.
- **`src/data/config.ts`** holds the macOS config string that users paste into
  RustDesk once. It is a reversed, base64url-encoded JSON object containing the
  server host and its public key. A wrong value fails silently in the client —
  it accepts the string and only errors later, when connecting — so decode it
  after editing: `pnpm check:config` checks it against `RUSTDESK_SERVER_HOST` and
  `RUSTDESK_SERVER_PUBKEY` (the deploy script runs it too).
- **macOS import steps** on the page name the RustDesk 1.4 menu items in each language
  (Ajustes → Red → Desbloquear Ajustes de Red → Servidor ID/Relay → paste icon). Re-check
  them against the client when RustDesk's settings UI changes. There is deliberately no
  `--config` Terminal command: RustDesk only honours it when run as root.
- **Platform detection** runs in an inline script in `Layout.astro` before first paint and
  sets `data-os` on `<html>`; components read that instead of sniffing the user agent.

- **Windows downloads are portable.** The published `.exe` unpacks itself and
  runs without installing anything, so the guidance on the page assumes the user
  is only running it for one session and then deleting it.
