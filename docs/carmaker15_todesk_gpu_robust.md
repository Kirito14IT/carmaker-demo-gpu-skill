# CarMaker 15.1 GPU Sensor demos on Ubuntu + ToDesk

## Final outcome

The robust ToDesk/NVIDIA setup is considered working on this machine.

Confirmed successful demos:

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

Observed UI evidence:

```text
RadarRSI_Motorway: Time 79.6, Distance 2194.18, returned to Idle after run
LidarRSI_Countryside: Time 94.9, Distance 624.61, returned to Idle after run
```

Observed wrapper log evidence:

```text
GPUSensor Server running: host=ubuntu-2204-4090 port=11500
STATUS-started-1436361-11500
APO: Successfully connected to: CarMaker 15.1 - Car_Generic
Loading Test Run from path /opt/ipg/carmaker/linux64-15.1/Data/TestRun/Examples/BasicFunctions/Sensors/RadarRSI_Motorway
IPGRsi library version: 15.1.10
Loading Test Run from path /opt/ipg/carmaker/linux64-15.1/Data/TestRun/Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

## Root cause summary

`GPU-Sensors 128: Error: Timeout during startup` was a secondary symptom. CarMaker waited for MovieNX GPUSensor, but MovieNX sometimes died during startup.

Evidence chain:

1. ToDesk default OpenGL used Mesa llvmpipe.
2. NVIDIA PRIME offload could expose the RTX 4090 correctly.
3. NVIDIA driver `580.126.09` made MovieNX `-listdevices` crash with `SIGSEGV`.
4. Downgrading to NVIDIA `565.77` fixed GPU enumeration.
5. GPUSensor mode still sometimes crashed even with correct GPU visibility.
6. gdb showed crashes inside MovieNX/Unigine initialization, including `MeshManager::init()` and property/asset loading.
7. Runtime logs also showed `double free or corruption (!prev)` and `SIGSEGV`, consistent with early initialization race/memory corruption on this 512-thread AMD EPYC host.

The stable operational fix is a project-local robust wrapper that reduces startup concurrency and retries early GPUSensor crashes.

## Current standard files

Launcher:

```text
/home/cqx/Downloads/CarMakerOffice-linux-15.1/start_carmaker15_gpu_todesk.sh
```

Wrapper:

```text
/home/cqx/Downloads/CarMakerOffice-linux-15.1/scripts/movienx_gpu_todesk_wrapper.sh
```

Project GPU configuration:

```text
/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA_Robust
```

Project GUI config must contain:

```text
GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA_Robust
```

Wrapper log:

```text
/tmp/movienx_gpu_todesk_wrapper.log
```

## Standard startup procedure

Use this every time from ToDesk:

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

In CarMaker Office:

1. Open a GPU Sensor TestRun, starting with `RadarRSI_Motorway`.
2. Click `Start`.
3. Wait if the UI stays at `GPUSensor Init`; the wrapper may be retrying an early MovieNX crash.
4. Verify `Status: Running`, or final `Idle` with nonzero time/distance after completion.

Do not start GPU demos from an unprepared desktop shortcut unless it launches the same script and project configuration.

## Robust wrapper behavior

The active GPU configuration appends these MovieNX options:

```text
-headless
-renderapi vulkan
-device 0
-noasyncstreaming
```

The wrapper adds:

```text
taskset -c 0
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
```

Early-crash retry policy:

- Default retries: `CM_MOVIENX_RETRIES=6`
- Early-start window: `CM_MOVIENX_RETRY_WINDOW=20` seconds
- Retry exit codes: `134` and `139`
- Rationale: abort/SIGSEGV before stable APO operation is usually MovieNX startup instability.

Optional wrapper environment variables:

```bash
CM_MOVIENX_LOG=/tmp/custom_movienx.log ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_LOG=off ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_RETRIES=10 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=0-3 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=none ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CLEAN_CACHE=0 ./start_carmaker15_gpu_todesk.sh
```

Keep logging on by default. The log is the decisive artifact for distinguishing:

- CarMaker did not invoke MovieNX.
- MovieNX started but crashed before APO.
- MovieNX retried and recovered.
- MovieNX connected to CarMaker successfully.

## Diagnostic commands

Check NVIDIA driver:

```bash
nvidia-smi
```

Expected working baseline:

```text
NVIDIA-SMI 565.77
Driver Version: 565.77
GPU: NVIDIA GeForce RTX 4090
```

Check default OpenGL:

```bash
glxinfo -B | grep -E "OpenGL vendor|OpenGL renderer|Accelerated"
```

On ToDesk it may show Mesa llvmpipe. That alone is not fatal if NVIDIA offload works.

Check NVIDIA offload OpenGL:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
glxinfo -B | grep -E "OpenGL vendor|OpenGL renderer|Accelerated"
```

