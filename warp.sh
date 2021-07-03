#!/usr/bin/env bash
#
# https://github.com/P3TERX/warp.sh
# Description: Cloudflare WARP configuration script
# System Required: Debian, Ubuntu, CentOS
# Version: beta7
#
# MIT License
#
# Copyright (c) 2021 P3TERX <https://p3terx.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

shVersion='beta7'
FontColor_Red="\033[31m"
FontColor_Green="\033[32m"
FontColor_LightYellow="\033[1;33m"
FontColor_LightPurple="\033[1;35m"
FontColor_Suffix="\033[0m"
MSG_info="[${FontColor_Green}INFO${FontColor_Suffix}]"
MSG_error="[${FontColor_Red}ERROR${FontColor_Suffix}]"
MSG_warn="[${FontColor_LightYellow}WARN${FontColor_Suffix}]"

if [[ $(uname -s) != Linux ]]; then
    echo -e "${MSG_error} This operating system is not supported."
    exit 1
fi

if [[ $(id -u) != 0 ]]; then
    echo -e "${MSG_error} This script must be run as root."
    exit 1
fi

if [[ -z $(command -v curl) ]]; then
    echo -e "${MSG_error} cURL is not installed."
    exit 1
fi

OS_ID=$(cat /etc/os-release | grep ^ID=)
WireGuardConfPath='/etc/wireguard/wgcf.conf'
WGCF_Profile='wgcf-profile.conf'
WGCF_SavePath="${HOME}/.wgcf"
WGCF_Profile_Path="${WGCF_SavePath}/${WGCF_Profile}"
WGCF_DNS_46='8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844'
WGCF_DNS_64='2001:4860:4860::8888,2001:4860:4860::8844,8.8.8.8,8.8.4.4'
WGCF_Endpoint_IPv4='162.159.192.1:2408'
WGCF_Endpoint_IPv6='[2606:4700:d0::a29f:c001]:2408'
WGCF_Endpoint_Domain='engage.cloudflareclient.com:2408'
WGCF_AllowedIPs_IPv4='0.0.0.0/0'
WGCF_AllowedIPs_IPv6='::/0'
WGCF_AllowedIPs_DualStack='0.0.0.0/0,::/0'
TestIPv4_1='8.8.8.8'
TestIPv4_2='9.9.9.9'
TestIPv6_1='2001:4860:4860::8888'
TestIPv6_2='2620:fe::fe'

Install_Requirements_Debian() {
    if [[ ! $(command -v lsb_release) ]]; then
        apt update
        apt install lsb-release -y
    fi
    if [[ ! $(command -v gpg) ]]; then
        apt update
        apt install gnupg -y
    fi
    if [[ ! $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]]; then
        apt update
        apt install apt-transport-https -y
    fi
}

Instal_WARP_Client_Debian() {
    Install_Requirements_Debian
    curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
    echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt update
    apt install cloudflare-warp -y
}

Instal_WARP_Client_Ubuntu() {
    Install_Requirements_Debian
    curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
    #echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    echo "deb http://pkg.cloudflareclient.com/ focal main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt update
    apt install cloudflare-warp -y
}

Instal_WARP_Client_CentOS() {
    CentOS_Version=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\..*/\1/')
    rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el${CentOS_Version}.rpm
    if [[ $? = 0 ]]; then
        yum install cloudflare-warp -y
    else
        echo -e "${MSG_error} This operating system is not supported."
        exit 1
    fi
}

Check_WARP_Client() {
    WARP_Client_Status=$(systemctl is-active warp-svc)
    WARP_Client_SelfStart=$(systemctl is-enabled warp-svc 2>/dev/null)
}

Instal_WARP_Client() {
    echo -e "${MSG_info} Installing Cloudflare WARP Client..."
    case ${OS_ID} in
    *debian*)
        Instal_WARP_Client_Debian
        ;;
    *ubuntu*)
        Instal_WARP_Client_Ubuntu
        ;;
    *centos* | *rhel*)
        Instal_WARP_Client_CentOS
        ;;
    *)
        echo -e "${MSG_error} This operating system is not supported."
        exit 1
        ;;
    esac
    Check_WARP_Client
    if [[ ${WARP_Client_Status} = active ]]; then
        echo -e "${MSG_info} Cloudflare WARP Client installed successfully!"
    else
        echo -e "${MSG_error} warp-svc failure to run!"
        journalctl -u warp-svc --no-pager
        exit 1
    fi
}

