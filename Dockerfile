# Build with: podman build --ulimit nofile=65535:65535 . -t custom-renovate
# Run with: podman run --rm <additional args> custom-renovate renovate

FROM registry.access.redhat.com/ubi10-minimal
LABEL description="Mintmaker - Renovate custom image" \
      summary="Mintmaker basic container image - a Renovate custom image" \
      maintainer="EXD Rebuilds Guild <exd-guild-rebuilds@redhat.com >" \
      io.k8s.description="Mintmaker - Renovate custom image" \
      com.redhat.component="mintmaker-renovate-image" \
      distribution-scope="public" \
      release="0.0.1" \
      url="https://github.com/konflux-ci/mintmaker-renovate-image/" \
      vendor="Red Hat, Inc."

# OpenShift preflight check requires licensing files under /licenses
COPY LICENSE /licenses/LICENSE

# The version number is from upstream Renovate, while the `-rpm` suffix
# is to differentiate the rpm lockfile enabled fork
ARG RENOVATE_VERSION=41.7.0-rpm

# Specific git commit hash from the redhat-exd-rebuilds/renovate fork
ARG RENOVATE_REVISION=331a6c40b1a06cb86d235937de68e316d1d4ade6

# Version for the rpm-lockfile-prototype executable from
# https://github.com/konflux-ci/rpm-lockfile-prototype/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/rpm-lockfile-prototype versioning=semver
ARG RPM_LOCKFILE_PROTOTYPE_VERSION=0.17.0

# Version for the pipeline-migration-tool from
# https://github.com/konflux-ci/pipeline-migration-tool/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/pipeline-migration-tool versioning=semver
ARG PIPELINE_MIGRATION_TOOL_VERSION=0.4.1

# Version for the tekton cli from
# https://github.com/tektoncd/cli/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=tektoncd/cli versioning=semver
ARG TEKTON_CLI_VERSION=0.41.1

# Version for the yq from
# https://github.com/mikefarah/yq/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=mikefarah/yq versioning=semver
ARG YQ_VERSION=4.47.1

# NodeJS version used for Renovate, has to satisfy the version
# specified in Renovate's package.json
ARG NODEJS_VERSION=22.17.1

ARG PNPM_VERSION=10.12.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipx
ARG PIPX_VERSION=1.7.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=poetry
ARG POETRY_VERSION=2.1.4

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pdm
ARG PDM_VERSION=2.25.5

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipenv
ARG PIPENV_VERSION=2025.0.4

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=hashin
ARG HASHIN_VERSION=1.0.5

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=uv
ARG UV_VERSION=0.8.8

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=hatch
ARG HATCH_VERSION=1.14.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pip-tools
ARG PIP_TOOLS_VERSION=7.5.0

# Support multiple Go versions
ENV GOTOOLCHAIN=auto

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS=--use-openssl-ca

ENV LANG=C.UTF-8

# PYENV_ROOT is also set in ~/.profile, but the file isn't always read
ENV PYENV_ROOT="/home/renovate/.pyenv"

RUN microdnf update -y && \
    microdnf install -y \
        subscription-manager-rhsm-certificates \
        git \
        openssl \
        python3.12 \
        python3.12-pip \
        python3-dnf \
        cargo \
        golang \
        skopeo \
        xz \
        xz-devel \
        tar \
        findutils \
        zlib-devel \
        bzip2 \
        bzip2-devel \
        ncurses-devel \
        libffi-devel \
        readline \
        sqlite \
        sqlite-devel \
        libpq-devel \
        krb5-devel && \
    microdnf clean all

    
RUN curl -L -o /tmp/tkn.tar.gz https://github.com/tektoncd/cli/releases/download/v${TEKTON_CLI_VERSION}/tkn_${TEKTON_CLI_VERSION}_Linux_x86_64.tar.gz && tar xvzf /tmp/tkn.tar.gz -C /usr/bin/ tkn && rm -f /tmp/tkn.tar.gz

RUN curl -L https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

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
RUN mkdir -p /home/renovate/.cache /home/renovate/.local /home/renovate/.local/state/pdm
RUN chown -R 1001:0 /home/renovate && chmod -R 2775 /home/renovate

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:/home/renovate/go/bin:/home/renovate/.pyenv/bin:/tmp/renovate/cache/others/go/bin:${PATH}"

# Install package managers
RUN npm install pnpm@${PNPM_VERSION} && npm cache clean --force

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3.12 install --user pipx==${PIPX_VERSION} && pip3.12 cache purge
RUN pipx install --python python3.12 poetry==${POETRY_VERSION} pdm==${PDM_VERSION} pipenv==${PIPENV_VERSION} \
    hashin==${HASHIN_VERSION} uv==${UV_VERSION} hatch==${HATCH_VERSION} pip-tools==${PIP_TOOLS_VERSION} \
    git+https://github.com/konflux-ci/pipeline-migration-tool.git@v${PIPELINE_MIGRATION_TOOL_VERSION} && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

# Install pyenv
RUN curl https://pyenv.run | sh
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile

# Install additional Python versions
RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.9) $HOME/python3.9
ENV PATH="${PATH}:/home/renovate/python3.9/bin"

RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.10) $HOME/python3.10
ENV PATH="${PATH}:/home/renovate/python3.10/bin"

RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.11) $HOME/python3.11
ENV PATH="${PATH}:/home/renovate/python3.11/bin"

RUN $PYENV_ROOT/plugins/python-build/bin/python-build $(pyenv latest -f -k 3.13) $HOME/python3.13
ENV PATH="${PATH}:/home/renovate/python3.13/bin"

# Install jsonnet-bundler
RUN go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest && go clean -cache -modcache

WORKDIR /home/renovate/renovate

# Clone Renovate from the fork and checkout the specific commit that includes custom
# features for RPM lockfile support and Red Hat Container/RPM vulnerability alerts
RUN git clone --depth=1 --branch develop https://github.com/redhat-exd-rebuilds/renovate.git . \
    && git fetch --depth 1 origin ${RENOVATE_REVISION} \
    && git checkout ${RENOVATE_REVISION}

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
