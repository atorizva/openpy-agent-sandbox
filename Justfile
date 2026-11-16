set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

IMAGE := env_var_or_default("OPENSHELL_IMAGE", "openpy-agent-sandbox:local")
NAME := env_var_or_default("OPENSHELL_SANDBOX_NAME", "agent-py-sandbox")
REPO_MOUNT := "/sandbox/repo"

default:
    @just --list

# Build the sandbox image locally
build-image:
    docker build -t {{IMAGE}} -f Dockerfile .

# Create a sandbox seeded with PROJECT_DIR, then attach to OpenCode so you can watch/guide the agent.
# Changes flow back to the host via a pull request, so a one-way upload is enough (no bind mount).
start PROJECT_DIR:
    openshell sandbox create --name {{NAME}} --from {{IMAGE}} --detach \
      --upload "{{PROJECT_DIR}}:/sandbox" --no-git-ignore \
      --provider opencode-go --provider github \
      --policy policy.yaml
    # Upload preserves the source basename; move it to the fixed /sandbox/repo path.
    # --no-git-ignore keeps .git (branch/remote/history) for the PR, then git clean -fdX
    # strips the .gitignore'd artifacts it also copied.
    openshell sandbox exec -n {{NAME}} -- \
      sh -lc "rm -rf /sandbox/repo && mv '/sandbox/$(basename '{{PROJECT_DIR}}')' /sandbox/repo && git -C /sandbox/repo clean -fdX"
    openshell sandbox exec -n {{NAME}} --tty --workdir {{REPO_MOUNT}} -- opencode --standalone

# Attach to the sandbox's canonical shell
connect:
    openshell sandbox connect {{NAME}}

# Re-attach OpenCode (interactive, standalone) inside the sandbox at /sandbox/repo
opencode:
    openshell sandbox exec -n {{NAME}} --tty --workdir {{REPO_MOUNT}} -- opencode --standalone

# Exec an arbitrary command in the sandbox
exec *ARGS:
    openshell sandbox exec -n {{NAME}} --workdir {{REPO_MOUNT}} -- {{ARGS}}

# Delete the sandbox (destructive)
delete:
    openshell sandbox delete {{NAME}}
