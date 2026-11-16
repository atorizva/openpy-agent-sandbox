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
- `.gitconfig` — git credential helper pointing at `gh`, so `git push` uses the injected GitHub token.
- `.github/workflows/publish-image.yml` — builds and pushes the image to GHCR on `main` and `v*`
  tags.

## Host prerequisites

- OpenShell CLI installed (tested with `0.1.8`).
- Docker Engine/daemon reachable.
- WSL2 + Docker Desktop on Linux x86_64 is **experimental**.

## Gateway config (one-time, host)

Copy the Docker sections of `gateway.example.toml` into `~/.config/openshell/gateway.toml`
(setting `compute_driver = "docker"`).

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

## Run (seed a project into the sandbox and attach)

```bash
just start /path/to/project
```

`just start` creates the sandbox, uploads the project (one-way, `.git` included via
`--no-git-ignore` so the agent can branch/commit/PR), moves it to `/sandbox/repo`, strips the
`.gitignore`'d artifacts with `git clean -fdX`, and drops you into the OpenCode TUI so you can
watch and guide the agent. Changes flow back to the host through a pull request, not a bind mount.

Raw equivalent:

```bash
openshell sandbox create --name agent-py-sandbox \
  --from openpy-agent-sandbox:local --detach \
  --upload /path/to/project:/sandbox --no-git-ignore \
  --provider opencode-go --provider github \
  --policy policy.yaml

openshell sandbox exec -n agent-py-sandbox -- \
  sh -lc "rm -rf /sandbox/repo && mv '/sandbox/$(basename /path/to/project)' /sandbox/repo && git -C /sandbox/repo clean -fdX"

openshell sandbox exec -n agent-py-sandbox --tty --workdir /sandbox/repo -- opencode --standalone
```

`--upload` preserves the source basename, so the second step moves it to the fixed `/sandbox/repo`
path. `--no-git-ignore` is required because the default `.gitignore` filtering also drops `.git`
itself (verified against 0.1.8); it keeps `.git` (branch/remote/history) but also copies ignored
files, which the following `git clean -fdX` removes.

## Image publishing

Push to `main` or a `v*` tag; the workflow builds and pushes to GHCR. Reference the image by
digest from the consumer project (`ghcr.io/atorizva/openpy-agent-sandbox@sha256:<digest>`).

## Notes

- No secrets belong here. Credentials are injected by OpenShell providers at runtime.
- The model is **not** baked into the image. Set it in your project by adding an `opencode.json`
  (or `opencode.jsonc`) to the project root; OpenCode reads it from the working directory
  (`/sandbox/repo`) and it is uploaded with the project. For example:
  `{"model": "opencode-go/deepseek-v4-pro"}`. Stick to `opencode-go/*` models (e.g.
  `deepseek-v4-pro`, `gemini-4-argon`) — they use `Authorization: Bearer` and are covered by the
  "OpenCode Go" subscription. The out-of-box default (`gemini-4-hydrogen`) is the pay-as-you-go
  "OpenCode Models" tier and returns `402 Insufficient balance` unless you top up credits and
  switch the profile placement to `x-goog-api-key`.
- `apk` package versions float at build time; pin the published image digest in consumers for
  reproducibility.
- Network policy is default-deny; review any change carefully.
