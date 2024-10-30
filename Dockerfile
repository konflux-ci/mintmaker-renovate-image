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
ARG RENOVATE_VERSION=38.136.0-rpm

# Version for the rpm-lockfile-prototype executable from
# https://github.com/konflux-ci/rpm-lockfile-prototype/tags
ARG RPM_LOCKFILE_PROTOTYPE_VERSION=0.9.0

# NodeJS version used for Renovate, has to satisfy the version
# specified in Renovate's package.json
ARG NODEJS_VERSION=20.17.0

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS=--use-openssl-ca

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
        cargo \
        golang \
        skopeo \
        xz && \
    microdnf clean all && \
    rpm --install --verbose \
        https://github.com/tektoncd/cli/releases/download/v0.35.1/tektoncd-cli-0.35.1_Linux-64bit.rpm

# Install nodejs
RUN curl -o node-v${NODEJS_VERSION}-linux-x64.tar.xz https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz
RUN tar xf node-v${NODEJS_VERSION}-linux-x64.tar.xz && \
    mv node-v${NODEJS_VERSION}-linux-x64/bin/* /bin/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/include/* /include/ && \
    mv node-v${NODEJS_VERSION}-linux-x64/lib/* /lib/ && \
    rm -fr node-v${NODEJS_VERSION}-linux-x64 && \
    rm -f node-v${NODEJS_VERSION}-linux-x64.tar.xz

# Add renovate user and switch to it
RUN useradd -lms /bin/bash -u 1001 renovate
RUN chmod -R 755 /home/renovate

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:/home/renovate/go/bin:/tmp/renovate/cache/others/go/bin:${PATH}"

# Install package managers
RUN npm install pnpm@9.2.0 && npm cache clean --force

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3.12 install --user pipx && pip3.12 cache purge
RUN pipx install --python python3.12 poetry pdm pipenv hashin && rm -fr ~/.cache/pipx && pip3.12 cache purge

WORKDIR /home/renovate/renovate

# Clone Renovate from specific ref (that includes the RPM lockfile support)
RUN git clone --depth=1 --branch extract-rpms https://github.com/redhat-exd-rebuilds/renovate.git .

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
