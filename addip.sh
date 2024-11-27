#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用root权限运行脚本！"
    exit 1
fi

# 获取第一个活动网络接口
interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)

# 如果没有找到活动接口，尝试使用ifconfig
if [ -z "$interface" ]; then
    interface=$(ifconfig | grep -o '^[a-zA-Z0-9]*' | grep -v lo | head -n 1)
fi

# 如果仍然没有找到活动接口，输出错误并退出
if [ -z "$interface" ]; then
    echo "未能检测到有效的网络接口。"
    exit 1
fi

echo "检测到活动的网络接口：$interface"

# 提示用户输入IPv4或IPv6地址
read -p "请输入要添加的IP地址 (IPv4/IPv6)： " ip_address

# 检查输入的IP地址类型
if [[ $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip_version="IPv4"
elif [[ $ip_address =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]]; then
    ip_version="IPv6"
else
    echo "输入的地址无效！"
    exit 1
fi

echo "检测到输入的地址类型：$ip_version"

# 添加IP地址
if [ "$ip_version" == "IPv4" ]; then
    ip addr add $ip_address dev $interface
elif [ "$ip_version" == "IPv6" ]; then
    ip -6 addr add $ip_address dev $interface
fi

# 检测IP是否生效
if ip addr show dev $interface | grep -q "$ip_address"; then
    echo "IP地址 $ip_address 已成功添加并生效！"
    
    # 重启网络服务，根据不同系统选择合适的命令
    echo "正在重启网络服务..."
    
    # 检测系统使用的服务管理工具
    if systemctl --version &>/dev/null; then
        # 如果使用 systemd
        systemctl restart networking
        echo "网络服务已通过 systemd 重启！"
    elif service --status-all &>/dev/null; then
        # 如果使用 SysVinit
        service networking restart
        echo "网络服务已通过 service 重启！"
    elif [ -f /etc/init.d/networking ]; then
        # 旧式的 init.d 脚本
        /etc/init.d/networking restart
        echo "网络服务已通过 init.d 重启！"
    else
        echo "无法确定网络服务管理方式，请手动重启网络服务。"
    fi

else
    echo "IP地址添加失败或未生效，请检查配置。"
fi
