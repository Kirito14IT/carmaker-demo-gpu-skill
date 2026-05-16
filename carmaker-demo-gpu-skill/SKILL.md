---
name: carmaker-demo-gpu-skill
description: Diagnose, document, and operate IPG CarMaker 15.x GPU Sensor demos on Ubuntu remote-desktop environments, especially ToDesk/GNOME sessions with NVIDIA PRIME offload. Use when users need to run CarMaker GPU demos such as RadarRSI_Motorway, fix "GPU-Sensors 128 Timeout during startup", verify MovieNX/NVIDIA/Vulkan/CUDA visibility, create ToDesk-safe launch wrappers, or explain the standard startup workflow for CarMaker GPU Sensor demos.
---

# CarMaker GPU Demo Skill

## Core workflow

1. Treat `GPU-Sensors 128 Timeout during startup` as a MovieNX/GPUSensor startup boundary problem until logs prove otherwise.
2. First verify the graphics stack:
   - `nvidia-smi`
   - default `glxinfo -B`
   - NVIDIA offload `glxinfo -B`
   - MovieNX `-listdevices` with NVIDIA offload variables.
3. If MovieNX can list the NVIDIA GPU but CarMaker still times out, inspect whether the project loads a GPU Configuration file and whether GPUSensor starts through the expected MovieNX command.
4. Prefer a project-local wrapper and GPU Configuration over changing global desktop or Xorg settings.
5. Avoid temporary headless Xorg tests on ToDesk machines unless the user explicitly accepts the risk; it previously disconnected the remote desktop session on this host.

## Known-good setup on this machine

- Project: `/home/cqx/CM_Projects/cm151_gpu_demo`
- Launcher: `/home/cqx/Downloads/CarMakerOffice-linux-15.1/start_carmaker15_gpu_todesk.sh`
- MovieNX wrapper: `/home/cqx/Downloads/CarMakerOffice-linux-15.1/scripts/movienx_gpu_todesk_wrapper.sh`
- GPU config: `/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA`
- Wrapper log: `/tmp/movienx_gpu_todesk_wrapper.log`
- Working driver observed: NVIDIA `565.77` on RTX 4090.

## Standard startup

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

Then open `Examples/BasicFunctions/Sensors/RadarRSI_Motorway` and click `Start`.

Success indicators:

- CarMaker Office shows `Status: Running`.
- Simulation time and distance increase.
- `/tmp/movienx_gpu_todesk_wrapper.log` contains `GPUSensor Server running`, `STATUS-started`, and `APO: Successfully connected`.

## References and tools

- Load `references/carmaker15_todesk_gpu.md` for the full incident record, commands, expected outputs, and troubleshooting decision tree.
- Run `scripts/check_carmaker_gpu_env.sh` for a read-only environment check before making changes.
