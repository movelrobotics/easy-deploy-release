# Internal Easy Deploy Release Guide

This guide is for the internal team that prepares Easy Deploy release zip files.

## Quick Start

From the repository root:

```bash
bash scripts/build_easy_deploy_release.sh --author "Movel Robotics"
```

The generated files will be placed in `dist/`:

```text
dist/easy-deploy-ros1-<version>-x86.zip
dist/easy-deploy-ros1-<version>-arm64.zip
dist/easy-deploy-ros2-<version>-x86.zip
dist/easy-deploy-ros2-<version>-arm64.zip
dist/manifest.json
```

Upload those zip files to GitHub Releases in this repository.

## Repository Purpose

This repository has two responsibilities:

1. Build release zip files for ROS1 and ROS2 Easy Deploy.
2. Provide the client installer script that downloads the correct zip from GitHub Releases.

Do not commit large Easy Deploy zip files into the Git branch. Zip files should be uploaded as GitHub Release assets.

## Required Local Inputs

Before running the builder, prepare these files/directories locally:

```text
easy-deploy-release/
  scripts/
    build_easy_deploy_release.sh
    install_easy_deploy.sh
  rns-config-release-<ros1-version>/
  rns-config2-release-<ros2-version>/
  easy-deploy-ros2:<old-version>-x86/
  easy-deploy-ros2:<old-version>-arm64/
  movel-ai-easy-deploy-x86_64-*/.../easy-deploy/
  movel-ai-easy-deploy-arm64-*/.../easy-deploy/
```

The exact folder names may differ, but the builder expects:

- ROS1 x86 Easy Deploy template.
- ROS1 arm64 Easy Deploy template.
- ROS2 x86 Easy Deploy template.
- ROS2 arm64 Easy Deploy template.
- Latest ROS1 config release from `rns-config`.
- Latest ROS2 config release from `rns-config2`.

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

The release version is read from each config's `seirios_config_release.yml` file:

```text
rns-config-release-2.73.0/seirios_config_release.yml
rns-config2-release-5.3.0/seirios_config_release.yml
```

The builder does not use the folder name as the version source.

## Version Rules

The version comes from:

```yaml
Version: 5.3.9
```

or:

```yaml
Version: rns-ros2-adhoc-qt
```

The value must be valid for Docker tags and file names:

```text
letters, numbers, underscore, dot, dash
```

Examples of valid versions:

```text
2.73.0
5.3.9
rns-ros2-adhoc-qt
```

Important: the same version is used as the Docker image tag. For example, `Version: rns-ros2-adhoc-qt` produces:

```yaml
image: movelrobots/rns-ros2:rns-ros2-adhoc-qt
```

Make sure that Docker image tag exists before releasing it.

## Build Commands

Default build:

```bash
bash scripts/build_easy_deploy_release.sh --author "Movel Robotics"
```

Use explicit config directories:

```bash
bash scripts/build_easy_deploy_release.sh \
  --author "Movel Robotics" \
  --ros1-config-dir /path/to/rns-config-release-2.73.0 \
  --ros2-config-dir /path/to/rns-config2-release-5.3.0
```

Override versions manually:

```bash
bash scripts/build_easy_deploy_release.sh \
  --ros1-version 2.73.0 \
  --ros2-version 5.3.9 \
  --author "Movel Robotics"
```

Use explicit template directories:

```bash
ROS1_X86_TEMPLATE=/path/to/ros1-x86/easy-deploy \
ROS1_ARM64_TEMPLATE=/path/to/ros1-arm64/easy-deploy \
ROS2_X86_TEMPLATE=/path/to/ros2-x86/easy-deploy \
ROS2_ARM64_TEMPLATE=/path/to/ros2-arm64/easy-deploy \
bash scripts/build_easy_deploy_release.sh --author "Movel Robotics"
```

## Build Behavior

The builder creates four packages:

