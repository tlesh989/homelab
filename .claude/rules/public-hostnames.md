# Public Hostname Hygiene

This repo is public and easily scraped. Hostnames under the public domain (the `.net` zone,
e.g. the public Minecraft server) are meant to stay unadvertised.

- **Never write a public-domain hostname** in anything published to GitHub: PR titles/bodies,
  PR/issue comments, commit messages, review replies (`/fix-pr`, `/ship` summaries), or
  code comments and examples. Say "the Minecraft server domain" or use `example.net`.
- **Code and config reference the domain by variable or env lookup only**
  (e.g. `lookup('env', 'MINECRAFT_SERVER')`, Doppler `DDNS_DOMAINS`) — never a literal.
- Quoting reviewer/bot text into a reply or comment counts: redact hostnames first.
- Before `gh pr create|edit|comment`, `git commit`, or `gh api ... replies`, check the text:
  `grep -E '\.net\b'` must return nothing (other than `example.net`).
- If one slips through, edit/delete the PR text or comment and tell the user; history
  rewrites need explicit approval (force-push to protected `main`).
- The internal `.xyz` domain is unaffected.