Expected:

```text
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA GeForce RTX 4090/PCIe/SSE2
```

Check MovieNX GPU enumeration only when no GPUSensor is active:

```bash
DISPLAY=:0 \
XDG_RUNTIME_DIR=/run/user/$(id -u) \
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json \
timeout 30s /opt/ipg/movienx/linux64-15.1/bin/MovieNX -listdevices
```

Expected decisive lines:

```text
Graphics API: Vulkan
CUDA runtime version: 12.0
CUDA driver version: 12.7
GPU #0 (active):
Name = NVIDIA GeForce RTX 4090
Driver = 565.77
Video memory = 23.99GB
Capability = 8.9
```

Weather/property duplicate messages such as `Property ... already exists` were observed on successful runs. Treat them as noise unless followed by an unrecovered crash.

## Troubleshooting decision tree

1. If `nvidia-smi` fails with driver/library mismatch, finish driver installation and reboot only with user approval.
2. If default `glxinfo` is llvmpipe but NVIDIA offload `glxinfo` works, continue with the wrapper.
3. If MovieNX `-listdevices` crashes, investigate driver version first.
4. If CarMaker times out and the wrapper log does not append, re-check `Data/Config/GUI` and the GPU Configuration dialog.
5. If the wrapper log shows `launch-attempt` followed by `double free`/`SIGSEGV`, wait for retries unless all attempts fail.
6. If the wrapper log shows `APO: Successfully connected`, the GPU Sensor server has connected to CarMaker.

## Additional GPU demos to test

Recommended sequence:

1. `Examples/BasicFunctions/Sensors/RadarRSI_Motorway` - baseline confirmed.
2. `Examples/BasicFunctions/Sensors/LidarRSI_Countryside` - baseline confirmed.
3. `Examples/BasicFunctions/Sensors/MultiRSI` - combined RSI load.
4. `Examples/BasicFunctions/Sensors/USonicRSI_Parking` - ultrasonic RSI.
5. `Examples/BasicFunctions/Sensors/USonicRSI_ConfigurableFrame` - ultrasonic frame configuration.
6. `Examples/BasicFunctions/Sensors/USonicRSI_ComparisonDynamicRayPattern` - dynamic ray pattern.
7. `Examples/BasicFunctions/MovieNX/WeatherRain_SensorCamera_NardoHandlingTrack` - MovieNX weather/camera workload.

Non-GPU or less decisive demos, useful for comparison but not proof of GPU Sensor readiness:

- `Examples/BasicFunctions/Sensors/RadarSensor_MergeObjects`
- `Examples/BasicFunctions/Sensors/RadarSensor_Occlusion`
- `Examples/BasicFunctions/Sensors/CameraSensor_DetectObjects`

## Things not to do by default

- Do not switch back to NVIDIA `580.126.09`; it was associated with MovieNX `SIGSEGV` on this machine.
- Do not use `prime-select nvidia`; this host has no integrated GPU, and `prime-select` reports `Error: no integrated GPU detected`.
- Do not use temporary Xorg experiments for routine operation; they previously disconnected ToDesk.
- Do not start multiple CarMaker/MovieNX GPU sessions at the same time.
- Do not treat non-GPU sensor demos as proof that MovieNX GPUSensor is ready.
