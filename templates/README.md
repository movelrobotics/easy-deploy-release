# Easy Deploy Templates

Place the full Easy Deploy template directories here when the team wants templates to be versioned in this repository.

Expected structure:

```text
templates/
  ros1/
    x86/easy-deploy/
    arm64/easy-deploy/
  ros2/
    x86/easy-deploy/
    arm64/easy-deploy/
```

Each `easy-deploy/` directory must contain at least:

```text
install-2-seirios.sh
files/catkin_ws/movel_ai/docker-compose.yaml
```

The builder uses these `templates/` paths first when they contain valid templates. If they are still empty placeholders, the builder falls back to the legacy local folders that were downloaded from Google Drive.
