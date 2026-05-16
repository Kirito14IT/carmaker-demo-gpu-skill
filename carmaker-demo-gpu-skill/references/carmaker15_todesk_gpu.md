# CarMaker 15.1 GPU Sensor demos on Ubuntu + ToDesk

## Outcome

The `Examples/BasicFunctions/Sensors/RadarRSI_Motorway` GPU demo is considered working when CarMaker Office shows `Status: Running`, simulation time and distance keep increasing, and the MovieNX wrapper log shows GPUSensor startup and APO connection.

Observed working evidence:

```text
Status: Running
Time: 47.1
Distance: 1306.62
```

Wrapper log evidence:

```text
GPUSensor Server running: host=ubuntu-2204-4090 port=11500
STATUS-started-605180-11500
APO: Successfully connected to: CarMaker 15.1 - Car_Generic
Loading Test Run from path /opt/ipg/carmaker/linux64-15.1/Data/TestRun/Examples/BasicFunctions/Sensors/RadarRSI_Motorway
IPGRsi library version: 15.1.10
```

## Root cause summary

The failure was not caused by missing TestRun parameters. The initial state had two independent problems:

1. ToDesk/remote GNOME default OpenGL rendered through Mesa llvmpipe, not the RTX 4090.
2. NVIDIA driver `580.126.09` caused MovieNX `-listdevices` to crash with `SIGSEGV`.

After downgrading to NVIDIA driver `565.77`, MovieNX could enumerate the RTX 4090 with explicit NVIDIA PRIME offload variables. CarMaker still timed out until the project was configured to launch GPUSensor through a wrapper that exports the same known-good environment.

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
/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA
```

Project GUI config must contain:

```text
GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA
```

## Standard startup procedure

Use this every time from ToDesk:

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

In CarMaker Office:

1. Open `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`.
2. Click `Start`.
3. Verify `Status: Running`.

Do not start this demo from an unprepared desktop shortcut unless it exports the same environment and loads the same GPU configuration.

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

On ToDesk it may show Mesa llvmpipe. That alone is not fatal if offload works.

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

Check MovieNX GPU enumeration:

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

Weather/property duplicate errors before those lines were observed and did not block the successful run.

Run `MovieNX -listdevices` before starting the GPU demo or after stopping it. If a GPUSensor `MovieNX.exe` process is already running, a second `-listdevices` process may crash; this does not imply the running demo is broken.

## Wrapper behavior

The MovieNX wrapper logs its arguments and environment to:

```text
/tmp/movienx_gpu_todesk_wrapper.log
```

For a successful CarMaker-launched GPUSensor, expect arguments similar to:

```text
-mode GPUSensor
-instance 128
-cudadevice 0
-guihost ubuntu-2204-4090:<port>
-instanceenginecache
-projectdir /home/cqx/CM_Projects/cm151_gpu_demo
-headless
-renderapi vulkan
-cudadevice 0
-device 0
```

If a new CarMaker run does not append to this log, CarMaker is not using the project GPU configuration. Re-check `Data/Config/GUI` and the GPU Configuration dialog.

## Things not to do by default

- Do not switch back to NVIDIA `580.126.09`; it was associated with MovieNX `SIGSEGV` on this machine.
- Do not use `prime-select nvidia`; this host has no integrated GPU, and `prime-select` reports `Error: no integrated GPU detected`.
- Do not use the temporary Xorg test script for routine operation; it previously disconnected ToDesk.
- Do not assume the non-GPU `RadarSensor_MergeObjects` result proves GPU Sensor readiness. It does not exercise MovieNX GPUSensor startup.

## Troubleshooting decision tree

1. If `nvidia-smi` fails with driver/library mismatch, finish driver installation and reboot only with user approval.
2. If default `glxinfo` is llvmpipe but NVIDIA offload `glxinfo` works, continue with wrapper/offload.
3. If MovieNX `-listdevices` crashes, investigate driver version before changing CarMaker parameters.
4. If MovieNX `-listdevices` works but CarMaker times out, force the project GPU Configuration to use the wrapper and inspect `/tmp/movienx_gpu_todesk_wrapper.log`.
5. If wrapper starts and reports `STATUS-started` but CarMaker still times out, inspect `-guihost`, hostname resolution, and latest `SimOutput/.../Log/*.log`.
