# Home box: the scrape worker on wg0

The owner's x86-64 box runs the ysscores fetch, because ysscores answers `403` to datacenter IPs.
It is a WireGuard peer that reaches Redis on `wg0` and nothing else: no database, no media disk, no
inbound ports (FR-028, research R21). The worker is `worker-scrape -Q scrape_home` from
`ghcr.io/<owner>/madar-backend-amd64:stable`, with a systemd timer that updates it every 10 minutes.

## What the box needs

| Item | Value |
| --- | --- |
| WireGuard peer | Added on VPS-1 with `infra/scripts/wg-add-peer.sh home-box`; its address becomes `HOME_BOX_WG_IP` (for example `10.8.0.4`) |
| Repo checkout | `/srv/madar/infra` on the box (`git clone` or `rsync`); it holds `compose/home-box.yml` and the update script |
| `.env` | `/srv/madar/.env`, mode 600, owned by the user that runs Docker |
| Docker | Engine with Compose v2, and the user in the `docker` group |
| Units | `home-box-update.service` and `home-box-update.timer` in `/etc/systemd/system/` |

The box's `.env` is `compose/example.env` with only these keys set (never a database URL):

```sh
GHCR_OWNER=<the lowercase GitHub owner>
REDIS_URL=redis://homebox:<REDIS_HOMEBOX_PASSWORD>@10.8.0.1:6379/0
SCRAPE_USER_AGENT=MadarSat/1.0 (+https://madar.example; you@example.com)
GHCR_READ_TOKEN=<a read-only packages token>
```

`REDIS_HOMEBOX_PASSWORD` must equal the value on VPS-1: that is the `homebox` user in
`infra/redis/users.acl.tmpl`. `GHCR_READ_TOKEN` is a GitHub token with only `read:packages`; the
script logs in with it and logs out immediately.

## Join the box to wg0

On VPS-1, as `deploy`:

```sh
/srv/madar/infra/scripts/wg-add-peer.sh home-box    # prints the peer's client config once
```

Paste that config into `/etc/wireguard/wg0.conf` on the box, then:

```sh
sudo systemctl enable --now wg-quick@wg0
sudo wg show                       # a handshake with 10.8.0.1
```

The WebRTC/VCN path is not used: the box talks to `10.8.0.1:6379` over `wg0`. Keep the hub's
public UDP 51820 open (it is, for every peer).

## Set `HOME_BOX_WG_IP` and apply the firewall

The peer's address is what limits Redis to this box:

1. Put it in VPS-1's `/srv/madar/.env` as `HOME_BOX_WG_IP` (it must be an IPv4 address).
2. Re-run `sudo /srv/madar/infra/scripts/bootstrap-vps.sh vps1` — it renders
   `infra/firewall/vps1.rules` with the new address, restarts Docker, and runs
   `check-firewall.sh`, which now fails if the Redis rule is missing or if any rule still accepts
   6379 from every `wg0` peer ([firewall-changes.md](firewall-changes.md)).
3. Deploy the ACL (any deploy does it): the rendered `/srv/madar/redis/users.acl` defines
   `homebox`, and Compose restarts Redis to read it ([deploy-and-rollback.md](deploy-and-rollback.md)).

## Start and check the worker

```sh
cd /srv/madar && docker compose --env-file /srv/madar/.env -f infra/compose/home-box.yml up -d
docker compose -f infra/compose/home-box.yml ps
docker compose -f infra/compose/home-box.yml logs -f worker-scrape
```

Healthy means the container reports `healthy` (its healthcheck runs `celery inspect ping`) and the
log line names the `scrape_home` queue. Then start a run by hand from VPS-2 and watch
`import_runs` ([imports-and-sources.md](imports-and-sources.md)): the fetch is on this box, the
ingest is on VPS-2.

The ACL allows only `celery:*`, `ratelimit:*` and `lock:fetch:*`. If the log shows `NOPERM`, the
box is touching a key it should not (or the ACL file on VPS-1 is stale): check
`docker exec madar-redis redis-cli -a "$REDIS_PASSWORD" ACL LIST` on VPS-1, and re-deploy.

## Updates

The timer runs `/srv/madar/infra/scripts/home-box-update.sh` every 10 minutes:

```sh
sudo systemctl enable --now home-box-update.timer
systemctl list-timers home-box-update.timer
sudo journalctl -u home-box-update.service -n 50
sudo /srv/madar/infra/scripts/home-box-update.sh --dry-run    # validates the Compose file only
```

The script logs in with `GHCR_READ_TOKEN`, pulls `madar-backend-amd64:stable`, logs out, and
recreates the worker. `stable` moves only after both VPS deploys succeed, so the box never runs an
image the API rejected. CI never connects to the box: an offline box fails nothing and catches up
on the next tick.

## Take it offline

```sh
cd /srv/madar && docker compose --env-file /srv/madar/.env -f infra/compose/home-box.yml down
sudo systemctl disable --now home-box-update.timer
```

While it is off, ysscores does not run (the beat entry queues on `scrape_home`, which now has no
consumer) and the bridge still brings fixtures from Sat Air. The queued fetches expire after 2
hours; nothing stale is replayed. To keep ysscores running meanwhile, switch
`YSSCORES_FETCH_QUEUE=scrape` on VPS-2 ([imports-and-sources.md](imports-and-sources.md)).

To remove the peer, delete its `[Peer]` block from `/etc/wireguard/wg0.conf` on VPS-1 and
`wg syncconf wg0 <(wg-quick strip wg0)`; leave `HOME_BOX_WG_IP` in place (the rule then admits an
address nobody has, and Redis stays closed to the other peers).
