# infra/ — Lane B2

Read `README.md` here first: hosts, layout and deploys. Lane B2 also owns `backend/app/adapters/`
and `.github/workflows/`.

- $0/month (constitution IX): 2 OCI Ampere arm64 VMs, Docker Compose and Caddy. No Kubernetes,
  no CDN. Every image is `linux/arm64`.
- Hosts are `sslip.io` names. Clients read the API and media hosts from Firebase Remote Config,
  never from code.
- No key, password, token or certificate is ever committed: templates and fake placeholders
  only. `gitleaks.yml` fails any PR that adds a secret.
