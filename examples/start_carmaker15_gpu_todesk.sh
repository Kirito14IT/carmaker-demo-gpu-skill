#!/usr/bin/env bash
set -euo pipefail

fail_if_carmaker_running() {
  local existing
  existing="$(ps -u "$(id -u)" -o pid=,args= | rg '/opt/ipg/(carmaker|movienx)/linux64-15\.1' || true)"

  if [[ -n "$existing" ]]; then
    cat >&2 <<EOF
Existing CarMaker/MovieNX 15.1 process found. Close CarMaker Office first.

$existing

If the GUI is already closed but these processes remain, terminate them before
starting a new GPU demo session.
EOF
    exit 2
  fi
}

backup_movienx_cache() {
  [[ "${CM_MOVIENX_CLEAN_CACHE:-1}" == "0" ]] && return 0

  local base="$HOME/.cache/MovieNX"
  [[ -d "$base" ]] || return 0

  local stamp moved
  stamp="$(date +%Y%m%d-%H%M%S)"
  moved=0

  for dir in "$base/cache_151" "$base/cache_151-128" "$base/cache_151-129"; do
    if [[ -e "$dir" ]]; then
      mv "$dir" "$dir.bak.$stamp"
      echo "Moved MovieNX cache: $dir -> $dir.bak.$stamp"
      moved=1
    fi
  done

  if [[ "$moved" == "1" ]]; then
    echo "MovieNX cache was backed up to avoid stale/corrupt Vulkan engine state."
  fi
}

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

fail_if_carmaker_running
backup_movienx_cache

exec /opt/ipg/bin/CM_Office-15.1 "$@"
