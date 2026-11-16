# Reproducible Linux build environment: Ubuntu 26.04 LTS + the official
# swift.org toolchain, installed the same way as swiftlang/swift-docker's
# 6.4/ubuntu/26.04/Dockerfile but on a plain, digest-pinned Ubuntu base.
#
# Build and use via scripts/linux-swift (see docs/linux.md).
#
# To update: bump UBUNTU_DIGEST (docker buildx imagetools inspect ubuntu:26.04)
# and/or SWIFT_VERSION, then rebuild and run the test suite.

ARG UBUNTU_DIGEST=sha256:d66b366dac61b575bee2aef07e9c26e8070096fbe84a3d4d3eb0da069b5d76db
FROM ubuntu:26.04@${UBUNTU_DIGEST}

LABEL org.opencontainers.image.description="NMEA2000 Swift build environment (Ubuntu 26.04 LTS, swift.org toolchain)"

# Toolchain runtime/build dependencies, per swiftlang/swift-docker 6.4/ubuntu/26.04.
RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get -q update \
 && apt-get -q install -y --no-install-recommends \
      binutils \
      binutils-gold \
      ca-certificates \
      curl \
      git \
      gnupg2 \
      libarchive-tools \
      libc6-dev \
      libcurl4-openssl-dev \
      libedit2 \
      libgcc-15-dev \
      libncurses5-dev \
      libpython3-dev \
      libsqlite3-0 \
      libstdc++-15-dev \
      libxml2-dev \
      libz3-dev \
      pkg-config \
      tzdata \
      unzip \
      zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

ARG SWIFT_VERSION=6.4.2
# Swift 6.x Release Signing Key (renewed 2026-10-12, expires 2028-10-11).
# Vendored from swiftlang/swift-org-website keys/release-key-swift-6.x.asc
# rather than fetched from a keyserver, which may still serve the expired copy.
ARG SWIFT_KEY_FINGERPRINT=52BB7E3DE28A71BE22EC05FFEF80A866B47A981F
COPY swift-6.x-release-key.asc /tmp/swift-key.asc

RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) ARCH_SUFFIX='' ;; \
      arm64) ARCH_SUFFIX='-aarch64' ;; \
      *) echo >&2 "unsupported architecture: $(dpkg --print-architecture)"; exit 1 ;; \
    esac; \
    PLATFORM=ubuntu26.04; \
    TAG="swift-${SWIFT_VERSION}-RELEASE"; \
    URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/$(echo $PLATFORM | tr -d .)${ARCH_SUFFIX}/${TAG}/${TAG}-${PLATFORM}${ARCH_SUFFIX}.tar.gz"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --quiet --import /tmp/swift-key.asc; \
    gpg --batch --list-keys --with-colons | grep -q "^fpr:::::::::${SWIFT_KEY_FINGERPRINT}:" \
      || { echo >&2 "vendored key fingerprint mismatch"; exit 1; }; \
    curl -fsSL "$URL" -o /tmp/swift.tar.gz "$URL.sig" -o /tmp/swift.tar.gz.sig; \
    gpg --batch --verify /tmp/swift.tar.gz.sig /tmp/swift.tar.gz; \
    # bsdtar works around https://github.com/orbstack/orbstack/issues/2588 (as upstream does)
    bsdtar -xzf /tmp/swift.tar.gz -C / --strip-components=1; \
    chmod -R o+r /usr/lib/swift; \
    rm -rf "$GNUPGHOME" /tmp/swift.tar.gz /tmp/swift.tar.gz.sig /tmp/swift-key.asc

RUN swift --version && swift format --version

WORKDIR /src
