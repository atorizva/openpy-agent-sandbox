set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

IMAGE := env_var_or_default("OPENSHELL_IMAGE", "openpy-agent-sandbox:local")
NAME := env_var_or_default("OPENSHELL_SANDBOX_NAME", "agent-py-sandbox")
REPO_MOUNT := "/sandbox/repo"

default:
    @just --list

# Build the sandbox image locally
build-image:
    docker build -t {{IMAGE}} -f Dockerfile .

# Create a sandbox seeded with PROJECT_DIR, then run OpenCode as the sandbox's main process.
# Changes flow back to the host via a pull request, so a one-way upload is enough (no bind mount).
start PROJECT_DIR:
    # opencode must BE the main process, not an exec: only the canonical main process shows
    # up in agent-aware panes (herdr-openshell) and survives detaching. --upload cannot be
    # combined with a trailing command, so the project is uploaded right after create and the
    # main process waits for the /sandbox/.repo-ready sentinel before exec'ing opencode.
    openshell sandbox create --name {{NAME}} --from {{IMAGE}} --tty --detach \
      --provider opencode-go --provider github \
      --policy policy.yaml \
      -- sh -lc "timeout 120 sh -c 'until [ -f /sandbox/.repo-ready ]; do sleep 1; done' && cd {{REPO_MOUNT}} && exec opencode --standalone"
    openshell sandbox upload {{NAME}} "{{PROJECT_DIR}}" /sandbox --no-git-ignore
    # Upload preserves the source basename; move it to the fixed /sandbox/repo path.
    # --no-git-ignore keeps .git (branch/remote/history) for the PR, then git clean -fdX
    # strips the .gitignore'd artifacts it also copied. The sentinel releases the main process.
    openshell sandbox exec -n {{NAME}} -- \
      sh -lc "rm -rf /sandbox/repo && mv '/sandbox/$(basename '{{PROJECT_DIR}}')' /sandbox/repo && git -C /sandbox/repo clean -fdX && touch /sandbox/.repo-ready"

# Attach to the sandbox's canonical main process (OpenCode)
connect:
    openshell sandbox connect {{NAME}}

# Attach to the OpenCode TUI running as the sandbox's main process
opencode:
    openshell sandbox connect {{NAME}}

# Exec an arbitrary command in the sandbox
exec *ARGS:
    openshell sandbox exec -n {{NAME}} --workdir {{REPO_MOUNT}} -- {{ARGS}}

# Delete the sandbox (destructive)
delete:
    openshell sandbox delete {{NAME}}
