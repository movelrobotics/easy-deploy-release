# Easy Deploy Client Installation Guide

This guide is for customers or deployment engineers who need to install Easy Deploy on a robot PC.

## Quick Start

Set the repository and branch first:

```bash
export EASY_DEPLOY_REPO=movelrobotics/easy-deploy-release
export EASY_DEPLOY_BRANCH=master
```

For a public repository, install ROS1 latest:

```bash
curl -fsSL "https://raw.githubusercontent.com/${EASY_DEPLOY_REPO}/${EASY_DEPLOY_BRANCH}/scripts/install_easy_deploy.sh" \
  | bash -s -- --repo "${EASY_DEPLOY_REPO}" --ros ros1 --version latest
```

For a public repository, install ROS2 latest:

```bash
curl -fsSL "https://raw.githubusercontent.com/${EASY_DEPLOY_REPO}/${EASY_DEPLOY_BRANCH}/scripts/install_easy_deploy.sh" \
  | bash -s -- --repo "${EASY_DEPLOY_REPO}" --ros ros2 --version latest
```

For a private repository, export a GitHub token first:

```bash
export GITHUB_TOKEN=ghp_xxx
export EASY_DEPLOY_REPO=movelrobotics/easy-deploy-release
export EASY_DEPLOY_BRANCH=master
```

Then install ROS1 latest:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/${EASY_DEPLOY_REPO}/contents/scripts/install_easy_deploy.sh?ref=${EASY_DEPLOY_BRANCH}" \
  | bash -s -- --repo "${EASY_DEPLOY_REPO}" --ros ros1 --version latest
```

Or install ROS2 latest:

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw" \
  "https://api.github.com/repos/${EASY_DEPLOY_REPO}/contents/scripts/install_easy_deploy.sh?ref=${EASY_DEPLOY_BRANCH}" \
  | bash -s -- --repo "${EASY_DEPLOY_REPO}" --ros ros2 --version latest
```

If `raw.githubusercontent.com` returns `404`, check the branch name and repository visibility. Private repositories should use the GitHub API command above.

The installer automatically detects the machine architecture:

```text
x86_64  -> x86
arm64   -> arm64
```

Only one matching zip is downloaded. For example, ROS2 on an x86 machine downloads only:

```text
easy-deploy-ros2-<version>-x86.zip
```

It does not download arm64 packages or ROS1 packages.

To download a package for another machine architecture, use `--arch` with `--no-install`.

## What The Installer Does

The installer:

1. Detects the machine architecture.
2. Resolves the requested ROS line and version.
3. Downloads the matching Easy Deploy zip from GitHub Releases.
4. Extracts the package into `~/Downloads/easy-deploy` by default.
5. Overwrites existing Easy Deploy config during reinstall.
6. Runs the package installer script.

## Installation Commands

Install ROS1 latest:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros1 \
  --version latest
```

Install ROS2 latest:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest
```

Install a specific ROS1 version:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --version 2.73.0
```

Install a specific ROS2 version:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --version 5.3.9
```

For numeric versions, the installer can infer the ROS line:

```text
2.x.x -> ros1
5.x.x -> ros2
```

For non-numeric versions, specify the ROS line explicitly:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version rns-ros2-adhoc-qt
```

Download and extract only, without running the installer:

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

Download an arm64 package from an x86 machine for offline transfer:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest \
  --arch arm64 \
  --no-install
```

Download an x86 package from an arm64 machine for offline transfer:

```bash
bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros1 \
  --version latest \
  --arch x86 \
  --no-install
```

Architecture override is for downloading only when the requested package architecture differs from the current machine. Cross-architecture installation is not supported.

## Private Repository Access

If the GitHub repository is private, provide a GitHub token before running the installer:

```bash
export GITHUB_TOKEN=ghp_xxx

bash install_easy_deploy.sh \
  --repo movelrobotics/easy-deploy-release \
  --ros ros2 \
  --version latest
```

The token must have permission to read repository contents and releases.

## Expected Download Structure

By default, the downloaded zip and extracted package are stored under:

```text
~/Downloads/easy-deploy/
```

Example after downloading ROS2 x86:

```text
~/Downloads/easy-deploy/
  easy-deploy-ros2-5.3.9-x86.zip
  easy-deploy-ros2-5.3.9-x86/
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
~/Downloads/easy-deploy/easy-deploy-ros2-5.3.9-x86/release_info.json
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
cd ~/Downloads/easy-deploy/easy-deploy-ros2-5.3.9-x86
bash install-2-seirios.sh
```

For Docker installation only:

```bash
cd ~/Downloads/easy-deploy/easy-deploy-ros2-5.3.9-x86
bash install-1-docker.sh
```

## Troubleshooting

If the architecture does not match, the installer stops before installing:

```text
Architecture does not match
```

Use the correct machine type or download the matching package.

If Docker image pull fails, confirm that the release version exists as a Docker image tag:

```text
movelrobots/rns-ros:<version>
movelrobots/rns-ros2:<version>
```

If the release cannot be found, confirm the GitHub Release tag format:

```text
ros1-<version>
ros2-<version>
```

If the repository is private, confirm `GITHUB_TOKEN` is set and has read access.
