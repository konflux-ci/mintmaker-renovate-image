# mintmaker-renovate-image

This repo hosts the MintMaker container image.
This container image is built and pushed to [Quay](https://quay.io/konflux-ci/mintmaker-renovate-image) with Konflux, so it is an automatic process.

This image is a custom [Renovate](https://docs.renovatebot.com/) image, with the addition of the `rpm` manager: that uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

Some dependencies are installed in this image in order to have the necessary dependencies to run specific managers. The list of enabled managers is then defined in the Renovate configuration.

## rpm-lockfile support

The main difference of this image with the upstream Renovate image is the support for the `rpm` manager. This is a custom manager.
In order to support this, we maintain a fork of Renovate [on GitHub](https://github.com/redhat-exd-rebuilds/renovate).

As mentioned before, the `rpm` manager uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

## Dockerfile design

MintMaker's [Dockerfile](https://github.com/konflux-ci/mintmaker-renovate-image/blob/main/Dockerfile) is built from [ubi10-minimal](https://catalog.redhat.com/en/software/containers/ubi10-minimal/66f16af45db83414cddcfc99).

The container image has to provide the following as a bare minimum:

- `renovate` executable
  - `node` and `npm` executables to be able to build Renovate from source
- `tkn` executable for running inside a Tekton pipeline
- `$PATH` environment variable extended with directories that contain
  executables of different managers
- The `renovate` user under which all processes run
- `git` for cloning the source repositories

## Running the image

The working directory is `/workspace`. If running in OpenShift, it must
run as the `renovate` user with UID 1001:

```yaml
apiVersion: tekton.dev/v1beta1
kind: Task
spec:
  stepTemplate:
    workingDir: /workspace
    securityContext:
      runAsUser: 1001
```

The command to run is `renovate`. All other commands by default run
under `/bin/sh`.

## RPM lockfile support

This feature requires `skopeo`, Python, `pip` and `python3-dnf` package
present in the image.

## Python based managers

Managers such as `poetry`, `pdm` and similar require Python and `pip`,
through which [pipx](https://github.com/pypa/pipx) is installed. `pipx` is used to isolate virtual
environments so it's easier to install all required managers independent
from each other's dependencies.

Some Python based projects can require a specific Python version,
which is why the Dockerfile adds multiple Python versions via `microdnf install`.

## Development

### Lint

Install the linters locally, then run `make lint`. CI runs the same checks in the `lint` job.

**macOS (Homebrew + npm):**

```bash
brew install hadolint shellcheck actionlint
npm install -g markdownlint-cli2@0.17.2
make lint
```

**Run individual checks:**

```bash
hadolint --failure-threshold warning --config .hadolint.yaml Dockerfile
shellcheck -x install-python.sh
markdownlint-cli2 --config .markdownlint.json README.md AGENTS.md
actionlint -shellcheck=shellcheck .github/workflows/*.yaml
```

`--failure-threshold warning` skips hadolint *info* findings (e.g. intentional single quotes in the pyenv profile setup).

### Build

```bash
podman build --ulimit nofile=65535:65535 . -t custom-renovate
```

### Lint coverage

| Location                                 | Linter                                   |
| ---------------------------------------- | ---------------------------------------- |
| `Dockerfile` `RUN` shell                 | hadolint (+ shellcheck where applicable) |
| `install-python.sh`                      | shellcheck                               |
| `.github/workflows/*.yaml` inline `run:` | actionlint + shellcheck                  |
| `README.md`, `AGENTS.md`                 | markdownlint                             |

### Lint baselines

Some pre-existing patterns are baselined so CI blocks only **new** violations. Config lives in `.hadolint.yaml` and `.markdownlint.json`.

#### Hadolint (`.hadolint.yaml`)

| Rule   | Why it is ignored                                                                          |
| ------ | ------------------------------------------------------------------------------------------ |
| DL3006 | Base image uses Red Hat catalog tags (`ubi10-minimal`), not semver pins                    |
| DL3041 | `microdnf install` does not pin individual RPM package versions                            |
| DL3059 | Many separate `RUN` instructions are intentional for Docker layer caching                  |
| DL4006 | Piped `RUN` steps (pyenv, rustup) do not use `SHELL … pipefail`; acceptable for this image |
| DL3042 | `pip`/`pipx` cache purge steps are deliberate during image build                           |
| DL3013 | Python packages are pinned via `ARG` + `${…}`; hadolint cannot see those substitutions     |
| DL3062 | `go install …@latest` for jsonnet-bundler is intentional                                   |
| DL3016 | `npm install --prefix` uses the local Renovate `package.json`, not a bare package name     |

`registry.access.redhat.com` is listed as a trusted registry.

#### Markdownlint (`.markdownlint.json`)

| Rule  | Why it is disabled                                       |
| ----- | -------------------------------------------------------- |
| MD013 | Line length — docs contain long URLs and technical prose |
