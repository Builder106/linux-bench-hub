#!/usr/bin/env bash
# Shared by every distro/architecture. Requires PTS, PHP XML, and build deps.
set -euo pipefail

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:?usage: run-workloads.sh OUTPUT_DIRECTORY}
run_root=$(mktemp -d "${TMPDIR:-/tmp}/lbh-workloads.XXXXXXXX")
trap 'rm -rf -- "$run_root"' EXIT

# PTS uses this root for config, suites, installed tests, and saved results.
# Fresh storage prevents partial or stale results from satisfying validation.
export PTS_USER_PATH_OVERRIDE="$run_root/"
export TEST_RESULTS_NAME=lbh-workloads
export FORCE_TIMES_TO_RUN=3
mkdir -p "$run_root/test-suites/local/lbh-workloads"
cp "$scripts_dir/pts-batch-config.xml" "$run_root/user-config.xml"
cp "$scripts_dir/workload-suite.xml" "$run_root/test-suites/local/lbh-workloads/suite-definition.xml"

printf 'y\nn\nn\nn\nn\nn\nn\n' | phoronix-test-suite batch-setup
# All options are in the suite; stdin is closed so new prompts cannot hang CI.
timeout 120m phoronix-test-suite batch-benchmark local/lbh-workloads </dev/null

composite="$run_root/test-results/$TEST_RESULTS_NAME/composite.xml"
php "$scripts_dir/validate-workloads.php" "$composite"

# Publish only the validated result, atomically on the destination filesystem.
mkdir -p "$output_dir"
staged=$(mktemp "$output_dir/.composite.XXXXXXXX")
trap 'rm -rf -- "$run_root"; rm -f -- "$staged"' EXIT
cp "$composite" "$staged"
chmod 644 "$staged"
mv -f -- "$staged" "$output_dir/composite.xml"
echo "Saved $output_dir/composite.xml"
