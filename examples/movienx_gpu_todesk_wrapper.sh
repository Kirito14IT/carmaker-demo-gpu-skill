#!/usr/bin/env bash
set -euo pipefail

log="/tmp/movienx_gpu_todesk_wrapper.log"

{
  echo "===== $(date '+%F %T') ====="
  echo "cwd=$(pwd)"
  echo "args:"
  printf '  [%q]\n' "$@"
  echo "env-before:"
  env | sort | rg '^(DISPLAY|XDG_RUNTIME_DIR|__NV|__GLX|__VK|VK_|CUDA|LD_|LIBGL|MESA)' || true
} >>"$log" 2>&1

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

{
  echo "env-after:"
  env | sort | rg '^(DISPLAY|XDG_RUNTIME_DIR|__NV|__GLX|__VK|VK_|CUDA|LD_|LIBGL|MESA)' || true
  echo "exec: /opt/ipg/movienx/linux64-15.1/bin/MovieNX"
} >>"$log" 2>&1

exec /opt/ipg/movienx/linux64-15.1/bin/MovieNX "$@" >>"$log" 2>&1
