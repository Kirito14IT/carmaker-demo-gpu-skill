#!/usr/bin/env bash
set -u

movie_nx="${MOVIENX_BIN:-/opt/ipg/movienx/linux64-15.1/bin/MovieNX}"
timeout_s="${MOVIENX_TIMEOUT:-30}"

section() {
  printf '\n== %s ==\n' "$1"
}

section "nvidia-smi"
nvidia-smi || true

section "default glx"
if command -v glxinfo >/dev/null 2>&1; then
  glxinfo -B | grep -E "OpenGL vendor|OpenGL renderer|Accelerated" || true
else
  echo "glxinfo not found"
fi

section "nvidia offload glx"
if command -v glxinfo >/dev/null 2>&1; then
  __NV_PRIME_RENDER_OFFLOAD=1 \
  __GLX_VENDOR_LIBRARY_NAME=nvidia \
  __VK_LAYER_NV_optimus=NVIDIA_only \
  glxinfo -B | grep -E "OpenGL vendor|OpenGL renderer|Accelerated" || true
else
  echo "glxinfo not found"
fi

section "MovieNX listdevices"
if [ -x "$movie_nx" ]; then
  if pgrep -u "$(id -u)" -f 'MovieNX(.exe)?' >/dev/null 2>&1 && [ "${FORCE_MOVIENX_LISTDEVICES:-0}" != "1" ]; then
    echo "MovieNX is already running; skip -listdevices to avoid disturbing an active GPUSensor session."
    echo "Stop the CarMaker GPU demo first, or rerun with FORCE_MOVIENX_LISTDEVICES=1."
    exit 0
  fi

  DISPLAY="${DISPLAY:-:0}" \
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
  __NV_PRIME_RENDER_OFFLOAD=1 \
  __GLX_VENDOR_LIBRARY_NAME=nvidia \
  __VK_LAYER_NV_optimus=NVIDIA_only \
  VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/nvidia_icd.json}" \
  timeout "$timeout_s" "$movie_nx" -listdevices || true
else
  echo "MovieNX binary not executable: $movie_nx"
fi
