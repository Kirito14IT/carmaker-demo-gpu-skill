#include <autoware_control_msgs/msg/control.hpp>
#include <msg_interfaces/msg/curb_boundaries.hpp>
#include <msg_interfaces/msg/hcinspvatzcb.hpp>
#include <rclcpp/rclcpp.hpp>

#include <chrono>
#include <cstdio>

using namespace std::chrono_literals;

int main(int argc, char **argv)
{
    rclcpp::init(argc, argv);
    auto node = std::make_shared<rclcpp::Node>("carmaker_ros2_probe");

    int chc_count = 0;
    int curb_count = 0;
    double last_lat = 0.0;
    double last_lon = 0.0;
    float last_speed = 0.0f;

    auto chc_sub = node->create_subscription<msg_interfaces::msg::Hcinspvatzcb>(
        "/chcnav/devpvt", 10,
        [&](msg_interfaces::msg::Hcinspvatzcb::ConstSharedPtr msg) {
            ++chc_count;
            last_lat = msg->latitude;
            last_lon = msg->longitude;
            last_speed = msg->speed;
        });

    auto curb_sub = node->create_subscription<msg_interfaces::msg::CurbBoundaries>(
        "/perception/curb_boundaries", rclcpp::SensorDataQoS(),
        [&](msg_interfaces::msg::CurbBoundaries::ConstSharedPtr) {
            ++curb_count;
        });

    auto control_pub = node->create_publisher<autoware_control_msgs::msg::Control>(
        "/control/control_cmd", 10);

    auto start = node->now();
    auto next_pub = start;
    while ((node->now() - start).seconds() < 12.0) {
        if (node->now() >= next_pub) {
            autoware_control_msgs::msg::Control cmd;
            cmd.longitudinal.velocity = 2.0;
            cmd.lateral.steering_tire_angle = 0.03;
            control_pub->publish(cmd);
            next_pub = node->now() + rclcpp::Duration::from_seconds(0.05);
        }

        rclcpp::spin_some(node);
        rclcpp::sleep_for(10ms);
    }

    std::printf("chc_count=%d curb_count=%d lat=%.8f lon=%.8f speed=%.3f\n",
                chc_count, curb_count, last_lat, last_lon, last_speed);
    rclcpp::shutdown();
    return (chc_count > 0 && curb_count > 0) ? 0 : 2;
}
