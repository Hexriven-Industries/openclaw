# Release Config Review

- Release: `<tag>`
- Compared against: `<previous-tag>`
- Reviewed by: `<name>`
- Date (UTC): `<yyyy-mm-dd>`

## Must-Review Keys (Security/Policy/Network/Auth)

- [ ] Reviewed all `must-review` keys from `config-surface-diff`.
- [ ] Decision recorded for each key below.

| Key     | Decision (`accept default` / `override`) | Rationale | Env (`dev`/`prod`/`both`) |
| ------- | ---------------------------------------- | --------- | ------------------------- |
| `<key>` | `<decision>`                             | `<why>`   | `<env>`                   |

## Optional Keys (Behavior/UX)

- [ ] Reviewed added optional keys and selected explicit overrides where needed.

| Key     | Decision     | Rationale |
| ------- | ------------ | --------- |
| `<key>` | `<decision>` | `<why>`   |

## Removed/Deprecated Keys

- [ ] Checked for removed keys still present in config.
- [ ] Cleanup planned or completed.

| Key     | Action               | Notes     |
| ------- | -------------------- | --------- |
| `<key>` | `<remove/keep-temp>` | `<notes>` |

## Verification

- [ ] Dev booted with target config path and state dir.
- [ ] `openclaw doctor` clean.
- [ ] `openclaw channels status --probe` passes expected channels.
- [ ] Exec approval flow confirmed in Discord for dev.
- [ ] SSRF allowlist hosts tested (expected allow/deny behavior).

## Sign-off

- [ ] Safe to promote from Dev to Prod.
