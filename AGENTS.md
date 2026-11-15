# Agent instructions — openpy-agent-sandbox

This repository is the sandbox trust boundary (image + network/filesystem policy + provider
profiles). Changes here are human-reviewed infrastructure; they are not agent-automated in
normal operation.

- Do not put secrets, keys, or credentials in this repo. Credentials are injected at runtime
  through OpenShell providers.
- Keep the image digest-pinned base and exact tool versions pinned.
- Network policy is default-deny; any change must be reviewed.
