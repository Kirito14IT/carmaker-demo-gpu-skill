# CarMaker 15.1 ROS2 Bridge 验证与使用说明

本文记录 `/home/cqx/CM_Projects/cm151_gpu_demo` 中 `ROS2Bridge` 从 CarMaker 14.1.1 项目移植到 CarMaker 15.1 后的验证方法、成功标志和后续接入注意事项。

结论：当前 `cm151_gpu_demo/src/CarMaker.linux64` 是 `linux64-15.1` 可执行文件，ROS2 bridge 已在 15.1 CLI TestRun 中完成发布数据和接收控制命令验证。RUNPATH 中出现 `linux64-14.1.1/install` 只是复用 ROS2 自定义消息包安装前缀，不代表运行的是 CarMaker 14.1.1。

## 关键路径

```text
CarMaker 15.1 项目: /home/cqx/CM_Projects/cm151_gpu_demo
CarMaker 可执行文件: /home/cqx/CM_Projects/cm151_gpu_demo/src/CarMaker.linux64
Bridge 源码: /home/cqx/CM_Projects/cm151_gpu_demo/src/ROS2Bridge.cpp
Bridge 头文件: /home/cqx/CM_Projects/cm151_gpu_demo/src/ROS2Bridge.h
CarMaker 用户集成点: /home/cqx/CM_Projects/cm151_gpu_demo/src/User.cpp
构建配置: /home/cqx/CM_Projects/cm151_gpu_demo/src/Makefile
可选 GPU 启动脚本: /home/cqx/CM_Projects/cm151_gpu_demo/start_carmaker15_gpu_todesk.sh
ROS2/消息包前缀: /opt/ros/humble, /opt/ipg/carmaker/linux64-14.1.1/install
Probe 程序: /tmp/carmaker_ros2_probe
```

## Bridge topic 契约

当前 bridge 的主要 ROS2 topic：

| 方向 | Topic | 消息类型 | 用途 |
| --- | --- | --- | --- |
| CarMaker -> ROS2 | `/chcnav/devpvt` | `msg_interfaces/msg/Hcinspvatzcb` | CHC430 风格定位/车辆状态 |
| CarMaker -> ROS2 | `/perception/curb_boundaries` | `msg_interfaces/msg/CurbBoundaries` | 路沿/边界信息 |
| CarMaker -> ROS2 | `/perception/curb_diagnostics` | `msg_interfaces/msg/CurbDiagnostics` | 路沿诊断信息 |
| CarMaker -> ROS2 | `/control/runtime_log_stop` | `nav_msgs/msg/Odometry` | 仿真结束状态 |
| ROS2 -> CarMaker | `/control/control_cmd` | `autoware_control_msgs/msg/Control` | 速度和前轮转角控制命令 |

## 手动验证步骤

### 1. 确认当前目录和 CarMaker 版本

```bash
cd /home/cqx/CM_Projects/cm151_gpu_demo
pwd
"./src/CarMaker.linux64" -help | head -5
```

成功标志：

```text
/home/cqx/CM_Projects/cm151_gpu_demo
APPLICATION     Car_Generic <insert.your.version.no> #4 (linux64-15.1)
COMPILED        cqx@ubuntu-2204-4090 2026-05-17 23:50:49
```

### 2. 确认动态库没有缺失

```bash
ldd "./src/CarMaker.linux64" | rg "not found"
```

成功标志：无输出。

检查 RUNPATH：

```bash
readelf -d "./src/CarMaker.linux64" | rg "RUNPATH|RPATH"
```

实测输出：

```text
0x000000000000001d (RUNPATH) Library runpath: [/opt/ros/humble/lib:/opt/ipg/carmaker/linux64-14.1.1/install/autoware_control_msgs/lib:/opt/ipg/carmaker/linux64-14.1.1/install/msg_interfaces/lib]
```

说明：这里的 `linux64-14.1.1/install` 是 ROS2 自定义消息包 `autoware_control_msgs` 和 `msg_interfaces` 的安装目录；只要第 1 步显示 `linux64-15.1`，即可证明运行的 CarMaker 主程序是 15.1。

### 3. 设置 ROS2 bridge 运行环境

```bash
export ROS_DISTRO=humble
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export BRIDGE_PREFIX="/opt/ipg/carmaker/linux64-14.1.1/install"
export AMENT_PREFIX_PATH="/opt/ros/humble:${BRIDGE_PREFIX}"
export COLCON_PREFIX_PATH="/opt/ros/humble:${BRIDGE_PREFIX}"
export LD_LIBRARY_PATH="/opt/ros/humble/lib:${BRIDGE_PREFIX}/autoware_control_msgs/lib:${BRIDGE_PREFIX}/msg_interfaces/lib"
```

如果需要使用 `ros2` 命令行，额外执行：

```bash
source /opt/ros/humble/setup.bash
```

只设置 `ROS_DISTRO` 不会自动把 `/opt/ros/humble/bin` 加入 `PATH`，所以直接输入 `ros2` 可能出现 `ros2：未找到命令`。这属于 shell 环境问题，不代表 bridge 失败。

### 4. 启动 20s CLI TestRun

