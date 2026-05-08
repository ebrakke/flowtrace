#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d .flowtrace ]]; then
  echo "missing .flowtrace directory" >&2
  exit 1
fi

shopt -s nullglob
traces=(.flowtrace/*.flow.json)
if (( ${#traces[@]} == 0 )); then
  echo "no .flowtrace/*.flow.json files found" >&2
  exit 1
fi

go test ./packages/cli/...

for trace in "${traces[@]}"; do
  echo "validating ${trace}"
  go run ./packages/cli/cmd/flowtrace validate --root . "${trace}"
done

echo "validated ${#traces[@]} FlowTrace artifact(s)"
