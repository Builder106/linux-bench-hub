#!/usr/bin/env bash
# Shared by every distro/architecture. Requires Ruby, PTS, PHP XML, and build deps.
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
# Non-root PTS defaults can still expand to the real home directory even
# with PTS_USER_PATH_OVERRIDE. Set absolute paths for both execution modes.
mkdir -p "$run_root/installed-tests"
export PTS_TEST_INSTALL_ROOT_PATH="$run_root/installed-tests/"
# shellcheck disable=SC2016 # PHP variables must reach PHP without shell expansion.
php -r '
  $xml = simplexml_load_file($argv[1]);
  $xml->Options->Installation->EnvironmentDirectory = $argv[2] . "/installed-tests/";
  $xml->Options->Testing->ResultsDirectory = $argv[2] . "/test-results/";
  if ($xml->asXML($argv[1]) === false) { exit(1); }
' "$run_root/user-config.xml" "$run_root"

printf 'y\nn\nn\nn\nn\nn\nn\n' | phoronix-test-suite batch-setup
# All options are in the suite; stdin is closed so new prompts cannot hang CI.
ruby "$scripts_dir/../../bin/lbh-telemetry" --json --output "$run_root/telemetry.json" \
  --exec 'timeout 120m phoronix-test-suite batch-benchmark local/lbh-workloads' </dev/null

composite="$run_root/test-results/$TEST_RESULTS_NAME/composite.xml"
php "$scripts_dir/validate-workloads.php" "$composite"

# Publish only the validated result, atomically on the destination filesystem.
mkdir -p "$output_dir"
staged=$(mktemp "$output_dir/.composite.XXXXXXXX")
staged_telemetry=$(mktemp "$output_dir/.telemetry.XXXXXXXX")
trap 'rm -rf -- "$run_root"; rm -f -- "$staged" "$staged_telemetry"' EXIT
cp "$composite" "$staged"
chmod 644 "$staged"
cp "$run_root/telemetry.json" "$staged_telemetry"
chmod 644 "$staged_telemetry"
mv -f -- "$staged_telemetry" "$output_dir/telemetry.json"
mv -f -- "$staged" "$output_dir/composite.xml"
echo "Saved $output_dir/composite.xml"
