# syntax=docker/dockerfile:1

# SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
#
# SPDX-License-Identifier: Apache-2.0

FROM debian:forky

RUN <<'EOT' bash -euo pipefail -O nullglob
dependencies=(
  build-essential
  ca-certificates
  cmake
  curl
  git
  libobs-dev
  ninja-build
  pkg-config
  qt6-base-dev
  sudo
  tar
  unzip
  zip
)
apt-get update
apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${dependencies[@]}"
rm -rf /var/lib/apt/lists/*
EOT

ENV VCPKG_ROOT=/usr/local/vcpkg VCPKG_DOWNLOADS=/usr/local/vcpkg-downloads

RUN <<'EOT' bash -euo pipefail -O nullglob
install -d "${VCPKG_DOWNLOADS}"
git clone --filter=blob:none --no-checkout https://github.com/microsoft/vcpkg.git "${VCPKG_ROOT}"
cd "${VCPKG_ROOT}"
git checkout 2025.08.27
"${VCPKG_ROOT}/bootstrap-vcpkg.sh" -disableMetrics
groupadd -g 999 vcpkg
chgrp -R vcpkg "${VCPKG_ROOT}" "${VCPKG_DOWNLOADS}"
chmod -R ug=rwX,o=rX "${VCPKG_ROOT}" "${VCPKG_DOWNLOADS}"
EOT

RUN <<'EOT' bash -euo pipefail -O nullglob
groupadd -g 1000 vscode
useradd -u 1000 -g vscode -m vscode -G vcpkg -s /bin/bash
EOT

COPY --chmod=400 <<'EOF' /etc/sudoers.d/vscode
vscode ALL=(ALL) NOPASSWD: ALL
EOF

CMD ["/bin/bash"]

USER vscode
