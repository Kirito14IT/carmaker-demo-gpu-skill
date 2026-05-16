# CarMaker 15.1 ToDesk GPU Demo 启动与修复记录

## 当前结论

当前方案已可稳定使用 CarMaker GPU Sensor demo。已验证：

```text
Examples/BasicFunctions/Sensors/RadarRSI_Motorway
Examples/BasicFunctions/Sensors/LidarRSI_Countryside
```

成功证据：

- CarMaker UI 中 Time/Distance 增长，运行结束后回到 `Idle`。
- `/tmp/movienx_gpu_todesk_wrapper.log` 中出现：

```text
GPUSensor Server running
STATUS-started
APO: Successfully connected
Loading Test Run from path .../RadarRSI_Motorway
Loading Test Run from path .../LidarRSI_Countryside
```

## 根本原因

`GPU-Sensors 128: Error: Timeout during startup` 不是 TestRun 参数没设置，而是 MovieNX GPUSensor 启动边界失败。

诊断过程确认：

1. ToDesk 默认 OpenGL 是 Mesa llvmpipe。
2. NVIDIA PRIME offload 可以正确使用 RTX 4090。
3. NVIDIA 580.x 下 MovieNX `-listdevices` 会 `SIGSEGV`。
4. 降到 NVIDIA 565.77 后，MovieNX 可以枚举 GPU。
5. 但 MovieNX GPUSensor 模式仍会在启动早期概率性崩溃。
6. gdb 定位到 MovieNX/Unigine 初始化阶段，例如 `MeshManager::init()`、属性/资源加载。
7. 日志中也出现过 `double free or corruption (!prev)` 与 `SIGSEGV`。

该机器是高核数 EPYC 服务器，MovieNX/Unigine 启动时会拉起大量线程，表现为概率性初始化崩溃。

## 最终修复方案

使用项目级 robust wrapper：

```text
/home/cqx/Downloads/CarMakerOffice-linux-15.1/scripts/movienx_gpu_todesk_wrapper.sh
```

使用项目 GPU 配置：

```text
/home/cqx/CM_Projects/cm151_gpu_demo/Data/Config/GPUConfiguration_ToDeskNVIDIA_Robust
```

`Data/Config/GUI` 中必须是：

```text
GPUParameters.FName = GPUConfiguration_ToDeskNVIDIA_Robust
```

robust wrapper 行为：

- 导出 NVIDIA PRIME offload 环境变量。
- 默认用 `taskset -c 0` 限制 MovieNX GPUSensor 单核启动。
- 使用 `-headless -renderapi vulkan -device 0 -noasyncstreaming`。
- 对早期 `SIGSEGV`/`double free` 自动重试，默认最多 6 次。
- 默认记录日志到 `/tmp/movienx_gpu_todesk_wrapper.log`。

## 正确启动方式

只用这个方式启动：

```bash
cd /home/cqx/Downloads/CarMakerOffice-linux-15.1
./start_carmaker15_gpu_todesk.sh
```

然后在 CarMaker Office 中打开 GPU Sensor TestRun 并点击 `Start`。

如果停在 `GPUSensor Init`，先看日志，不要连续点 Start：

```bash
tail -f /tmp/movienx_gpu_todesk_wrapper.log
```

## 可选日志配置

默认日志开启：

```text
/tmp/movienx_gpu_todesk_wrapper.log
```

可修改或关闭：

```bash
CM_MOVIENX_LOG=/tmp/custom_movienx.log ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_LOG=off ./start_carmaker15_gpu_todesk.sh
```

建议默认保持开启，因为它能快速判断：

- CarMaker 是否真的调用了 MovieNX；
- MovieNX 是否崩在启动早期；
- wrapper 是否自动重试成功；
- MovieNX 是否成功连接 APO。

## 可调参数

```bash
CM_MOVIENX_RETRIES=10 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=0-3 ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CPUSET=none ./start_carmaker15_gpu_todesk.sh
CM_MOVIENX_CLEAN_CACHE=0 ./start_carmaker15_gpu_todesk.sh
```

## 后续建议测试 demo

按顺序测试：

1. `Examples/BasicFunctions/Sensors/RadarRSI_Motorway`
2. `Examples/BasicFunctions/Sensors/LidarRSI_Countryside`
3. `Examples/BasicFunctions/Sensors/MultiRSI`
4. `Examples/BasicFunctions/Sensors/USonicRSI_Parking`
5. `Examples/BasicFunctions/Sensors/USonicRSI_ConfigurableFrame`
6. `Examples/BasicFunctions/Sensors/USonicRSI_ComparisonDynamicRayPattern`
7. `Examples/BasicFunctions/MovieNX/WeatherRain_SensorCamera_NardoHandlingTrack`

## 不建议做的事

- 不要用普通桌面图标直接跑 GPU demo。
- 不要切回 NVIDIA 580.x。
- 不要使用临时 Xorg 脚本作为日常方案。
- 不要同时启动多个 CarMaker/MovieNX GPU session。
- 不要把非 GPU demo 的成功当作 GPU Sensor 成功。
