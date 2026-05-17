---
name: carmaker-ros2-bridge-skill
description: Use when migrating, validating, documenting, or operating the CarMaker 15.1 ROS2 bridge; triggers include ROS2Bridge.cpp, CarMaker 14.1.1 to 15.1 bridge migration, /chcnav/devpvt, /perception/curb_boundaries, /control/control_cmd, msg_interfaces, autoware_control_msgs, AMENT_PREFIX_PATH, LD_LIBRARY_PATH, RUNPATH, and CarMaker.linux64 bridge validation.
---

# CarMaker ROS2 Bridge Skill

## Core principle

Prove the runtime first: the executable must report `linux64-15.1`, shared libraries must resolve, and live ROS2 traffic must be observed. A `linux64-14.1.1/install` RUNPATH can be valid when it only supplies ROS2 message libraries.

## Verified local baseline

- Project: `/home/cqx/CM_Projects/cm151_gpu_demo`
- Executable: `/home/cqx/CM_Projects/cm151_gpu_demo/src/CarMaker.linux64`
- Bridge files: `src/ROS2Bridge.cpp`, `src/ROS2Bridge.h`, `src/User.cpp`, `src/Makefile`
- ROS2 distro: Humble
- Message prefix: `/opt/ipg/carmaker/linux64-14.1.1/install`
- Optional launcher: `/home/cqx/CM_Projects/cm151_gpu_demo/start_carmaker15_gpu_todesk.sh`
- Probe binary: `/tmp/carmaker_ros2_probe`

## Topic contract

| Direction | Topic | Type |
| --- | --- | --- |
| CarMaker -> ROS2 | `/chcnav/devpvt` | `msg_interfaces/msg/Hcinspvatzcb` |
| CarMaker -> ROS2 | `/perception/curb_boundaries` | `msg_interfaces/msg/CurbBoundaries` |
| CarMaker -> ROS2 | `/perception/curb_diagnostics` | `msg_interfaces/msg/CurbDiagnostics` |
| CarMaker -> ROS2 | `/control/runtime_log_stop` | `nav_msgs/msg/Odometry` |
| ROS2 -> CarMaker | `/control/control_cmd` | `autoware_control_msgs/msg/Control` |

## Standard validation workflow

1. Check version: `./src/CarMaker.linux64 -help | head -5` must show `linux64-15.1`.
2. Check dependencies: `ldd ./src/CarMaker.linux64 | rg "not found"` must produce no output.
3. Check RUNPATH: it should include `/opt/ros/humble/lib`, `autoware_control_msgs/lib`, and `msg_interfaces/lib`.
4. Export ROS2 env (`ROS_DISTRO=humble`, `RMW_IMPLEMENTATION=rmw_fastrtps_cpp`, `AMENT_PREFIX_PATH`, `COLCON_PREFIX_PATH`, `LD_LIBRARY_PATH`).
5. Run the 20s CLI TestRun and confirm `ROS2 bridge initialized for CarMaker 15.1`.
6. Run `/tmp/carmaker_ros2_probe` during simulation; success requires `chc_count > 0` and `curb_count > 0`.
7. Confirm CarMaker logs show `ROS2 control: target=... steer_tire=...`.

Use `scripts/check_carmaker_ros2_bridge.sh` for read-only checks. Use `--run-smoke` only when it is acceptable to launch a short CarMaker CLI simulation.

## Success indicators

- `APPLICATION ... (linux64-15.1)`.
- No `ldd` missing libraries.
- Bridge initialization logs for `/chcnav/devpvt` and `/perception/curb_boundaries`.
- Probe output like `chc_count=308 curb_count=303 ...`.
- Control logs change vehicle throttle/brake/steer state.

`Vehicle leaves road` after a fixed steering command is expected in the probe scenario; it indicates control affected vehicle motion, not that the bridge failed.

## References and tools

- Load `references/carmaker15_ros2_bridge.md` for exact commands, expected logs, troubleshooting notes, and Apollo/Autoware integration caveats.
- Run `scripts/check_carmaker_ros2_bridge.sh` for local structural validation.