Uninstall_WARP_Client() {
    echo -e "${MSG_info} Uninstalling Cloudflare WARP Client..."
    case ${OS_ID} in
    *debian* | *ubuntu*)
        apt purge cloudflare-warp -y
        ;;
    *centos* | *rhel*)
        yum remove cloudflare-warp -y
        ;;
    *)
        echo -e "${MSG_error} This operating system is not supported."
        exit 1
        ;;
    esac
}

Init_WARP_Client() {
    Check_WARP_Client
    if [[ ${WARP_Client_SelfStart} != enabled || ${WARP_Client_Status} != active ]]; then
        Instal_WARP_Client
    fi
    yes | warp-cli
    if [[ $(warp-cli account) = MissingRegistration ]]; then
        echo -e "${MSG_info} Cloudflare WARP Account Registration in progress..."
        warp-cli register
    fi
}

Connect_WARP() {
    echo -e "${MSG_info} Connecting to WARP..."
    warp-cli connect
    echo -e "${MSG_info} Enable WARP Always-On..."
    warp-cli enable-always-on
}

Disconnect_WARP() {
    echo -e "${MSG_info} Disable WARP Always-On..."
    warp-cli disable-always-on
    echo -e "${MSG_info} Disconnect from WARP..."
    warp-cli disconnect
}

Set_WARP_Mode_Proxy() {
    echo -e "${MSG_info} Setting up WARP Proxy Mode..."
    warp-cli set-mode proxy
}

Enable_WARP_Client_Proxy() {
    Init_WARP_Client
    Set_WARP_Mode_Proxy
    Connect_WARP
    Print_WARP_Client_Status
}

Get_WARP_Proxy_Port() {
    WARP_Proxy_Port='40000'
}

Print_Delimiter() {
    printf '=%.0s' $(seq $(tput cols))
    echo
}

Install_wgcf() {
    curl -fsSL git.io/wgcf.sh | bash
}

Uninstall_wgcf() {
    rm -f /usr/local/bin/wgcf
}

Register_WARP_Account() {
    while [[ ! -f wgcf-account.toml ]]; do
        Install_wgcf
        echo -e "${MSG_info} Cloudflare WARP Account registration in progress..."
        yes | wgcf register
        sleep 5
    done
}

Generate_WGCF_Profile() {
    while [[ ! -f ${WGCF_Profile} ]]; do
        Register_WARP_Account
        echo -e "${MSG_info} WARP WireGuard profile (wgcf-profile.conf) generation in progress..."
        wgcf generate
    done
}

Backup_WGCF_Profile() {
    mkdir -p ${WGCF_SavePath}
    mv -f wgcf* ${WGCF_SavePath}
}

Read_WGCF_Profile() {
    WGCF_PrivateKey=$(cat ${WGCF_Profile_Path} | grep ^PrivateKey | cut -d= -f2- | awk '$1=$1')
    WGCF_Address=$(cat ${WGCF_Profile_Path} | grep ^Address | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    WGCF_PublicKey=$(cat ${WGCF_Profile_Path} | grep ^PublicKey | cut -d= -f2- | awk '$1=$1')
}

Load_WGCF_Profile() {
    if [[ -f ${WGCF_Profile} ]]; then
        Backup_WGCF_Profile
        Read_WGCF_Profile
    elif [[ -f ${WGCF_Profile_Path} ]]; then
        Read_WGCF_Profile
    else
        Generate_WGCF_Profile
        Backup_WGCF_Profile
        Read_WGCF_Profile
    fi
}

Install_WireGuardTools_Debian() {
    if [[ ! $(command -v lsb_release) ]]; then
        apt update
        apt install lsb-release -y
    fi
    DebianVer=$(lsb_release -sr | cut -d. -f1)
    case ${DebianVer} in
    10)
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ;;
    9)
        echo "deb http://deb.debian.org/debian/ unstable main" | tee /etc/apt/sources.list.d/unstable.list
        echo -e "Package: *\nPin: release a=unstable\nPin-Priority: 150\n" | tee /etc/apt/preferences.d/limit-unstable
        ;;
    *)
        if [[ ${DebianVer} -lt 9 ]]; then
            echo -e "${MSG_error} This operating system is not supported."
            exit 1
        fi
        ;;
    esac
    apt update
    apt install iproute2 openresolv -y
    apt install wireguard-tools --no-install-recommends -y
}

