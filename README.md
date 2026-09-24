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
  after editing and check the key against the server:

  ```sh
  python3 - <<'EOF'
  import base64, json, re, pathlib
  s = re.search(r'"(=.*?)"', pathlib.Path('src/data/config.ts').read_text()).group(1)
  print(json.loads(base64.urlsafe_b64decode(s[::-1] + '=')))
  EOF
  ```

- **Windows downloads are portable.** The published `.exe` unpacks itself and
  runs without installing anything, so the guidance on the page assumes the user
  is only running it for one session and then deleting it.
