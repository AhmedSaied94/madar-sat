# Deploy and roll back

Deploys are automatic. A push to `master` that changes `backend/**` (or `backend.yml`) builds the images and deploys them to VPS-1 and then VPS-2. A push that changes only `infra/**` or `.github/**` applies the infra files without a new image. Both go through `infra/scripts/deploy.sh`, over WireGuard. It renders the Redis ACL, applies the infra services, records the running tag, pulls, migrates, starts the new release, checks health, and starts the previous release again if the check fails. Background: `specs/001-d01-foundation/research.md` R13, `specs/002-d02-core-flows/research.md` R20–R22, SD §9, and the header of `deploy.sh`.

## How a release reaches VPS-1

`backend.yml`, on a push to `master`:

| Job | What it does | Runs on PRs |
| --- | --- | --- |
| `test` | ruff, `mypy --strict`, pytest with PostgreSQL 16 and Redis 7 services | Yes |
| `openapi` | Exports both OpenAPI documents and fails if the committed ones differ; once `contract-v1` exists, fails on a breaking change | Yes |
| `clients` | Regenerates the admin and app clients and fails if they're stale. Skipped until `admin/orval.config.ts` and `app/swagger_parser.yaml` both exist. | Yes |
| `build` | Builds `linux/arm64` with buildx and QEMU (or on `vars.ARM_RUNNER`) and pushes `ghcr.io/ahmedsaied94/madar-backend:<sha>` | No |
| `build-amd64` | Builds `linux/amd64` natively on `ubuntu-24.04` and pushes `ghcr.io/ahmedsaied94/madar-backend-amd64:<sha>`, the home box's image | No |
| `deploy` | Joins WireGuard as `ci`, pins VPS-1's host key, `rsync`s `infra/` to `/srv/madar/infra/`, then runs `deploy.sh <sha>` as `deploy@10.8.0.1`, with the job's `GITHUB_TOKEN` on stdin | No |
| `deploy-vps2` | Same WireGuard step, then rsyncs `infra/` and runs `deploy.sh --host vps2 <sha>` through the ssh config's `vps1` jump (`ProxyJump`, no `-J` on the command line) ([workers.md](workers.md)) | No |
| `stable` | Moves `madar-backend-amd64:stable` to `<sha>`, so the home box picks the release only after both hosts are healthy | No |
| `retention` | Keeps the newest 3 versions of `madar-backend` and of `madar-backend-amd64` in GHCR ("Images in GHCR" below) | No |

`deploy.sh <sha>`, in order:

1. renders `/srv/madar/redis/users.acl` from `infra/redis/users.acl.tmpl` and `/srv/madar/.env` through `render-redis-acl.sh` (file mode 640, directory 750, group 999, so the redis user can read it), then `docker compose up -d --wait caddy postgres redis` (only services whose definition changed are recreated), then `caddy reload`. A changed ACL restarts Redis and pings as both `default` and `homebox`; a refused ACL puts the previous file back, both when the `up` recreates Redis and when the reload restarts it (B2-R3-2);
2. writes the running tag to `/srv/madar/previous_tag`;
3. logs in to GHCR with the token from stdin, pulls, and logs out (also on exit), so no registry credential stays on the host;
4. runs `alembic upgrade head` in a one-off `migrate` container. If it fails, it stops **before** touching the running APIs;
5. starts `api-public`, `api-admin` and `worker-media` on the new tag;
6. polls `http://127.0.0.1:8000/healthz`, `http://10.8.0.1:8001/admin/api/healthz` and `worker-media`'s healthcheck for 60 s;
7. on success, writes the tag to `/srv/madar/current_tag`. On failure, starts the previous tag again (the media worker included), checks it, and exits non-zero.

