# CarMaker GPU Demo Skill 与 ToDesk/NVIDIA 启动指南

[English](README.md) · 中文文档

本仓库打包了一个 Codex skill，以及在 Ubuntu + ToDesk + NVIDIA 环境下运行 IPG CarMaker 15.x GPU Sensor demo 的启动和排障资料。

该方案来自一次已验证成功的修复，目标 demo 是：

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
```

## 解决的问题

典型报错：

```text
GPU-Sensors 128: Error: Timeout during startup.
```

在已记录的环境中，这不是因为 TestRun 参数没配，而是 MovieNX/GPUSensor 启动边界问题：

- ToDesk 默认 OpenGL 是 Mesa llvmpipe。
- NVIDIA PRIME offload 可以正确暴露 RTX 4090。
- NVIDIA 580.x 驱动下 `MovieNX -listdevices` 会崩溃。
- 使用 NVIDIA 565.77，并通过项目级 MovieNX wrapper 启动 GPUSensor 后，demo 可以正常运行。

## 仓库内容

```text
carmaker-demo-gpu-skill/
  SKILL.md
  references/carmaker15_todesk_gpu.md
  scripts/check_carmaker_gpu_env.sh
docs/
  CarMaker15_ToDesk_GPU_Demo_启动与修复记录.md
examples/
  start_carmaker15_gpu_todesk.sh
  movienx_gpu_todesk_wrapper.sh
  GPUConfiguration_ToDeskNVIDIA
dist/
  carmaker-demo-gpu-skill.skill
```

## 快速启动

在 CarMaker 安装工作目录执行：

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

然后在 CarMaker Office 中打开：

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
```

点击 `Start`。

成功标志：

- CarMaker Office 显示 `Status: Running`。
- 仿真时间和距离持续增长。
- `/tmp/movienx_gpu_todesk_wrapper.log` 包含 `GPUSensor Server running`、`STATUS-started`、`APO: Successfully connected`。

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

如果当前已有 CarMaker GPU demo 对应的 MovieNX 进程在运行，脚本会默认跳过 `-listdevices`，避免干扰正在运行的 GPUSensor 会话。

## 手动安装 Codex skill

将 skill 目录复制到 Codex skills 目录：

```bash
mkdir -p "$HOME/.codex/skills"
cp -a carmaker-demo-gpu-skill "$HOME/.codex/skills/"
```

如果你的 Codex 环境支持 packaged skill，也可以使用 `dist/carmaker-demo-gpu-skill.skill`。

## 注意事项

- 不要提交凭据、`.env` 文件、日志或 core dump。
- 非 GPU 的 CarMaker demo 能运行，不代表 MovieNX GPUSensor 已经可用。
- 不建议在正在使用 ToDesk 的机器上随意做临时 Xorg 实验，可能断开远程桌面。

## License

MIT License. See [LICENSE](LICENSE).
