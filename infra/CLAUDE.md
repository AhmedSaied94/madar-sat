# infra/ — Lane B2

Read `README.md` here first: hosts, layout and deploys. Lane B2 also owns `backend/app/adapters/`
and `.github/workflows/`.

- $0/month (constitution IX): 2 OCI Ampere arm64 VMs for the API and the workers, plus the owner's
  x86-64 home box for the scrape worker. Docker Compose and Caddy only. Every VPS image is
  `linux/arm64`; only the home box runs `linux/amd64` (`madar-backend-amd64`), because ysscores
  blocks datacenter IPs (research R21).
- Hosts are `sslip.io` names. Clients read the API and media hosts from Firebase Remote Config,
  never from code.
- The home box holds no database credentials and reaches only Redis (`10.8.0.1:6379`) as the
  `homebox` user of `redis/users.acl.tmpl`. Its firewall access is limited to `HOME_BOX_WG_IP`.
- No key, password, token or certificate is ever committed: templates and fake placeholders
  only. `gitleaks.yml` fails any PR that adds a secret.
- Every new or changed setup, deploy, rollback, recovery or rotation step lands in its runbook in
  `docs/runbooks/` in the same change, with commands that match the scripts.
