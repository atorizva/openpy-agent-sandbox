# openpy-agent-sandbox

OpenShell sandbox configuration for the agent-driven Python project: a derived OpenCode image
plus deny-by-default network/filesystem policy and provider profiles.

This repo is the **trust boundary**. The image is built and published to GitHub Container
Registry (`ghcr.io/atorizva/openpy-agent-sandbox`); the consuming project repo pins the image by
digest and clones this repo (pinned tag) for `policy.yaml`, `providers/`, and the lifecycle
`Justfile`.

## Contents

- `Dockerfile` — derived from the digest-pinned official OpenCode image; adds git, gh, ssh, just,
  uv (0.13.8), prek (0.5.10); non-root `agent` user; `WORKDIR /sandbox`.
- `policy.yaml` — OpenShell v1 policy: Landlock `hard_requirement`, non-root 1000:1000,
  default-deny egress with enforced rules for OpenCode, GitHub (API/Git/SSH), and PyPI.
- `providers/` — OpenCode Go and GitHub credential profiles.
- `Justfile` — `build-image`, `start`, `connect`, `opencode`, `exec`, `delete`.
- `.github/workflows/publish-image.yml` — builds and pushes the image to GHCR on `main` and `v*`
  tags.

## Host prerequisites

- OpenShell CLI installed (tested with `0.1.8`).
- Docker Engine/daemon reachable.
- WSL2 + Docker Desktop on Linux x86_64 is **experimental**.

## Gateway config (one-time, host)

Copy the Docker sections of `gateway.example.toml` into `~/.config/openshell/gateway.toml`
(setting `compute_driver = "docker"`, `enable_bind_mounts = true`, `allow_driver_config = true`).

## Build the image (local)

```bash
just build-image
# or
docker build -t openpy-agent-sandbox:local -f Dockerfile .
```

## Import profiles + create providers (host env vars required)

```bash
openshell profile lint -f providers/opencode-go.yaml
openshell profile import -f providers/opencode-go.yaml --global
export OPENCODE_API_KEY="..."
openshell provider create --name opencode-go --type opencode-go --global-profile --credential OPENCODE_API_KEY

openshell profile lint -f providers/github.yaml
openshell profile import -f providers/github.yaml --global
export GITHUB_TOKEN="ghp_..."   # or a fine-grained token
openshell provider create --name github --type github --global-profile --credential GITHUB_TOKEN
```

## Run (bind a project directory to /sandbox/repo)

```bash
just start /path/to/project
just opencode
```

Raw equivalent:

```bash
openshell sandbox create --name agent-py-sandbox \
  --from openpy-agent-sandbox:local --detach \
  --driver-config-json '{"docker":{"mounts":[{"type":"bind","source":"/path/to/project","target":"/sandbox/repo","read_only":false}]}}' \
  --provider opencode-go --provider github \
  --policy policy.yaml -- \
  sh -lc 'while true; do sleep 3600; done'

openshell sandbox exec -n agent-py-sandbox --tty --workdir /sandbox/repo -- opencode --standalone
```

## Image publishing

Push to `main` or a `v*` tag; the workflow builds and pushes to GHCR. Reference the image by
digest from the consumer project (`ghcr.io/atorizva/openpy-agent-sandbox@sha256:<digest>`).

## Notes

- No secrets belong here. Credentials are injected by OpenShell providers at runtime.
- `apk` package versions float at build time; pin the published image digest in consumers for
  reproducibility.
- Network policy is default-deny; review any change carefully.
pr-test 1794766028
