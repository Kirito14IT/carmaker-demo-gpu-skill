# CarMaker GPU Demo Skill and ToDesk/NVIDIA Robust Setup Guide

English · [中文文档](README_zh-CN.md)

This repository packages a Codex skill, scripts, and practical notes for running IPG CarMaker 15.x GPU Sensor demos on Ubuntu remote-desktop environments, especially ToDesk/GNOME sessions backed by NVIDIA GPUs.

One-line purpose: this is a startup, troubleshooting, and fix manual plus script package for reliably running CarMaker 15.1 GPU Sensor demos on Ubuntu + ToDesk + RTX 4090.

一句话：这个 skill 是“CarMaker 15.1 在 Ubuntu + ToDesk + RTX 4090 上稳定运行 GPU Sensor demo 的启动、排障和修复手册 + 脚本包”。

The current robust setup has been validated with:

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

## What this solves

The typical failure is:

```text
GPU-Sensors 128: Error: Timeout during startup.
```

In the documented environment, the timeout was not caused by missing CarMaker TestRun parameters. It was a MovieNX/GPUSensor startup boundary issue:

- ToDesk's default OpenGL renderer was Mesa llvmpipe.
- NVIDIA PRIME offload could expose the RTX 4090 correctly.
- NVIDIA driver 580.x made MovieNX `-listdevices` crash.
- NVIDIA driver 565.77 fixed GPU enumeration.
- MovieNX GPUSensor could still crash early with `SIGSEGV` or `double free`.
- The robust wrapper reduces startup concurrency and retries early MovieNX crashes.

## Repository contents

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

## Quick start

From the CarMaker installation workspace:

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

Then open a GPU Sensor TestRun and click `Start`.

Success indicators:

- CarMaker Office shows `Status: Running`, or returns to `Idle` after completion with nonzero time/distance.
- `/tmp/movienx_gpu_todesk_wrapper.log` contains `GPUSensor Server running`, `STATUS-started`, and `APO: Successfully connected`.

## Robust wrapper highlights

The wrapper keeps logging enabled by default and can be tuned through environment variables:

```bash
CM_MOVIENX_LOG=/tmp/custom_movienx.log ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_LOG=off ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_RETRIES=10 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=0-3 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=none ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CLEAN_CACHE=0 ./start_carmaker15_gpu_todesk.sh
```

Default behavior:

- NVIDIA PRIME offload environment is exported.
- MovieNX GPUSensor is launched with `taskset -c 0`.
- GPU configuration uses `-headless -renderapi vulkan -device 0 -noasyncstreaming`.
- Early crashes with exit `134`/`139` are retried up to 6 times.

Live troubleshooting:

```bash
tail -f /tmp/movienx_gpu_todesk_wrapper.log
```

## Environment check

Run the bundled read-only check script:

```bash
carmaker-demo-gpu-skill/scripts/check_carmaker_gpu_env.sh
```

The script checks:

- `nvidia-smi`
- default `glxinfo -B`
- NVIDIA PRIME offload `glxinfo -B`
- `MovieNX -listdevices`
- CarMaker project GPU configuration
- optional MovieNX wrapper log tail

## More GPU demos to test

Recommended sequence:

1. `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`
2. `Examples/BasicFunctions/Sensors/LidarRSI_Countryside`
3. `Examples/BasicFunctions/Sensors/MultiRSI`
4. `Examples/BasicFunctions/Sensors/USonicRSI_Parking`
5. `Examples/BasicFunctions/Sensors/USonicRSI_ConfigurableFrame`
6. `Examples/BasicFunctions/Sensors/USonicRSI_ComparisonDynamicRayPattern`
7. `Examples/BasicFunctions/MovieNX/WeatherRain_SensorCamera_NardoHandlingTrack`

## Install the Codex skill manually

Copy the skill folder into your Codex skills directory:

```bash
mkdir -p "$HOME/.codex/skills"
cp -a carmaker-demo-gpu-skill "$HOME/.codex/skills/"
```

Or use the packaged skill from `dist/carmaker-demo-gpu-skill.skill` if your Codex setup supports packaged skill installation.

## Notes

- Do not commit credentials, `.env` files, logs, or core dumps.
- Do not assume a non-GPU CarMaker sensor demo proves MovieNX GPUSensor readiness.
- Avoid temporary Xorg experiments on active ToDesk machines unless you accept the risk of disconnecting the remote desktop session.

## License

MIT License. See [LICENSE](LICENSE).
