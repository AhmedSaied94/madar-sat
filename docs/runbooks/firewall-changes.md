# Firewall changes

Each VM's firewall comes from the repository: `infra/firewall/vps1.rules`, `vps2.rules` and `rules.v6`. `bootstrap-vps.sh` renders them into `/etc/iptables/rules.v4` and `rules.v6`, tests them with `iptables-restore --test`, applies them, restarts Docker, and runs `check-firewall.sh`. `netfilter-persistent` restores them at boot. The owner reviews every change to these files (T055). Applying a change touches production: Docker restarts, and every container on that VM with it. Background: SD §7.2, research R12, and the headers of the rules files.

Two layers must both allow a port: OCI's security list ([provision-host.md §1](provision-host.md#1-reserve-the-ip-and-create-the-vm)) and the VM's own iptables.

## The rules

- **Rendering:** `${VCN_IP}`, `${PEER_VCN_IP}` and, on VPS-1, `${HOME_BOX_WG_IP}` come from `/srv/madar/.env`. The marker `# @PUBLIC_SSH@` becomes the public TCP 22 rule while it is still allowed ([provision-host.md §6](provision-host.md#6-ssh-over-wireguard-only)). `# @OCI_INSTANCE_SERVICES@` becomes OCI's `InstanceServices` rules, copied from the image's original `rules.v4`, which the first run saved as `/etc/iptables/rules.v4.oci-original`.
- **Order:** every ACCEPT comes before the final `REJECT`.
- **Docker-published ports never reach `INPUT`.** Docker rewrites them to the container's address, so their limits are `DOCKER-USER` rules, matched on the original destination. A port opened in `INPUT` alone does nothing for a container, and a port published on the wrong address isn't blocked by `INPUT`.
- **Never run `netfilter-persistent save`.** It would write Docker's own chains into the persisted rules.
- **Never edit `/etc/iptables/rules.v4` by hand.** The next `bootstrap-vps.sh` run replaces it. A live `iptables -I` change lasts until the next reboot or run: fine for break-glass, wrong for anything else.

## 1. Change the rules in the repository

Edit `infra/firewall/`, in a Lane B2 PR. **CI doesn't check the rules.** `infra.yml` checks the Compose files, the Caddyfile, the shell scripts and the workflows, not iptables syntax. Before you merge, check that the change parses, on the VM it's for. On VPS-1, over WireGuard, after copying the branch's `infra/` to `~/madar-infra-test`:

```bash
sudo env VCN_IP="$(sudo sed -n 's/^VCN_IP=//p' /srv/madar/.env)" \
  PEER_VCN_IP="$(sudo sed -n 's/^PEER_VCN_IP=//p' /srv/madar/.env)" \
  HOME_BOX_WG_IP="$(sudo sed -n 's/^HOME_BOX_WG_IP=//p' /srv/madar/.env)" \
  envsubst '${VCN_IP} ${PEER_VCN_IP} ${HOME_BOX_WG_IP}' < ~/madar-infra-test/firewall/vps1.rules \
  | sudo iptables-restore --test && echo parses
sudo ip6tables-restore --test < ~/madar-infra-test/firewall/rules.v6 && echo parses
rm -r ~/madar-infra-test
```

The marker lines are comments, so the test parses everything else. For VPS-2, use `vps2.rules` on VPS-2.

## 2. Apply it after the merge

Pick a quiet hour: applying restarts Docker, so the API and the data stores are down for some seconds. Keep your WireGuard session open the whole time, and test a **new** session before you close it.

**VPS-1**, from the repository root on your machine, at the merged `master`:

```bash
rsync -a --delete infra/ ubuntu@10.8.0.1:madar-infra/
ssh ubuntu@10.8.0.1 sudo ./madar-infra/scripts/bootstrap-vps.sh vps1
```

**VPS-2**, through VPS-1:

```bash
rsync -a --delete -e 'ssh -J ubuntu@10.8.0.1' infra/ ubuntu@10.1.0.118:madar-infra/
ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118 sudo ./madar-infra/scripts/bootstrap-vps.sh vps2
```

- If the rendered rules equal the installed ones and `check-firewall.sh` passes, it prints `firewall already up to date` and changes nothing.
- Otherwise it prints `applying the firewall (public SSH: closed)` and restarts Docker.
- The run also re-checks the packages, the `deploy` user, the sshd drop-in and the `/srv` folders. That is harmless when nothing changed.
- On VPS-1 the public-SSH decision is made again on every run. With your tunnel connected, it stays closed.

## Redis on wg0 (the home box)

Redis is published on `10.8.0.1:6379` for the owner's scrape box, and only that box may reach it
(research R21). Two rules make that true, and both are in the file:

```text
-A DOCKER-USER ! -s ${HOME_BOX_WG_IP}/32 -p tcp -m conntrack --ctorigdst 10.8.0.1 --ctorigdstport 6379 --ctdir ORIGINAL -j DROP
```

- The `DOCKER-USER` rule is the one that matters: Docker publishes the port, so traffic is DNATed
  and never reaches `INPUT`.
- D1's `-A INPUT -i wg0 -p tcp --dport 6379 -j ACCEPT`, which accepted every `wg0` peer, is gone.
  `check-firewall.sh` now fails if it (or any rule accepting 6379 from the whole `wg0` subnet)
  comes back, or if the `DOCKER-USER` rule disappears.

`HOME_BOX_WG_IP` is the address `wg-add-peer.sh home-box` gave the box; `bootstrap-vps.sh` refuses
to run on VPS-1 while it is empty or not an IPv4 address.

After applying it, test from a **second** peer (your laptop, not the home box):

```bash
redis-cli -h 10.8.0.1 -p 6379 ping      # must time out, not answer
nc -vz 10.8.0.1 6379                    # times out
```

Then from the home box itself (`redis-cli -h 10.8.0.1 -p 6379 --user homebox --pass … ping`), which
must answer `PONG`.

## 3. Check

On the VM:

```bash
sudo ./madar-infra/scripts/check-firewall.sh --role vps1; echo "exit $?"   # or vps2; exit 0
sudo iptables -S INPUT
sudo iptables -S DOCKER-USER
curl -fsS http://127.0.0.1:8000/healthz                           # VPS-1: the API is back
```

Then, from outside WireGuard, run [exposure-check.md](exposure-check.md). If the change affects boot, reboot once and run `check-firewall.sh` again ([provision-host.md §9](provision-host.md#9-reboot-check)).

## If it fails

| Output | Meaning | Do |
| --- | --- | --- |
| `the rendered IPv4 rules don't parse (kept in /tmp/…)` | Nothing was applied | Read that file, fix the rules, try again |
| `infra/firewall/rules.v6 doesn't parse` | Nothing was applied | Fix `rules.v6` |
| `check-firewall.sh`: `active rules DIFFER from /etc/iptables/rules.v4`, with a diff | Someone changed the live rules, or a rule doesn't survive a restore unchanged | Read the diff. Re-run `bootstrap-vps.sh` to load the persisted rules again. If the diff stays, the rule's canonical form differs from how it's written: write it the way `iptables-save` prints it. |
| You lost your session and can't get back in | | [break-glass.md "A firewall change locked you out"](break-glass.md#a-firewall-change-locked-you-out) |
