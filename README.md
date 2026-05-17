# CarMaker Skills

English · [中文文档](README_zh-CN.md)

This repository is a Codex skill collection for IPG CarMaker 15.x work on Ubuntu. It currently contains two focused skills:

| Skill | Use when |
| --- | --- |
| `carmaker-demo-gpu-skill` | Running or troubleshooting CarMaker 15.x GPU Sensor demos under ToDesk/GNOME + NVIDIA PRIME offload. |
| `carmaker-ros2-bridge-skill` | Migrating, validating, or operating the CarMaker 15.1 ROS2 bridge that publishes vehicle/localization/curb data and accepts Autoware-style control commands. |

## Repository layout

```text
carmaker-demo-gpu-skill/
  SKILL.md
  references/carmaker15_todesk_gpu.md
  scripts/check_carmaker_gpu_env.sh
carmaker-ros2-bridge-skill/
  SKILL.md
  references/carmaker15_ros2_bridge.md
  scripts/check_carmaker_ros2_bridge.sh
docs/
  CarMaker15_ToDesk_GPU_Demo_启动与修复记录.md
  CarMaker15_ROS2Bridge_验证与使用说明.md
  carmaker15_todesk_gpu_robust.md
examples/
  GPUConfiguration_ToDeskNVIDIA_Robust
  movienx_gpu_todesk_wrapper.sh
  start_carmaker15_gpu_todesk.sh
  carmaker_ros2_probe.cpp
dist/
  carmaker-demo-gpu-skill.skill
  carmaker-ros2-bridge-skill.skill
```

## Skill: `carmaker-demo-gpu-skill`

Purpose: a startup, troubleshooting, and fix manual plus script package for reliably running CarMaker 15.1 GPU Sensor demos on Ubuntu + ToDesk + NVIDIA GPU.

Validated TestRuns:

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

Typical failure handled by the skill:

```text
GPU-Sensors 128: Error: Timeout during startup.
```

Quick start from the CarMaker installation workspace:

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

Read-only check:

```bash
carmaker-demo-gpu-skill/scripts/check_carmaker_gpu_env.sh
```

Success indicators:

- CarMaker Office shows `Status: Running`, or completes with nonzero time/distance.
- `/tmp/movienx_gpu_todesk_wrapper.log` contains `GPUSensor Server running`, `STATUS-started`, and `APO: Successfully connected`.

## Skill: `carmaker-ros2-bridge-skill`

Purpose: a migration and validation runbook for the CarMaker 15.1 ROS2 bridge in `/home/cqx/CM_Projects/cm151_gpu_demo`.

Verified bridge contract:

| Direction | Topic | Type |
| --- | --- | --- |
| CarMaker -> ROS2 | `/chcnav/devpvt` | `msg_interfaces/msg/Hcinspvatzcb` |
| CarMaker -> ROS2 | `/perception/curb_boundaries` | `msg_interfaces/msg/CurbBoundaries` |
| CarMaker -> ROS2 | `/perception/curb_diagnostics` | `msg_interfaces/msg/CurbDiagnostics` |
| CarMaker -> ROS2 | `/control/runtime_log_stop` | `nav_msgs/msg/Odometry` |
| ROS2 -> CarMaker | `/control/control_cmd` | `autoware_control_msgs/msg/Control` |

Read-only structural check:

```bash
carmaker-ros2-bridge-skill/scripts/check_carmaker_ros2_bridge.sh
```

Optional 20s CLI smoke run:

```bash
carmaker-ros2-bridge-skill/scripts/check_carmaker_ros2_bridge.sh --run-smoke
```

Manual acceptance evidence:

```bash
cd /home/cqx/CM_Projects/cm151_gpu_demo
"./src/CarMaker.linux64" -help | head -5
ldd "./src/CarMaker.linux64" | rg "not found"
readelf -d "./src/CarMaker.linux64" | rg "RUNPATH|RPATH"
```

Expected key indicators:

- `APPLICATION ... (linux64-15.1)`.
- `ldd` has no `not found` output.
- CarMaker logs `ROS2 bridge initialized for CarMaker 15.1`.
- `/tmp/carmaker_ros2_probe` reports `chc_count > 0` and `curb_count > 0`.
- CarMaker logs `ROS2 control: target=... steer_tire=...`.

`Vehicle leaves road` during the fixed probe command is not a bridge failure; it proves the test command affected vehicle motion.

## Manual skill installation

Copy one or both skill folders into your Codex skills directory:

```bash
mkdir -p "$HOME/.codex/skills"
cp -a carmaker-demo-gpu-skill "$HOME/.codex/skills/"
cp -a carmaker-ros2-bridge-skill "$HOME/.codex/skills/"
```

If your Codex setup supports packaged skills, use:

```text
dist/carmaker-demo-gpu-skill.skill
dist/carmaker-ros2-bridge-skill.skill
```

## Validation for maintainers

Run skill structure validation:

```bash
python3 "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" carmaker-demo-gpu-skill
python3 "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" carmaker-ros2-bridge-skill
```

Check packaged contents:

```bash
unzip -l dist/carmaker-demo-gpu-skill.skill
unzip -l dist/carmaker-ros2-bridge-skill.skill
```

## Notes

- Do not commit credentials, `.env` files, logs, core dumps, private licenses, or machine-local secrets.
- A non-GPU CarMaker demo does not prove MovieNX GPUSensor readiness.
- A ROS2 bridge does not make Apollo connect directly; Apollo/Cyber RT requires an adapter layer.
- Keep project-specific runtime logs in local project directories or `/tmp`, not in this repository.

## License

MIT License. See [LICENSE](LICENSE).
