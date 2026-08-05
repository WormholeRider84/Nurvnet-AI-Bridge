# Nurvnet-AI-Bridge

Nurvnet-AI-Bridge is a self-hosted AI workspace that connects **Open WebUI** to
**CLIProxyAPI**. Open WebUI never needs upstream provider credentials: every
model request goes through the local CLIProxyAPI gateway.

The stack uses pinned container versions:

- Open WebUI `v0.11.0`
- CLIProxyAPI `v7.2.119`
- CLIProxyAPI Management Center `v1.21.4`

## Install

### Linux or macOS

```sh
curl -fsSL https://raw.githubusercontent.com/WormholeRider84/Nurvnet-AI-Bridge/main/install.sh | sh
```

With `wget`:

```sh
wget -qO- https://raw.githubusercontent.com/WormholeRider84/Nurvnet-AI-Bridge/main/install.sh | sh
```

The installer requires Docker with Compose v2, verifies the release checksum,
creates persistent configuration, starts both services, waits for readiness,
and opens the workspace and provider setup pages.

To install from a clone instead:

```sh
git clone https://github.com/WormholeRider84/Nurvnet-AI-Bridge.git
cd Nurvnet-AI-Bridge
./install.sh
```

### Windows PowerShell

Install Docker Desktop, then run:

```powershell
irm https://raw.githubusercontent.com/WormholeRider84/Nurvnet-AI-Bridge/main/install.ps1 | iex
```

The default Windows installation directory is
`%LOCALAPPDATA%\Nurvnet-AI-Bridge`.

## First run

The installer opens two local pages:

- Workspace: <http://localhost:3000>
- Provider setup: <http://localhost:8317/management.html#/ai-providers>

Copy the printed management key into the provider setup login. Then either:

1. Add an API-key provider under **AI Providers**; use its model import action
   when the upstream exposes `/models`.
2. Open **OAuth** for Codex, Claude, Gemini, Kimi, Antigravity, or Grok login
   flows.
3. Add model IDs manually when an upstream provider has no discovery endpoint.

Open WebUI reads CLIProxyAPI's live `/v1/models` catalog. Use **System → Models**
in the management center to fetch the current gateway list, then reload Open
WebUI's model selector. Provider changes are watched and persisted in
`config/cliproxyapi.yaml` and `data/cliproxyapi/auths/`.

The first Open WebUI account becomes its administrator. Additional Open WebUI
users follow Open WebUI's normal approval flow.

## Everyday operation

Run these commands from the installation directory:

```sh
./nurvnet start
./nurvnet stop
./nurvnet restart
./nurvnet status
./nurvnet logs
./nurvnet open
./nurvnet setup
```

Containers use `restart: unless-stopped`, so they return automatically when the
Docker daemon starts. `stop` is graceful and removes only containers and the
private Compose network; persistent files remain.

On Windows, run lifecycle commands from the installation directory with Docker
Compose, for example `docker compose up -d`, `docker compose down`, and
`docker compose logs -f --tail=200`.

## Upgrade

Repeat the original one-line installer. It downloads and verifies the newest
release, replaces packaged files, pulls the newly pinned images, and recreates
the stack. These paths are never overwritten during an upgrade:

- `.env`
- `.runtime/`
- `config/cliproxyapi.yaml`
- `data/`

Review release notes before upgrading across major Open WebUI or CLIProxyAPI
versions.

## Backup and restore

Backups contain provider and session secrets. Store them securely.

```sh
./nurvnet stop
tar -czf "nurvnet-ai-bridge-backup-$(date +%Y%m%d).tar.gz" \
  .env .runtime config/cliproxyapi.yaml data
./nurvnet start
```

To restore, stop the stack, extract those paths into the same installation
directory, and start it again.

## Uninstall

Remove the running stack while retaining local data:

```sh
./scripts/uninstall.sh
```

For a default one-line installation, permanently remove the installation and
all chats, credentials, configuration, and logs:

```sh
./scripts/uninstall.sh --purge
```

The purge command requires typing `PURGE` and refuses to delete an unexpected
directory. A source clone is intentionally never purged automatically.

## Configuration

Normal setup requires no file editing. Advanced deployment values live in
`.env`:

```dotenv
BIND_ADDRESS=127.0.0.1
WEBUI_PORT=3000
CLIPROXY_PORT=8317
```

The default localhost binding protects the management API and workspace from
the LAN. Setting `BIND_ADDRESS=0.0.0.0` exposes the services and OAuth callback
ports to other machines. Do that only behind an appropriate firewall or TLS
reverse proxy, retain strong management credentials, and configure Open WebUI
authentication for the intended users.

Templates are kept in `config/cliproxyapi.example.yaml` and
`config/open-webui.env.example`. Runtime secrets are generated with restrictive
permissions and are excluded from Git. The management center is downloaded at
its pinned version, checksum-verified, persisted locally, and excluded from its
upstream background update mechanism.

## Troubleshooting

### Docker or Compose is unavailable

The installer requires `docker compose` v2 and a running Docker daemon. Start
Docker Desktop on macOS/Windows or the Docker service on Linux, then rerun the
installer.

### A service never becomes ready

```sh
./nurvnet status
./nurvnet logs
```

Check for port conflicts on `3000`, `8317`, or the OAuth callback ports `1455`,
`8085`, `54545`, `51121`, and `11451`. Change the two main ports in `.env`; OAuth
callback ports must retain their documented values.

### Provider setup returns 401

Run `./nurvnet setup` to print the saved management key. The gateway API key is
different and is used internally by Open WebUI.

### Models are missing

1. Confirm the provider credential is healthy under **Auth Files** or **AI
   Providers**.
2. Open **System → Models** in the management center and fetch `/v1/models`.
3. For OpenAI-compatible providers, import upstream models or add manual model
   entries if the upstream lacks `/models`.
4. Reload Open WebUI. If it still shows an old list, restart it with
   `./nurvnet restart` and inspect logs.

### OAuth callback fails

Close any application using the provider's callback port and retry. OAuth
callbacks must originate from the same machine that runs Docker because the
ports are localhost-only by default.

## Packaging

From a clean Git checkout:

```sh
./scripts/package.sh
```

This creates checksum-protected tar.gz and zip artifacts under `dist/`. Tags
matching `v*` run the release workflow and publish those artifacts to GitHub.

## License

Nurvnet-AI-Bridge's original scripts and configuration are MIT licensed. Open
WebUI, CLIProxyAPI, their container images, and the bundled management center
remain subject to their respective upstream licenses.
