#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 系统检测与更新函数
system_detect_and_update() {
    echo -e "${BLUE}正在检测系统信息...${NC}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}无法确定操作系统类型${NC}"
        return 1
    fi

    echo -e "${GREEN}检测到系统: $OS $VERSION${NC}"

    case $OS in
        debian|ubuntu)
            apt update && apt upgrade -y
            ;;
        centos|rhel|fedora)
            yum update -y
            ;;
        *)
            echo -e "${RED}不支持的操作系统${NC}"
            return 1
    esac

    echo -e "${GREEN}系统更新完成！${NC}"
}

# 安装必要软件包
install_necessary_packages() {
    echo -e "${YELLOW}开始安装必要软件包...${NC}"
    
    case $OS in
        debian|ubuntu)
            apt install -y curl wget vim net-tools ufw fail2ban software-properties-common gnupg2
            ;;
        centos|rhel|fedora)
            yum install -y curl wget vim net-tools ufw fail2ban epel-release
            ;;
        *)
            echo -e "${RED}不支持的操作系统${NC}"
            return 1
    esac

    echo -e "${GREEN}必要软件包安装完成！${NC}"
}

# SSH端口修改
modify_ssh_port() {
    read -p "请输入新的SSH端口号(默认22): " NEW_SSH_PORT
    NEW_SSH_PORT=${NEW_SSH_PORT:-22}
    
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # 修改SSH配置
    sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    
    # 重启SSH服务
    systemctl restart ssh || systemctl restart sshd
    
    echo -e "${GREEN}SSH端口已修改为 $NEW_SSH_PORT${NC}"
}

# UFW防火墙高级管理
ufw_firewall_management() {
    while true; do
        echo -e "${PURPLE}===== UFW防火墙管理 =====${NC}"
        echo -e "${RED}1. 启用UFW${NC}"
        echo -e "${GREEN}2. 添加放行端口${NC}"
        echo -e "${YELLOW}3. 删除端口规则${NC}"
        echo -e "${BLUE}4. 查看当前规则${NC}"
        echo -e "${CYAN}0. 返回主菜单${NC}"
        
        read -p "请选择操作: " UFW_CHOICE
        
        case $UFW_CHOICE in
            1) 
                ufw enable
                echo -e "${GREEN}UFW已启用${NC}"
                ;;
            2)
                read -p "请输入要放行的端口号: " PORT
                ufw allow $PORT/tcp
                echo -e "${GREEN}已放行 $PORT 端口${NC}"
                ;;
            3)
                read -p "请输入要删除的端口号: " PORT
                ufw delete allow $PORT/tcp
                echo -e "${YELLOW}已删除 $PORT 端口规则${NC}"
                ;;
            4)
                ufw status
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
    done
}

# Fail2Ban快速配置
fail2ban_quick_config() {
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    
    echo -e "${YELLOW}选择Fail2Ban预设配置:${NC}"
    echo -e "${GREEN}1. SSH防护${NC}"
    echo -e "${BLUE}2. SSH+HTTP/HTTPS防护${NC}"
    echo -e "${RED}3. 全面防护${NC}"
    
    read -p "请选择配置类型(1-3): " FAIL2BAN_CHOICE
    
    case $FAIL2BAN_CHOICE in
        1)
            sed -i 's/port     = ssh/port     = '"$NEW_SSH_PORT"'/' /etc/fail2ban/jail.local
            sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
            ;;
        2)
            sed -i 's/port     = ssh/port     = '"$NEW_SSH_PORT"'/' /etc/fail2ban/jail.local
            sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
            
            # 启用HTTP/HTTPS防护
            sed -i 's/enabled  = false/enabled  = true/' /etc/fail2ban/jail.local
            ;;
        3)
            sed -i 's/port     = ssh/port     = '"$NEW_SSH_PORT"'/' /etc/fail2ban/jail.local
            sed -i 's/maxretry = 5/maxretry = 2/' /etc/fail2ban/jail.local
            
            # 全面防护规则
            sed -i 's/enabled  = false/enabled  = true/g' /etc/fail2ban/jail.local
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            return 1
    esac
    
    systemctl restart fail2ban
    echo -e "${GREEN}Fail2Ban配置完成${NC}"
}