Install_WireGuardTools_Ubuntu() {
    apt update
    apt install iproute2 openresolv -y
    apt install wireguard-tools --no-install-recommends -y
}

Install_WireGuardTools_CentOS() {
    yum install epel-release -y
    yum install iproute wireguard-tools -y
}

Install_WireGuardTools_Fedora() {
    dnf install iproute openresolv wireguard-tools -y
    chmod +x /usr/sbin/resolvconf.openresolv
}

Install_WireGuardTools_Arch() {
    pacman -Sy iproute2 openresolv wireguard-tools --noconfirm
}

Install_WireGuardTools() {
    echo -e "${MSG_info} Installing wireguard-tools..."
    case ${OS_ID} in
    *debian*)
        Install_WireGuardTools_Debian
        ;;
    *ubuntu*)
        Install_WireGuardTools_Ubuntu
        ;;
    *centos* | *rhel*)
        Install_WireGuardTools_CentOS
        ;;
    *fedora*)
        Install_WireGuardTools_Fedora
        ;;
    *arch*)
        Install_WireGuardTools_Arch
        ;;
    *)
        echo -e "${MSG_error} This operating system is not supported."
        exit 1
        ;;
    esac
}

Install_WireGuardGo() {
    KernelVer1=$(uname -r | awk -F . '{print $1}')
    KernelVer2=$(uname -r | awk -F . '{print $2}')
    if [[ ${KernelVer1} -lt 5 || ${KernelVer2} -lt 6 ]]; then
        curl -fsSL git.io/wireguard-go.sh | bash
    fi
}

Check_WireGuard() {
    WireGuard_Status=$(systemctl is-active wg-quick@wgcf)
    WireGuard_SelfStart=$(systemctl is-enabled wg-quick@wgcf 2>/dev/null)
}

Install_WireGuard() {
    Check_WireGuard
    if [[ ${WireGuard_SelfStart} != enabled || ${WireGuard_Status} != active ]]; then
        Install_WireGuardTools
        Install_WireGuardGo
    fi
}

Start_WireGuard() {
    Check_WARP_Client
    echo -e "${MSG_info} Starting WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl enable wg-quick@wgcf --now
        systemctl start warp-svc
    else
        systemctl enable wg-quick@wgcf --now
    fi
    echo -e "${MSG_info} Done."
}

Restart_WireGuard() {
    Check_WARP_Client
    echo -e "${MSG_info} Restarting WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl restart wg-quick@wgcf
        systemctl start warp-svc
    else
        systemctl restart wg-quick@wgcf
    fi
    echo -e "${MSG_info} Done."
}

Enable_IPv6_Support() {
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ]]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi
}

Enable_WireGuard() {
    Enable_IPv6_Support
    Check_WireGuard
    if [[ ${WireGuard_SelfStart} = enabled ]]; then
        Restart_WireGuard
    else
        Start_WireGuard
    fi
    Check_WireGuard
    if [[ ${WireGuard_Status} = active ]]; then
        echo -e "${MSG_info} WireGuard is running!"
    else
        echo -e "${MSG_error} WireGuard failure to run!"
        journalctl -u wg-quick@wgcf --no-pager
        exit 1
    fi
}

Stop_WireGuard() {
    Check_WARP_Client
    echo -e "${MSG_info} Stoping WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl stop wg-quick@wgcf
        systemctl start warp-svc
    else
        systemctl stop wg-quick@wgcf
    fi
    echo -e "${MSG_info} Done."
}

Disable_WireGuard() {
    Check_WARP_Client
    echo -e "${MSG_info} Disabling WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl disable wg-quick@wgcf --now
        systemctl start warp-svc
    else
        systemctl disable wg-quick@wgcf --now
    fi
    echo -e "${MSG_info} Done."
}

