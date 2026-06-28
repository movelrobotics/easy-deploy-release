# Internal Easy Deploy Release Guide

This guide is for the internal team that builds Easy Deploy release bundles for ROS1 and ROS2.

Repository:

```text
movelrobotics/easy-deploy-release
```

## Quick Start

Releases are driven by the single source of truth [release-config.yml](release-config.yml),
which declares the deploy scope, config repo refs, bundle version, and all image tags.
Edit that file, then either:

- push to `master` to let CircleCI build and publish automatically, or
- run the orchestrator locally:

```bash
bash scripts/release.sh --no-upload
```

The orchestrator clones the config repos at the configured ref, renders the per-ROS
manifests, runs the builder, and (unless `--no-upload` is set) uploads the zips to
GitHub Releases.

If `release-config.yml` is absent, the orchestrator falls back to the legacy manual
flow using `manifests/*.yaml` and a pre-existing local config directory:

```text
manifests/ros1-release.yaml
manifests/ros2-release.yaml
templates/ros1/x86/easy-deploy/
templates/ros1/arm64/easy-deploy/
templates/ros2/x86/easy-deploy/
templates/ros2/arm64/easy-deploy/
```

templates can also using fallback from google drive, only download the zip and extract to local

Build all packages (legacy path):

```bash
bash scripts/build_easy_deploy_release.sh
```

The output goes to `dist/`:

```text
dist/easy-deploy-ros1-bundle-1.0.0-x86.zip
dist/easy-deploy-ros1-bundle-1.0.0-arm64.zip
dist/easy-deploy-ros2-bundle-1.0.0-x86.zip
dist/easy-deploy-ros2-bundle-1.0.0-arm64.zip
dist/manifest.json
```

Upload the zip files to GitHub Releases. Do not commit the zip files to the Git branch.

## Upload To GitHub Releases

Use this tag convention:

```text
ros1-<bundle-id>
ros2-<bundle-id>
```

Example ROS2 release:

```text
Tag: ros2-bundle-1.0.0
Assets:
- easy-deploy-ros2-bundle-1.0.0-x86.zip
- easy-deploy-ros2-bundle-1.0.0-arm64.zip
```

Upload with GitHub CLI:

```bash
gh release create ros1-bundle-1.0.0 \
  dist/easy-deploy-ros1-bundle-1.0.0-x86.zip \
  dist/easy-deploy-ros1-bundle-1.0.0-arm64.zip \
  --repo movelrobotics/easy-deploy-release \
  --title "Easy Deploy ROS1 bundle-1.0.0" \
  --notes "Easy Deploy ROS1 bundle-1.0.0"

gh release create ros2-bundle-1.0.0 \
  dist/easy-deploy-ros2-bundle-1.0.0-x86.zip \
  dist/easy-deploy-ros2-bundle-1.0.0-arm64.zip \
  --repo movelrobotics/easy-deploy-release \
  --title "Easy Deploy ROS2 bundle-1.0.0" \
  --notes "Easy Deploy ROS2 bundle-1.0.0"
```

Upload to an existing release and replace assets with the same name:

```bash
gh release upload ros2-bundle-1.0.0 \
  dist/easy-deploy-ros2-bundle-1.0.0-x86.zip \
  dist/easy-deploy-ros2-bundle-1.0.0-arm64.zip \
  --repo movelrobotics/easy-deploy-release \
  --clobber
```

Manual upload through the GitHub web UI is also valid. The release tag and asset names must match the installer convention.

## Release Model

We use an **Easy Deploy Bundle** model.

A bundle is a complete set of versions for one Easy Deploy release:

```text
ROS image version
backend image version
frontend image version
backend-worker image version
Redis image version
RabbitMQ image version
Mongo image version
RNS config version
architecture
```

Clients do not need to know backend/frontend versions. Clients only choose:

```text
ros1 or ros2
latest or a specific bundle id
```

Example client-facing bundle ids:

```text
bundle-1.0.0
bundle-1.0.1
bundle-1.1.0
```

## Required Local Inputs

Before running the builder, prepare these local inputs:

```text
easy-deploy-release/
  scripts/
    build_easy_deploy_release.sh
    install_easy_deploy.sh
  manifests/
    ros1-release.yaml
    ros2-release.yaml
  templates/
    ros1/
      x86/easy-deploy/
      arm64/easy-deploy/
    ros2/
      x86/easy-deploy/
      arm64/easy-deploy/
  rns-config-release-<version>/
  rns-config2-release-<version>/
```

The builder needs:

- ROS1 x86 Easy Deploy template.
- ROS1 arm64 Easy Deploy template.
- ROS2 x86 Easy Deploy template.
- ROS2 arm64 Easy Deploy template.
- Latest ROS1 config release from `rns-config`.
- Latest ROS2 config release from `rns-config2`.
- ROS1 release manifest.
- ROS2 release manifest.