```text
easy-deploy-ros1-<ros1-version>-x86.zip
easy-deploy-ros1-<ros1-version>-arm64.zip
easy-deploy-ros2-<ros2-version>-x86.zip
easy-deploy-ros2-<ros2-version>-arm64.zip
```

For each package, the builder:

- Copies the matching Easy Deploy template.
- Replaces `files/catkin_ws/movel_ai/config` with the latest config.
- Updates `docker-compose.yaml` with the target RNS Docker image tag.
- Updates `version_config*.yaml` with the target RNS Docker image tag.
- Writes `PACKAGE_DATE.txt`.
- Writes `release_info.json`.
- Updates install behavior so existing config is overwritten during reinstall.

If the same version is built again, the zip with the same name is overwritten. If a different version is built, the old zip remains in `dist/` and a new zip is added.

## Output Package Structure

Each generated zip contains one top-level directory:

```text
easy-deploy-ros2-5.3.9-x86/
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

The `release_info.json` file contains release metadata:

```json
{
  "package_name": "easy-deploy-ros2-5.3.9-x86",
  "file_name": "easy-deploy-ros2-5.3.9-x86.zip",
  "author": "Movel Robotics",
  "build_date": "2026-05-29T02:21:22+07:00",
  "ros": "ros2",
  "version": "5.3.9",
  "arch": "x86",
  "docker_compose": "files/catkin_ws/movel_ai/docker-compose.yaml",
  "docker_image": "movelrobots/rns-ros2:5.3.9",
  "config_path": "files/catkin_ws/movel_ai/config",
  "config_source": "./rns-config2-release-5.3.0",
  "template_source": "./easy-deploy-ros2:5.2.7-x86"
}
```

## Upload To GitHub Releases

Use this tag convention:

```text
ros1-<version>
ros2-<version>
```

Example ROS1 release:

```text
Tag: ros1-2.73.0
Assets:
- easy-deploy-ros1-2.73.0-x86.zip
- easy-deploy-ros1-2.73.0-arm64.zip
```

Example ROS2 release:

```text
Tag: ros2-5.3.9
Assets:
- easy-deploy-ros2-5.3.9-x86.zip
- easy-deploy-ros2-5.3.9-arm64.zip
```

Example non-numeric release:

```text
Tag: ros2-rns-ros2-adhoc-qt
Assets:
- easy-deploy-ros2-rns-ros2-adhoc-qt-x86.zip
- easy-deploy-ros2-rns-ros2-adhoc-qt-arm64.zip
```

Upload with GitHub CLI:

```bash
gh release create ros1-2.73.0 \
  dist/easy-deploy-ros1-2.73.0-x86.zip \
  dist/easy-deploy-ros1-2.73.0-arm64.zip \
  --title "Easy Deploy ROS1 2.73.0" \
  --notes "Easy Deploy ROS1 2.73.0"

gh release create ros2-5.3.9 \
  dist/easy-deploy-ros2-5.3.9-x86.zip \
  dist/easy-deploy-ros2-5.3.9-arm64.zip \
  --title "Easy Deploy ROS2 5.3.9" \
  --notes "Easy Deploy ROS2 5.3.9"
```

Upload to an existing release and replace assets with the same name:

```bash
gh release upload ros2-5.3.9 \
  dist/easy-deploy-ros2-5.3.9-x86.zip \
  dist/easy-deploy-ros2-5.3.9-arm64.zip \
  --clobber
```

Manual upload through the GitHub web UI is also valid. Make sure the tag and asset names match the installer convention.

## Internal Release Checklist

Before publishing a release:

- Confirm `seirios_config_release.yml` contains the intended `Version:`.
- Confirm the Docker image tag exists in the registry.
- Run the builder.
- Check `dist/manifest.json`.
- Check one package's `release_info.json`.
- Upload the correct assets to GitHub Releases.
- Test the client installer with `--no-install` first if possible.

Example test:

```bash
bash scripts/install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version 5.3.9 \
  --no-install
```
