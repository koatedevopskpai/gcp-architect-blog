#!/usr/bin/env bash
# Shared command resolution for the demo shell scripts.
#
# Windows + WSL exposes python.exe / aws.exe, while Linux CI exposes python3 / aws.
# Resolve either, and allow an explicit override via PYTHON_BIN / AWS_BIN.

resolve_python() {
  if [ -n "${PYTHON_BIN:-}" ]; then
    echo "$PYTHON_BIN"
    return 0
  fi
  for candidate in python python3 python.exe; do
    if path="$(command -v "$candidate" 2>/dev/null)"; then
      echo "$path"
      return 0
    fi
  done
  echo "python not found; set PYTHON_BIN to the interpreter path" >&2
  return 1
}

resolve_aws() {
  if [ -n "${AWS_BIN:-}" ]; then
    echo "$AWS_BIN"
    return 0
  fi
  for candidate in aws aws.exe; do
    if path="$(command -v "$candidate" 2>/dev/null)"; then
      echo "$path"
      return 0
    fi
  done
  echo "aws not found; set AWS_BIN to the CLI path" >&2
  return 1
}
