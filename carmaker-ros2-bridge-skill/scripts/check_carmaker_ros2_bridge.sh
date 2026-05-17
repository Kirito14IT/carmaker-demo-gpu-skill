#!/usr/bin/env bash
set -euo pipefail

project_dir="${CARMAKER_PROJECT_DIR:-/home/cqx/CM_Projects/cm151_gpu_demo}"
bridge_prefix="${BRIDGE_PREFIX:-/opt/ipg/carmaker/linux64-14.1.1/install}"
run_smoke=0
failures=0

usage() {
  cat <<'USAGE'
Usage: check_carmaker_ros2_bridge.sh [--project PATH] [--run-smoke]

Read-only checks for the CarMaker 15.1 ROS2 bridge migration.

Options:
  --project PATH   CarMaker project path. Default: /home/cqx/CM_Projects/cm151_gpu_demo
  --run-smoke      Launch a 20s CLI TestRun and check bridge logs.
  -h, --help       Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      project_dir="${2:?missing value for --project}"
      shift 2
      ;;
    --run-smoke)
      run_smoke=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

exe="${project_dir}/src/CarMaker.linux64"
bridge_cpp="${project_dir}/src/ROS2Bridge.cpp"
bridge_h="${project_dir}/src/ROS2Bridge.h"
user_cpp="${project_dir}/src/User.cpp"
makefile="${project_dir}/src/Makefile"
launcher="${project_dir}/start_carmaker15_gpu_todesk.sh"

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  failures=$((failures + 1))
}

require_rg() {
  if ! command -v rg >/dev/null 2>&1; then
    echo "rg is required for this check script." >&2
    exit 2
  fi
}

check_file() {
  if [ -f "$1" ]; then
    pass "$2"
  else
    fail "$2 missing: $1"
  fi
}

check_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if [ -f "$file" ] && rg -q "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

require_rg

section "Project"
printf 'project=%s\n' "$project_dir"
printf 'bridge_prefix=%s\n' "$bridge_prefix"

section "Files"
if [ -x "$exe" ]; then
  pass "CarMaker executable exists and is executable"
else
  fail "CarMaker executable missing or not executable: $exe"
fi
check_file "$bridge_cpp" "ROS2Bridge.cpp exists"
check_file "$bridge_h" "ROS2Bridge.h exists"
check_file "$user_cpp" "User.cpp exists"
check_file "$makefile" "Makefile exists"

section "Version"
if [ -x "$exe" ]; then
  help_out="$("$exe" -help 2>&1 | sed -n '1,5p')"
  printf '%s\n' "$help_out"
  if printf '%s\n' "$help_out" | rg -q 'linux64-15\.1'; then
    pass "Executable reports linux64-15.1"
  else
    fail "Executable does not report linux64-15.1"
  fi
fi

section "Shared libraries"
if [ -x "$exe" ]; then
  missing="$(ldd "$exe" 2>&1 | rg 'not found' || true)"
  if [ -z "$missing" ]; then
    pass "ldd reports no missing libraries"
  else
    printf '%s\n' "$missing"
    fail "ldd reports missing libraries"
  fi

  runpath="$(readelf -d "$exe" 2>/dev/null | rg 'RUNPATH|RPATH' || true)"
  printf '%s\n' "${runpath:-<no RUNPATH/RPATH>}"
  if printf '%s\n' "$runpath" | rg -q '/opt/ros/humble/lib'; then
    pass "RUNPATH includes /opt/ros/humble/lib"
  else
    fail "RUNPATH missing /opt/ros/humble/lib"
  fi
  if printf '%s\n' "$runpath" | rg -q 'autoware_control_msgs/lib'; then
    pass "RUNPATH includes autoware_control_msgs/lib"
  else
    fail "RUNPATH missing autoware_control_msgs/lib"
  fi
  if printf '%s\n' "$runpath" | rg -q 'msg_interfaces/lib'; then
    pass "RUNPATH includes msg_interfaces/lib"
  else
    fail "RUNPATH missing msg_interfaces/lib"
  fi
fi

section "Bridge source contract"
check_pattern "$bridge_cpp" '/chcnav/devpvt' "publishes /chcnav/devpvt"
check_pattern "$bridge_cpp" '/perception/curb_boundaries' "publishes /perception/curb_boundaries"
check_pattern "$bridge_cpp" '/perception/curb_diagnostics' "publishes /perception/curb_diagnostics"
check_pattern "$bridge_cpp" '/control/control_cmd' "subscribes /control/control_cmd"
check_pattern "$bridge_cpp" '/control/runtime_log_stop' "publishes /control/runtime_log_stop"
check_pattern "$user_cpp" 'ROS2 bridge initialized for CarMaker 15\.1' "User.cpp logs CarMaker 15.1 bridge init"
check_pattern "$makefile" 'ROS2Bridge\.o' "Makefile builds ROS2Bridge.o"
check_pattern "$makefile" 'autoware_control_msgs' "Makefile links autoware_control_msgs"
check_pattern "$makefile" 'msg_interfaces' "Makefile links msg_interfaces"

section "Launcher"
if [ -f "$launcher" ]; then
  pass "Project launcher exists"
  check_pattern "$launcher" 'AMENT_PREFIX_PATH' "launcher exports AMENT_PREFIX_PATH"
  check_pattern "$launcher" 'LD_LIBRARY_PATH' "launcher exports LD_LIBRARY_PATH"
else
  printf '[WARN] optional launcher not found: %s\n' "$launcher"
fi

if [ "$run_smoke" -eq 1 ]; then
  section "20s CLI smoke run"
  smoke_log="$(mktemp /tmp/carmaker_ros2_bridge_smoke.XXXXXX.log)"
  printf 'log=%s\n' "$smoke_log"

  export ROS_DISTRO=humble
  export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
  export AMENT_PREFIX_PATH="/opt/ros/humble:${bridge_prefix}"
  export COLCON_PREFIX_PATH="/opt/ros/humble:${bridge_prefix}"
  export LD_LIBRARY_PATH="/opt/ros/humble/lib:${bridge_prefix}/autoware_control_msgs/lib:${bridge_prefix}/msg_interfaces/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

  if timeout 40s "$exe" \
      -screen \
      -projectdir "$project_dir" \
      -taccel 1 \
      -tstop 20 \
      "Examples/VehicleDynamics/Handling/Slalom18m" >"$smoke_log" 2>&1; then
    pass "CLI TestRun exited successfully"
  else
    fail "CLI TestRun failed; inspect $smoke_log"
  fi

  if rg -q 'ROS2 bridge initialized for CarMaker 15\.1' "$smoke_log"; then
    pass "smoke log contains CarMaker 15.1 bridge init"
  else
    fail "smoke log missing CarMaker 15.1 bridge init"
  fi

  if rg -q 'Publishing: /chcnav/devpvt' "$smoke_log" && rg -q 'Publishing: /perception/curb_boundaries' "$smoke_log"; then
    pass "smoke log contains bridge publisher announcements"
  else
    fail "smoke log missing bridge publisher announcements"
  fi
fi

section "Result"
if [ "$failures" -eq 0 ]; then
  echo "PASS: CarMaker ROS2 bridge structural checks passed."
  exit 0
fi

echo "FAIL: $failures check(s) failed."
exit 1