Print_WireGuard_Log() {
    journalctl -u wg-quick@wgcf -f
}

Check_Network_Status_IPv4() {
    if ping -c1 ${TestIPv4_1} >/dev/null 2>&1 || ping -c1 ${TestIPv4_2} >/dev/null 2>&1; then
        IPv4Status='on'
    else
        IPv4Status='off'
    fi
}

Check_Network_Status_IPv6() {
    if ping6 -c1 ${TestIPv6_1} >/dev/null 2>&1 || ping6 -c1 ${TestIPv6_2} >/dev/null 2>&1; then
        IPv6Status='on'
    else
        IPv6Status='off'
    fi
}

Check_Network_Status() {
    Disable_WireGuard
    Check_Network_Status_IPv4
    Check_Network_Status_IPv6
}

Check_IPv4_addr() {
    Interface=$(ip -4 r | awk '/^def/{print $5}')
    IPv4_addr=$(ip -4 -o addr show dev ${Interface} | awk '{print $4}' | cut -d'/' -f1 | head -1)
}

Check_IPv6_addr() {
    Interface=$(ip -6 r | awk '/^def/{print $5}')
    IPv6_addr=$(ip -6 -o addr show dev ${Interface} | awk '{print $4}' | cut -d'/' -f1 | head -1)
}

Get_IP_addr() {
    Check_Network_Status
    if [[ ${IPv4Status} = on ]]; then
        echo -e "${MSG_info} Checking IPv4 Address..."
        Check_IPv4_addr
        echo -e "${MSG_info} IPv4 Address: ${FontColor_LightPurple}${IPv4_addr}${FontColor_Suffix}"
    fi
    if [[ ${IPv6Status} = on ]]; then
        echo -e "${MSG_info} Checking IPv6 Address..."
        Check_IPv6_addr
        echo -e "${MSG_info} IPv6 Address: ${FontColor_LightPurple}${IPv6_addr}${FontColor_Suffix}"
    fi
}

Get_IPv4_addr() {
    echo -e "${MSG_info} 正在检测 IPv4 地址..."
    Check_IPv4_addr
    if [[ -z ${IPv4_addr} ]]; then
        echo -e "${MSG_error} IPv4 地址自动检测失败！"
        Input_IPv4_addr
    else
        echo -e "${MSG_info} 检测到 IPv4 地址：${FontColor_LightPurple}${IPv4_addr}${FontColor_Suffix}"
        unset answer_YN
        read -p "是否需要修改？[y/N] " answer_YN
        case ${answer_YN:-n} in
        Y | y)
            Input_IPv4_addr
            ;;
        N | n)
            echo
            ;;
        *)
            echo -e "${MSG_error} 无效输入！"
            Get_IPv4_addr
            ;;
        esac
    fi
}

Get_IPv6_addr() {
    echo -e "${MSG_info} 正在检测 IPv6 地址..."
    Check_IPv6_addr
    if [[ -z ${IPv6_addr} ]]; then
        echo -e "${MSG_error} IPv6 地址自动检测失败！"
        Input_IPv6_addr
    else
        echo -e "${MSG_info} 检测到 IPv6 地址：${FontColor_LightPurple}${IPv6_addr}${FontColor_Suffix}"
        unset answer_YN
        read -p "是否需要修改？[y/N] " answer_YN
        case ${answer_YN:-n} in
        Y | y)
            Input_IPv6_addr
            ;;
        N | n)
            echo
            ;;
        *)
            echo -e "${MSG_error} 无效输入！"
            Get_IPv6_addr
            ;;
        esac
    fi
}

Input_IPv4_addr() {
    read -p "请输入 IPv4 地址：" IPv4_addr
    if [[ -z ${IPv4_addr} ]]; then
        echo -e "${MSG_error} 无效输入！"
        Get_IPv4_addr
    fi
}

Input_IPv6_addr() {
    read -p "请输入 IPv6 地址：" IPv6_addr
    if [[ -z ${IPv6_addr} ]]; then
        echo -e "${MSG_error} 无效输入！"
        Get_IPv6_addr
    fi
}