VPS-2's deploy is shorter because nothing there owns state: no Caddy, no migrations, no Redis. It
records the running tag, pulls, runs `compose --profile workers up -d` for `worker-imports`,
`worker-scrape`, `worker-maintenance` and `beat`, waits up to 90 s for all four healthchecks, and — like
VPS-1 — rolls back to the previous tag when the start or the check fails ([workers.md](workers.md)).

Deploys never overlap. `backend.yml`'s `deploy` and `infra.yml`'s `sync` share the concurrency group `deploy-vps1`, `deploy-vps2` has its own group, and `deploy.sh` holds `/srv/madar/.deploy.lock` while it runs. GitHub keeps one waiting run per group, so a third merge replaces the waiting one, and the newest commit wins.

The `build` job, under QEMU, is the slow part. SC-005 asks for a change to be live within 15 minutes.

## Working on VPS-1

The other runbooks use this shell. Over WireGuard:

```bash
ssh ubuntu@10.8.0.1
sudo -iu deploy                      # owns /srv/madar, and is in the docker group
cd /srv/madar/infra                  # CI's copy of infra/; don't edit it, the next sync replaces it
export IMAGE_TAG=$(cat /srv/madar/current_tag 2>/dev/null || echo none)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps1.yml "$@"; }
dc ps
```

`vps1.yml` needs `IMAGE_TAG` to parse. `none` is enough for commands that don't touch the APIs.

Useful from there:

```bash
cat /srv/madar/current_tag /srv/madar/previous_tag   # serving and previous tags
docker logs --tail 100 madar-api-public-1             # also madar-api-admin-1, madar-caddy-1, madar-postgres-1, madar-redis-1
curl -fsS http://127.0.0.1:8000/healthz               # what deploy.sh checks
```

## Reading a failed deploy

`deploy.sh` exits 1 on every failure (2 for a wrong call), so read the last `[deploy]` lines in the job's "Deploy <sha>" step:

| Last lines | Meaning | What's serving | Do |
| --- | --- | --- | --- |
| `wg-quick` errors in "Join WireGuard", `Host key verification failed`, or `Permission denied (publickey)` | CI can't reach VPS-1 | Unchanged | Check `WG_CI_CONFIG`, `DEPLOY_KNOWN_HOSTS` and `DEPLOY_SSH_KEY` against [provision-host.md §8](provision-host.md#8-deploy-peer-and-keys) |
| `error: /srv/madar/.env is missing` | The host isn't bootstrapped | Unchanged | [provision-host.md §4](provision-host.md#4-fill-the-env-file-and-re-run) |
| `error: another deploy is running` | A manual deploy holds the lock | Unchanged | On VPS-1: `pgrep -af deploy.sh`. Wait for it, then re-run the job. |
| Compose or Caddy errors before `pulling` | Step 1: `caddy`, `postgres` or `redis` didn't come up healthy, or the Caddyfile didn't load | The APIs are unchanged. A failed `caddy reload` keeps the old config. | Read that container's log. Fix in a new commit. |
| `denied` or `unauthorized` at login or pull | The repository can't read the package | Unchanged | "Images in GHCR" below |
| `error: migration failed; the running containers were not touched (still <tag>)` | `alembic upgrade head` failed | The previous release | Read the migration's error above it. [database-migrations.md](database-migrations.md#when-a-migration-fails) |
| `health check failed for <sha>`, then `rolled back to <prev>, which is healthy` | The new release didn't pass `/healthz`, or `worker-media` didn't get healthy, within 60 s | The previous release, restored | See below: the failed release's containers are already gone |
| `error: no previous tag to roll back to; <sha> is left running for inspection` | The very first deploy failed | The failed release | `docker logs --tail 100 madar-api-public-1`, fix, push again |
| `rolled back to <prev>, but it is not healthy either` | Both releases fail `/healthz` | **Possibly nothing** | **Act now.** `/healthz` returns 503 when PostgreSQL or Redis is down: `dc ps`, then the `postgres` and `redis` logs. Then deploy a known-good tag by hand ("Roll back"). |