```bash
timeout 40s "./src/CarMaker.linux64" \
  -screen \
  -projectdir "/home/cqx/CM_Projects/cm151_gpu_demo" \
  -taccel 1 \
  -tstop 20 \
  "Examples/VehicleDynamics/Handling/Slalom18m"
```

成功标志：

```text
[INFO] [..] [carmaker_ros_bridge]: CarMaker ROS Bridge initialized (CHC430 mode)
[INFO] [..] [carmaker_ros_bridge]:   Publishing: /chcnav/devpvt (CHC430 format)
[INFO] [..] [carmaker_ros_bridge]:   Publishing: /perception/curb_boundaries (GPS blind zone support)
                ROS2 bridge initialized for CarMaker 15.1
SIM_START       Examples/VehicleDynamics/Handling/Slalom18m
TIME    0.000
SIMULATE        Examples/VehicleDynamics/Handling/Slalom18m
                ROS2 bridge: RoadEval handle created for curb publishing
TIME    19.999
                Tstop=20s reached, forcing end of simulation
                ROS2 bridge final state published
SIM_END         Examples/VehicleDynamics/Handling/Slalom18m     20s
                ROS2 bridge cleaned up
```

### 5. 验证 ROS2 数据发布

在 CarMaker TestRun 运行期间执行：

```bash
/tmp/carmaker_ros2_probe
```

实测输出：

```text
chc_count=308 curb_count=303 lat=29.05468773 lon=110.48084613 speed=0.000
```

成功判断：

- `chc_count > 0`：证明 `/chcnav/devpvt` 有数据。
- `curb_count > 0`：证明 `/perception/curb_boundaries` 有数据。
- 经纬度和速度字段能被正常解析。

### 6. 验证控制命令接收

Probe 会向 `/control/control_cmd` 持续发布固定控制命令：

```text
velocity = 2.0 m/s
steering_tire_angle = 0.03 rad
```

CarMaker 端出现类似日志即表示 bridge 已收到并施加控制命令：

```text
ROS2 control: target=2.00 m/s actual=14.97 m/s steer_tire=0.030 rad gas=0.00 brake=1.00 clutch=0.94 gear=1 fresh=0
ROS2 control: target=2.00 m/s actual=2.05 m/s steer_tire=0.030 rad gas=0.00 brake=0.22 clutch=0.00 gear=1 fresh=0
```

如果随后看到：

```text
ERROR           Vehicle leaves road at about x=91.2309, y=3.5013 TireNo=0
SIM_ABORT       Examples/VehicleDynamics/Handling/Slalom18m
```

这不是 bridge 失败，而是 probe 固定发布 `0.03 rad` 转角导致车辆在 `Slalom18m` 测试中偏离道路。它反而说明控制链路已经影响了车辆运动。

## 判定标准

满足以下条件即可认为 CarMaker 15.1 上的 bridge 可用：

1. `./src/CarMaker.linux64 -help` 显示 `linux64-15.1`。
2. `ldd ./src/CarMaker.linux64 | rg "not found"` 无输出。
3. CarMaker 启动日志包含 `ROS2 bridge initialized for CarMaker 15.1`。
4. `/tmp/carmaker_ros2_probe` 输出 `chc_count > 0` 且 `curb_count > 0`。
5. CarMaker 日志包含 `ROS2 control: target=... steer_tire=...`。

当前实测已满足以上 5 项。

## 后续接入自动驾驶软件

这个 bridge 已证明可在 CarMaker 15.1 中：

- 实时发布车辆/定位/路沿数据到 ROS2。
- 从 ROS2 接收速度和转向控制命令并作用到车辆。

因此，后续自动驾驶软件只要能按上述 topic 和消息类型对接，就可以复用该 bridge。

注意：

- 如果自动驾驶软件本身是 ROS2/Autoware 风格，重点检查消息字段、坐标系、时间戳、QoS 和控制限幅。
- 如果使用 Apollo，Apollo 默认是 Cyber RT，不是 ROS2，需要额外做 ROS2 <-> Cyber RT 适配层，不能假设 Apollo 可直接订阅这些 ROS2 topic。
- 正式联调建议先用低速、零转角、短时 TestRun，再逐步接入闭环规划控制。

## 常见问题

### `ros2：未找到命令`

原因：没有 source ROS2 环境，`PATH` 中没有 `/opt/ros/humble/bin`。

处理：

```bash
source /opt/ros/humble/setup.bash
```

或者直接使用：

```bash
/opt/ros/humble/bin/ros2 topic list --no-daemon
```

### RUNPATH 里为什么有 14.1.1？

原因：当前复用的是 `/opt/ipg/carmaker/linux64-14.1.1/install` 下的 ROS2 自定义消息包安装产物。CarMaker 主程序版本由 `./src/CarMaker.linux64 -help` 中的 `linux64-15.1` 判定。

### `Vehicle leaves road` 是否代表失败？

不是。该现象来自 probe 的固定控制命令，不是 bridge 初始化、数据发布或控制订阅失败。要避免该现象，可以改用更短 `tstop`、更小转角或仅做数据订阅 probe。