Generate_WireGuardProfile_Interface() {
    echo -e "${MSG_info} WireGuard profile (${WireGuardConfPath}) generation in progress..."
    cat <<EOF >${WireGuardConfPath}
[Interface]
PrivateKey = ${WGCF_PrivateKey}
Address = ${WGCF_Address}
DNS = ${WGCF_DNS}
MTU = 1280
EOF
}

Generate_WireGuardProfile_Interface_IPv4Rule() {
    cat <<EOF >>${WireGuardConfPath}
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Interface_IPv6Rule() {
    cat <<EOF >>${WireGuardConfPath}
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Peer() {
    cat <<EOF >>${WireGuardConfPath}
[Peer]
PublicKey = ${WGCF_PublicKey}
AllowedIPs = ${WGCF_AllowedIPs}
Endpoint = ${WGCF_Endpoint}
EOF
}

Check_WARP_Client_Status() {
    Check_WARP_Client
    case ${WARP_Client_Status} in
    active)
        WARP_Client_Status_en="${FontColor_Green}Running${FontColor_Suffix}"
        WARP_Client_Status_zh="${FontColor_Green}运行中${FontColor_Suffix}"
        ;;
    *)
        WARP_Client_Status_en="${FontColor_Red}Stopped${FontColor_Suffix}"
        WARP_Client_Status_zh="${FontColor_Red}未运行${FontColor_Suffix}"
        ;;
    esac
}

Check_WARP_Proxy_Status() {
    Get_WARP_Proxy_Port
    WARP_Proxy_Status=$(curl -sx "socks5h://127.0.0.1:${WARP_Proxy_Port}" https://www.cloudflare.com/cdn-cgi/trace | grep warp | cut -d= -f2)
    case ${WARP_Proxy_Status} in
    on)
        WARP_Proxy_Status_en="${FontColor_Green}On${FontColor_Suffix}"
        WARP_Proxy_Status_zh="${FontColor_Green}已开启${FontColor_Suffix}"
        ;;
    plus)
        WARP_Proxy_Status_en="${FontColor_Green}On(WARP+)${FontColor_Suffix}"
        WARP_Proxy_Status_zh="${FontColor_Green}已开启(WARP+)${FontColor_Suffix}"
        ;;
    *)
        WARP_Proxy_Status_en="${FontColor_Red}Off${FontColor_Suffix}"
        WARP_Proxy_Status_zh="${FontColor_Red}未开启${FontColor_Suffix}"
        ;;
    esac
}

Check_WireGuard_Status() {
    Check_WireGuard
    case ${WireGuard_Status} in
    active)
        WireGuard_Status_en="${FontColor_Green}Running${FontColor_Suffix}"
        WireGuard_Status_zh="${FontColor_Green}运行中${FontColor_Suffix}"
        ;;
    *)
        WireGuard_Status_en="${FontColor_Red}Stopped${FontColor_Suffix}"
        WireGuard_Status_zh="${FontColor_Red}未运行${FontColor_Suffix}"
        ;;
    esac
}

Check_WARP_WireGuard_Status() {
    WARP_IPv4_Status=$(curl -s4 https://www.cloudflare.com/cdn-cgi/trace | grep warp | cut -d= -f2)
    case ${WARP_IPv4_Status} in
    on)
        WARP_IPv4_Status_en="${FontColor_Green}WARP${FontColor_Suffix}"
        WARP_IPv4_Status_zh="${WARP_IPv4_Status_en}"
        ;;
    plus)
        WARP_IPv4_Status_en="${FontColor_Green}WARP+${FontColor_Suffix}"
        WARP_IPv4_Status_zh="${WARP_IPv4_Status_en}"
        ;;
    off)
        WARP_IPv4_Status_en="Normal"
        WARP_IPv4_Status_zh="正常"
        ;;
    *)
        WARP_IPv4_Status_en="${FontColor_Red}Unconnected${FontColor_Suffix}"
        WARP_IPv4_Status_zh="${FontColor_Red}未连接${FontColor_Suffix}"
        ;;
    esac
    WARP_IPv6_Status=$(curl -s6 https://www.cloudflare.com/cdn-cgi/trace | grep warp | cut -d= -f2)
    case ${WARP_IPv6_Status} in
    on)
        WARP_IPv6_Status_en="${FontColor_Green}WARP${FontColor_Suffix}"
        WARP_IPv6_Status_zh="${WARP_IPv6_Status_en}"
        ;;
    plus)
        WARP_IPv6_Status_en="${FontColor_Green}WARP+${FontColor_Suffix}"
        WARP_IPv6_Status_zh="${WARP_IPv6_Status_en}"
        ;;
    off)
        WARP_IPv6_Status_en="Normal"
        WARP_IPv6_Status_zh="正常"
        ;;
    *)
        WARP_IPv6_Status_en="${FontColor_Red}Unconnected${FontColor_Suffix}"
        WARP_IPv6_Status_zh="${FontColor_Red}未连接${FontColor_Suffix}"
        ;;
    esac
}