# 修改时区为中国时区
set_china_timezone() {
    echo -e "${CYAN}选择中国时区:${NC}"
    echo -e "${GREEN}1. 上海 Asia/Shanghai${NC}"
    echo -e "${YELLOW}2. 北京 Asia/Beijing${NC}"
    echo -e "${BLUE}3. 重庆 Asia/Chongqing${NC}"
    echo -e "${PURPLE}4. 香港 Asia/Hong_Kong${NC}"
    
    read -p "请选择时区(1-4): " TIMEZONE_CHOICE
    
    case $TIMEZONE_CHOICE in
        1) timedatectl set-timezone Asia/Shanghai ;;
        2) timedatectl set-timezone Asia/Beijing ;;
        3) timedatectl set-timezone Asia/Chongqing ;;
        4) timedatectl set-timezone Asia/Hong_Kong ;;
        *) 
            echo -e "${RED}无效选择，默认为上海时区${NC}"
            timedatectl set-timezone Asia/Shanghai
            ;;
    esac
    
    echo -e "${GREEN}时区已设置完成${NC}"
}

# 添加SWAP（支持自定义大小）
add_swap() {
    echo -e "${YELLOW}SWAP添加选项:${NC}"
    echo -e "${GREEN}1. 固定大小SWAP${NC}"
    echo -e "${BLUE}2. 动态大小SWAP${NC}"
    
    read -p "请选择SWAP添加方式(1-2): " SWAP_TYPE
    
    case $SWAP_TYPE in
        1)
            read -p "请输入固定SWAP大小(单位:G,默认2G): " SWAP_SIZE
            SWAP_SIZE=${SWAP_SIZE:-2}
            ;;
        2)
            # 根据系统内存动态分配
            TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
            SWAP_SIZE=$((TOTAL_MEM * 2))
            ;;
        *)
            echo -e "${RED}无效选择，使用默认2G${NC}"
            SWAP_SIZE=2
            ;;
    esac
    
    dd if=/dev/zero of=/swapfile bs=1G count=$SWAP_SIZE
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    echo -e "${GREEN}SWAP已添加 ${SWAP_SIZE}G${NC}"
}

# 宝塔面板安装
install_bt_panel() {
    echo -e "${YELLOW}选择宝塔面板安装类型:${NC}"
    echo -e "${GREEN}1. 正式版${NC}"
    echo -e "${RED}2. 破解版${NC}"
    read -p "请选择(1/2): " BT_TYPE

    case $BT_TYPE in
        1)
            url=https://download.bt.cn/install/install_lts.sh
            if [ -f /usr/bin/curl ]; then
                curl -sSO $url
            else
                wget -O install_lts.sh $url
            fi
            bash install_lts.sh ed8484bec
            ;;
        2)
            if [ -f /usr/bin/curl ]; then
                curl -sSO http://io.bt.sb/install/install_panel.sh
            else
                wget -O install_panel.sh http://io.bt.sb/install/install_panel.sh
            fi
            bash install_panel.sh
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# DD重装系统
reinstall_system() {
    read -p "请选择要重装的系统(如debian12): " SYSTEM_TYPE
    
    curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O reinstall.sh $_
    bash reinstall.sh $SYSTEM_TYPE
}

# 主菜单
main_menu() {
    while true; do
        echo -e "${CYAN}========= 全面系统配置与安装工具 =========${NC}"
        echo -e "${RED}1. 系统检测与更新${NC}"
        echo -e "${GREEN}2. 安装必要软件包${NC}"
        echo -e "${YELLOW}3. 修改SSH端口${NC}"
        echo -e "${BLUE}4. UFW防火墙管理${NC}"
        echo -e "${PURPLE}5. Fail2Ban安全配置${NC}"
        echo -e "${CYAN}6. 修改中国时区${NC}"
        echo -e "${RED}7. 添加SWAP${NC}"
        echo -e "${GREEN}8. 安装宝塔面板${NC}"
        echo -e "${YELLOW}9. DD重装系统${NC}"
        echo -e "${BLUE}0. 退出${NC}"
        
        read -p "请选择操作(0-9): " CHOICE
        
        case $CHOICE in
            1) system_detect_and_update ;;
            2) install_necessary_packages ;;
            3) modify_ssh_port ;;
            4) ufw_firewall_management ;;
            5) fail2ban_quick_config ;;
            6) set_china_timezone ;;
            7) add_swap ;;
            8) install_bt_panel ;;
            9) reinstall_system ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}" ;;
        esac
        
        read -p "按回车键继续..." CONTINUE
    done
}

# 以root权限检查
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}此脚本必须以root权限运行${NC}" 
   exit 1
fi

# 脚本入口
main_menu