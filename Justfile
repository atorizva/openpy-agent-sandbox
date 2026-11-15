set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

IMAGE := env_var_or_default("OPENSHELL_IMAGE", "openpy-agent-sandbox:local")
NAME := env_var_or_default("OPENSHELL_SANDBOX_NAME", "agent-py-sandbox")
REPO_MOUNT := "/sandbox/repo"

default:
    @just --list

# Build the sandbox image locally
build-image:
    docker build -t {{IMAGE}} -f Dockerfile .

# Start a persistent detached sandbox bound to a project directory (required arg).
start PROJECT_DIR:
    openshell sandbox create -n {{NAME}} --from {{IMAGE}} --detach \
      --driver-config-json '{"docker":{"mounts":[{"type":"bind","source":"{{PROJECT_DIR}}","target":"/sandbox/repo","read_only":false}]}}' \
      --provider opencode-go --provider github \
      --policy policy.yaml -- \
      sh -lc 'while true; do sleep 3600; done'

# Attach to the sandbox's canonical shell
connect:
    openshell sandbox connect -n {{NAME}}

# Run OpenCode (interactive, standalone) inside the sandbox at /sandbox/repo
opencode:
    openshell sandbox exec -n {{NAME}} --tty --workdir {{REPO_MOUNT}} -- opencode --standalone

# Exec an arbitrary command in the sandbox
exec *ARGS:
    openshell sandbox exec -n {{NAME}} --workdir {{REPO_MOUNT}} -- {{ARGS}}

# Delete the sandbox (destructive)
delete:
    openshell sandbox delete -n {{NAME}}
