# Build with: podman build --ulimit nofile=65535:65535 . -t custom-renovate
# Run with: podman run --rm <additional args> custom-renovate renovate

FROM registry.access.redhat.com/ubi9-minimal
LABEL description="Mintmaker - Renovate custom image" \
      summary="Mintmaker basic container image - a Renovate custom image" \
      maintainer="EXD Rebuilds Guild <exd-guild-rebuilds@redhat.com >" \
      io.k8s.description="Mintmaker - Renovate custom image" \
      com.redhat.component="mintmaker-renovate-image" \
      distribution-scope="public" \
      release="0.0.1" \
      url="https://github.com/konflux-ci/mintmaker-renovate-image/" \
      vendor="Red Hat, Inc."

# The version number is from upstream Renovate, while the `-rpm` suffix
# is to differentiate the rpm lockfile enabled fork
ARG RENOVATE_VERSION=38.132.0-rpm

# Version for the rpm-lockfile-prototype executable from
# https://github.com/konflux-ci/rpm-lockfile-prototype/tags
ARG RPM_LOCKFILE_PROTOTYPE_VERSION=0.13.2

# NodeJS version used for Renovate, has to satisfy the version
# specified in Renovate's package.json
ARG NODEJS_VERSION=20.17.0

# Support multiple Go versions
ENV GOTOOLCHAIN=auto

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS=--use-openssl-ca

ENV LANG=C.UTF-8

# PYENV_ROOT is also set in ~/.profile, but the file isn't always read
ENV PYENV_ROOT="/home/renovate/.pyenv"

RUN microdnf update -y && \
    microdnf install -y \
        git \
        openssl \
        python3.12-pip \
        python3.12 \
        python3.11 \
        python3.11-pip \
        python3-pip \
        python3-dnf \
        python3.9 \
        golang \
        skopeo \
        xz \
        xz-devel \
        findutils \
        zlib-devel \
        bzip2 \
        bzip2-devel \
        ncurses-devel \
        libffi-devel \
        readline \
        sqlite \
        sqlite-devel && \
    microdnf clean all

RUN curl -L -o /tmp/tkn.tar.gz https://github.com/tektoncd/cli/releases/download/v0.38.1/tkn_0.38.1_Linux_x86_64.tar.gz && tar xvzf /tmp/tkn.tar.gz -C /usr/bin/ tkn && rm -f /tmp/tkn.tar.gz

RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

# Install nodejs
RUN curl -o node-v${NODEJS_VERSION}-linux-x64.tar.xz https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz
RUN tar xf node-v${NODEJS_VERSION}-linux-x64.tar.xz && \
    mv node-v${NODEJS_VERSION}-linux-x64/bin/* /bin/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/include/* /include/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/lib/* /lib/ && \
    rm -fr node-v${NODEJS_VERSION}-linux-x64 && \
    rm -f node-v${NODEJS_VERSION}-linux-x64.tar.xz

# Add renovate user and switch to it
RUN useradd -lms /bin/bash -u 1001 -g 0 renovate
RUN chmod -R 6775 /home/renovate && chown :0 /home/renovate
RUN mkdir -p /home/renovate/.cache && chown :0 /home/renovate/.cache && chmod 6775 /home/renovate/.cache

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:/home/renovate/go/bin:/home/renovate/.pyenv/bin:/home/renovate/.cargo/bin:/tmp/renovate/cache/others/go/bin:${PATH}"

# Install package managers
RUN npm install pnpm@9.2.0 && npm cache clean --force

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3.12 install --user pipx && pip3.12 cache purge
RUN pipx install --python python3.12 poetry pdm pipenv hashin uv hatch pip-tools \
    git+https://github.com/konflux-ci/pipeline-migration-tool.git && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

# Install pyenv
RUN curl https://pyenv.run | sh
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile

# Install additional Python versions
RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.10) $HOME/python3.10
ENV PATH="${PATH}:/home/renovate/python3.10/bin"

RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.13) $HOME/python3.13
ENV PATH="${PATH}:/home/renovate/python3.13/bin"

# Use rustup to install the latest Rust toolchain
RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y

WORKDIR /home/renovate/renovate

# Clone Renovate from specific ref (that includes the RPM lockfile support)
RUN git clone --depth=1 --branch rpm-lockfiles-new https://github.com/redhat-exd-rebuilds/renovate.git .

# Replace package.json version for this build
RUN sed -i "s/0.0.0-semantic-release/${RENOVATE_VERSION}/g" package.json

# Install project dependencies, build and install Renovate
RUN pnpm install && pnpm build && npm install --prefix /home/renovate . && pnpm store prune && npm cache clean --force

WORKDIR /home/renovate/rpm-lockfile-prototype

# Clone and install the rpm-lockfile-prototype
# We must pass --no-dependencies, otherwise it would try to
# fetch dnf from PyPI, which is just a dummy package
RUN git clone --depth=1 --branch v${RPM_LOCKFILE_PROTOTYPE_VERSION} https://github.com/konflux-ci/rpm-lockfile-prototype.git .
USER root
RUN pip3 install jsonschema PyYaml productmd requests && pip3 install --no-dependencies . && pip3 cache purge
USER 1001

WORKDIR /workspace
