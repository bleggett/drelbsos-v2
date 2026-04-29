#!/bin/bash

set -ouex pipefail

echo "::group::Executing setup_repos"
trap 'echo "::endgroup::"' EXIT

dnf5 -y install dnf5-plugins && \
for copr in \
    ublue-os/staging \
    ublue-os/akmods \
    bazzite-org/LatencyFleX \
    bazzite-org/rom-properties \
    bazzite-org/webapp-manager \
    bazzite-org/vk_hdr_layer \
    hhd-dev/hhd \
    che/nerd-fonts \
    hikariknight/looking-glass-kvmfr \
    rok/cdemu \
    rodoma92/rmlint \
    drelbszoomer/drelbsos-copr \
    erikreider/SwayNotificationCenter \
    ilyaz/LACT; \
do \
    echo "Enabling copr: $copr"; \
    dnf5 -y copr enable $copr; \
    dnf5 -y config-manager setopt copr:copr.fedorainfracloud.org:${copr////:}.priority=98 ;\
done && unset -v copr && \
dnf5 config-manager addrepo --from-repofile="https://negativo17.org/repos/fedora-multimedia.repo" && \
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release{,-extras} && \
dnf5 -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/fedora-multimedia.repo && \
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-rar.repo && \
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-steam.repo && \
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-nvidia.repo && \
dnf5 -y config-manager setopt "*akmods*".priority=2 && \
dnf5 -y config-manager setopt "*terra*".priority=3 "*terra*".exclude="nerd-fonts" && \
dnf5 -y config-manager setopt "*fedora-multimedia*".priority=10 && \
dnf5 -y config-manager setopt "*rpmfusion*".priority=20
