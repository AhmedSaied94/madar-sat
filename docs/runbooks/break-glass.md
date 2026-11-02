# Break-glass: getting back into a VM

Use this runbook when you can't reach a VM the normal way: VPS-1 over WireGuard (`ssh ubuntu@10.8.0.1`), or VPS-2 through it (`ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118`). Typical causes: `wg0` is broken, the hub key is lost, every device with a peer is gone, or a firewall or sshd change locked you out. It also covers Oracle stopping an instance. Background: SD §7.2 ("Break-glass access", "OCI gotchas") and FR-023.

The public API usually keeps serving through all of this, since only the private side is affected. Check `curl -s https://api.<VPS1_IP>.sslip.io/healthz` before you change anything.

VPS-2 is normally reached through VPS-1. If VPS-1 is down or its WireGuard is broken, VPS-2's only way in is its own serial console.

## Path 1: the serial console (try this first)

1. In the OCI console, open **Compute → Instances → the VM's instance → Console connection → Launch Cloud Shell connection**.
2. Press Enter, then sign in as `ubuntu` with **that VM's console password** from the password manager ([provision-host.md §2](provision-host.md#2-console-password-then-test-the-serial-console)).

This works without the VM's network. If you get no login prompt, go to Path 2.

The commands below run from `~/madar-infra`, the copy of `infra/` kept on each VM ([provision-host.md §3](provision-host.md#3-run-the-bootstrap-script)). Once you're in, pick the fix that matches the cause.

### WireGuard is down (VPS-1)

```bash
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0 -n 50
sudo wg show wg0
```

Fix the error the journal shows (usually a hand edit of `/etc/wireguard/wg0.conf`), then:

```bash
sudo systemctl restart wg-quick@wg0
```

Docker starts after `wg0`, but if `wg0` was down when Docker started, `api-admin` couldn't bind `10.8.0.1:8001`. Start it again once `wg0` is up ([deploy-and-rollback.md "Working on VPS-1"](deploy-and-rollback.md#working-on-vps-1), then `dc up -d api-admin`).

### Re-key the hub (key lost or exposed)

```bash
sudo systemctl stop wg-quick@wg0
sudo mv /etc/wireguard/wg0.conf /root/wg0.conf.old-$(date +%F)
sudo mv /etc/wireguard/wg0.key /root/wg0.key.old-$(date +%F)
sudo ./madar-infra/scripts/bootstrap-vps.sh vps1
```

The script generates a new hub key, writes a new `wg0.conf` on `10.8.0.1/24` with no peers, and prints the new `hub public key`. Every client config for VPS-1 is now useless.

- With no peer connected, this run **opens public SSH** in iptables again ([provision-host.md §6](provision-host.md#6-ssh-over-wireguard-only)). The security list still blocks it if you did provision-host.md §7.
- Re-add every peer with `wg-add-peer.sh` ([private-network.md "Add a peer"](private-network.md#add-a-peer)), the `ci` peer included, and replace `WG_CI_CONFIG`.
- Connect over the new tunnel, then run `sudo ./madar-infra/scripts/bootstrap-vps.sh vps1` once more to close public SSH.
- Then shred the old files: `sudo shred -u /root/wg0.conf.old-* /root/wg0.key.old-*`.

### Every device is lost

Add a peer for a new device from the console:

```bash
sudo ./madar-infra/scripts/wg-add-peer.sh <new-device>
sudo apt-get install -y qrencode
sudo qrencode -t ansiutf8 < /root/wireguard-peers/<new-device>.conf    # scan it with the phone's WireGuard app
sudo shred -u /root/wireguard-peers/<new-device>.conf
```

If the QR code doesn't render in the console, reopen SSH temporarily (below) and copy the file over SSH instead. Then remove the lost devices' peers ([private-network.md "Remove a peer"](private-network.md#remove-a-peer)).

### A firewall change locked you out

Load Oracle's original rules, which allow public SSH, into the running firewall:

```bash
sudo iptables-restore < /etc/iptables/rules.v4.oci-original
sudo systemctl restart docker      # a full restore removes Docker's chains; the restart recreates them
```

That changes only the live rules. The bad rules are still in `/etc/iptables/rules.v4` and come back at the next boot. Fix `infra/firewall/` in the repository, copy it to `~/madar-infra`, and re-run `bootstrap-vps.sh` ([firewall-changes.md](firewall-changes.md)).

### An sshd change locked you out

`bootstrap-vps.sh` only adds `/etc/ssh/sshd_config.d/05-madar.conf` (no passwords, no root login). For anything else:

```bash
sudo install -d -m 755 /run/sshd   # sshd -t needs it; Ubuntu 24.04's socket-started sshd may not have made it
sudo sshd -t                        # shows the config error
sudo systemctl restart ssh
```

### Reopen SSH temporarily

Do this only if you need SSH from the internet, for example because no device can run WireGuard right now. Allow only your own address, and undo it as soon as you're done.

```bash
sudo iptables -I INPUT 1 -p tcp -s <your public ip>/32 --dport 22 -m comment --comment madar-breakglass -j ACCEPT
```

Then add a TCP 22 ingress rule for `<your public ip>/32` to the security list. The `iptables` rule isn't saved: a reboot or any `bootstrap-vps.sh` run removes it. To undo it sooner:

```bash
sudo iptables -D INPUT -p tcp -s <your public ip>/32 --dport 22 -m comment --comment madar-breakglass -j ACCEPT
```

Then remove the security-list rule.

## Path 2: boot-volume rescue

Use this when the serial console doesn't work. You fix the A1 instance's disk from a temporary Always Free AMD instance. The two boot volumes use 147 GB of the 200 GB allowance, so the 53 GB left fits one 47 GB rescue volume: rescue one VM at a time.

1. **Stop** the A1 instance (Force stop if it hangs).
2. Under the instance's **Boot volume**, choose **Detach**.
3. Create the rescue instance:
   - shape `VM.Standard.E2.1.Micro`, Always Free;
   - image Ubuntu 24.04 (x86), with a **47 GB** boot volume;
   - in VCN `madar` and its public subnet, with your SSH key and an ephemeral public IP.

   Add a TCP 22 ingress rule for `<your public ip>/32` to the security list, so you can reach it. Step 8 needs the rule too.
4. **Attach** the A1 boot volume to the rescue instance as a block volume (paravirtualized). Then connect to the rescue instance:

   ```bash
   ssh ubuntu@<rescue ip>
   lsblk -f                                  # the A1 disk is the second one, such as sdb; its root is the large ext4 partition
   sudo mkdir -p /mnt/rescue && sudo mount /dev/sdb1 /mnt/rescue
   ```

5. Fix the files. You can only edit files here, not run the A1 system's programs (it's aarch64):
   - **Firewall lockout:** `sudo cp /mnt/rescue/etc/iptables/rules.v4.oci-original /mnt/rescue/etc/iptables/rules.v4`. These are Oracle's original rules, which allow public SSH.
   - **Lost SSH key:** append your public key to `/mnt/rescue/home/ubuntu/.ssh/authorized_keys`.
   - **sshd lockout:** `sudo rm /mnt/rescue/etc/ssh/sshd_config.d/05-madar.conf`, or fix whatever other file broke it.
6. Unmount it (`sudo umount /mnt/rescue`), detach it from the rescue instance, and re-attach it to the A1 instance as its **boot volume**. Start the A1 instance.
7. **Terminate the rescue instance and delete its boot volume**, to stay inside the 200 GB allowance.
8. SSH in over the VM's public IP (the rule from step 3 allows it). Repair WireGuard (Path 1), re-run `sudo ./madar-infra/scripts/bootstrap-vps.sh <role>` to restore the rules and the sshd drop-in, and remove the TCP 22 rule again.

## Instance stopped by Oracle

Oracle may stop an Always Free instance it considers idle over 7 days (SD §7.2 quotes under 10–20 % CPU, network and memory). The boot volume is kept. VPS-2, with no worker code before D3, is the likelier one.

- **Signs:** the console shows the instance as **Stopped**. For VPS-1, `https://api.<VPS1_IP>.sslip.io/healthz` stops answering. Uptime Kuma alerts from D3.
- **Fix:** choose **Start**. On "Out of host capacity", retry later.
- **After it starts:**
  - Check that the reserved IP is still attached to the VNIC.
  - `curl https://api.<VPS1_IP>.sslip.io/healthz`.
  - Over WireGuard, `sudo docker ps`. The `unless-stopped` restart policies bring every container back.
  - Look at the instance's utilization for the week before the stop, and note it in research.md R12.
- Don't add artificial load to dodge the rule. SD §7.2 notes that upgrading the account to pay-as-you-go, still free within the limits, reportedly removes the risk: an owner decision.
