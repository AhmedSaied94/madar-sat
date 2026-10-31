# Private network (WireGuard)

SSH and the admin are reachable only over WireGuard. VPS-1 runs the hub on `wg0`, at `10.8.0.1/24` on UDP port 51820 of `130.110.117.215`. A WireGuard server never answers packets from unknown keys, so to a port scan it looks closed. VPS-2 isn't on WireGuard: you reach it by jumping through VPS-1. Background: SD §7.2, FR-022, and `infra/wireguard/`.

| | |
| --- | --- |
| Hub | `10.8.0.1/24`, endpoint `130.110.117.215:51820` |
| Peer addresses | `10.8.0.2`–`10.8.0.254`, one `/32` each. `wg-add-peer.sh` takes the lowest free one unless you pass one. |
| Peers | Your devices; `ci`, the deploy peer ([provision-host.md §8](provision-host.md#8-deploy-peer-and-keys)); the home scrape box later (D2) |
| What a peer reaches | Only `10.8.0.1`: SSH (TCP 22) and the admin site (TCP 443). Each peer config routes `10.8.0.1/32` through the tunnel and nothing else. |
| VPS-2 | `ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118` |

There are no peer roles. Any peer can reach SSH, but only someone whose key is in an `authorized_keys` file logs in.

## Your SSH config

On your machine, `~/.ssh/config` names the four ways in. The keys are the ones you gave each VM when you created it (`~/.ssh/madar-vps1.key`, `~/.ssh/madar-vps2.key`, mode 600):

| Alias | Goes to | Works |
| --- | --- | --- |
| `madar-vps1-public` | `ubuntu@130.110.117.215` | Until public SSH closes on VPS-1 ([provision-host.md §6–7](provision-host.md#6-ssh-over-wireguard-only)) |
| `madar-vps2-public` | `ubuntu@130.110.97.25` | Until public SSH closes on VPS-2 |
| `madar-vps1` | `ubuntu@10.8.0.1`, over WireGuard | Once your peer is up ([provision-host.md §5](provision-host.md#5-your-wireguard-peer)) |
| `madar-vps2` | `ubuntu@10.1.0.118`, with `ProxyJump madar-vps1` | Once `madar-vps1` works and the `10.1.0.97/32` TCP 22 rule is in the security list |

```sshconfig
Host madar-vps1-public
    HostName 130.110.117.215
    User ubuntu
    IdentityFile ~/.ssh/madar-vps1.key
    IdentitiesOnly yes

Host madar-vps2-public
    HostName 130.110.97.25
    User ubuntu
    IdentityFile ~/.ssh/madar-vps2.key
    IdentitiesOnly yes

Host madar-vps1
    HostName 10.8.0.1
    User ubuntu
    IdentityFile ~/.ssh/madar-vps1.key
    IdentitiesOnly yes

Host madar-vps2
    HostName 10.1.0.118
    User ubuntu
    IdentityFile ~/.ssh/madar-vps2.key
    IdentitiesOnly yes
    ProxyJump madar-vps1
```

The jump to VPS-2 authenticates to VPS-1 with VPS-1's key, then to VPS-2 with VPS-2's, both from your machine. No key is copied to VPS-1.

## Peers

Run these on VPS-1, over WireGuard (`ssh ubuntu@10.8.0.1`). The commands assume the copy of `infra/` in `~/madar-infra` ([provision-host.md §3](provision-host.md#3-run-the-bootstrap-script)).

### Add a peer

```bash
sudo ./madar-infra/scripts/wg-add-peer.sh <name>              # name: lowercase letters, digits, "-", such as owner-phone
sudo ./madar-infra/scripts/wg-add-peer.sh <name> 10.8.0.<n>   # or pick the address
```

It adds the peer to `/etc/wireguard/wg0.conf` and to the running `wg0`, and writes the client config to `/root/wireguard-peers/<name>.conf` (mode 600). It refuses a name that already exists. The config holds the device's private key, which the hub doesn't keep, so treat it like a password. Move it to the device, then delete it on VPS-1.

- **Linux laptop**, from your machine:

  ```bash
  ssh madar-vps1-public sudo cat /root/wireguard-peers/<name>.conf | sudo sh -c 'umask 077 && cat > /etc/wireguard/madar.conf'
  sudo wg-quick up madar
  ```

  Use `madar-vps1-public` (`130.110.117.215`) only for your very first peer, while public SSH is still open (provision-host.md §5). After that, use `madar-vps1` (`10.8.0.1`) from a device that is already connected ([Your SSH config](#your-ssh-config)). The tunnel routes only `10.8.0.1/32`, so it sits beside other WireGuard tunnels without clashing.
- **Other desktops:** copy the file the same way to `madar.conf`, use "Import tunnel(s) from file" in the WireGuard app, then delete the file.
- **Phone:** show it as a QR code on VPS-1 and scan it in the app. Never send the file by chat or email.

  ```bash
  sudo apt-get install -y qrencode
  sudo qrencode -t ansiutf8 < /root/wireguard-peers/<name>.conf
  ```

Then, on VPS-1:

```bash
sudo shred -u /root/wireguard-peers/<name>.conf
```

### The home box peer

The owner's x86-64 scrape box is a peer like any other, with one rule that no other peer has: it is
the only address allowed to reach Redis on `10.8.0.1:6379` ([firewall-changes.md](firewall-changes.md#redis-on-wg0-the-home-box)).

```bash
sudo ./madar-infra/scripts/wg-add-peer.sh home-box        # prints the client config once
```

Then:

1. put the config on the box as `/etc/wireguard/wg0.conf` and `sudo systemctl enable --now wg-quick@wg0`;
2. note its address (`10.8.0.<n>`, from `wg show wg0` or the `[Peer]` block) and set it in VPS-1's
   `/srv/madar/.env` as `HOME_BOX_WG_IP`;
3. re-run `sudo ./madar-infra/scripts/bootstrap-vps.sh vps1` so the rendered firewall carries that
   address, and deploy once so the Redis ACL defines the `homebox` user;
4. finish the box's own setup: [home-box.md](home-box.md).

`wg-add-peer.sh` also gives the peer the hub's public key and a preshared key, which is why the
box's config must be moved to it and deleted from VPS-1 like any other.

### List peers

```bash
sudo wg show wg0                                   # public keys, endpoints, latest handshakes
sudo grep -A3 '^# peer:' /etc/wireguard/wg0.conf   # names, with their public keys and addresses
```

### Remove a peer

Do this when a device is lost, replaced or handed back, or when its owner leaves.

```bash
sudo grep -A1 -x '# peer: <name>' /etc/wireguard/wg0.conf   # the line after it is "PublicKey = <key>"
sudo wg set wg0 peer '<key>' remove                          # access ends now
sudoedit /etc/wireguard/wg0.conf                             # delete the peer's block: [Peer], "# peer: <name>", PublicKey, PresharedKey, AllowedIPs
sudo wg show wg0                                             # the key is gone
```

Do both. `wg set` alone lasts only until `wg-quick@wg0` restarts. Editing the file alone takes effect only then. `wg0.conf` is the source of truth: the hub never writes it back on its own.

If the device also held an SSH private key, remove that key's line from `/home/ubuntu/.ssh/authorized_keys` on both VMs (VPS-2 through the jump). If it was your only device, see [break-glass.md](break-glass.md).

### Rotate the CI peer

Do this if `WG_CI_CONFIG` may have leaked, or with every deploy-key replacement.

1. Remove the peer `ci`, as above.
2. Add it again and replace the secret, from your machine:

   ```bash
   R=AhmedSaied94/madar-sat
   ssh ubuntu@10.8.0.1 sudo ./madar-infra/scripts/wg-add-peer.sh ci
   ssh ubuntu@10.8.0.1 sudo cat /root/wireguard-peers/ci.conf | gh secret set WG_CI_CONFIG -R "$R"
   ssh ubuntu@10.8.0.1 sudo shred -u /root/wireguard-peers/ci.conf
   ```

3. Prove it works: re-run the newest `infra` run on `master`. `infra.yml` has no manual trigger, and a re-run uses the current secrets.

   ```bash
   gh run rerun "$(gh run list -R "$R" --workflow infra.yml --branch master -L 1 --json databaseId -q '.[0].databaseId')" -R "$R"
   ```

`DEPLOY_KNOWN_HOSTS` doesn't change: it pins VPS-1's SSH host key, not the WireGuard key.

## The admin site

`https://10.8.0.1`, over WireGuard only. Caddy listens for it on `10.8.0.1` alone, with its own certificate authority (`tls internal`).

| Path | Served by |
| --- | --- |
| `/admin/api/*` | `api-admin`, on `10.8.0.1:8001` |
| Everything else | The admin SPA in `/srv/admin`. Until D4 that is the placeholder page from `infra/admin-placeholder/`. |

Always type `https://`. Check it from a connected device:

```bash
curl -s --cacert madar-admin-root.crt https://10.8.0.1/admin/api/healthz | jq .data   # {"db": "ok", "redis": "ok"}
```

Before you trust the root (next section), `curl -sk` skips the check.

## Install the admin CA root

The admin certificate comes from Caddy's own certificate authority on VPS-1, so each device that uses the admin trusts that root once. Fetch it from your machine, over WireGuard:

```bash
ssh ubuntu@10.8.0.1 sudo docker exec madar-caddy-1 cat /data/caddy/pki/authorities/local/root.crt > madar-admin-root.crt
openssl x509 -in madar-admin-root.crt -noout -fingerprint -sha256
```

Keep the fingerprint in your password manager. Copy the file to each device, and check the fingerprint there before you trust it.

| Device | Steps |
| --- | --- |
| Arch Linux | `sudo trust anchor --store madar-admin-root.crt` |
| Debian or Ubuntu | `sudo cp madar-admin-root.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates` |
| Firefox (any OS) | It keeps its own store: Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import |
| macOS | Open the file. In Keychain Access, under System, set the certificate to "Always Trust". |
| Windows | `certmgr.msc` → Trusted Root Certification Authorities → Certificates → All Tasks → Import |
| Android | Settings → Security → Encryption & credentials → Install a certificate → CA certificate |
| iOS | Install the profile from the file, then turn it on under Settings → General → About → Certificate Trust Settings |

- The root lives in VPS-1's `madar_caddy_data` volume and lasts for years. Leaf certificates renew on their own.
- If that volume is lost, or VPS-1 is rebuilt, Caddy creates a new root. Every admin device then needs the new one, and should remove the old one.
- A device that trusts this root trusts **any** certificate signed with its key, for any site. The key sits unencrypted in the `caddy_data` volume, so root on VPS-1 is enough to impersonate any site to every device that trusts it. Install the root only on the devices, or a dedicated browser profile, used for the admin, and remove it when someone leaves. A real domain with publicly trusted certificates (O4) removes this risk.

## Troubleshooting

- **No handshake** (`sudo wg show wg0` shows none for your peer): the device isn't reaching UDP 51820. Check the security list's UDP 51820 rule and the device's network. Some guest Wi-Fi and ISPs block UDP: try mobile data.
- **Handshake, but SSH hangs:** check `sudo iptables -S INPUT | grep wg0` on VPS-1 (the `-i wg0 … --dport 22` rule) and that sshd listens (`sudo ss -tlnp | grep ':22 '`).
- **Handshake, but the admin doesn't load:** check that Caddy runs (`sudo docker ps --filter name=madar-caddy`) and read its log (`sudo docker logs --tail 50 madar-caddy-1`). Check the CA root, and that you typed `https://`.
- **`/admin/api/` answers 502:** `api-admin` is down. Read `sudo docker logs --tail 100 madar-api-admin-1`. If `wg0` came up after Docker, `api-admin` couldn't bind `10.8.0.1:8001`: check the drop-in (`systemctl show docker -p After | grep -o wg-quick@wg0.service`), then start it again ([deploy-and-rollback.md "Working on VPS-1"](deploy-and-rollback.md#working-on-vps-1), `dc up -d api-admin`).
- **The hub is broken, its key is lost, or every device is gone:** [break-glass.md](break-glass.md).
