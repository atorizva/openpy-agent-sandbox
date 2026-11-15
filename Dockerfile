# Derived from the official OpenCode image (digest-pinned).
# Reset ENTRYPOINT so OpenShell/supervisor controls the command.
FROM ghcr.io/anomalyco/opencode@sha256:998e3e184c650e603d8bacb5cbeaeb090837078262c25521a7136b0375d2b652

USER root
ENV UV_INSTALL_DIR=/usr/local/bin \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/opt/uv-tools \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python

RUN apk add --no-cache \
      bash \
      ca-certificates \
      curl \
      git \
      github-cli \
      just \
      openssh-client \
      openssh-client-default \
      openssh-client-krb5

# Install uv (pinned)
RUN curl -LsSf https://astral.sh/uv/0.13.8/install.sh | sh

# Install prek (pinned) via uv tool
RUN uv tool install prek==0.5.10 --no-cache

# Non-root user matching host UID/GID for bind-mount ownership
RUN addgroup -g 1000 agent || true \
    && adduser -D -u 1000 -G agent agent || true \
    && mkdir -p /sandbox /sandbox/repo \
    && chown -R agent:agent /sandbox

USER agent
WORKDIR /sandbox
ENTRYPOINT []
CMD ["sh"]
