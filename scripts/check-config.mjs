// Fails if RUSTDESK_CONFIG_STRING in src/data/config.ts does not decode to the server host and
// public key declared next to it. RustDesk accepts a wrong string silently and only fails at
// connect time, so this runs before every build that gets deployed.
import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('../src/data/config.ts', import.meta.url), 'utf8');
const constant = (name) => {
  const m = src.match(new RegExp(`export const ${name} = "([^"]*)"`));
  if (!m) throw new Error(`${name} not found in src/data/config.ts`);
  return m[1];
};

const configString = constant('RUSTDESK_CONFIG_STRING');
const host = constant('RUSTDESK_SERVER_HOST');
const key = constant('RUSTDESK_SERVER_PUBKEY');

// The string is base64url of a JSON object, reversed.
const decoded = JSON.parse(
  Buffer.from([...configString].reverse().join(''), 'base64url').toString('utf8'),
);

const problems = [];
if (decoded.host !== host) problems.push(`host is "${decoded.host}", expected "${host}"`);
if (decoded.key !== key) problems.push(`key is "${decoded.key}", expected "${key}"`);

if (problems.length) {
  console.error(`RUSTDESK_CONFIG_STRING is wrong: ${problems.join('; ')}`);
  process.exit(1);
}
console.log(`config string OK: host=${decoded.host}, key=${decoded.key.slice(0, 8)}…`);
