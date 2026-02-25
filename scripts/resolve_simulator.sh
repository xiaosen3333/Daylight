#!/usr/bin/env bash
set -euo pipefail

project_path="${1:?project path is required}"
scheme_name="${2:?scheme name is required}"
preferred_device="${3:-iPhone 16}"

if ! destinations="$(xcodebuild -project "${project_path}" -scheme "${scheme_name}" -showdestinations 2>&1)"; then
  echo "${destinations}" >&2
  exit 1
fi

extract_id() {
  local name_pattern="$1"
  echo "${destinations}" | awk -v target="${name_pattern}" '
    index($0, "platform:iOS Simulator") && index($0, "name:" target) {
      if (match($0, /id:[^,}]+/)) {
        id = substr($0, RSTART + 3, RLENGTH - 3)
        gsub(/^[ \t]+|[ \t]+$/, "", id)
        print id
        exit
      }
    }
  '
}

simulator_id="$(extract_id "${preferred_device}")"
if [[ -z "${simulator_id}" ]]; then
  simulator_id="$(extract_id "iPhone")"
fi
if [[ -z "${simulator_id}" ]]; then
  simulator_id="$(echo "${destinations}" | awk '
    index($0, "platform:iOS Simulator") {
      if (match($0, /id:[^,}]+/)) {
        id = substr($0, RSTART + 3, RLENGTH - 3)
        gsub(/^[ \t]+|[ \t]+$/, "", id)
        print id
        exit
      }
    }
  ')"
fi

if [[ -z "${simulator_id}" ]]; then
  echo "No iOS simulator destination found for scheme '${scheme_name}'." >&2
  exit 1
fi

echo "${simulator_id}"
