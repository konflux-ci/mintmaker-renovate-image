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
ARG RENOVATE_VERSION=42.26.5-rpm

# Specific git commit hash from the redhat-exd-rebuilds/renovate fork
ARG RENOVATE_REVISION=56eaafa3f15f70521c67e5f0ba28ba3eba7fffdb

# Version for the rpm-lockfile-prototype executable from
# https://github.com/konflux-ci/rpm-lockfile-prototype/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/rpm-lockfile-prototype versioning=semver
ARG RPM_LOCKFILE_PROTOTYPE_VERSION=0.21.0

# Version for the pipeline-migration-tool from
# https://github.com/konflux-ci/pipeline-migration-tool/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=konflux-ci/pipeline-migration-tool versioning=semver
ARG PIPELINE_MIGRATION_TOOL_VERSION=0.5.3

# Version for the tekton cli from
# https://github.com/tektoncd/cli/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=tektoncd/cli versioning=semver
ARG TEKTON_CLI_VERSION=0.44.0

# Version for the yq from
# https://github.com/mikefarah/yq/tags
# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=mikefarah/yq versioning=semver
ARG YQ_VERSION=4.52.4

# NodeJS version used for Renovate, has to satisfy the version
# specified in Renovate's package.json
ARG NODEJS_VERSION=24.11.0

ARG PNPM_VERSION=10.23.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=npm depName=yarn
ARG YARN_VERSION=1.22.22

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=npm depName=bun
ARG BUN_VERSION=1.3.10

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=npm depName=meteor
ARG METEOR_VERSION=3.4.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=rubygems depName=bundler
ARG BUNDLER_VERSION=4.0.7

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipx
ARG PIPX_VERSION=1.8.0

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=poetry
ARG POETRY_VERSION=2.3.2

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pdm
ARG PDM_VERSION=2.26.6

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pipenv
ARG PIPENV_VERSION=2026.0.3

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=hashin
ARG HASHIN_VERSION=1.0.5

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=uv
ARG UV_VERSION=0.10.6

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=hatch
ARG HATCH_VERSION=1.16.4

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=pypi depName=pip-tools
ARG PIP_TOOLS_VERSION=7.5.3

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=helm/helm
ARG HELM_V3_VERSION=4.1.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=gradle/gradle
ARG GRADLE_VERSION=9.3.1

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=clojure/brew-install
ARG CLOJURE_VERSION=1.12.4.1582

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=sbt/sbt
ARG SBT_VERSION=1.12.4

# Do not remove the following line, renovate uses it to propose version updates
# renovate: datasource=github-tags depName=technomancy/leiningen
ARG LEININGEN_VERSION=2.12.0

# Support multiple Go versions
ENV GOTOOLCHAIN=auto

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS="--use-openssl-ca --max-old-space-size=2816"

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
        ruby \
        golang \
        skopeo \
        jq \
        xz \
        tar \
        zip unzip \
        java-21-openjdk-devel \
        which \
        libpq-devel \
        krb5-devel && \
    microdnf clean all


# Install tekton
RUN curl -L -o /tmp/tkn.tar.gz https://github.com/tektoncd/cli/releases/download/v${TEKTON_CLI_VERSION}/tkn_${TEKTON_CLI_VERSION}_Linux_x86_64.tar.gz && tar xvzf /tmp/tkn.tar.gz -C /usr/bin/ tkn && rm -f /tmp/tkn.tar.gz

# Install helmv3
RUN curl -L -o /tmp/helmv3.tar.gz https://get.helm.sh/helm-v${HELM_V3_VERSION}-linux-amd64.tar.gz && tar xvzf /tmp/helmv3.tar.gz -C /tmp; mv /tmp/linux-amd64/helm /usr/bin/helm && rm -f /tmp/helmv3.tar.gz && rm -rf /tmp/linux-amd64

# Install yq
RUN curl -L https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -o /usr/bin/yq && chmod +x /usr/bin/yq

