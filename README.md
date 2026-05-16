# CarMaker GPU Demo Skill and ToDesk/NVIDIA Setup Guide

English · [中文文档](README_zh-CN.md)

This repository packages a Codex skill and practical setup notes for running IPG CarMaker 15.x GPU Sensor demos on Ubuntu remote-desktop environments, especially ToDesk sessions backed by NVIDIA GPUs.

It was created from a successful fix for the CarMaker demo:

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
```

## What this solves

The typical failure is:

```text
GPU-Sensors 128: Error: Timeout during startup.
```

In the documented environment, the timeout was caused by the MovieNX/GPUSensor startup boundary rather than missing CarMaker TestRun parameters:

- ToDesk's default OpenGL renderer was Mesa llvmpipe.
- NVIDIA PRIME offload could expose the RTX 4090 correctly.
- MovieNX crashed with NVIDIA driver 580.x during `-listdevices`.
- NVIDIA driver 565.77 plus a project-level MovieNX wrapper made the GPU demo run successfully.

## Repository contents

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

## Quick start

From the CarMaker installation workspace:

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

Then open:

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
```

Click `Start`.

Success indicators:

- CarMaker Office shows `Status: Running`.
- Simulation time and distance increase.
- `/tmp/movienx_gpu_todesk_wrapper.log` contains `GPUSensor Server running`, `STATUS-started`, and `APO: Successfully connected`.

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

If MovieNX is already running for an active CarMaker GPU demo, the script skips `-listdevices` by default to avoid disturbing the active GPUSensor session.

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
