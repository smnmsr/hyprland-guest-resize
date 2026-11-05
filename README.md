# hyprland-guest-resize

Keep a Hyprland output in sync with a resized QEMU/KVM **virtio-gpu** window.

When a VM window is resized, QEMU updates the virtual GPU's EDID/preferred mode.
The kernel emits a DRM `change` uevent and exposes the new mode in
`/sys/class/drm/card*-Virtual-*/modes`, but Hyprland does not apply it on its
own. This small watcher notices the uevent and switches the output to the new
mode.

Inspired by [m1st0/wayland_guest_resize](https://github.com/m1st0/wayland_guest_resize).
This project is a self-contained rewrite that adds connector auto-detection,
refresh-rate matching, retries, a systemd user service, and no `sudo`
requirement.

## How it works

```
VM window resize
      |
      v
QEMU updates virtio-gpu preferred mode
      |
      v
Kernel emits DRM "change" uevent
      |
      v
/sys/class/drm/card*-Virtual-*/modes   (first line = preferred mode)
      |
      v
sync-guest-display
      |
      v
hyprctl eval "hl.monitor(...)"         (or hyprctl keyword monitor)
      |
      v
Hyprland applies the new resolution
```

The script:

1. Auto-detects a connected, enabled `Virtual-*` DRM connector and its
   matching Hyprland output (for example `card1-Virtual-1` → `Virtual-1`).
2. Reads the first (preferred) mode from the connector's `modes` file.
3. Watches DRM uevents with `udevadm monitor` (unprivileged, no `sudo`).
4. Picks the best refresh rate Hyprland knows for that resolution (fastest at
   or below 60 Hz, otherwise the slowest available).
5. Applies the mode while preserving the output's current position and scale,
   with retries and a final `preferred` fallback.
6. Skips the switch when the size already matches.

## Requirements

- Linux guest in QEMU/KVM with a **virtio-gpu** display
- Hyprland running as a Wayland session
- `udevadm` (systemd-udev)
- `jq`
- A systemd user session (for the service; running the script manually works too)

Kernel modesetting for virtio-gpu must be active. On most current kernels it is
enabled by default; on GRUB-based guests you may need `virtio_gpu.modeset=1` in
`GRUB_CMDLINE_LINUX_DEFAULT`, followed by `grub-mkconfig`. Check with:

```bash
dmesg | grep -i virtio_gpu
```

`spice-vdagent` is **not** required by this script.

## Install

```bash
git clone https://github.com/smnmsr/hyprland-guest-resize.git
cd hyprland-guest-resize
./install.sh
```

This copies the script to `~/.local/bin`, installs a systemd user unit, and
enables/starts it for the current session and future logins.

Manual install, if you prefer:

```bash
install -Dm755 sync-guest-display ~/.local/bin/sync-guest-display
install -Dm644 sync-guest-display.service ~/.config/systemd/user/sync-guest-display.service
systemctl --user daemon-reload
systemctl --user enable --now sync-guest-display.service
```

## Usage

The service starts automatically. Resize the VM window and follow the log:

```bash
journalctl --user -u sync-guest-display -f
```

Expected output:

```
display size is 1720x1228; switching Virtual-1 to 1720x1228@60
applied 1720x1228@60 to Virtual-1
display size is 1720x1440; switching Virtual-1 to 1720x1440@60
applied 1720x1440@60 to Virtual-1
```

Apply the current size once, without starting the watcher:

```bash
sync-guest-display --once
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `SYNC_GUEST_OUTPUT` | auto-detect | Hyprland output name to manage, e.g. `Virtual-1` |
| `SYNC_GUEST_DRM_GLOB` | `/sys/class/drm/card*-Virtual-*` | Connector glob used for auto-detection |

Set an override for the service by editing
`~/.config/systemd/user/sync-guest-display.service`:

```ini
[Service]
Environment=SYNC_GUEST_OUTPUT=Virtual-1
```

Then `systemctl --user daemon-reload && systemctl --user restart sync-guest-display`.

For a one-off run:

```bash
SYNC_GUEST_OUTPUT=Virtual-1 sync-guest-display --once
```

## Troubleshooting

**Check what the guest sees**

```bash
ls /sys/class/drm/
head -n1 /sys/class/drm/card1-Virtual-1/modes
hyprctl monitors all -j | jq '.[] | {name, width, height, availableModes}'
```

The first line of `modes` is the preferred mode and should change when you
resize the VM window.

**The service is running but nothing happens**

- Confirm the DRM uevent fires: `udevadm monitor --udev --subsystem-match=drm`
  while resizing the window.
- Check that the connector name matches a Hyprland output (`hyprctl monitors all`).
- Check the log: `journalctl --user -u sync-guest-display -f`.

**Wrong output selected**

Set `SYNC_GUEST_OUTPUT` to the exact name from `hyprctl monitors all`.

**Older Hyprland versions**

The script automatically falls back to `hyprctl keyword monitor` when
`hyprctl eval` is unavailable. No extra configuration is needed.

## Uninstall

```bash
./uninstall.sh
```

or manually:

```bash
systemctl --user disable --now sync-guest-display
rm ~/.local/bin/sync-guest-display ~/.config/systemd/user/sync-guest-display.service
systemctl --user daemon-reload
```

## Tested with

- Arch Linux / Omarchy guest
- QEMU/KVM with virtio-gpu (`Virtual-1`)
- Hyprland 0.56

## Credits

- [m1st0/wayland_guest_resize](https://github.com/m1st0/wayland_guest_resize) —
  the original udev + `hl.monitor` approach this project is based on.

## License

Apache-2.0. See [LICENSE](LICENSE).