Check_ALL_Status() {
    Check_WARP_Client_Status
    Check_WARP_Proxy_Status
    Check_WireGuard_Status
    Check_WARP_WireGuard_Status
}

Print_WARP_Client_Status() {
    Check_WARP_Client_Status
    Check_WARP_Proxy_Status
    echo -e "
 ------------------------
 WARP Client\t: ${WARP_Client_Status_en}
 SOCKS5 Status\t: ${WARP_Proxy_Status_en}
 ------------------------
"
}

Print_WARP_WireGuard_Status() {
    Check_WireGuard_Status
    Check_WARP_WireGuard_Status
    echo -e "
 ------------------------
 WireGuard\t: ${WireGuard_Status_en}
 IPv4 Network\t: ${WARP_IPv4_Status_en}
 IPv6 Network\t: ${WARP_IPv6_Status_en}
 ------------------------
"
}

Print_ALL_Status() {
    Check_ALL_Status
    echo -e "
 ------------------------
 WARP Client\t: ${WARP_Client_Status_en}
 SOCKS5 Status\t: ${WARP_Proxy_Status_en}
 ------------------------
 WireGuard\t: ${WireGuard_Status_en}
 IPv4 Network\t: ${WARP_IPv4_Status_en}
 IPv6 Network\t: ${WARP_IPv6_Status_en}
 ------------------------
"
}

Print_ALL_Status_menu() {
    echo -e " -----------------------
 WARP 客户端\t: ${WARP_Client_Status_zh}
 SOCKS5 状态\t: ${WARP_Proxy_Status_zh}
 -----------------------
 WireGuard 状态\t: ${WireGuard_Status_zh}
 IPv4 网络状态\t: ${WARP_IPv4_Status_zh}
 IPv6 网络状态\t: ${WARP_IPv6_Status_zh}
 -----------------------
"
}

View_WireGuard_Profile() {
    Print_Delimiter
    cat ${WireGuardConfPath}
    Print_Delimiter
}

