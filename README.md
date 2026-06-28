# Easy Deploy Release

Release tooling and installer for RNS Easy Deploy bundle packages for ROS1 and ROS2.

## Automated Releases

Releases are generated automatically by CircleCI. The single source of truth is
[release-config.yml](release-config.yml): it declares the deploy scope (`deploy_for`),
the config repo branch/tag per ROS line, the bundle version, and every Docker image
tag for x86 and arm64.

Pushing to `master` triggers the pipeline, which:

1. Clones the matching config repos (`rns-config`, `rns-config2`) at the configured ref.
2. Renders per-ROS manifests and builds the Easy Deploy zips via
   [scripts/build_easy_deploy_release.sh](scripts/build_easy_deploy_release.sh).
3. Uploads the zips to GitHub Releases under tags `ros1-<bundle-id>` / `ros2-<bundle-id>`.

To cut a release, edit `release-config.yml` and push to `master`.

## Documentation

- Internal release guide: [README_INTERNAL.md](README_INTERNAL.md)
- Client installation guide: [README_CLIENT.md](README_CLIENT.md)
- Release source of truth: [release-config.yml](release-config.yml)
- ROS1 bundle manifest: [manifests/ros1-release.yaml](manifests/ros1-release.yaml)
- ROS2 bundle manifest: [manifests/ros2-release.yaml](manifests/ros2-release.yaml)
- Release orchestrator: [scripts/release.sh](scripts/release.sh)
- Easy Deploy template layout: [templates/README.md](templates/README.md)
