# Build with: podman build --ulimit nofile=65535:65535 . -t custom-renovate
# Run with: podman run --rm <additional args> custom-renovate renovate

FROM quay.io/fedora/fedora:40-x86_64
LABEL description="Mintmaker - Renovate custom image" \
      summary="Mintmaker basic container image - a Renovate custom image" \
      maintainer="EXD Rebuilds Guild <exd-guild-rebuilds@redhat.com >"

ARG RENOVATE_VERSION=37.407.1-custom

# Using OpenSSL store allows for external modifications of the store. It is needed for the internal Red Hat cert.
ENV NODE_OPTIONS=--use-openssl-ca

RUN dnf update -y && \
    dnf install -y \
        git \
        python3-dnf \
        python3-pip \
        python3.11 \
        python3.10 \
        python3.9 \
        python3.8 \
        nodejs \
        npm \
        skopeo \
        podman && \
    dnf clean all && \
    rpm --install --verbose \
        https://github.com/tektoncd/cli/releases/download/v0.35.1/tektoncd-cli-0.35.1_Linux-64bit.rpm

# Add renovate user and switch to it
RUN useradd -lms /bin/bash -u 1001 renovate

WORKDIR /home/renovate
USER 1001

# Enable renovate user's bin dirs,
#   ~/.local/bin for Python executables
#   ~/node_modules/.bin for renovate
ENV PATH="/home/renovate/.local/bin:/home/renovate/node_modules/.bin:${PATH}"

# Install package managers
RUN npm install pnpm@9.2.0

# Use virtualenv isolation to avoid dependency issues with other global packages
RUN pip3 install --user pipx
RUN pipx install poetry pdm pipenv

WORKDIR /home/renovate/renovate

# Clone Renovate from specific ref (that includes the RPM lockfile support)
RUN git clone --depth=1 --branch rpm-lockfiles https://github.com/redhat-exd-rebuilds/renovate.git .

# Replace package.json version for this build
RUN sed -i "s/0.0.0-semantic-release/${RENOVATE_VERSION}/g" package.json

# Install project dependencies
RUN pnpm install

# Build Renovate
RUN pnpm build

# Install executables into the bin dir
RUN npm install --prefix /home/renovate .

WORKDIR /home/renovate/rpm-lockfile-prototype

# Clone and install the rpm-lockfile-prototype
# We must pass --no-dependencies, otherwise it would try to
# fetch dnf from PyPI, which is just a dummy package
RUN git clone --depth=1 --branch v0.1.0-alpha.5 https://github.com/konflux-ci/rpm-lockfile-prototype.git .
RUN pip3 install --user jsonschema PyYaml productmd requests
RUN pip3 install --user --no-dependencies .

WORKDIR /workspace