Set_WARP_IPv4() {
    Install_WireGuard
    Get_IP_addr
    Load_WGCF_Profile
    if [[ ${IPv4Status} = on ]]; then
        WGCF_DNS="${WGCF_DNS_46}"
    else
        WGCF_DNS="${WGCF_DNS_64}"
    fi
    WGCF_AllowedIPs="${WGCF_AllowedIPs_IPv4}"
    WGCF_Endpoint="${WGCF_Endpoint_Domain}"
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv4_addr} ]]; then
        Generate_WireGuardProfile_Interface_IPv4Rule
    fi
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Set_WARP_IPv6() {
    Install_WireGuard
    Get_IP_addr
    Load_WGCF_Profile
    if [[ ${IPv4Status} = on ]]; then
        WGCF_DNS="${WGCF_DNS_46}"
    else
        WGCF_DNS="${WGCF_DNS_64}"
    fi
    WGCF_AllowedIPs="${WGCF_AllowedIPs_IPv6}"
    WGCF_Endpoint="${WGCF_Endpoint_Domain}"
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv6_addr} ]]; then
        Generate_WireGuardProfile_Interface_IPv6Rule
    fi
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Set_WARP_DualStack() {
    Install_WireGuard
    Get_IP_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_46}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_DualStack}"
    WGCF_Endpoint="${WGCF_Endpoint_Domain}"
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv4_addr} ]]; then
        Generate_WireGuardProfile_Interface_IPv4Rule
    fi
    if [[ -n ${IPv6_addr} ]]; then
        Generate_WireGuardProfile_Interface_IPv6Rule
    fi
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Add_WARP_IPv4__Change_WARP_IPv6() {
    Install_WireGuard
    Get_IPv6_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_64}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_DualStack}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv6}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv6Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Add_WARP_IPv6__Change_WARP_IPv4() {
    Install_WireGuard
    Get_IPv4_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_46}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_DualStack}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv4}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv4Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Change_WARP_IPv6() {
    Install_WireGuard
    Get_IPv6_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_46}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_IPv6}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv6}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv6Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Change_WARP_IPv4() {
    Install_WireGuard
    Get_IPv4_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_64}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_IPv4}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv4}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv4Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Change_WARP_DualStack_IPv4Out() {
    Install_WireGuard
    Get_IPv4_addr
    Get_IPv6_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_46}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_DualStack}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv4}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv4Rule
    Generate_WireGuardProfile_Interface_IPv6Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Change_WARP_DualStack_IPv6Out() {
    Install_WireGuard
    Get_IPv4_addr
    Get_IPv6_addr
    Load_WGCF_Profile
    WGCF_DNS="${WGCF_DNS_46}"
    WGCF_AllowedIPs="${WGCF_AllowedIPs_DualStack}"
    WGCF_Endpoint="${WGCF_Endpoint_IPv6}"
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_IPv4Rule
    Generate_WireGuardProfile_Interface_IPv6Rule
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Menu_DualStack() {
    clear
    echo -e "
${FontColor_LightYellow}Cloudflare WARP 一键配置脚本${FontColor_Suffix} ${FontColor_Red}[${shVersion}]${FontColor_Suffix} by ${FontColor_LightPurple}P3TERX.COM${FontColor_Suffix}

 ${FontColor_Green}0.${FontColor_Suffix} 返回主菜单
 -
 ${FontColor_Green}1.${FontColor_Suffix} 置换 IPv4 为 WARP 网络
 ${FontColor_Green}2.${FontColor_Suffix} 置换 IPv6 为 WARP 网络
 ${FontColor_Green}3.${FontColor_Suffix} 置换 IPv4/IPv6 为 WARP 网络 (IPv4 节点)
 ${FontColor_Green}4.${FontColor_Suffix} 置换 IPv4/IPv6 为 WARP 网络 (IPv6 节点)
 ${FontColor_Green}5.${FontColor_Suffix} 添加 WARP IPv4 网络，置换 IPv6 为 WARP 网络
 ${FontColor_Green}6.${FontColor_Suffix} 添加 WARP IPv6 网络，置换 IPv4 为 WARP 网络
"
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    0)
        Start_Menu
        ;;
    1)
        Change_WARP_IPv4
        ;;
    2)
        Change_WARP_IPv6
        ;;
    3)
        Change_WARP_DualStack_IPv4Out
        ;;
    4)
        Change_WARP_DualStack_IPv6Out
        ;;
    5)
        Add_WARP_IPv4__Change_WARP_IPv6
        ;;
    6)
        Add_WARP_IPv6__Change_WARP_IPv4
        ;;
    *)
        echo -e "${MSG_error} 无效输入！"
        sleep 2s
        Menu_DualStack
        ;;
    esac
}

Menu_Other() {
    clear
    echo -e "
${FontColor_LightYellow}Cloudflare WARP 一键配置脚本${FontColor_Suffix} ${FontColor_Red}[${shVersion}]${FontColor_Suffix} by ${FontColor_LightPurple}P3TERX.COM${FontColor_Suffix}

 ${FontColor_Green}0.${FontColor_Suffix} 返回主菜单
 -
 ${FontColor_Green}1.${FontColor_Suffix} 关闭 WARP 官方客户端 SOCKS5 代理
 ${FontColor_Green}2.${FontColor_Suffix} 卸载 WARP 官方客户端
 -
 ${FontColor_Green}3.${FontColor_Suffix} 查看 WARP WireGuard 日志
 ${FontColor_Green}4.${FontColor_Suffix} 重启 WARP WireGuard 服务
 ${FontColor_Green}5.${FontColor_Suffix} 停止 WARP WireGuard 服务
 ${FontColor_Green}6.${FontColor_Suffix} 关闭 WARP WireGuard 网络
"
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    0)
        Start_Menu
        ;;
    1)
        Disconnect_WARP
        ;;
    2)
        Uninstall_WARP_Client
        ;;
    3)
        Print_WireGuard_Log
        ;;
    4)
        Restart_WireGuard
        ;;
    5)
        Stop_WireGuard
        ;;
    6)
        Disable_WireGuard
        ;;
    *)
        echo -e "${MSG_error} 无效输入！"
        sleep 2s
        Menu_Other
        ;;
    esac
}

