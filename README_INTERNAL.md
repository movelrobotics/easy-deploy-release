# Internal Easy Deploy Release Guide

This guide is for the internal team that builds Easy Deploy release bundles for ROS1 and ROS2.

Repository:

```text
movelrobotics/easy-deploy-release
```

## Quick Start

Prepare the latest config folders and update the release manifests:

```text
rns-config-release-<ros1-config-version>/
rns-config2-release-<ros2-config-version>/
manifests/ros1-release.yaml
manifests/ros2-release.yaml
templates/ros1/x86/easy-deploy/
templates/ros1/arm64/easy-deploy/
templates/ros2/x86/easy-deploy/
templates/ros2/arm64/easy-deploy/
```

templates can also using fallback from google drive, only download the zip and extract to local

Build all packages:

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

- Download and extract the latest config release.
- Update `manifests/ros1-release.yaml` and/or `manifests/ros2-release.yaml`.
- Confirm the config `seirios_config_release.yml` contains the intended `Version:`.
- Confirm every Docker image tag in the manifest exists.
- Run the builder.
- Check `dist/manifest.json`.
- Check one package's `release_info.json`.
- Upload the correct assets to GitHub Releases.
- Test the client installer with `--no-install` first.

Example test:

```bash
bash scripts/install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version bundle-1.0.0 \
  --no-install
```