The builder checks `templates/` first. If the template placeholders are still empty, it can still fall back to legacy local folders downloaded from Google Drive. Once templates are committed to this repository, `templates/` should become the main source.

## Template Folder

The expected template structure is:

```text
templates/
  ros1/
    x86/easy-deploy/
    arm64/easy-deploy/
  ros2/
    x86/easy-deploy/
    arm64/easy-deploy/
```

Each `easy-deploy/` template must contain at least:

```text
install-2-seirios.sh
files/catkin_ws/movel_ai/docker-compose.yaml
```

The full template should include install scripts, license files, `version_config.yaml`, `utils/`, and `files/catkin_ws/`.

## Getting Latest Config

Download the latest config release zip from the config repositories:

- ROS1 config: `rns-config`
- ROS2 config: `rns-config2`

Extract them into the same working directory as this repository.

Example:

```text
rns-config-release-2.73.0/
rns-config2-release-5.3.0/
```

The config version is still read from each config's `seirios_config_release.yml`:

```text
rns-config-release-2.73.0/seirios_config_release.yml
rns-config2-release-5.3.0/seirios_config_release.yml
```

The bundle id is not read from the config folder. The bundle id is read from the release manifest.

When using the automated path, `scripts/release.sh` clones the config repos at the ref
configured in `release-config.yml` (see below), so no manual download is required.

## Automated Release (release-config.yml)

`release-config.yml` is the single source of truth for an automated release. It overrides
the hand-maintained `manifests/*.yaml` when present. When it is absent, the legacy manual
flow (manifests + a pre-existing local config directory) is used unchanged.

```yaml
deploy_for: both          # ros1 | ros2 | both
author: Movel Robotics

ros1:
  config: release/2.73.0   # branch or tag in movelrobotics/rns-config
  version: 1.0.1           # raw version; bundle id becomes bundle-1.0.1
  x86:
    rns: movelrobots/rns-ros:2.73.0
    backend: movelrobots/rns-backend:4.39.0-alpha
    ...
  arm64:
    rns: movelrobots/rns-ros:2.73.0
    backend: movelrobots/rns-backend:arm64-4.39.0-alpha
    ...

ros2:
  config: release/5.3.0   # branch or tag in movelrobotics/rns-config2
  version: 1.0.1
  x86: { ...same keys... }
  arm64: { ...same keys... }
```

Field reference:

```text
deploy_for          Which ROS line(s) to build and publish: ros1, ros2, or both.
author              Release author written to release_info.json.
<ros>.config        Branch or tag to clone from the matching config repo.
<ros>.version       Raw version; the bundle id is bundle-<version>.
<ros>.(x86|arm64).* Docker image refs, each MUST include a tag.
```

The `ros` token (`ros1`/`ros2`) drives the package filename
(`easy-deploy-<ros>-<bundle-id>-<arch>.zip`) and the release tag (`<ros>-<bundle-id>`),
as well as the internal service/repo logic.

`scripts/release.sh` is the orchestrator:

```bash
# Build only, no upload (local dry-run)
bash scripts/release.sh --no-upload

# Override the scope regardless of release-config.yml
bash scripts/release.sh --deploy-for ros1 --no-upload

# Full release (clone configs, build, and upload to GitHub Releases)
bash scripts/release.sh
```

Flags: `--deploy-for {ros1,ros2,both}`, `--no-upload`, `--keep-config`,
`--dist-dir DIR`. The orchestrator auto-installs `yq` if it is missing.

Authentication: `GITHUB_USER`/`GITHUB_TOKEN` are used to clone the private config repos
and (as `GH_TOKEN`) to publish via the GitHub CLI. These are already configured in the
CircleCI `movelai-global`/`movelai-ros` contexts.

## CI Pipeline

The CircleCI workflow in `.circleci/config.yml` auto-runs on push to `master` only (no
approval gate):

1. Installs build tools and runs `scripts/release.sh`.
2. Builds the in-scope packages and writes `dist/manifest.json`.
3. Uploads the zips to GitHub Releases under `ros1-<bundle-id>` / `ros2-<bundle-id>`.
4. Sends Google Chat notifications (running/success/failure).

To cut a release, edit `release-config.yml` and push to `master`.

## Manifest YAML

The release manifest is the internal source of truth for a bundle.

ROS2 example:

```yaml
bundle:
  id: bundle-1.0.0
  ros: ros2
  author: Movel Robotics

config:
  path: ./rns-config2-release-5.3.0

images:
  x86:
    rns: movelrobots/rns-ros2:5.3.9
    backend: movelrobots/rns-backend:4.39.0-alpha
    frontend: movelrobots/rns-frontend:4.39.0-alpha
    backend_worker: movelrobots/rns-backend-worker:3.3.0
    redis: library/redis:6.2.0
    rabbitmq: library/rabbitmq:3.8.12-management
    mongo: library/mongo:4.4.4

  arm64:
    rns: movelrobots/rns-ros2:5.3.9
    backend: movelrobots/rns-backend:arm64-4.39.0-alpha
    frontend: movelrobots/rns-frontend:arm64-4.39.0-alpha
    backend_worker: movelrobots/rns-backend-worker:3.3.0
    redis: library/redis:6.2.0
    rabbitmq: library/rabbitmq:3.8.12-management
    mongo: library/mongo:4.4.4
```

