#!/usr/bin/env bash
set -euo pipefail

log="${CM_MOVIENX_LOG:-/tmp/movienx_gpu_todesk_wrapper.log}"
if [[ "$log" == "0" || "$log" == "off" || "$log" == "none" ]]; then
  log="/dev/null"
fi
movie_bin="/opt/ipg/movienx/linux64-15.1/bin/MovieNX"
child_pid=""

prepend_local_xcb_cursor_lib() {
  local script_dir root_dir lib_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  root_dir="$(cd -- "$script_dir/.." && pwd)"
  lib_dir="$root_dir/local_deps/libxcb-cursor0/usr/lib/x86_64-linux-gnu"

  if [[ -e "$lib_dir/libxcb-cursor.so.0" ]]; then
    export LD_LIBRARY_PATH="$lib_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
}

has_arg() {
  local needle="$1"
  shift

  local arg
  for arg in "$@"; do
    [[ "$arg" == "$needle" ]] && return 0
  done

  return 1
}

is_gpusensor_mode() {
  local prev=""
  local arg

  for arg in "$@"; do
    if [[ "$prev" == "-mode" && "$arg" == "GPUSensor" ]]; then
      return 0
    fi
    prev="$arg"
  done

  return 1
}

terminate_child() {
  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  exit 143
}

backup_instance_cache() {
  [[ "${CM_MOVIENX_CLEAN_CACHE:-1}" == "0" ]] && return 0

  local instance=""
  local prev=""

  for arg in "$@"; do
    if [[ "$prev" == "-instance" ]]; then
      instance="$arg"
      break
    fi
    prev="$arg"
  done

  [[ -n "$instance" ]] || return 0

  local dir="$HOME/.cache/MovieNX/cache_151-$instance"
  [[ -e "$dir" ]] || return 0

  local target="$dir.bak.$(date +%Y%m%d-%H%M%S)"
  mv "$dir" "$target"
  echo "moved-instance-cache: $dir -> $target"
}

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
prepend_local_xcb_cursor_lib
trap terminate_child TERM INT

{
  backup_instance_cache "$@"
  echo "env-after:"
  env | sort | rg '^(DISPLAY|XDG_RUNTIME_DIR|__NV|__GLX|__VK|VK_|CUDA|LD_|LIBGL|MESA)' || true
  echo "exec: $movie_bin"
} >>"$log" 2>&1

cmd=("$movie_bin" "$@")

if is_gpusensor_mode "$@"; then
  if command -v taskset >/dev/null 2>&1 && [[ "${CM_MOVIENX_CPUSET:-0}" != "none" ]]; then
    cmd=(taskset -c "${CM_MOVIENX_CPUSET:-0}" "${cmd[@]}")
  fi

  retries="${CM_MOVIENX_RETRIES:-6}"
  retry_window="${CM_MOVIENX_RETRY_WINDOW:-20}"

  for ((attempt = 1; attempt <= retries; attempt++)); do
    start_time="$(date +%s)"
    {
      echo "launch-attempt=$attempt/$retries"
      printf 'launch-cmd:'
      printf ' %q' "${cmd[@]}"
      echo
    } >>"$log" 2>&1

    set +e
    "${cmd[@]}" >>"$log" 2>&1 &
    child_pid="$!"
    wait "$child_pid"
    rc="$?"
    child_pid=""
    set -e

    duration="$(( $(date +%s) - start_time ))"
    if (( rc == 0 || (rc != 134 && rc != 139) || duration >= retry_window || attempt == retries )); then
      exit "$rc"
    fi

    {
      echo "early-exit: rc=$rc duration=${duration}s; retrying MovieNX GPUSensor"
    } >>"$log" 2>&1
    sleep 1
    backup_instance_cache "$@" >>"$log" 2>&1 || true
  done
fi

exec "${cmd[@]}" >>"$log" 2>&1
