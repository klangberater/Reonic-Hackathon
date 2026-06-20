# Server setup — getfletcher.ai (reused from the Hallo-Theo hackathon)

Replicates the theo-copilot deploy pattern for our Node/TS backend. The server already
terminates TLS for `getfletcher.ai`, so the iOS app gets HTTPS for free (no ATS exception).

**Server:** `getfletcher.ai` / `87.106.213.53` (Ubuntu). Deploy user: `github-runner`.
**Our backend:** Node service bound to `127.0.0.1:8090`, fronted by the existing reverse proxy.

## One-time server steps (need SSH + sudo on the box)

1. **Clone our repo** (replacing/alongside the old project):
   ```bash
   sudo mkdir -p /opt/reonic && sudo chown github-runner:github-runner /opt/reonic
   sudo -u github-runner git clone https://github.com/klangberater/Reonic-Hackathon.git /opt/reonic/repo
   ```
2. **Node 20+** (if not already present): `node -v` → install via nvm or apt if missing.
3. **Env file** `/opt/reonic/.env` (chmod 600, owned by github-runner):
   ```
   ANTHROPIC_API_KEY=sk-ant-...
   PORT=8090
   DEMO_CLOCK=summer
   ```
4. **systemd unit:** copy `deploy/reonic-backend.service` → `/etc/systemd/system/`, then
   ```bash
   sudo systemctl daemon-reload && sudo systemctl enable --now reonic-backend.service
   ```
5. **sudoers** — let the deploy user restart only this service without a password:
   ```
   # /etc/sudoers.d/reonic   (sudo visudo -f /etc/sudoers.d/reonic)
   github-runner ALL=(ALL) NOPASSWD: /bin/systemctl restart reonic-backend.service
   ```
6. **Reverse-proxy route** → forward to `127.0.0.1:8090`. Pick the file that matches the
   server's proxy (find with `sudo nginx -T` or `cat /etc/caddy/Caddyfile`):
   - nginx: add the snippet from `deploy/nginx-reonic.conf` and `sudo nginx -s reload`
   - Caddy: add the block from `deploy/Caddyfile.snippet` and `sudo systemctl reload caddy`
7. **GitHub secret:** add `DEPLOY_SSH_KEY` to THIS repo's Actions secrets (same private key the
   theo repo uses for `github-runner@87.106.213.53`, or a fresh key added to that user's
   `~/.ssh/authorized_keys`).

## Removing the old project (do deliberately, after ours is up)
The theo services are `theo-app.service`, `theo-intake.service`, `theo-whatsapp-bridge.service`,
plus the `theo-neo4j` container. Stop/disable only once ours is confirmed working:
```bash
sudo systemctl disable --now theo-app.service theo-intake.service theo-whatsapp-bridge.service
docker compose -f /opt/fletcher/repo/theo-copilot/docker-compose.theo.yml down   # optional
```
Then remove its proxy routes. **Don't delete `/opt/fletcher` until the demo is over** — keep a fallback.

## Deploy after setup
Push to `main` → `.github/workflows/deploy.yml` SSHes in, pulls, `npm ci && npm run build`,
restarts the service, smoke-tests `https://getfletcher.ai/api/health`.
