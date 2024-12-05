#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志记录函数
log_action() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# 错误处理函数
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

# 检查root权限
check_root() {
    [[ $EUID -ne 0 ]] && error_exit "此脚本必须以root权限运行"
}

# 获取系统信息
get_system_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif command -v lsb_release &> /dev/null; then
        OS=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
        OS_VERSION=$(lsb_release -r | cut -d: -f2 | sed s/'^\t'//)
    else
        error_exit "无法识别操作系统"
    fi
    
    log_action "检测到系统: $OS $OS_VERSION"
}

# 系统更新和软件包安装
system_update_and_packages() {
    get_system_info
    
    case $OS in
        ubuntu|debian)
            apt update
            apt upgrade -y
            apt install -y curl wget vim git ufw fail2ban software-properties-common
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum update -y
            yum install -y curl wget vim git firewalld fail2ban epel-release
            ;;
        *)
            error_exit "不支持的操作系统: $OS"
            ;;
    esac
    
    log_action "系统更新和必要软件包安装完成"
}

# SSH安全配置
configure_ssh() {
    local new_port=${1:-22}
    
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # 修改SSH配置
    sed -i "s/^#*Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # 重启SSH服务
    systemctl restart sshd
    log_action "SSH配置已更新，端口修改为 $new_port"
}

# UFW防火墙配置
configure_ufw() {
    ufw --force enable
    ufw default deny
    
    # SSH端口放行
    ufw allow ssh
    
    log_action "UFW防火墙已启用"
}

# Fail2Ban配置
configure_fail2ban() {
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i 's/bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
    sed -i 's/findtime  = 10m/findtime  = 30m/' /etc/fail2ban/jail.local
    
    systemctl restart fail2ban
    log_action "Fail2Ban安全配置完成"
}

# 设置中国时区
set_timezone() {
    timedatectl set-timezone Asia/Shanghai
    log_action "系统时区已设置为中国时区"
}

# 配置和管理SWAP
configure_swap() {
    echo -e "${GREEN}SWAP空间管理${NC}"
    echo "1. 创建SWAP"
    echo "2. 删除SWAP"
    read -p "$(echo -e "${YELLOW}请选择操作：${NC}")" swap_choice

    case $swap_choice in
        1)
            # 创建SWAP
            read -p "$(echo -e "${YELLOW}请输入SWAP大小(MB)：${NC}")" swap_size
            
            # 检查是否已存在swapfile
            if [ -f /swapfile ]; then
                echo -e "${RED}警告：已存在swapfile，请先删除现有SWAP${NC}"
                return
            fi
            
            # 创建SWAP文件
            fallocate -l ${swap_size}M /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            
            # 永久生效
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
            fi
            
            log_action "SWAP空间已配置 ${swap_size}MB"
            ;;
        
        2)
            # 删除SWAP
            if [ ! -f /swapfile ]; then
                echo -e "${RED}未找到SWAP文件${NC}"
                return
            fi

            # 关闭SWAP
            swapoff /swapfile

            # 删除SWAP文件
            rm /swapfile

            # 从fstab中移除挂载记录
            sed -i '\|/swapfile|d' /etc/fstab

            log_action "SWAP空间已删除"
            ;;
        
        *)
            echo -e "${RED}无效的选择${NC}"
            ;;
    esac

    # 显示SWAP状态
    echo -e "${CYAN}当前SWAP状态:${NC}"
    free -h | grep Swap
}
# 宝塔面板安装
install_bt_panel() {
    echo -e "${GREEN}选择宝塔面板版本${NC}"
    echo "1. 宝塔正式版"
    echo "2. 宝塔破解版"
    read -p "$(echo -e "${YELLOW}请选择：${NC}")" bt_choice

    case $bt_choice in
        1)
            wget -O install_lts.sh https://download.bt.cn/install/install_lts.sh
            bash install_lts.sh ed8484bec
            ;;
        2)
            wget -O install_panel.sh http://io.bt.sb/install/install_panel.sh
            bash install_panel.sh
            ;;
        *) 
            error_exit "无效选择"
            ;;
    esac
}

# DD重装系统
reinstall_system() {
    read -p "$(echo -e "${RED}警告：重装系统将清除所有数据！是否继续？(y/n)：${NC}")" confirm
    
    [[ $confirm != [yY] ]] && return
    
    wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    bash reinstall.sh debian12
}

# BBR加速
install_bbr() {
    wget -N --no-check-certificate https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh
    chmod +x tcp.sh
    bash tcp.sh
}

# 主菜单
main_menu() {
    check_root

    while true; do
        clear
        echo -e "${GREEN}========== FUFU的小鸡综合管理脚本 ==========${NC}"
        echo -e "${RED}1. 系统更新与软件包安装${NC}"
        echo -e "${BLUE}2. SSH安全配置${NC}"
        echo -e "${YELLOW}3. UFW防火墙配置${NC}"
        echo -e "${PURPLE}4. Fail2Ban安全防护${NC}"
        echo -e "${CYAN}5. 设置中国时区${NC}"
        echo -e "${GREEN}6. SWAP空间配置${NC}"
        echo -e "${RED}7. 宝塔面板安装${NC}"
        echo -e "${BLUE}8. DD系统重装${NC}"
        echo -e "${YELLOW}9. BBR加速安装${NC}"
        echo -e "${PURPLE}0. 退出脚本${NC}"
        
        read -p "$(echo -e "${GREEN}请选择操作(0-9)：${NC}")" choice

        case $choice in
            1) system_update_and_packages ;;
            2) configure_ssh ;;
            3) configure_ufw ;;
            4) configure_fail2ban ;;
            5) set_timezone ;;
            6) configure_swap ;;
            7) install_bt_panel ;;
            8) reinstall_system ;;
            9) install_bbr ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效的选择，请重试${NC}" ;;
        esac

        read -p "$(echo -e "${GREEN}按Enter继续...${NC}")" pause
    done
}

# 启动主菜单
main_menu