Start_Menu() {
    echo -e "${MSG_info} 正在检查状态..."
    Check_ALL_Status
    clear
    echo -e "
${FontColor_LightYellow}Cloudflare WARP 一键配置脚本${FontColor_Suffix} ${FontColor_Red}[${shVersion}]${FontColor_Suffix} by ${FontColor_LightPurple}P3TERX.COM${FontColor_Suffix}

 ${FontColor_Green}1.${FontColor_Suffix} 自动配置 WARP 官方客户端 SOCKS5 代理
 ${FontColor_Green}2.${FontColor_Suffix} 自动配置 WARP WireGuard IPv4 网络
 ${FontColor_Green}3.${FontColor_Suffix} 自动配置 WARP WireGuard IPv6 网络
 ${FontColor_Green}4.${FontColor_Suffix} 自动配置 WARP WireGuard 双栈全局网络
 ${FontColor_Green}5.${FontColor_Suffix} 手动选择 WARP WireGuard 双栈配置方案
 ${FontColor_Green}6.${FontColor_Suffix} 其它选项
"
    Print_ALL_Status_menu
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    1)
        Enable_WARP_Client_Proxy
        ;;
    2)
        Set_WARP_IPv4
        ;;
    3)
        Set_WARP_IPv6
        ;;
    4)
        Set_WARP_DualStack
        ;;
    5)
        Menu_DualStack
        ;;
    6)
        Menu_Other
        ;;
    *)
        echo -e "${MSG_error} 无效输入！"
        sleep 2s
        Start_Menu
        ;;
    esac
}

Print_Usage() {
    echo -e "
Cloudflare WARP configuration script

USAGE:
    bash <(curl -fsSL git.io/warp.sh) [SUBCOMMAND]

SUBCOMMANDS:
    install         Install Cloudflare WARP Official Linux Client
    uninstall       uninstall Cloudflare WARP Official Linux Client
    proxy           Enable WARP Client Proxy Mode (default SOCKS5 port: 40000)
    unproxy         Disable WARP Client Proxy Mode
    wg4             Configuration WARP IPv4 Network interface (with WireGuard)
    wg6             Configuration WARP IPv6 Network interface (with WireGuard)
    wgd             Configuration WARP Dual Stack Network interface (with WireGuard)
    rewg            Restart WARP WireGuard service
    unwg            Disable WARP WireGuard service
    status          Prints status information
    version         Prints version information
    help            Prints this message or the help of the given subcommand(s)
    menu            Chinese special features menu
"
}

if [ $# -ge 1 ]; then
    case ${1} in
    install)
        Instal_WARP_Client
        ;;
    uninstall)
        Uninstall_WARP_Client
        ;;
    proxy | socks5 | s5)
        Enable_WARP_Client_Proxy
        ;;
    unproxy | unsocks5 | uns5)
        Disconnect_WARP
        ;;
    4 | wg4)
        Set_WARP_IPv4
        ;;
    6 | wg6)
        Set_WARP_IPv6
        ;;
    d | wgd)
        Set_WARP_DualStack
        ;;
    rewg)
        Restart_WireGuard
        ;;
    unwg)
        Disable_WireGuard
        ;;
    status)
        Print_ALL_Status
        ;;
    help)
        Print_Usage
        ;;
    version)
        echo "${shVersion}"
        ;;
    menu)
        Start_Menu
        ;;
    *)
        echo -e "${MSG_error} Invalid Parameters: $*"
        Print_Usage
        exit 1
        ;;
    esac
else
    Print_Usage
fi
