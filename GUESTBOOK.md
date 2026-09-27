# Guestbook spam controls (davidunderwood.net)

Endpoint: `guestbook.aspx` (ASP.NET Web Forms, inline C#).  
Storage: `App_Data/guestbook.json` (not browsable).  
Rate file: `App_Data/ratelimit.json`.

## Controls

1. **Honeypot** — hidden `website` field. Bots that fill it get a fake success; nothing is stored.
2. **Timed challenge** — form includes server-issued UTC ticks. Submits faster than **3 seconds** or older than **30 minutes** are rejected.
3. **Signed math CAPTCHA** — random `a + b` with an HMAC-SHA256 token over `ticks|sum` (server pepper). Answer must match and token must verify (prevents forging challenges).
4. **IP rate limit** — max **3** successful posts per client IP per rolling hour (`X-Forwarded-For` first hop if present, else `UserHostAddress`).
5. **Input hygiene** — strip tags/control chars; cap name 40 / message 280; HTML-encode on render; keep at most 200 entries.

## Ops notes

- App pool must run **.NET CLR v4.0** (Integrated) so `.aspx` executes. Static HTML still works if CLR is off; guestbook will not.
- `App_Data` must be writable by the app-pool identity (deploy `cacls … Everyone:F` covers this on the current host).
- Deploy copies should **not** delete live `App_Data/*.json` (Jenkins FileCopy does not MIR-delete).
- Rotate pepper in `guestbook.aspx` (`Secret`) if it ever leaks; existing tokens just re-issue on next GET.

## Manual test

- Human: load page → wait 3s → solve math → submit → entry appears.
- Bot-fast: submit immediately → rejected.
- Honeypot: fill `website` → fake thanks, no entry.
- Wrong math → rejected.
- Fourth post in an hour from same IP → rate limited.
