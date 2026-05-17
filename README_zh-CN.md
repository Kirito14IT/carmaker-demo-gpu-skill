# CarMaker Skills

[English](README.md) · 中文文档

本仓库是面向 Ubuntu 上 IPG CarMaker 15.x 工作流的 Codex skill 集合，目前包含两个聚焦 skill：

| Skill | 适用场景 |
| --- | --- |
| `carmaker-demo-gpu-skill` | 在 ToDesk/GNOME + NVIDIA PRIME offload 环境中启动、诊断和修复 CarMaker 15.x GPU Sensor demo。 |
| `carmaker-ros2-bridge-skill` | 迁移、验证或运行 CarMaker 15.1 ROS2 bridge，用于发布车辆/定位/路沿数据并接收 Autoware 风格控制命令。 |

## 仓库结构

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

## Skill：`carmaker-demo-gpu-skill`

用途：作为 CarMaker 15.1 在 Ubuntu + ToDesk + NVIDIA GPU 上稳定运行 GPU Sensor demo 的启动、排障和修复手册 + 脚本包。

已验证 TestRun：

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

该 skill 重点处理的典型错误：

```text
GPU-Sensors 128: Error: Timeout during startup.
```

快速启动：

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

只读检查：

```bash
carmaker-demo-gpu-skill/scripts/check_carmaker_gpu_env.sh
```

成功标志：

- CarMaker Office 显示 `Status: Running`，或运行完成后 Time/Distance 非 0。
- `/tmp/movienx_gpu_todesk_wrapper.log` 包含 `GPUSensor Server running`、`STATUS-started`、`APO: Successfully connected`。

## Skill：`carmaker-ros2-bridge-skill`

用途：记录 `/home/cqx/CM_Projects/cm151_gpu_demo` 中 CarMaker 15.1 ROS2 bridge 的迁移、验证和运行方法。

已验证 bridge topic 契约：

| 方向 | Topic | 类型 |
| --- | --- | --- |
| CarMaker -> ROS2 | `/chcnav/devpvt` | `msg_interfaces/msg/Hcinspvatzcb` |
| CarMaker -> ROS2 | `/perception/curb_boundaries` | `msg_interfaces/msg/CurbBoundaries` |
| CarMaker -> ROS2 | `/perception/curb_diagnostics` | `msg_interfaces/msg/CurbDiagnostics` |
| CarMaker -> ROS2 | `/control/runtime_log_stop` | `nav_msgs/msg/Odometry` |
| ROS2 -> CarMaker | `/control/control_cmd` | `autoware_control_msgs/msg/Control` |

只读结构检查：

```bash
carmaker-ros2-bridge-skill/scripts/check_carmaker_ros2_bridge.sh
```

可选 20s CLI 冒烟测试：

```bash
carmaker-ros2-bridge-skill/scripts/check_carmaker_ros2_bridge.sh --run-smoke
```

手动验收证据：

```bash
cd /home/cqx/CM_Projects/cm151_gpu_demo
"./src/CarMaker.linux64" -help | head -5
ldd "./src/CarMaker.linux64" | rg "not found"
readelf -d "./src/CarMaker.linux64" | rg "RUNPATH|RPATH"
```

关键成功标志：

- `APPLICATION ... (linux64-15.1)`。
- `ldd` 没有 `not found` 输出。
- CarMaker 日志出现 `ROS2 bridge initialized for CarMaker 15.1`。
- `/tmp/carmaker_ros2_probe` 输出 `chc_count > 0` 且 `curb_count > 0`。
- CarMaker 日志出现 `ROS2 control: target=... steer_tire=...`。

固定 probe 控制命令导致的 `Vehicle leaves road` 不是 bridge 失败；它说明控制命令已经影响车辆运动。

## 手动安装 skill

将一个或两个 skill 目录复制到 Codex skills 目录：

```bash
mkdir -p "$HOME/.codex/skills"
cp -a carmaker-demo-gpu-skill "$HOME/.codex/skills/"
cp -a carmaker-ros2-bridge-skill "$HOME/.codex/skills/"
```

如果 Codex 环境支持 packaged skill，也可以使用：

```text
dist/carmaker-demo-gpu-skill.skill
dist/carmaker-ros2-bridge-skill.skill
```

## 维护者验证

运行 skill 结构检查：

```bash
python3 "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" carmaker-demo-gpu-skill
python3 "$HOME/.codex/skills/.system/skill-creator/scripts/quick_validate.py" carmaker-ros2-bridge-skill
```

检查打包内容：

```bash
unzip -l dist/carmaker-demo-gpu-skill.skill
unzip -l dist/carmaker-ros2-bridge-skill.skill
```

## 注意事项

- 不要提交凭据、`.env` 文件、日志、core dump、私有 license 或本机密钥。
- 非 GPU 的 CarMaker demo 能运行，不代表 MovieNX GPUSensor 已经可用。
- ROS2 bridge 不代表 Apollo 可直接连接；Apollo/Cyber RT 需要适配层。
- 项目运行日志保留在本地项目目录或 `/tmp`，不要放入本仓库。

## License

MIT License. See [LICENSE](LICENSE).
