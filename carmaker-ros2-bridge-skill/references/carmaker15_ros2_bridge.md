# CarMaker 15.1 ROS2 Bridge Reference

## Purpose

This reference captures the verified CarMaker 15.1 ROS2 bridge setup in `/home/cqx/CM_Projects/cm151_gpu_demo`. It is intended for migration checks, regression validation, and handoff to future operators.

## Runtime proof

Run from the project root:

```bash
cd /home/cqx/CM_Projects/cm151_gpu_demo
"./src/CarMaker.linux64" -help | head -5
```

Expected key line:

```text
APPLICATION     Car_Generic <insert.your.version.no> #4 (linux64-15.1)
```

Dependency check:

```bash
ldd "./src/CarMaker.linux64" | rg "not found"
```

Expected: no output.

RUNPATH check:

```bash
readelf -d "./src/CarMaker.linux64" | rg "RUNPATH|RPATH"
```

Observed:

```text
0x000000000000001d (RUNPATH) Library runpath: [/opt/ros/humble/lib:/opt/ipg/carmaker/linux64-14.1.1/install/autoware_control_msgs/lib:/opt/ipg/carmaker/linux64-14.1.1/install/msg_interfaces/lib]
```

The `14.1.1/install` path is the ROS2 message package prefix. It does not define the CarMaker executable version.

## Environment

```bash
export ROS_DISTRO=humble
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export BRIDGE_PREFIX="/opt/ipg/carmaker/linux64-14.1.1/install"
export AMENT_PREFIX_PATH="/opt/ros/humble:${BRIDGE_PREFIX}"
export COLCON_PREFIX_PATH="/opt/ros/humble:${BRIDGE_PREFIX}"
export LD_LIBRARY_PATH="/opt/ros/humble/lib:${BRIDGE_PREFIX}/autoware_control_msgs/lib:${BRIDGE_PREFIX}/msg_interfaces/lib"
```

For `ros2` CLI usage:

```bash
source /opt/ros/humble/setup.bash
```

If `ros2` is still unavailable, use `/opt/ros/humble/bin/ros2`.

## CLI smoke run

```bash
timeout 40s "./src/CarMaker.linux64" \
  -screen \
  -projectdir "/home/cqx/CM_Projects/cm151_gpu_demo" \
  -taccel 1 \
  -tstop 20 \
  "Examples/VehicleDynamics/Handling/Slalom18m"
```

Expected bridge logs:

```text
CarMaker ROS Bridge initialized (CHC430 mode)
Publishing: /chcnav/devpvt (CHC430 format)
Publishing: /perception/curb_boundaries (GPS blind zone support)
ROS2 bridge initialized for CarMaker 15.1
ROS2 bridge: RoadEval handle created for curb publishing
ROS2 bridge final state published
ROS2 bridge cleaned up
```

## Probe validation

Run during the CarMaker simulation:

```bash
/tmp/carmaker_ros2_probe
```

Observed successful output:

```text
chc_count=308 curb_count=303 lat=29.05468773 lon=110.48084613 speed=0.000
```

Interpretation:

- `chc_count > 0`: `/chcnav/devpvt` publishes CHC430-style state.
- `curb_count > 0`: `/perception/curb_boundaries` publishes curb boundaries.
- Parsed `lat`, `lon`, and `speed` prove the custom message libraries are usable.

The probe also publishes:

```text
/control/control_cmd
velocity = 2.0 m/s
steering_tire_angle = 0.03 rad
```

CarMaker control logs proving command reception:

```text
ROS2 control: target=2.00 m/s actual=14.97 m/s steer_tire=0.030 rad gas=0.00 brake=1.00 clutch=0.94 gear=1 fresh=0
ROS2 control: target=2.00 m/s actual=2.05 m/s steer_tire=0.030 rad gas=0.00 brake=0.22 clutch=0.00 gear=1 fresh=0
```

## Acceptance criteria

The bridge is considered usable on CarMaker 15.1 when all are true:

1. `CarMaker.linux64 -help` reports `linux64-15.1`.
2. `ldd` reports no `not found` entries.
3. CarMaker logs `ROS2 bridge initialized for CarMaker 15.1`.
4. Probe reports both `chc_count > 0` and `curb_count > 0`.
5. CarMaker logs `ROS2 control: target=... steer_tire=...`.

## Common failure interpretation

| Symptom | Meaning | Action |
| --- | --- | --- |
| `ros2: command not found` | PATH was not initialized for ROS2 CLI | `source /opt/ros/humble/setup.bash` |
| RUNPATH contains `14.1.1/install` | ROS2 message libraries are reused from old prefix | Confirm executable still reports `linux64-15.1` |
| `Vehicle leaves road` | Fixed probe control caused an off-road trajectory | Use smaller steering, shorter `tstop`, or a receive-only probe |
| No `curb_count` | RoadEval/curb publishing may not be initialized or QoS mismatched | Check `RoadEval handle created` and use SensorDataQoS |
| No `chc_count` | Bridge publisher missing or ROS env/library issue | Check init logs and `LD_LIBRARY_PATH` |

## Integration notes

- Autoware-style ROS2 stacks can connect directly if their message contracts, frames, time stamps, QoS, and control limits match.
- Apollo normally uses Cyber RT. A ROS2 <-> Cyber RT adapter is required; do not assume direct Apollo subscription to these ROS2 topics.
- Start closed-loop integration with low speed, zero or small steering, and short simulations.

## Optional source files

The repository includes `examples/carmaker_ros2_probe.cpp`, matching the probe used in validation. It is a small integration probe, not a replacement for the production bridge.
