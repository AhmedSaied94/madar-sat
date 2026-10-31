# Staff accounts

Who can sign in to the admin API, and how to create an account, reset a password, switch an account off, and respond to a suspected leak. Accounts are managed from the backend CLI until the admin app gets its own screen (A16, D6); TOTP follows on D16. Every command here changes production's database. Background: research R1–R4, FR-055; code in `backend/app/auth/admins.py` and `backend/app/cli.py`.

## Before you start

- You are in the "Working on VPS-1" shell ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)): `dc` is defined and `IMAGE_TAG` is set.
- The commands run in the `cli` service, which uses the image of `IMAGE_TAG`. It reads `DATABASE_URL_SYNC` from `/srv/madar/.env`. It does not need `ADMIN_JWT_SECRET` to run, but `api-admin` refuses to start without one ([secrets.md](secrets.md#where-they-live)).
- The roles:

  | Role | Can do |
  | --- | --- |
  | `editor` | The admin API on D2: matches, entities, lists and uploads, except the next row |
  | `admin` | Everything an editor can, plus the bulk action `remove_channels` (clearing the visible channel links of many matches at once). An editor who tries it gets `403 forbidden` with `required_role: admin`. Later days limit more to admins (account management in A16, D6). |

  Give editors `editor`. Keep `admin` to the owner.
- A password is 12 to 256 characters. There is no `--password` option on purpose: it would land in your shell history and in `ps`. The CLI asks for it twice with no echo, or reads one line from stdin with `--password-stdin`.
- Passwords are stored as argon2id hashes. No command prints one, and the `audit_log` row each command writes holds no password or hash.

## Create an account

```bash
dc run --rm cli create-admin --email owner@example.com --name "اسم المحرر" --role admin
```

You should see `Password:` and `Repeat password:` prompts (the terminal shows nothing as you type), then:

```text
created admin owner@example.com (id 1)
```

`dc run` gives the command a terminal, which the prompts need. To feed the password from a pipe instead, for example from your password manager's CLI:

```bash
read -rsp 'Password: ' PW; echo
printf '%s\n' "$PW" | dc run --rm -T cli create-admin --email editor@example.com --name "محرر" --role editor --password-stdin
unset PW
```

It refuses, and prints why (`error: …`, exit status 1), when:

| Message | Cause |
| --- | --- |
| `the password must be 12 to 256 characters long` | Too short or too long |
| `the two passwords differ` | The prompts didn't match |
| `an admin with that email already exists` | Emails compare case-insensitively |
| `not a valid email address: …` | The address doesn't parse |
| `the name must be 1 to 80 characters long` | |
| `the role must be one of: editor, admin` | |

Give the person the password over a channel you trust, and ask them to keep it in a password manager. There is no self-service reset yet.

## Check an account works

From a WireGuard peer ([private-network.md](private-network.md#the-admin-site) has the CA root):

```bash
API=https://10.8.0.1/admin/api; CA="--cacert $HOME/.config/madar/caddy-root.crt"
read -rsp 'Password: ' PW; echo
jq -n --arg email owner@example.com --arg password "$PW" '{email: $email, password: $password}' \
  | curl $CA -s -X POST $API/auth/login -H 'Content-Type: application/json' -d @- | jq '.data.admin, .data.expires_in'
unset PW
```

You should see the account (`id`, `email`, `name`, `role`) and `900`.

## Reset a password

```bash
dc run --rm cli set-admin-password --email editor@example.com
```

It ends with `password changed for editor@example.com; every session of theirs has ended`. The change revokes the person's refresh tokens, so an old session can't refresh: it stops working when its 15-minute access token runs out. If a stolen session must stop this minute, [deactivate the account](#deactivate-an-account) instead (it is refused on the next request), then bring it back as described there.

A locked-out person ("too many attempts") has not forgotten their password: five failed logins in 15 minutes lock **that email from that address** for 15 minutes. The lock ends by itself, and a password reset doesn't clear it. Tell them to wait 15 minutes.

## Deactivate an account

For someone who leaves, or a stolen device:

```bash
dc run --rm cli deactivate-admin --email editor@example.com
```

It ends with `deactivated editor@example.com; every session of theirs has ended`. The account is refused at once, even for a valid access token, because every admin request loads the account from the database and the access token's role is never trusted. The row and its `audit_log` history stay, so their past edits keep their name.

There is no command to reactivate an account yet. If you deactivated the wrong one, in `psql` ([database-migrations.md](database-migrations.md#read-the-state)):

```sql
UPDATE admin_users SET is_active = true WHERE email = 'editor@example.com';
```

then set a new password with `set-admin-password`.

## Who changed what

Every admin edit writes an `audit_log` row with the admin's id, and the account commands above write a row with no admin and no source (a system action), `entity = 'admin_users'`. In `psql`:

```sql
SELECT created_at, entity, entity_id, action, diff
FROM audit_log WHERE entity = 'admin_users' ORDER BY id DESC LIMIT 20;
```

## A token or password may have leaked

Pick by what leaked:

| What leaked | Do |
| --- | --- |
| One person's password, or their laptop | [`set-admin-password`](#reset-a-password) for them. If they must be out immediately, [`deactivate-admin`](#deactivate-an-account) first. |
| `ADMIN_JWT_SECRET` | [Rotate it](secrets.md#rotate-the-admin-jwt-secret). Every access token ever signed with the old key stops verifying, so nobody can forge one. Refresh tokens are random values kept hashed in the database, not signed with this key, so people stay signed in: their next refresh gives them a new access token. |
| A refresh token (a cookie or a log line) | The token's owner: `set-admin-password`, which revokes all their refresh tokens. A token that is used twice already revokes its whole family. |
| Every session, now | Rotate `ADMIN_JWT_SECRET`, then end all refresh tokens in `psql` (below). Everyone signs in again. |

To end every session:

```sql
UPDATE admin_refresh_tokens SET revoked_at = now() WHERE revoked_at IS NULL;
```

Then look for use you don't recognise: `audit_log` rows in the window ([above](#who-changed-what), filtered by `admin_user_id`), and `sudo wg show wg0` for WireGuard peers you don't know. Admin routes are reachable only over WireGuard, so a leaked token alone does not reach them from the internet.

## If it fails

| Symptom | Do |
| --- | --- |
| `dc run` says `IMAGE_TAG` is not set | Re-run the `export IMAGE_TAG=…` line of the shell setup. |
| `error: the two passwords differ` | Run the command again. |
| `the input device is not a TTY` | You piped into `dc run` without `-T`. Add `-T` and `--password-stdin`, or run it without the pipe. |
| Login answers `429 account_locked` | Five failures in 15 minutes. It ends after the `Retry-After` seconds. |
| Login answers `401 invalid_credentials` for a password you just set | Check the email (case doesn't matter) and that the account isn't deactivated (`SELECT email, is_active FROM admin_users;`). The answer is the same for an unknown email on purpose. |
| `api-admin` restarts in a loop after a deploy | `ADMIN_JWT_SECRET` is missing or shorter than 32 bytes in `/srv/madar/.env`: see `dc logs api-admin`. |