The repository includes these example manifests:

```text
manifests/ros1-release.yaml
manifests/ros2-release.yaml
```

Update these manifest files whenever any component version changes.

## Manifest Rules

The `bundle.id` is used for GitHub Release tags and zip names.

Example:

```yaml
bundle:
  id: bundle-1.0.0
```

Generated release tag:

```text
ros2-bundle-1.0.0
```

Generated assets:

```text
easy-deploy-ros2-bundle-1.0.0-x86.zip
easy-deploy-ros2-bundle-1.0.0-arm64.zip
```

The manifest image values must include Docker tags:

```text
movelrobots/rns-ros2:5.3.9
movelrobots/rns-backend:4.39.0-alpha
```

Make sure every image tag exists in the Docker registry before publishing a release.

## Build Commands

Default build using `manifests/ros1-release.yaml` and `manifests/ros2-release.yaml`:

```bash
bash scripts/build_easy_deploy_release.sh
```

Use explicit manifest files:

```bash
bash scripts/build_easy_deploy_release.sh \
  --ros1-manifest manifests/ros1-release.yaml \
  --ros2-manifest manifests/ros2-release.yaml
```

Use explicit config directories if needed:

```bash
bash scripts/build_easy_deploy_release.sh \
  --ros1-config-dir /path/to/rns-config-release-2.73.0 \
  --ros2-config-dir /path/to/rns-config2-release-5.3.0
```

Use explicit template directories if the builder cannot auto-detect them:

```bash
ROS1_X86_TEMPLATE=/path/to/ros1-x86/easy-deploy \
ROS1_ARM64_TEMPLATE=/path/to/ros1-arm64/easy-deploy \
ROS2_X86_TEMPLATE=/path/to/ros2-x86/easy-deploy \
ROS2_ARM64_TEMPLATE=/path/to/ros2-arm64/easy-deploy \
bash scripts/build_easy_deploy_release.sh
```

Override bundle ids manually only when necessary:

```bash
bash scripts/build_easy_deploy_release.sh \
  --ros1-version bundle-1.0.1 \
  --ros2-version bundle-1.0.1
```

Build only one ROS line (skips reading/building the other):

```bash
bash scripts/build_easy_deploy_release.sh --deploy-for ros1
# ros1 | ros2 | both (default: both)
```

## Build Behavior

For each package, the builder:

- Copies the matching Easy Deploy template.
- Replaces `files/catkin_ws/movel_ai/config` with the selected config folder.
- Updates `docker-compose.yaml` using image versions from the manifest.
- Updates `version_config*.yaml` using image versions from the manifest.
- Writes `PACKAGE_DATE.txt`.
- Writes `release_info.json`.
- Updates install behavior so existing config is overwritten during reinstall.

If the same bundle id is built again, the zip with the same name is overwritten. If a different bundle id is built, the old zip remains in `dist/` and a new zip is added.

## Output Package Structure

Each generated zip contains one top-level directory:

```text
easy-deploy-ros2-bundle-1.0.0-x86/
  ARCH.txt
  PACKAGE_DATE.txt
  release_info.json
  version_config.yaml
  version_config-*.yaml
  install-1-docker.sh
  install-2-seirios.sh
  install/
    check_arch.sh
    check_docker.sh
    install_catkin_ws.sh
    install_docker.sh
    install_license.sh
    pull_seirios.sh
  utils/
    bash_utils.sh
  files/
    catkin_ws/
      movel_ai/
        docker-compose.yaml
        config/
        maps/
        paths/
        aux_tasks/
        Downloads/
        logs/
        backup/
      license/
```

The `release_info.json` file contains bundle metadata, including all image versions.

## Internal Release Checklist

Before publishing a release:

- Update `release-config.yml` (deploy scope, config refs, version, image tags).
  - For the legacy manual path instead: update `manifests/ros1-release.yaml` and/or `manifests/ros2-release.yaml` and provide a local config directory.
- Confirm the config `seirios_config_release.yml` (at the configured ref) contains the intended `Version:`.
- Confirm every Docker image tag in `release-config.yml` exists.
- Run `bash scripts/release.sh --no-upload` (or push to `master` for the CI path).
- Check `dist/manifest.json`.
- Check one package's `release_info.json`.
- Upload the correct assets to GitHub Releases (`release.sh` does this automatically without `--no-upload`).
- Test the client installer with `--no-install` first.

Example test:

```bash
bash scripts/install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version bundle-1.0.0 \
  --no-install
```
