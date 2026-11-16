# Linux build environment

The supported target is **Ubuntu 26.04 LTS** with the **swift.org** toolchain. `docker/Dockerfile` reproduces that environment exactly, so everyone builds and tests against the same OS and compiler.

## Usage

```sh
scripts/linux-swift build
scripts/linux-swift test
scripts/linux-swift test --filter <SuiteOrTestName>
scripts/linux-swift format lint -s -r Sources Tests
```

The script builds the image from `docker/` (cached after the first run), mounts the repo at `/src`, and runs `swift <args>`. Linux build products go in the Docker volume `nmea2000-swift-linux-build`, not in the host's `.build`, so macOS and Linux builds don't overwrite each other. To start clean, run `docker volume rm nmea2000-swift-linux-build`.

## What is pinned

| Input | Pinned to | Where |
|---|---|---|
| Base OS | `ubuntu:26.04` by digest | `UBUNTU_DIGEST` in `docker/Dockerfile` |
| Swift | `6.4.2` release from download.swift.org | `SWIFT_VERSION` |
| Signing key | Swift 6.x Release Signing Key `52BB7E3DE28A71BE22EC05FFEF80A866B47A981F` | `docker/swift-6.x-release-key.asc` |

The toolchain tarball's PGP signature is checked against the key file in the repo, and the build fails if the check fails. The install steps follow the official [swiftlang/swift-docker](https://github.com/swiftlang/swift-docker) `6.4/ubuntu/26.04/Dockerfile`, but run on a plain Ubuntu base instead of the `swift` image.

The signing key is kept in the repo instead of being fetched from a keyserver. swift.org renewed it on 2026-10-12 (same fingerprint, now expiring 2028-10-11), and keyservers may still serve the old copy that expired 2026-09-16. The source of truth is `keys/release-key-swift-6.x.asc` in [swiftlang/swift-org-website](https://github.com/swiftlang/swift-org-website/tree/main/keys).

Apt package versions aren't pinned. They come from the Ubuntu 26.04 archive as of the build.

## Updating

- **Ubuntu:** run `docker buildx imagetools inspect ubuntu:26.04`, and copy the top-level digest into `UBUNTU_DIGEST`.
- **Swift:** set `SWIFT_VERSION`. If a release is signed with a new or renewed key, replace `docker/swift-6.x-release-key.asc` with the copy from swift-org-website and update the fingerprint.

After either change, rebuild, run `scripts/linux-swift test`, and commit the change by itself.
