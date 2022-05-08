# Copyright (c) 2021 Leorize <leorize+oss@disroot.org>
#
# This file is licensed under the terms of the MIT license. See "license.txt"
# included in this distribution for more information.

# Update this monthly
#
# If you alter this line formatting or move it away from the top, update
# check-node-updates.sh to do update checking/fixing properly.
ARG node_version=16.15.0

# --- Builder image to download NodeJS for other images

# This image tracks testing since it works better for ARMv7
FROM docker.io/debian:testing-slim as node-downloader

# Inherit this from global environment
ARG node_version

# Update APT and install tools to download nodejs
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
         --no-install-recommends \
         curl \
         ca-certificates \
         gnupg \
         xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and extract nodejs
RUN set -eux \
    && dpkg_arch=$(dpkg --print-architecture) \
    && node_arch= \
    && case "$dpkg_arch" in \
       amd64) node_arch="x64";; \
       arm64) node_arch="arm64";; \
       armhf) node_arch="armv7l";; \
       *) echo "Error: unsupported nodejs architecture"; exit 1;; \
       esac \
    # Import trusted release keys
    # https://github.com/nodejs/node#release-keys
    && gpg --keyserver keyserver.ubuntu.com \
         --keyserver keys.openpgp.org \
         --recv-keys \
         4ED778F539E3634C779C87C6D7062848A1AB005C \
         94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
         74F12602B6F1C4E913FAA37AD3A89613643B6201 \
         71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
         8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
         C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
         C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
         DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
         A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
         108F52B48DB57BB0CC439B2997B01419BD92F80A \
         B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    # Download the tarball
    && release_name=node-v${node_version}-linux-${node_arch} \
    && tarball_name=${release_name}.tar.xz \
    && curl -LO "https://nodejs.org/dist/v${node_version}/${tarball_name}" \
    # Download the checksums
    && curl -LO "https://nodejs.org/dist/v${node_version}/SHASUMS256.txt.asc" \
    # Verify the signatures
    && gpg -o SHASUMS256.txt --decrypt SHASUMS256.txt.asc \
    # Verify the checksums
    #
    # It would be better if we have pipefail here, but sha256sum knows to bail
    # when there is an empty input, so all is well.
    && grep -F "${tarball_name}" SHASUMS256.txt | sha256sum -c - \
    # Extract the tarball
    && mkdir -p "/node-${node_version}" \
    && tar -C "/node-${node_version}" --strip-components=1 -xf "${tarball_name}" \
    # Remove artifacts to save space (even though this is just a builder image)
    && rm SHASUMS256.txt* "$tarball_name"

# --- Image used for building the compiler

FROM docker.io/debian:buster-20220418-slim as builder

# Switch to snapshot repositories to ensure that the image is reproducible
#
# These repositories are kept as comments in /etc/apt/sources.list, of which we
# use sed to switch to them
RUN sed \
      # Delete all repository lines
      -e '/^deb /d' \
      # Uncomment the snapshot lines
      -e 's/^# \(deb.*\)/\1/g' \
      # Do this inline, saving the old file as .non-snapshot
      -i.non-snapshot \
      /etc/apt/sources.list \
    # Since we switch to snapshot, Check-Valid-Until has to be disabled
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/container-snapshot

# Update APT then install compiler build dependencies
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
         --no-install-recommends \
         # Required for building the compiler
         gcc \
         g++ \
         # Required for building C stuff
         libc-dev \
         # Required for building csources
         make \
         # Required for retrieving source information
         git \
         # Required for running build script
         python3 \
         # Required for sharing artifacts in CI
         ca-certificates \
         curl \
         # Required to build archives
         zstd \
    && rm -rf /var/lib/apt/lists/*

# Inherit the variable to this image
ARG node_version

# Install NodeJS
COPY --from=node-downloader /node-${node_version} /opt/node-${node_version}

# Add Node to PATH
ENV PATH="/opt/node-${node_version}/bin:${PATH}"

# --- Image used for testing the compiler

FROM builder as tester

# Install additional dependencies for compiler tests
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      --no-install-recommends \
      # Required by Boehm GC tests
      libgc-dev \
      # Required for ARC/ORC memory leak tests
      libc6-dbg \
      valgrind \
      # Required for tgetprotobyname.nim
      netbase \
    # Remove APT lists after we are done
    && rm -rf /var/lib/apt/lists/*
