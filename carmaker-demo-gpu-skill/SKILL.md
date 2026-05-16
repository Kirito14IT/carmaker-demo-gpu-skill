---
name: carmaker-demo-gpu-skill
description: Use when diagnosing, documenting, or operating IPG CarMaker 15.x GPU Sensor demos on Ubuntu remote desktop environments, especially ToDesk/GNOME with NVIDIA PRIME offload; triggers include RadarRSI_Motorway, LidarRSI_Countryside, MovieNX GPUSensor startup, "GPU-Sensors 128 Timeout", SIGSEGV, double free, driver 565/580 issues, wrapper logs, and robust launch configuration.
---

# CarMaker GPU Demo Skill

## Core principle

Treat `GPU-Sensors 128 Timeout during startup` as a MovieNX/GPUSensor boundary failure until logs prove otherwise. Do not assume missing TestRun parameters.

## Current robust setup on this machine

- Project: `/home/cqx/CM_Projects/cm151_gpu_demo`
- Launcher: `/home/cqx/Downloads/CarMakerOffice-linux-15.1/start_carmaker15_gpu_todesk.sh`
- MovieNX wrapper: `/home/cqx/Downloads/CarMakerOffice-linux-15.1/scripts/movienx_gpu_todesk_wrapper.sh`
- Active GPU config: `/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA_Robust`
- GUI config must contain: `GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA_Robust`
- Default wrapper log: `/tmp/movienx_gpu_todesk_wrapper.log`
- Working driver observed: NVIDIA `565.77` on RTX 4090.

## Standard startup

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

Then open a GPU Sensor TestRun and click `Start`.

Confirmed working TestRuns:

- `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`
- `Examples/BasicFunctions/Sensors/LidarRSI_Countryside`

Success indicators:

- CarMaker Office shows `Status: Running` or completes and returns to `Idle` with nonzero time/distance.
- Simulation time and distance increase.
- Wrapper log contains `GPUSensor Server running`, `STATUS-started`, and `APO: Successfully connected`.

## Robust wrapper behavior

The robust wrapper intentionally keeps MovieNX GPUSensor startup conservative:

- Exports ToDesk-safe NVIDIA PRIME offload variables.
- Runs GPUSensor through `taskset -c 0` by default to reduce high-core-count initialization races.
- Uses headless Vulkan with synchronous asset streaming: `-headless -renderapi vulkan -device 0 -noasyncstreaming`.
- Retries early MovieNX crashes (`SIGSEGV`/`double free`, exit `134`/`139`) up to 6 times.
- Stops retrying once the process survives the early-start window, so it does not restart an active simulation.

Useful environment overrides:

```bash
CM_MOVIENX_LOG=/tmp/custom_movienx.log ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_LOG=off ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_RETRIES=10 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=0-3 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=none ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CLEAN_CACHE=0 ./start_carmaker15_gpu_todesk.sh
```

Keep logging enabled by default because it is the fastest way to distinguish CarMaker timeout symptoms from MovieNX startup crashes.

## Diagnostic workflow

1. Verify `nvidia-smi` works and reports NVIDIA `565.77` on RTX 4090.
2. Check default `glxinfo -B`; ToDesk may show Mesa llvmpipe.
3. Check NVIDIA offload `glxinfo -B`; it should show `NVIDIA Corporation`.
4. Run MovieNX `-listdevices` only when no GPUSensor session is active.
5. If CarMaker times out, inspect `/tmp/movienx_gpu_todesk_wrapper.log`.
6. If the log does not append, CarMaker is not using the robust GPU configuration.
7. If the log shows early crash followed by retry, wait; the wrapper may recover automatically.

## References and tools

- Load `references/carmaker15_todesk_gpu.md` for the incident record, commands, root-cause notes, robust-wrapper details, and suggested GPU demos.
- Run `scripts/check_carmaker_gpu_env.sh` for a read-only environment check.
