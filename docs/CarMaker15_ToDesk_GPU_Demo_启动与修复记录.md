# CarMaker 15.1 在 ToDesk 下启动 GPU Demo 的修复记录

## 结论

已经成功运行 CarMaker GPU demo `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`。

成功现象：

- CarMaker Office 中 `Status` 显示为 `Running`。
- 仿真 `Time` 和 `Distance` 持续增长。
- `/tmp/movienx_gpu_todesk_wrapper.log` 中出现 `GPUSensor Server running`、`STATUS-started`、`APO: Successfully connected`。

## 环境

- 系统：Ubuntu 22.04
- 远程桌面：ToDesk
- GPU：NVIDIA GeForce RTX 4090
- 当前可用 NVIDIA 驱动：`565.77`
- CarMaker Office：`15.1`
- 项目目录：`/home/cqx/CM_Projects/cm151_gpu_demo`
- 启动目录：`/home/cqx/Downloads/CarMakerOffice-linux-15.1`

## 原始问题

直接在 ToDesk 桌面启动 CarMaker Office 后，打开：

```text
Examples / BasicFunctions / Sensors / RadarRSI_Motorway
```

点击 `Start` 会弹窗：

```text
GPU-Sensors 128: Error: Timeout during startup.
```

这不是因为没有设置 TestRun 参数。非 GPU demo `RadarSensor_MergeObjects` 能运行，只能说明普通传感器和 CarMaker 主程序没问题，不能证明 MovieNX GPUSensor 能启动。

## 关键诊断过程

### 1. ToDesk 默认 OpenGL 不是 NVIDIA

默认 `glxinfo -B` 显示：

```text
OpenGL vendor string: Mesa
OpenGL renderer string: llvmpipe
Accelerated: no
```

这说明 ToDesk/远程 GNOME 会话默认走软件渲染。

但使用 NVIDIA PRIME offload 后可以看到 RTX 4090：

```bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
glxinfo -B | grep -E "OpenGL vendor|OpenGL renderer|Accelerated"
```

期望输出：

```text
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA GeForce RTX 4090/PCIe/SSE2
```

### 2. NVIDIA 580 驱动下 MovieNX 会崩溃

使用 driver `580.126.09` 时：

```bash
/opt/ipg/movienx/linux64-15.1/bin/MovieNX -listdevices
```

出现：

```text
Received signal SIGSEGV, invalid memory reference
```

所以当时的问题不是 CarMaker 参数，而是 MovieNX/GPU 栈无法正常枚举 GPU。

### 3. 降到 NVIDIA 565.77 后 MovieNX 可以识别 GPU

当前 `nvidia-smi` 应显示类似：

```text
NVIDIA-SMI 565.77
Driver Version: 565.77
NVIDIA GeForce RTX 4090
```

MovieNX 正常枚举 GPU 的关键输出：

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

日志中出现若干 `Property ... already exists` / `can't load ... prop` 信息时，只要后面能列出 GPU，就不是本次 timeout 的根因。

## 最终修复方案

### 1. 使用专用启动脚本启动 CarMaker

文件：

```text
/home/cqx/Downloads/CarMakerOffice-linux-15.1/start_carmaker15_gpu_todesk.sh
```

作用：为 CarMaker Office 设置 ToDesk 下需要的 NVIDIA PRIME/Vulkan 环境变量。

核心环境变量：

```bash
DISPLAY=:0
XDG_RUNTIME_DIR=/run/user/$(id -u)
__NV_PRIME_RENDER_OFFLOAD=1
__GLX_VENDOR_LIBRARY_NAME=nvidia
__VK_LAYER_NV_optimus=NVIDIA_only
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
```

### 2. 使用 MovieNX wrapper 启动 GPUSensor

文件：

```text
/home/cqx/Downloads/CarMakerOffice-linux-15.1/scripts/movienx_gpu_todesk_wrapper.sh
```

作用：

- 记录 CarMaker 启动 MovieNX 时传入的参数。
- 再次强制设置 NVIDIA PRIME/Vulkan 环境变量。
- 最后执行真正的 MovieNX。

日志位置：

```text
/tmp/movienx_gpu_todesk_wrapper.log
```

### 3. 项目加载专用 GPU Configuration

文件：

```text
/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA
```

当前项目 GUI 配置：

```text
/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GUI
```

必须包含：

```text
GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA
```

该 GPU 配置会强制 GPUSensor 使用 wrapper，并附加：

```text
-headless
-renderapi vulkan
-cudadevice 0
-device 0
```

## 后续正确启动方式

每次使用 ToDesk 运行 CarMaker GPU demo 时，执行：

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

然后在 CarMaker Office 中打开：

```text
Examples / BasicFunctions / Sensors / RadarRSI_Motorway
```

点击 `Start`。

看到下面现象即可认为正常：

```text
Status: Running
Time 持续增长
Distance 持续增长
```

## 快速验证命令

### 查看 GPU 驱动

```bash
nvidia-smi
```

如果 GPU demo 正在运行，`nvidia-smi` 里应能看到 `MovieNX.exe` 占用显存。

### 查看 wrapper 是否被 CarMaker 调用

```bash
tail -n 220 /tmp/movienx_gpu_todesk_wrapper.log
```

成功时应包含：

```text
-mode GPUSensor
-instance 128
GPUSensor Server running
STATUS-started
APO: Successfully connected
Loading Test Run from path /opt/ipg/carmaker/linux64-15.1/Data/TestRun/Examples/BasicFunctions/Sensors/RadarRSI_Motorway
```

### 确认项目已加载 GPU 配置

```bash
rg -n '^GPUParameters\.FName' /home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GUI
```

期望：

```text
GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA
```

注意：`MovieNX -listdevices` 建议在启动 GPU demo 前或停止 demo 后执行。当前 demo 已经运行时，再启动第二个 `MovieNX -listdevices` 进程可能崩溃，这不代表正在运行的 demo 有问题。

## 注意事项

- 不要随意切回 NVIDIA `580.126.09`，该版本在本机曾导致 MovieNX `SIGSEGV`。
- 不要依赖 `prime-select nvidia`。这台机器没有集成显卡，执行会报 `Error: no integrated GPU detected`。
- 不要再把临时 Xorg 测试脚本作为常规流程，它曾导致 ToDesk 断开。
- 不要从普通桌面快捷方式直接启动 GPU demo，除非确认快捷方式也设置了相同环境变量并加载了同一个 GPU Configuration。
- 如果后续再次 timeout，优先看 `/tmp/movienx_gpu_todesk_wrapper.log`，不要先重启或改驱动。

## 故障恢复思路

1. `nvidia-smi` 失败：先解决驱动加载问题。
2. 默认 `glxinfo` 是 llvmpipe，但 offload `glxinfo` 是 NVIDIA：继续使用 wrapper 方案。
3. `MovieNX -listdevices` 崩溃：优先怀疑驱动版本或 MovieNX/GPU 栈。
4. `MovieNX -listdevices` 正常但 CarMaker timeout：检查 `GPUParameters.FName` 和 wrapper 日志。
5. wrapper 日志完全没有新记录：说明 CarMaker 没有使用该 GPU Configuration。
