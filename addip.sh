#!/bin/bash

# 当前脚本的版本号
SCRIPT_VERSION="1.0.1"

# 远程脚本版本和地址
REMOTE_SCRIPT_URL="https://your-server.com/scripts/addip.sh"  # 替换为实际远程脚本URL
REMOTE_VERSION_URL="https://your-server.com/scripts/version.txt"  # 替换为实际版本信息文件URL

# 获取当前脚本的版本号
get_current_version() {
    echo "$SCRIPT_VERSION"
}

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请使用root权限运行脚本！"
        exit 1
    fi
}

# 自动检测并返回活动网络接口
detect_network_interface() {
    local interface
    interface=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    
    if [ -z "$interface" ]; then
        interface=$(ifconfig | grep -o '^[a-zA-Z0-9]*' | grep -v lo | head -n 1)
    fi

    if [ -z "$interface" ]; then
        echo "未能检测到有效的网络接口。"
        exit 1
    fi
    echo "$interface"
}

# 检查输入的IPv4或IPv6地址类型
check_ip_type() {
    local ip_address=$1
    if [[ $ip_address =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IPv4"
    elif [[ $ip_address =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]] || [[ $ip_address =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ ]] || [[ $ip_address =~ ^::[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){0,7}$ ]]; then
        echo "IPv6"
    else
        echo "无效地址"
    fi
}

# 更新脚本
update_script() {
    echo "正在检查脚本更新..."
    # 下载远程版本号
    remote_version=$(curl -s $REMOTE_VERSION_URL)
    current_version=$(get_current_version)
    
    if [ "$remote_version" != "$current_version" ]; then
        echo "检测到新版本，正在下载并更新脚本..."
        curl -s -o /tmp/addip.sh $REMOTE_SCRIPT_URL
        mv /tmp/addip.sh /usr/local/bin/addip.sh
        chmod +x /usr/local/bin/addip.sh
        echo "脚本已更新，正在重新启动..."
        exec /usr/local/bin/addip.sh  # 重启新脚本
    else
        echo "当前脚本已经是最新版本。"
    fi
}

# 添加IPv4地址
add_ipv4() {
    local ip_address=$1
    local interface=$2
    ip addr add $ip_address dev $interface
}

# 添加IPv6地址
add_ipv6() {
    local ip_address=$1
    local interface=$2
    echo "正在添加IPv6地址：$ip_address 到接口 $interface"
    ip -6 addr add $ip_address dev $interface 2>&1 | tee /tmp/ipv6_add.log
    if [ $? -eq 0 ]; then
        echo "IPv6地址添加成功！"
    else
        echo "IPv6地址添加失败！请检查日志 /tmp/ipv6_add.log"
    fi
}

# 重启网络服务
restart_network_service() {
    echo "正在重启网络服务..."
    if systemctl --version &>/dev/null; then
        systemctl restart networking
        echo "网络服务已通过 systemd 重启！"
    elif service --status-all &>/dev/null; then
        service networking restart
        echo "网络服务已通过 service 重启！"
    elif [ -f /etc/init.d/networking ]; then
        /etc/init.d/networking restart
        echo "网络服务已通过 init.d 重启！"
    else
        echo "无法确定网络服务管理方式，请手动重启网络服务。"
    fi
}

# 主菜单
show_menu() {
    clear
    echo "================================================="
    echo "欢迎使用网络IP管理脚本 v$SCRIPT_VERSION"
    echo "1. 一键添加IPv4地址"
    echo "2. 一键添加IPv6地址"
    echo "3. 更新脚本"
    echo "4. 退出脚本"
    echo "================================================="
}

# 主程序
while true; do
    show_menu
    read -p "请输入选择: " choice

    case $choice in
        1)  # 添加IPv4
            check_root
            interface=$(detect_network_interface)
            read -p "请输入IPv4地址: " ip_address
            ip_type=$(check_ip_type $ip_address)
            if [ "$ip_type" == "IPv4" ]; then
                add_ipv4 $ip_address $interface
                restart_network_service
            else
                echo "无效的IPv4地址！"
            fi
            ;;
        2)  # 添加IPv6
            check_root
            interface=$(detect_network_interface)
            read -p "请输入IPv6地址: " ip_address
            ip_type=$(check_ip_type $ip_address)
            if [ "$ip_type" == "IPv6" ]; then
                add_ipv6 $ip_address $interface
                restart_network_service
            else
                echo "无效的IPv6地址！"
            fi
            ;;
        3)  # 更新脚本
            update_script
            ;;
        4)  # 退出
            echo "退出脚本。"
            exit 0
            ;;
        *)  # 无效选择
            echo "无效选择，请重新选择。"
            ;;
    esac
done
