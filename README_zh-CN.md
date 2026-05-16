# CarMaker GPU Demo Skill 与 ToDesk/NVIDIA 稳定启动指南

[English](README.md) · 中文文档

本仓库打包了一个 Codex skill、启动脚本和排障资料，用于在 Ubuntu 远程桌面环境中运行 IPG CarMaker 15.x GPU Sensor demo，尤其是 ToDesk/GNOME + NVIDIA GPU 场景。

一句话：这个 skill 是“CarMaker 15.1 在 Ubuntu + ToDesk + RTX 4090 上稳定运行 GPU Sensor demo 的启动、排障和修复手册 + 脚本包”。

当前 robust 方案已验证通过：

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

## 解决的问题

典型报错：

```text
GPU-Sensors 128: Error: Timeout during startup.
```

在已记录的环境中，这不是 TestRun 参数没配，而是 MovieNX/GPUSensor 启动边界问题：

- ToDesk 默认 OpenGL 是 Mesa llvmpipe。
- NVIDIA PRIME offload 可以正确暴露 RTX 4090。
- NVIDIA 580.x 驱动下 `MovieNX -listdevices` 会崩溃。
- NVIDIA 565.77 可以正常枚举 GPU。
- MovieNX GPUSensor 仍可能在启动早期 `SIGSEGV` 或 `double free`。
- robust wrapper 通过降低启动并发和自动重试早期崩溃来稳定启动。

## 仓库内容

```text
carmaker-demo-gpu-skill/
  SKILL.md
  references/carmaker15_todesk_gpu.md
  scripts/check_carmaker_gpu_env.sh
docs/
  carmaker15_todesk_gpu_robust.md
examples/
  start_carmaker15_gpu_todesk.sh
  movienx_gpu_todesk_wrapper.sh
  GPUConfiguration_ToDeskNVIDIA_Robust
dist/
  carmaker-demo-gpu-skill.skill
```

## 快速启动

在 CarMaker 安装工作目录执行：

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

然后打开 GPU Sensor TestRun，点击 `Start`。

成功标志：

- CarMaker Office 显示 `Status: Running`，或运行完成后回到 `Idle` 且 Time/Distance 非 0。
- `/tmp/movienx_gpu_todesk_wrapper.log` 包含 `GPUSensor Server running`、`STATUS-started`、`APO: Successfully connected`。

## robust wrapper 重点

日志默认开启，并可通过环境变量调整：

```bash
CM_MOVIENX_LOG=/tmp/custom_movienx.log ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_LOG=off ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_RETRIES=10 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=0-3 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=none ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CLEAN_CACHE=0 ./start_carmaker15_gpu_todesk.sh
```

默认行为：

- 导出 NVIDIA PRIME offload 环境变量。
- 使用 `taskset -c 0` 启动 MovieNX GPUSensor。
- GPU 配置使用 `-headless -renderapi vulkan -device 0 -noasyncstreaming`。
- 对退出码 `134`/`139` 的早期崩溃最多重试 6 次。

实时排障：

```bash
tail -f /tmp/movienx_gpu_todesk_wrapper.log
```

## 环境检查

运行只读检查脚本：

```bash
carmaker-demo-gpu-skill/scripts/check_carmaker_gpu_env.sh
```

该脚本检查：

- `nvidia-smi`
- 默认 `glxinfo -B`
- NVIDIA PRIME offload `glxinfo -B`
- `MovieNX -listdevices`
- CarMaker 项目 GPU 配置
- 可选 MovieNX wrapper 日志尾部

## 后续可测试的 GPU demo

建议顺序：

1. `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`
2. `Examples/BasicFunctions/Sensors/LidarRSI_Countryside`
3. `Examples/BasicFunctions/Sensors/MultiRSI`
4. `Examples/BasicFunctions/Sensors/USonicRSI_Parking`
5. `Examples/BasicFunctions/Sensors/USonicRSI_ConfigurableFrame`
6. `Examples/BasicFunctions/Sensors/USonicRSI_ComparisonDynamicRayPattern`
7. `Examples/BasicFunctions/MovieNX/WeatherRain_SensorCamera_NardoHandlingTrack`

## 手动安装 Codex skill

将 skill 目录复制到 Codex skills 目录：

```bash
mkdir -p "$HOME/.codex/skills"
cp -a carmaker-demo-gpu-skill "$HOME/.codex/skills/"
```

如果 Codex 环境支持 packaged skill，也可以使用 `dist/carmaker-demo-gpu-skill.skill`。

## 注意事项

- 不要提交凭据、`.env` 文件、日志或 core dump。
- 非 GPU 的 CarMaker demo 能运行，不代表 MovieNX GPUSensor 已经可用。
- 不建议在正在使用 ToDesk 的机器上做临时 Xorg 实验，可能断开远程桌面。

## License

MIT License. See [LICENSE](LICENSE).
