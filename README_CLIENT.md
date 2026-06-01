# Easy Deploy Client Installation Guide

This guide is for customers or deployment engineers who need to install Easy Deploy on a robot PC.

The current distribution model uses a private GitHub repository. A temporary GitHub token is required to download the installer script and release assets.

## Quick Start With Temporary GitHub Token

Set the temporary GitHub token provided by Movel Robotics:

```bash
export GITHUB_TOKEN=ghp_xxx
```

Download, extract, and install ROS1 latest:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/movelrobotics/easy-deploy-release/contents/scripts/install_easy_deploy.sh?ref=master" \
  | bash -s -- --repo movelrobotics/easy-deploy-release --ros ros1 --version latest --yes
```

Download, extract, and install ROS2 latest:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/movelrobotics/easy-deploy-release/contents/scripts/install_easy_deploy.sh?ref=master" \
  | bash -s -- --repo movelrobotics/easy-deploy-release --ros ros2 --version latest --yes
```

## Safe Test Mode

Use `--no-install` to only download and extract the package without running the installer.

ROS1 latest download only:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/movelrobotics/easy-deploy-release/contents/scripts/install_easy_deploy.sh?ref=master" \
  | bash -s -- --repo movelrobotics/easy-deploy-release --ros ros1 --version latest --no-install
```

ROS2 latest download only:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/movelrobotics/easy-deploy-release/contents/scripts/install_easy_deploy.sh?ref=master" \
  | bash -s -- --repo movelrobotics/easy-deploy-release --ros ros2 --version latest --no-install
```

After download-only mode, install manually from the extracted package:

```bash
cd ~/Downloads/easy-deploy/easy-deploy-ros2-bundle-1.0.0-x86
bash install-2-seirios.sh
```

## Specific Bundle Install

Install a specific ROS1 bundle:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros1 \
  --version bundle-1.0.0 \
  --yes
```

Install a specific ROS2 bundle:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version bundle-1.0.0 \
  --yes
```

Clients do not need to know backend/frontend/config component versions. The selected bundle already contains those versions.

## Architecture Detection

The installer automatically detects the machine architecture:

```text
x86_64  -> x86
aarch64 -> arm64
arm64   -> arm64
```

Only one matching zip is downloaded. For example, ROS2 on an x86 machine downloads only:

```text
easy-deploy-ros2-<bundle-id>-x86.zip
```

It does not download arm64 packages or ROS1 packages.

To download a package for another machine architecture, use `--arch` with `--no-install`:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest \
  --arch arm64 \
  --no-install
```

Architecture override is for downloading only when the requested package architecture differs from the current machine. Cross-architecture installation is not supported.

## What The Installer Does

The installer:

1. Detects the machine architecture.
2. Resolves the requested ROS line and bundle id.
3. Downloads the matching Easy Deploy zip from GitHub Releases.
4. Extracts the package into `~/Downloads/easy-deploy` by default.
5. Overwrites existing Easy Deploy config during reinstall.
6. Runs the package installer script when `--yes` is used or the prompt is confirmed.

## Token Requirements

The temporary token must be able to read:

```text
movelrobotics/easy-deploy-release repository contents
movelrobotics/easy-deploy-release release assets
```

For a classic personal access token, the minimum practical private-repo scope is:

```text
repo
```

For a fine-grained personal access token, use repository-only access to `movelrobotics/easy-deploy-release` with:

```text
Contents: Read-only
Metadata: Read-only
```

The token should have a short expiration, for example 3 days, and should be revoked after deployment is complete.

## Additional Commands

Download and extract only:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest \
  --no-install
```

Run without confirmation prompt:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest \
  --yes
```

Use a custom download directory:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest \
  --download-dir /tmp/easy-deploy
```

## Expected Download Structure

By default, the downloaded zip and extracted package are stored under:

```text
~/Downloads/easy-deploy/
```

Example after downloading ROS2 x86:

```text
~/Downloads/easy-deploy/
  easy-deploy-ros2-bundle-1.0.0-x86.zip
  easy-deploy-ros2-bundle-1.0.0-x86/
    ARCH.txt
    PACKAGE_DATE.txt
    release_info.json
    version_config.yaml
    version_config-*.yaml
    install-1-docker.sh
    install-2-seirios.sh
    install/
    utils/
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

The package metadata is available at:

```text
~/Downloads/easy-deploy/easy-deploy-ros2-bundle-1.0.0-x86/release_info.json
```

## Expected Installed Structure

After installation, Easy Deploy files are prepared under:

```text
~/catkin_ws/
  src/
  movel_ai/
    docker-compose.yaml
    config/
    maps/
      nav/
      graph_files/
      transit_points/
    paths/
    aux_tasks/
    Downloads/
      export/
      import/
    logs/
    backup/
    license/
    rabbitmq.conf
  license/
```

On reinstall, the installer overwrites:

```text
~/catkin_ws/movel_ai/config
```

This ensures the latest package config is used.

## Manual Installation After Download

If the package was downloaded with `--no-install`, run the installer manually:

```bash
cd ~/Downloads/easy-deploy/easy-deploy-ros2-bundle-1.0.0-x86
bash install-2-seirios.sh
```

For Docker installation only:

```bash
cd ~/Downloads/easy-deploy/easy-deploy-ros2-bundle-1.0.0-x86
bash install-1-docker.sh
```

## Troubleshooting

If `raw.githubusercontent.com` returns `404`, use the GitHub API command shown in the Quick Start section because this repository is private.

If the architecture does not match, the installer stops before installing:

```text
Architecture does not match
```

If Docker image pull fails, confirm that all image tags in `release_info.json` exist in the Docker registry.

If the release cannot be found, confirm the GitHub Release tag format:

```text
ros1-<bundle-id>
ros2-<bundle-id>
```
