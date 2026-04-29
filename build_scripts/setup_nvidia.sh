#!/usr/bin/bash

set -eoux pipefail

echo "::group::Executing setup_nvidia"
trap 'echo "::endgroup::"' EXIT

RELEASE="$(rpm -E %fedora)"
RELEASE_ARCH="$(rpm -E '%fedora.%_arch')"
AKMODNV_PATH=${AKMODNV_PATH:-/tmp/akmods-rpms}

dnf5 -y copr enable ublue-os/staging && \
dnf5 -y install \
    mesa-dri-drivers.x86_64

# this is only to aid in human understanding of any issues in CI
find "${AKMODNV_PATH}"/

if [[ ! $(command -v dnf5) ]]; then
    echo "Requires dnf5... Exiting"
    exit 1
fi

# disable any remaining rpmfusion repos
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion*.repo

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo

# Install MULTILIB packages from negativo17-multimedia prior to disabling repo

MULTILIB=(
    mesa-dri-drivers.i686
    mesa-filesystem.i686
    mesa-libEGL.i686
    mesa-libGL.i686
    mesa-libgbm.i686
    mesa-va-drivers.i686
    mesa-vulkan-drivers.i686
)

if [[ "$(rpm -E %fedora)" -lt 41 ]]; then
    MULTILIB+=(
        mesa-libglapi.i686
        libvdpau.i686
    )
fi

dnf5 install -y "${MULTILIB[@]}"

dnf5 -y config-manager setopt "fedora-nvidia".enabled=true

# Disable Multimedia
NEGATIVO17_MULT_PREV_ENABLED=N
if [[ -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo ]] && grep -q "enabled=1" /etc/yum.repos.d/negativo17-fedora-multimedia.repo; then
    NEGATIVO17_MULT_PREV_ENABLED=Y
    echo "disabling negativo17-fedora-multimedia to ensure negativo17-fedora-nvidia is used"
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
fi

source "${AKMODNV_PATH}"/kmods/nvidia-vars

ls -lah  "${AKMODNV_PATH}"/kmods/
ls -lah  "${AKMODNV_PATH}"/kmods/nvidia

NOARCH_RELEASE="$(rpm -E '%fedora')"

NVIDIA_BASE_VERSION=${NVIDIA_AKMOD_VERSION%-*}

dnf5 install -y \
    "${AKMODNV_PATH}"/kmods/kmod-nvidia-"${KERNEL_VERSION}"-"${NVIDIA_AKMOD_VERSION}".fc"${RELEASE_ARCH}".rpm \
    nvidia-kmod-common-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE} \
    nvidia-modprobe-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE}

dnf5 install -y \
    libnvidia-fbc-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE} \
    nvidia-driver-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE} \
    nvidia-driver-cuda-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE} \
    nvidia-settings-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE} \
    libnvidia-ml-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${RELEASE}.i686 \
    nvidia-driver-cuda-libs-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${NOARCH_RELEASE}.i686 \
    nvidia-driver-libs-${NVIDIA_BASE_VERSION}-'[0-9]'.fc${NOARCH_RELEASE}.i686 \
    libva-nvidia-driver

## nvidia post-install steps
dnf5 -y config-manager setopt "fedora-nvidia".enabled=false

# Suspend without the systemd services still not working correctly in all cases
sed -i 's/NVreg_UseKernelSuspendNotifiers=1/NVreg_UseKernelSuspendNotifiers=0/' /usr/lib/modprobe.d/nvidia.conf

# we must force driver load to fix black screen on boot for nvidia desktops
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# re-enable negativo17-mutlimedia since we disabled it
if [[ "${NEGATIVO17_MULT_PREV_ENABLED}" = "Y" ]]; then
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
fi

rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
rm -f /usr/share/vulkan/icd.d/lvp_icd.*.json && \
ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
dnf5 -y copr disable ublue-os/staging
