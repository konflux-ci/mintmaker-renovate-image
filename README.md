# mintmaker-renovate-image

This repo hosts the MintMaker container image.
This container image is built and pushed [here](https://quay.io/konflux-ci/mintmaker-renovate-image) with Konflux, so it is an automatic process.

This image is a custom [Renovate](https://docs.renovatebot.com/) image, with the addition of the `rpm` manager: that uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

Some dependencies are installed in this image in order to have the necessary dependencies to run specific managers. The list of enabled managers is then defined in the Renovate configuration.

## rpm-lockfile support

The main difference of this image with the upstream Renovate image is the support for the `rpm` manager. This is a custom manager.
In order to support this, we maintain a fork of Renovate, that can be found [here](https://github.com/redhat-exd-rebuilds/renovate).

As mentioned before, the `rpm` manager uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

# Dockerfile design

MintMaker's [Dockerfile](https://github.com/konflux-ci/mintmaker-renovate-image/blob/main/Dockerfile)
is built from [ubi9-minimal](https://catalog.redhat.com/software/containers/ubi9-minimal/61832888c0d15aff4912fe0d).

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
