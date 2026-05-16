#!/usr/bin/env bash
set -u

movie_nx="${MOVIENX_BIN:-/opt/ipg/movienx/linux64-15.1/bin/MovieNX}"
timeout_s="${MOVIENX_TIMEOUT:-30}"
project_dir="${CARMAKER_PROJECT_DIR:-/home/cqx/CM_Projects/cm151_gpu_demo}"
wrapper_log="${CM_MOVIENX_LOG:-/tmp/movienx_gpu_todesk_wrapper.log}"

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

section "CarMaker project GPU config"
gui_cfg="$project_dir/Data/Config/GUI"
if [ -f "$gui_cfg" ]; then
  grep -E '^GPUParameters\.FName' "$gui_cfg" || true
else
  echo "GUI config not found: $gui_cfg"
fi

for cfg in "$project_dir"/Data/Config/GPUConfiguration_ToDeskNVIDIA*; do
  [ -f "$cfg" ] || continue
  printf '\n-- %s --\n' "$cfg"
  grep -E 'MovieCmd|headless|renderapi|device 0|noasyncstreaming' "$cfg" || true
done

section "MovieNX wrapper log"
if [ "$wrapper_log" = "off" ] || [ "$wrapper_log" = "0" ] || [ "$wrapper_log" = "none" ]; then
  echo "Wrapper log disabled by CM_MOVIENX_LOG=$wrapper_log"
elif [ -f "$wrapper_log" ]; then
  echo "Log path: $wrapper_log"
  echo "Use this for live troubleshooting:"
  echo "  tail -f \"$wrapper_log\""
  if [ "${SHOW_MOVIENX_LOG_TAIL:-0}" = "1" ]; then
    tail -n "${MOVIENX_LOG_TAIL_LINES:-80}" "$wrapper_log"
  else
    echo "Set SHOW_MOVIENX_LOG_TAIL=1 to print the recent log tail."
  fi
else
  echo "Wrapper log not found yet: $wrapper_log"
fi
