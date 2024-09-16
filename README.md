# mintmaker-renovate-image

This repo hosts the MintMaker container image.
This container image is built and pushed [here](https://quay.io/konflux-ci/mintmaker-renovate-image) with Konflux, so it is an automatic process.

This image is a custom [Renovate](https://docs.renovatebot.com/) image, with the addition of the `rpm` manager: that uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

Some dependencies are installed in this image in order to have the necessary dependencies to run specific managers. The list of enabled managers is then defined in the Renovate configuration.

## rpm-lockfile support

The main difference of this image with the upstream Renovate image is the support for the `rpm` manager. This is a custom manager.
In order to support this, we maintain a fork of Renovate, that can be found [here](https://github.com/redhat-exd-rebuilds/renovate).

As mentioned before, the `rpm` manager uses the [rpm-lockfile-prototype](https://github.com/konflux-ci/rpm-lockfile-prototype) to update a lockfile that tracks installed rpms.

