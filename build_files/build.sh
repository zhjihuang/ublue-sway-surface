#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

# systemctl enable podman.socket

# remove kernel locks
dnf5 versionlock delete kernel{,-core,-modules,-modules-core,-modules-extra,-tools,-tools-lib,-headers,-devel,-devel-matched}

# Add the Surface Linux repo
dnf5 config-manager \
    addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo

# Install the Surface Linux kernel and related packages
dnf5 -y install --allowerasing kernel-surface iptsd libwacom-surface surface-secureboot surface-control

# Remove the default Fedora kernel and related packages
dnf5 -y remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

tee /usr/lib/modules-load.d/surface.conf << EOF
# Only on AMD models
pinctrl_amd

# Surface Book 2
pinctrl_sunrisepoint

# For Surface Laptop 3/Surface Book 3
pinctrl_icelake

# For Surface Laptop 4/Surface Laptop Studio
pinctrl_tigerlake

# For Surface Pro 9/Surface Laptop 5
pinctrl_alderlake

# For Surface Pro 10/Surface Laptop 6
pinctrl_meteorlake

# Only on Intel models
intel_lpss
intel_lpss_pci

# Add modules necessary for Disk Encryption via keyboard
surface_aggregator
surface_aggregator_registry
surface_aggregator_hub
surface_hid_core
8250_dw

# Surface Laptop 3/Surface Book 3 and later
surface_hid
surface_kbd
EOF

KERNEL_SUFFIX="surface"
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//')"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

# Prevent kernel stuff from upgrading again
dnf5 versionlock add kernel{,-core,-modules,-modules-core,-modules-extra,-tools,-tools-lib,-headers,-devel,-devel-matched}

tee /etc/containers/policy.json << EOF
{
  "default": [
    {
      "type": "reject"
    }
  ],
  "transports": {
    "docker": {
      "ghcr.io/zhjihuang": [
        {
          "type": "sigstoreSigned",
          "keyPath": "/etc/pki/containers/ghcr.io-zhjihuang.pub",
          "signedIdentity": {
            "type": "matchRepository"
          }
        }
      ],
      "": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    },
    "docker-daemon": {
      "": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  }
}
EOF

tee /etc/containers/registries.d/ghcr.io-zhjihuang.yaml << EOF
docker:
    ghcr.io/zhjihuang:
        use-sigstore-attachments: true
EOF

GENERAL_PACKAGES=(
    alsa-firmware
    android-udev-rules
    apr
    apr-util
    distrobox
    fdk-aac
    ffmpeg
    ffmpeg-libs
    ffmpegthumbnailer
    flatpak-spawn
    fuse
    fzf
    grub2-tools-extra
    google-noto-sans-balinese-fonts
    google-noto-sans-cjk-fonts
    google-noto-sans-javanese-fonts
    google-noto-sans-sundanese-fonts
    heif-pixbuf-loader
    htop
    intel-vaapi-driver
    just
    libavcodec
    libcamera
    libcamera-tools
    libcamera-gstreamer
    libcamera-ipa
    libfdk-aac
    libheif
    libimobiledevice-utils
    libratbag-ratbagd
    libva-utils
    lshw
    mesa-libxatracker
    net-tools
    nvme-cli
    nvtop
    openrgb-udev-rules
    openssl
    oversteer-udev
    pam-u2f
    pam_yubico
    pamu2fcfg
    pipewire-libs-extra
    pipewire-plugin-libcamera
    powerstat
    smartmontools
    solaar-udev
    squashfs-tools
    symlinks
    tcpdump
    tmux
    traceroute
    usbmuxd
    vim
    wireguard-tools
    wl-clipboard
    xhost
    xorg-x11-xauth
    yubikey-manager
    zstd
)

SWAY_PACKAGES=(
    clipman
    gvfs-mtp
    thunar-volman
    tumbler
)

SURFACE_PACKAGES=(
    iptsd
    libcamera
    libcamera-tools
    libcamera-gstreamer
    libcamera-ipa
    pipewire-plugin-libcamera
)

dnf5 install --assumeyes --skip-unavailable "${GENERAL_PACKAGES[@]} \
                                             ${SWAY_PACKAGES[@]} \
                                             ${SURFACE_PACKAGES[@]}"

dnf5 clean all
