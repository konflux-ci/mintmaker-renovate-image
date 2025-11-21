#!/usr/bin/env bash

ARCH="x86_64-unknown-linux-gnu"
CONFIGURATION="install_only_stripped"
PYTHON_VERSION=$1

if [ "$#" -ne 1 ]; then
    echo "Error: This script requires exactly one argument - Python version request (e.g. '3.13')." >&2
    exit 1
fi

# Get the latest release tag (in format YYYYMMDD) and use that to filter all release assets
# to find one matching cpython-{version}-{arch}-{configuration}.tar.gz, since the patch version
# is not known to this script, i.e. we request "3.13", but we don't know that "3.13.7" is the latest
if [ "$PYTHON_VERSION" = "3.9" ]; then
    RELEASE_TAG="20251028"
else
    RELEASE_TAG=$(curl -s -L -H "Accept: application/json" https://github.com/astral-sh/python-build-standalone/releases/latest | jq -r .tag_name)
fi

DOWNLOAD_URL=$(curl -s -L -H "Accept: application/json" "https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/$RELEASE_TAG" | jq ".assets.[]|select(.name | startswith(\"cpython-$PYTHON_VERSION\"))|select(.name | endswith(\"$ARCH-$CONFIGURATION.tar.gz\"))" | jq -r .browser_download_url)

# Download the archive and extract into ~/python{version}
curl -s -L -o /tmp/python-$PYTHON_VERSION.tar.gz $DOWNLOAD_URL
mkdir $HOME/python$PYTHON_VERSION
tar xf /tmp/python-$PYTHON_VERSION.tar.gz -C $HOME/python$PYTHON_VERSION
mv $HOME/python$PYTHON_VERSION/python/* $HOME/python$PYTHON_VERSION/

# Clean up
rm -r $HOME/python$PYTHON_VERSION/python
rm /tmp/python-$PYTHON_VERSION.tar.gz
