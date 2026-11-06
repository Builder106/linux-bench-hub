#!/usr/bin/env bash
# Run inside a distro container after installing the matrix's package list.
# The caller mounts/copies this directory and supplies an output directory.
set -euo pipefail

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pts_source=$(mktemp -d /tmp/lbh-pts.XXXXXXXX)
trap 'rm -rf -- "$pts_source"' EXIT

# PTS 10.8.4, pinned to the upstream release commit rather than moving master.
pts_revision=f0365737ae42c2a4ae80c28491a8c0ac22a10f3c
git -C "$pts_source" init
git -C "$pts_source" remote add origin https://github.com/phoronix-test-suite/phoronix-test-suite.git
git -C "$pts_source" fetch --depth 1 origin "$pts_revision"
git -C "$pts_source" checkout --detach FETCH_HEAD
(cd "$pts_source" && ./install-sh /opt/pts)
ln -sf /opt/pts/bin/phoronix-test-suite /usr/local/bin/phoronix-test-suite
phoronix-test-suite version

bash "$scripts_dir/run-workloads.sh" "${1:-/output}"