After a rollback, the new release's containers have been replaced, so `docker logs` shows the previous release. To see why the new one failed, start it once by hand, without published ports, and read its output (Ctrl-C to stop):

```bash
IMAGE_TAG=<sha> dc run --rm api-public
```

## Roll back

**Migrations are never reversed.** Every migration keeps the previous release working (expand/contract, constitution "Migrations"), so an older release runs on the newer schema.

- **Automatic:** step 7 above.
- **By hand, to any tag** (works across migrations). In the "Working on VPS-1" shell:

  ```bash
  docker image ls ghcr.io/ahmedsaied94/madar-backend      # the tag must be on the host
  IMAGE_TAG=<tag> HEALTHZ_FORCE_FAIL=false dc up -d api-public api-admin worker-media
  curl -fsS http://127.0.0.1:8000/healthz && curl -fsS http://10.8.0.1:8001/admin/api/healthz
  docker inspect --format '{{.State.Health.Status}}' "$(IMAGE_TAG=<tag> dc ps -q worker-media)"   # healthy
  echo <tag> > /srv/madar/current_tag
  ```

- **VPS-2** rolls back by itself when its four services don't get healthy in 90 s. To do it by hand,
  run `deploy.sh --host vps2 <tag>` with the earlier tag: [workers.md "Roll back VPS-2"](workers.md#roll-back-vps-2).

  If the tag isn't on the host, pull it first. The package is private, so log in with a token that has `read:packages`, from your machine:

  ```bash
  gh auth refresh -s read:packages          # once
  gh auth token | ssh ubuntu@10.8.0.1 'sudo -u deploy docker login ghcr.io -u ahmedsaied94 --password-stdin'
  ssh ubuntu@10.8.0.1 'sudo -u deploy docker pull ghcr.io/ahmedsaied94/madar-backend:<tag>; sudo -u deploy docker logout ghcr.io'
  ```

- **From GitHub:** re-running the `deploy` job of an older `backend` run redeploys that commit through `deploy.sh`. That runs that release's `alembic upgrade head`, which fails (`Can't locate revision …`) if a migration was added since. Use it only when no migration came after that release, and only if its image is among the 3 kept in GHCR.

Then revert the bad commit on `master`. The revert deploys normally. Until then, the next backend push deploys the bad change again.

## Rehearse the failure path

The rollback drill (SC-005, T066). It deploys `master`'s newest commit with `HEALTHZ_FORCE_FAIL=true`, so its `/healthz` fails and `deploy.sh` rolls back.

**First, make sure `master`'s newest commit isn't the one serving.** `deploy.sh` records the running tag as the previous one, so if `master`'s head is already deployed, the drill "rolls back" to the same image and only proves the setting change. It also overwrites `previous_tag` with the current tag.

```bash
ssh ubuntu@10.8.0.1 cat /srv/madar/current_tag
ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118 cat /srv/madar/current_tag   # VPS-2 comes back too
git fetch origin && git rev-parse origin/master
```

If they match, merge a change that doesn't touch `backend/**` first (a docs change is enough), so `master`'s head has a new, undeployed sha. Then:

```bash
R=AhmedSaied94/madar-sat
gh workflow run backend.yml -R "$R" --ref master -f break_healthcheck=true
gh run watch -R "$R" "$(gh run list -R "$R" --workflow backend.yml -L 1 --json databaseId -q '.[0].databaseId')"
```

Poll the public API from another terminal during the run. It must answer `200` throughout, apart from a few seconds while the containers swap:

```bash
while sleep 1; do curl -s -o /dev/null -w '%{http_code}\n' https://api.130.110.117.215.sslip.io/healthz; done
```

Expect:

- `test`, `openapi`, `clients` and `build` pass; `deploy` fails; `retention` is skipped;
- the deploy log shows `health check failed for <new sha>`, `rolling back to <old sha>`, then `rolled back to <old sha>, which is healthy`;
- on VPS-1, `cat /srv/madar/current_tag` is the old sha, and `docker ps --format '{{.Names}} {{.Image}}'` shows the old tag on both APIs.

For the rest of T066, merge a trivial `backend/` change and time it from merge to `current_tag` showing its sha (15 minutes or less). Then count the versions in GHCR (next section).

## Images in GHCR

Images live in `ghcr.io/ahmedsaied94/madar-backend`, tagged with the commit sha. The repository is private, so the package is private too, and the free plan gives private packages only 500 MB of storage (research R13). After every successful deploy, the `retention` job keeps the newest 3 versions: the current one, the previous one for rollback, and a spare.

```bash
gh auth refresh -s read:packages      # once
gh api /user/packages/container/madar-backend/versions --jq length     # 3 after a successful deploy
```

- **Access.** The deploy pulls with the job's `GITHUB_TOKEN`, and `retention` deletes with it. Both need the repository to have access to the package. After the first push: your GitHub profile → Packages → `madar-backend` → Package settings → Manage Actions access → add `madar-sat` with the **Admin** role. Without it, `retention` fails, and pulls may fail with `denied`.
- **Storage.** Check Settings → Billing for package storage. Three versions share most layers, but if they don't fit in 500 MB, keep fewer or make the package public (a decision for constitution IX).
- **VPS-1's disk.** Nothing removes old images on the host. Check now and then, and remove tags other than the current and previous ones:

  ```bash
  docker system df
  docker image ls ghcr.io/ahmedsaied94/madar-backend
  docker image rm ghcr.io/ahmedsaied94/madar-backend:<old sha>
  ```

  Don't use `docker image prune -a`: it also removes the previous release's image, which the manual rollback needs.

## One-time setup

Do these before the first merge of Lanes B1 and B2.

1. **Secrets and variables** (Settings → Secrets and variables → Actions). The workflows read repository-level secrets; there are no GitHub Environments.

   | Name | Kind | Made in |
   | --- | --- | --- |
   | `WG_CI_CONFIG` | Secret | [provision-host.md §8](provision-host.md#8-deploy-peer-and-keys) |
   | `DEPLOY_SSH_KEY` | Secret | provision-host.md §8 |
   | `DEPLOY_KNOWN_HOSTS` | Secret | provision-host.md §8 |
   | `FIREBASE_SERVICE_ACCOUNT` | Secret | [firebase-hosting.md §2](firebase-hosting.md#2-service-account-and-key) |
   | `VPS1_IP`, `VPS2_IP` | Variables | The reserved IPs. No workflow reads them today; they are a record. |
   | `ARM_RUNNER` | Variable, optional | The label of a native arm64 runner. Leave it unset to build with QEMU. |

   Always set secrets from a file or a pipe, so the value never shows on screen or in shell history:

   ```bash
   R=AhmedSaied94/madar-sat
   gh secret set <NAME> -R "$R" < <file>
   gh variable set VPS1_IP -R "$R" --body 130.110.117.215
   gh variable set VPS2_IP -R "$R" --body 130.110.97.25
   ```

2. **Actions minutes.** The repository is private (checked 2026-10-29). The free plan caps Actions minutes for private repositories, and GitHub's free arm64 runners serve public repositories only, so every backend build runs under QEMU and takes many minutes. Watch Settings → Billing → Actions. If the minutes run out, the options are making the repository public or a self-hosted arm64 runner (`ARM_RUNNER`); either is an owner decision under constitution IX.
3. **Failure emails:** GitHub → Settings → Notifications → Actions: turn on email for failed workflows. That email is the deploy alert until Uptime Kuma (D3).
4. **Who can reach the secrets.** Branch protection isn't available for private repositories on the free plan, and the secrets aren't tied to an Environment, so a workflow pushed to any branch of this repository can read them. Keep write access to yourself.

## Replacing a deploy key

Do this when `DEPLOY_SSH_KEY` may have leaked, or on a schedule.

1. Make a new key pair on your machine, as in [provision-host.md §8](provision-host.md#8-deploy-peer-and-keys).
2. On VPS-1, over WireGuard:

   ```bash
   sudoedit /srv/madar/.env                          # DEPLOY_SSH_PUBLIC_KEY=<the new .pub line>
   sudo ./madar-infra/scripts/bootstrap-vps.sh vps1  # adds the new key
   sudoedit /home/deploy/.ssh/authorized_keys        # delete the old key's line: the script never removes keys
   ```

3. `gh secret set DEPLOY_SSH_KEY -R AhmedSaied94/madar-sat < <new private key>`, then `shred -u` the key file.
4. Re-run the newest `infra` run on `master` to prove it ([private-network.md "Rotate the CI peer"](private-network.md#rotate-the-ci-peer) step 3 has the command).

If the key leaked, rotate the CI peer too: whoever has both can log in as `deploy`, which can run Docker.

`DEPLOY_KNOWN_HOSTS` holds VPS-1's host key **and** VPS-2's (the `deploy-vps2` job jumps through VPS-1). It changes if either VM is rebuilt: pin both, as in provision-host.md §8. `DEPLOY_SSH_KEY`'s public half must be in `deploy`'s `authorized_keys` on both hosts.

## Updating the edge or infra

A merge to `master` that changes `infra/**`, `.github/workflows/**` or `.github/actions/**` runs `infra.yml`: the checks (Compose validation for all four files, the home-box units, the ACL placeholders, Caddy, shellcheck, actionlint), then the `sync` job. `sync` joins WireGuard, `rsync`s `infra/` to `/srv/madar/infra/`, and runs `deploy.sh --infra-only`, which is step 1 above: it renders the Redis ACL, runs `compose up -d` for `caddy`, `postgres` and `redis` (only changed ones are recreated; recreating PostgreSQL or Redis is a short outage), then `caddy reload`. It reads no token and doesn't touch the APIs.

VPS-2's copy of `infra/` is synced by `backend.yml`'s `deploy-vps2`, which runs after every backend deploy. An infra-only change reaches VPS-2 on the next backend push, or by running `deploy.sh --host vps2 <current tag>` by hand ([workers.md](workers.md#deploy-vps-2)). The home box takes only the image and its own `compose/home-box.yml`, which it keeps in its checkout.

What it does **not** apply:

| Change | Applied by |
| --- | --- |
| `api-public`, `api-admin`, `worker-media`, `migrate` or `cli` in `vps1.yml` | The next backend deploy. To apply it now, in the "Working on VPS-1" shell: `dc up -d api-public api-admin worker-media`. |
| `/srv/madar/.env` | Nothing: it lives only on the host. Recreate the services that read it: `dc up -d --force-recreate api-public api-admin`, and `caddy` for `VPS1_IP`, `ACME_EMAIL` or `FIREBASE_PROJECT_ID`. |
| `infra/firewall/`, `infra/wireguard/`, the sshd drop-in, Docker's start order | `bootstrap-vps.sh` only: [firewall-changes.md](firewall-changes.md) |
| `vps2.yml`, or `infra/` on VPS-2 | `backend.yml`'s `deploy-vps2` on the next backend push, or `deploy.sh --host vps2 <tag>` by hand ([workers.md](workers.md)). |

If CI can't sync (WireGuard or the deploy key is broken), apply it by hand from your machine, over WireGuard:

```bash
rsync -a --delete infra/ ubuntu@10.8.0.1:madar-infra/
ssh ubuntu@10.8.0.1 'sudo rsync -a --delete --chown=deploy:deploy madar-infra/ /srv/madar/infra/ && sudo -iu deploy /srv/madar/infra/scripts/deploy.sh --infra-only'
```