# Install nodejs
RUN curl -o node-v${NODEJS_VERSION}-linux-x64.tar.xz https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz
RUN tar xf node-v${NODEJS_VERSION}-linux-x64.tar.xz && \
    mv node-v${NODEJS_VERSION}-linux-x64/bin/* /bin/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/include/* /include/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/lib/* /lib/ && \
    rm -fr node-v${NODEJS_VERSION}-linux-x64 && \
    rm -f node-v${NODEJS_VERSION}-linux-x64.tar.xz

# Install gradle
RUN curl -Lo gradle.zip https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip && \
    mkdir /opt/gradle-${GRADLE_VERSION} && unzip -d /opt/gradle-${GRADLE_VERSION} gradle.zip && \
    rm gradle.zip && \
    ln -s /opt/gradle-${GRADLE_VERSION}/gradle-${GRADLE_VERSION}/bin/gradle /usr/bin/gradle

# Install Clojure
RUN curl -Lo install-clojure.sh https://github.com/clojure/brew-install/releases/download/${CLOJURE_VERSION}/linux-install.sh && \
    chmod +x install-clojure.sh && ./install-clojure.sh && rm install-clojure.sh

# Install sbt
RUN curl -Lo sbt.tgz https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz && \
    mkdir /opt/sbt-v${SBT_VERSION} && tar xf sbt.tgz -C /opt/sbt-v${SBT_VERSION} && \
    rm sbt.tgz && \
    ln -s /opt/sbt-v${SBT_VERSION}/sbt/bin/sbt /usr/bin/sbt

# Install Lieningen
RUN curl -Lo /usr/bin/lein https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein && chmod +x /usr/bin/lein

# Add renovate user and switch to it
RUN useradd -lms /bin/bash -u 1001 -g 0 renovate
RUN mkdir -p /home/renovate/.cache /home/renovate/.local /home/renovate/.local/state/pdm /home/renovate/.rustup/tmp
RUN chown -R 1001:0 /home/renovate && chmod -R 2775 /home/renovate

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:/home/renovate/go/bin:/home/renovate/.pyenv/bin:/home/renovate/.cargo/bin:/tmp/renovate/cache/others/go/bin:${PATH}"

# Install package managers
RUN npm install pnpm@${PNPM_VERSION} yarn@${YARN_VERSION} bun@${BUN_VERSION} && npm cache clean --force
RUN npx clear-npx-cache && npx meteor@${METEOR_VERSION} install
ENV PATH="/home/renovate/.meteor:${PATH}"

# Install bundler
RUN gem install bundler -v ${BUNDLER_VERSION}

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3.12 install --user pipx==${PIPX_VERSION} && pip3.12 cache purge
RUN pipx install --python python3.12 poetry==${POETRY_VERSION} pdm==${PDM_VERSION} pipenv==${PIPENV_VERSION} \
    hashin==${HASHIN_VERSION} uv==${UV_VERSION} hatch==${HATCH_VERSION} pip-tools==${PIP_TOOLS_VERSION} \
    git+https://github.com/konflux-ci/pipeline-migration-tool.git@v${PIPELINE_MIGRATION_TOOL_VERSION}\
    && pipx inject hashin certifi\
    && rm -fr ~/.cache/pipx && pip3.12 cache purge

# Install pyenv
RUN curl https://pyenv.run | sh
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.profile && \
    echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.profile && \
    echo 'eval "$(pyenv init -)"' >> ~/.profile

# Install additional Python versions
COPY install-python.sh /home/renovate/install-python.sh

# Download prebuilt CPython
RUN ./install-python.sh 3.9
RUN ./install-python.sh 3.10
RUN ./install-python.sh 3.11
RUN ./install-python.sh 3.13
RUN ./install-python.sh 3.14

# Ensure Python requests library uses system root certificates
# Particularly important for Python virtual environments
ENV REQUESTS_CA_BUNDLE=/etc/pki/tls/certs/ca-bundle.crt

# Set paths for openssl/urllib
ENV SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
ENV SSL_CERT_DIR=/etc/pki/tls/certs

# Update paths
ENV PATH="${PATH}:/home/renovate/python3.9/bin:/home/renovate/python3.10/bin:/home/renovate/python3.11/bin:/home/renovate/python3.13/bin:/home/renovate/python3.14/bin"

# Install jsonnet-bundler
RUN go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest && go clean -cache -modcache

# Use rustup to install the latest Rust toolchain
RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y

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

# Run pipx install with the --system-site-packages so rpm-lockfile-prototype can use the system's python3-dnf package
RUN pipx install --python python3.12 git+https://github.com/konflux-ci/rpm-lockfile-prototype.git@v${RPM_LOCKFILE_PROTOTYPE_VERSION} --system-site-packages && \
    rm -fr ~/.cache/pipx && pip3.12 cache purge

WORKDIR /workspace
