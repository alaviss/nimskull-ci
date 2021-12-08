#!/usr/bin/env bash

# Set safety bash features
set -eu -o pipefail

scriptDir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Grab the containers NodeJS version
containerVer=$(grep -m 1 -F "node_version=" "$scriptDir/Dockerfile" | cut -d'=' -f 2)

echo "Containers version: $containerVer"

# Look for the latest LTS in NodeJS index
latestLts=$(curl -sL https://nodejs.org/dist/index.json | jq -r 'first(.[] | select(.lts != false) | .version | ltrimstr("v"))')

echo "Latest LTS version: $latestLts"

if [[ $latestLts == "$containerVer" ]]; then
  echo "Containers' NodeJS is up-to-date"
else
  echo "Containers' NodeJS is outdated, performing update"
  temporary=$(mktemp "$scriptDir/Dockerfile.tmp.XXXXXXXXXX")
  # Write the update to a temporary
  #
  # This sed script captures everything up to `node_version=`, then change the
  # portion after the `=` to the latest version
  sed 's/\(.*node_version=\).*/\1'"$latestLts"'/' "$scriptDir/Dockerfile" > "$temporary"
  # Show the diff
  diff -u "$scriptDir/Dockerfile" "$temporary" || {
    # Diff returns either 1 or 0 on success, so exit failure otherwise
    if [[ $? -ne 1 && $? -ne 0 ]]; then
      exit "$?"
    fi
  }
  # Then replace the original file
  mv -v "$temporary" "$scriptDir/Dockerfile"

  # Integration with CI by emitting the target version
  if [[ -v GITHUB_ACTIONS ]]; then
    echo "::set-output name=updated-to::$latestLts"
  fi
fi
