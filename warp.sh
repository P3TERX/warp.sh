#!/usr/bin/env bash
#
# https://github.com/P3TERX/warp.sh
# Description: Cloudflare WARP Installer
# System Required: Debian, Ubuntu, Fedora, CentOS, Oracle Linux, Arch Linux
# Version: beta39
#
# MIT License
#
# Copyright (c) 2021-2022 P3TERX <https://p3terx.com>
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

shVersion='beta39'

FontColor_Red="\033[31m"
FontColor_Red_Bold="\033[1;31m"
FontColor_Green="\033[32m"
FontColor_Green_Bold="\033[1;32m"
FontColor_Yellow="\033[33m"
FontColor_Yellow_Bold="\033[1;33m"
FontColor_Purple="\033[35m"
FontColor_Purple_Bold="\033[1;35m"
FontColor_Suffix="\033[0m"

log() {
    local LEVEL="$1"
    local MSG="$2"
    case "${LEVEL}" in
    INFO)
        local LEVEL="[${FontColor_Green}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${MSG}"
        ;;
    WARN)
        local LEVEL="[${FontColor_Yellow}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${MSG}"
        ;;
    ERROR)
        local LEVEL="[${FontColor_Red}${LEVEL}${FontColor_Suffix}]"
        local MSG="${LEVEL} ${MSG}"
        ;;
    *) ;;
    esac
    echo -e "${MSG}"
}

if [[ $(uname -s) != Linux ]]; then
    log ERROR "This operating system is not supported."
    exit 1
fi

if [[ $(id -u) != 0 ]]; then
    log ERROR "This script must be run as root."
    exit 1
fi

if [[ -z $(command -v curl) ]]; then
    log ERROR "cURL is not installed."
    exit 1
fi

WGCF_Profile='wgcf-profile.conf'
WGCF_ProfileDir="/etc/warp"
WGCF_ProfilePath="${WGCF_ProfileDir}/${WGCF_Profile}"

WireGuard_Interface='wgcf'
WireGuard_ConfPath="/etc/wireguard/${WireGuard_Interface}.conf"

WireGuard_Interface_DNS_IPv4='8.8.8.8,8.8.4.4'
WireGuard_Interface_DNS_IPv6='2001:4860:4860::8888,2001:4860:4860::8844'
WireGuard_Interface_DNS_46="${WireGuard_Interface_DNS_IPv4},${WireGuard_Interface_DNS_IPv6}"
WireGuard_Interface_DNS_64="${WireGuard_Interface_DNS_IPv6},${WireGuard_Interface_DNS_IPv4}"
WireGuard_Interface_Rule_table='51888'
WireGuard_Interface_Rule_fwmark='51888'
WireGuard_Interface_MTU='1280'

WireGuard_Peer_Endpoint_IP4='162.159.192.1'
WireGuard_Peer_Endpoint_IP6='2606:4700:d0::a29f:c001'
WireGuard_Peer_Endpoint_IPv4="${WireGuard_Peer_Endpoint_IP4}:2408"
WireGuard_Peer_Endpoint_IPv6="[${WireGuard_Peer_Endpoint_IP6}]:2408"
WireGuard_Peer_Endpoint_Domain='engage.cloudflareclient.com:2408'
WireGuard_Peer_AllowedIPs_IPv4='0.0.0.0/0'
WireGuard_Peer_AllowedIPs_IPv6='::/0'
WireGuard_Peer_AllowedIPs_DualStack='0.0.0.0/0,::/0'

TestIPv4_1='1.0.0.1'
TestIPv4_2='9.9.9.9'
TestIPv6_1='2606:4700:4700::1001'
TestIPv6_2='2620:fe::fe'
CF_Trace_URL='https://www.cloudflare.com/cdn-cgi/trace'

Get_System_Info() {
    source /etc/os-release
    SysInfo_OS_CodeName="${VERSION_CODENAME}"
    SysInfo_OS_Name_lowercase="${ID}"
    SysInfo_OS_Name_Full="${PRETTY_NAME}"
    SysInfo_RelatedOS="${ID_LIKE}"
    SysInfo_Kernel="$(uname -r)"
    SysInfo_Kernel_Ver_major="$(uname -r | awk -F . '{print $1}')"
    SysInfo_Kernel_Ver_minor="$(uname -r | awk -F . '{print $2}')"
    SysInfo_Arch="$(uname -m)"
    SysInfo_Virt="$(systemd-detect-virt)"
    case ${SysInfo_RelatedOS} in
    *fedora* | *rhel*)
        SysInfo_OS_Ver_major="$(rpm -E '%{rhel}')"
        ;;
    *)
        SysInfo_OS_Ver_major="$(echo ${VERSION_ID} | cut -d. -f1)"
        ;;
    esac
}

Print_System_Info() {
    echo -e "
System Information
---------------------------------------------------
  Operating System: ${SysInfo_OS_Name_Full}
      Linux Kernel: ${SysInfo_Kernel}
      Architecture: ${SysInfo_Arch}
    Virtualization: ${SysInfo_Virt}
---------------------------------------------------
"
}

Install_Requirements_Debian() {
    if [[ ! $(command -v gpg) ]]; then
        apt update
        apt install gnupg -y
    fi
    if [[ ! $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]]; then
        apt update
        apt install apt-transport-https -y
    fi
}

Install_WARP_Client_Debian() {
    if [[ ${SysInfo_OS_Name_lowercase} = ubuntu ]]; then
        case ${SysInfo_OS_CodeName} in
        bionic | focal | jammy) ;;
        *)
            log ERROR "This operating system is not supported."
            exit 1
            ;;
        esac
    elif [[ ${SysInfo_OS_Name_lowercase} = debian ]]; then
        case ${SysInfo_OS_CodeName} in
        buster | bullseye) ;;
        *)
            log ERROR "This operating system is not supported."
            exit 1
            ;;
        esac
    fi
    Install_Requirements_Debian
    curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${SysInfo_OS_CodeName} main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt update
    apt install cloudflare-warp -y
}

Install_WARP_Client_CentOS() {
    if [[ ${SysInfo_OS_Ver_major} = 8 ]]; then
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        yum install cloudflare-warp -y
    else
        log ERROR "This operating system is not supported."
        exit 1
    fi
}

Check_WARP_Client() {
    WARP_Client_Status=$(systemctl is-active warp-svc)
    WARP_Client_SelfStart=$(systemctl is-enabled warp-svc 2>/dev/null)
}

Install_WARP_Client() {
    Print_System_Info
    log INFO "Installing Cloudflare WARP Client..."
    if [[ ${SysInfo_Arch} != x86_64 ]]; then
        log ERROR "This CPU architecture is not supported: ${SysInfo_Arch}"
        exit 1
    fi
    case ${SysInfo_OS_Name_lowercase} in
    *debian* | *ubuntu*)
        Install_WARP_Client_Debian
        ;;
    *centos* | *rhel*)
        Install_WARP_Client_CentOS
        ;;
    *)
        if [[ ${SysInfo_RelatedOS} = *rhel* || ${SysInfo_RelatedOS} = *fedora* ]]; then
            Install_WARP_Client_CentOS
        else
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
    Check_WARP_Client
    if [[ ${WARP_Client_Status} = active ]]; then
        log INFO "Cloudflare WARP Client installed successfully!"
    else
        log ERROR "warp-svc failure to run!"
        journalctl -u warp-svc --no-pager
        exit 1
    fi
}

Uninstall_WARP_Client() {
    log INFO "Uninstalling Cloudflare WARP Client..."
    case ${SysInfo_OS_Name_lowercase} in
    *debian* | *ubuntu*)
        apt purge cloudflare-warp -y
        rm -f /etc/apt/sources.list.d/cloudflare-client.list /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
        ;;
    *centos* | *rhel*)
        yum remove cloudflare-warp -y
        ;;
    *)
        if [[ ${SysInfo_RelatedOS} = *rhel* || ${SysInfo_RelatedOS} = *fedora* ]]; then
            yum remove cloudflare-warp -y
        else
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
}

Restart_WARP_Client() {
    log INFO "Restarting Cloudflare WARP Client..."
    systemctl restart warp-svc
    Check_WARP_Client
    if [[ ${WARP_Client_Status} = active ]]; then
        log INFO "Cloudflare WARP Client has been restarted."
    else
        log ERROR "Cloudflare WARP Client failure to run!"
        journalctl -u warp-svc --no-pager
        exit 1
    fi
}

Init_WARP_Client() {
    Check_WARP_Client
    if [[ ${WARP_Client_SelfStart} != enabled || ${WARP_Client_Status} != active ]]; then
        Install_WARP_Client
    fi
    if [[ $(warp-cli --accept-tos account) = *Missing* ]]; then
        log INFO "Cloudflare WARP Account Registration in progress..."
        warp-cli --accept-tos register
    fi
}

Connect_WARP() {
    log INFO "Connecting to WARP..."
    warp-cli --accept-tos connect
    log INFO "Enable WARP Always-On..."
    warp-cli --accept-tos enable-always-on
}

Disconnect_WARP() {
    log INFO "Disable WARP Always-On..."
    warp-cli --accept-tos disable-always-on
    log INFO "Disconnect from WARP..."
    warp-cli --accept-tos disconnect
}

Set_WARP_Mode_Proxy() {
    log INFO "Setting up WARP Proxy Mode..."
    warp-cli --accept-tos set-mode proxy
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
        log INFO "Cloudflare WARP Account registration in progress..."
        yes | wgcf register
        sleep 5
    done
}

Generate_WGCF_Profile() {
    while [[ ! -f ${WGCF_Profile} ]]; do
        Register_WARP_Account
        log INFO "WARP WireGuard profile (wgcf-profile.conf) generation in progress..."
        wgcf generate
    done
    Uninstall_wgcf
}

Backup_WGCF_Profile() {
    mkdir -p ${WGCF_ProfileDir}
    mv -f wgcf* ${WGCF_ProfileDir}
}

Read_WGCF_Profile() {
    WireGuard_Interface_PrivateKey=$(cat ${WGCF_ProfilePath} | grep ^PrivateKey | cut -d= -f2- | awk '$1=$1')
    WireGuard_Interface_Address=$(cat ${WGCF_ProfilePath} | grep ^Address | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    WireGuard_Peer_PublicKey=$(cat ${WGCF_ProfilePath} | grep ^PublicKey | cut -d= -f2- | awk '$1=$1')
    WireGuard_Interface_Address_IPv4=$(echo ${WireGuard_Interface_Address} | cut -d, -f1 | cut -d'/' -f1)
    WireGuard_Interface_Address_IPv6=$(echo ${WireGuard_Interface_Address} | cut -d, -f2 | cut -d'/' -f1)
}

Load_WGCF_Profile() {
    if [[ -f ${WGCF_Profile} ]]; then
        Backup_WGCF_Profile
        Read_WGCF_Profile
    elif [[ -f ${WGCF_ProfilePath} ]]; then
        Read_WGCF_Profile
    else
        Generate_WGCF_Profile
        Backup_WGCF_Profile
        Read_WGCF_Profile
    fi
}

Install_WireGuardTools_Debian() {
    case ${SysInfo_OS_Ver_major} in
    10)
        if [[ -z $(grep "^deb.*buster-backports.*main" /etc/apt/sources.list{,.d/*}) ]]; then
            echo "deb http://deb.debian.org/debian buster-backports main" | tee /etc/apt/sources.list.d/backports.list
        fi
        ;;
    *)
        if [[ ${SysInfo_OS_Ver_major} -lt 10 ]]; then
            log ERROR "This operating system is not supported."
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
    yum install epel-release -y || yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-${SysInfo_OS_Ver_major}.noarch.rpm -y
    yum install iproute iptables wireguard-tools -y
}

Install_WireGuardTools_Fedora() {
    dnf install iproute iptables wireguard-tools -y
}

Install_WireGuardTools_Arch() {
    pacman -Sy iproute2 openresolv wireguard-tools --noconfirm
}

Install_WireGuardTools() {
    log INFO "Installing wireguard-tools..."
    case ${SysInfo_OS_Name_lowercase} in
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
        if [[ ${SysInfo_RelatedOS} = *rhel* || ${SysInfo_RelatedOS} = *fedora* ]]; then
            Install_WireGuardTools_CentOS
        else
            log ERROR "This operating system is not supported."
            exit 1
        fi
        ;;
    esac
}

Install_WireGuardGo() {
    case ${SysInfo_Virt} in
    openvz | lxc*)
        curl -fsSL git.io/wireguard-go.sh | bash
        ;;
    *)
        if [[ ${SysInfo_Kernel_Ver_major} -lt 5 || ${SysInfo_Kernel_Ver_minor} -lt 6 ]]; then
            curl -fsSL git.io/wireguard-go.sh | bash
        fi
        ;;
    esac
}

Check_WireGuard() {
    WireGuard_Status=$(systemctl is-active wg-quick@${WireGuard_Interface})
    WireGuard_SelfStart=$(systemctl is-enabled wg-quick@${WireGuard_Interface} 2>/dev/null)
}

Install_WireGuard() {
    Print_System_Info
    Check_WireGuard
    if [[ ${WireGuard_SelfStart} != enabled || ${WireGuard_Status} != active ]]; then
        Install_WireGuardTools
        Install_WireGuardGo
    else
        log INFO "WireGuard is installed and running."
    fi
}

Start_WireGuard() {
    Check_WARP_Client
    log INFO "Starting WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl enable wg-quick@${WireGuard_Interface} --now
        systemctl start warp-svc
    else
        systemctl enable wg-quick@${WireGuard_Interface} --now
    fi
    Check_WireGuard
    if [[ ${WireGuard_Status} = active ]]; then
        log INFO "WireGuard is running."
    else
        log ERROR "WireGuard failure to run!"
        journalctl -u wg-quick@${WireGuard_Interface} --no-pager
        exit 1
    fi
}

Restart_WireGuard() {
    Check_WARP_Client
    log INFO "Restarting WireGuard..."
    if [[ ${WARP_Client_Status} = active ]]; then
        systemctl stop warp-svc
        systemctl restart wg-quick@${WireGuard_Interface}
        systemctl start warp-svc
    else
        systemctl restart wg-quick@${WireGuard_Interface}
    fi
    Check_WireGuard
    if [[ ${WireGuard_Status} = active ]]; then
        log INFO "WireGuard has been restarted."
    else
        log ERROR "WireGuard failure to run!"
        journalctl -u wg-quick@${WireGuard_Interface} --no-pager
        exit 1
    fi
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
}

Stop_WireGuard() {
    Check_WARP_Client
    if [[ ${WireGuard_Status} = active ]]; then
        log INFO "Stoping WireGuard..."
        if [[ ${WARP_Client_Status} = active ]]; then
            systemctl stop warp-svc
            systemctl stop wg-quick@${WireGuard_Interface}
            systemctl start warp-svc
        else
            systemctl stop wg-quick@${WireGuard_Interface}
        fi
        Check_WireGuard
        if [[ ${WireGuard_Status} != active ]]; then
            log INFO "WireGuard has been stopped."
        else
            log ERROR "WireGuard stop failure!"
        fi
    else
        log INFO "WireGuard is stopped."
    fi
}

Disable_WireGuard() {
    Check_WARP_Client
    Check_WireGuard
    if [[ ${WireGuard_SelfStart} = enabled || ${WireGuard_Status} = active ]]; then
        log INFO "Disabling WireGuard..."
        if [[ ${WARP_Client_Status} = active ]]; then
            systemctl stop warp-svc
            systemctl disable wg-quick@${WireGuard_Interface} --now
            systemctl start warp-svc
        else
            systemctl disable wg-quick@${WireGuard_Interface} --now
        fi
        Check_WireGuard
        if [[ ${WireGuard_SelfStart} != enabled && ${WireGuard_Status} != active ]]; then
            log INFO "WireGuard has been disabled."
        else
            log ERROR "WireGuard disable failure!"
        fi
    else
        log INFO "WireGuard is disabled."
    fi
}

Print_WireGuard_Log() {
    journalctl -u wg-quick@${WireGuard_Interface} -f
}

Check_Network_Status_IPv4() {
    if ping -c1 -W1 ${TestIPv4_1} >/dev/null 2>&1 || ping -c1 -W1 ${TestIPv4_2} >/dev/null 2>&1; then
        IPv4Status='on'
    else
        IPv4Status='off'
    fi
}

Check_Network_Status_IPv6() {
    if ping6 -c1 -W1 ${TestIPv6_1} >/dev/null 2>&1 || ping6 -c1 -W1 ${TestIPv6_2} >/dev/null 2>&1; then
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
    IPv4_addr=$(
        ip route get ${TestIPv4_1} 2>/dev/null | grep -oP 'src \K\S+' ||
            ip route get ${TestIPv4_2} 2>/dev/null | grep -oP 'src \K\S+'
    )
}

Check_IPv6_addr() {
    IPv6_addr=$(
        ip route get ${TestIPv6_1} 2>/dev/null | grep -oP 'src \K\S+' ||
            ip route get ${TestIPv6_2} 2>/dev/null | grep -oP 'src \K\S+'
    )
}

Get_IP_addr() {
    Check_Network_Status
    if [[ ${IPv4Status} = on ]]; then
        log INFO "Getting the network interface IPv4 address..."
        Check_IPv4_addr
        if [[ ${IPv4_addr} ]]; then
            log INFO "IPv4 Address: ${IPv4_addr}"
        else
            log WARN "Network interface IPv4 address not obtained."
        fi
    fi
    if [[ ${IPv6Status} = on ]]; then
        log INFO "Getting the network interface IPv6 address..."
        Check_IPv6_addr
        if [[ ${IPv6_addr} ]]; then
            log INFO "IPv6 Address: ${IPv6_addr}"
        else
            log WARN "Network interface IPv6 address not obtained."
        fi
    fi
}

Get_WireGuard_Interface_MTU() {
    log INFO "Getting the best MTU value for WireGuard..."
    MTU_Preset=1500
    MTU_Increment=10
    if [[ ${IPv4Status} = off && ${IPv6Status} = on ]]; then
        CMD_ping='ping6'
        MTU_TestIP_1="${TestIPv6_1}"
        MTU_TestIP_2="${TestIPv6_2}"
    else
        CMD_ping='ping'
        MTU_TestIP_1="${TestIPv4_1}"
        MTU_TestIP_2="${TestIPv4_2}"
    fi
    while true; do
        if ${CMD_ping} -c1 -W1 -s$((${MTU_Preset} - 28)) -Mdo ${MTU_TestIP_1} >/dev/null 2>&1 || ${CMD_ping} -c1 -W1 -s$((${MTU_Preset} - 28)) -Mdo ${MTU_TestIP_2} >/dev/null 2>&1; then
            MTU_Increment=1
            MTU_Preset=$((${MTU_Preset} + ${MTU_Increment}))
        else
            MTU_Preset=$((${MTU_Preset} - ${MTU_Increment}))
            if [[ ${MTU_Increment} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTU_Preset} -le 1360 ]]; then
            log WARN "MTU is set to the lowest value."
            MTU_Preset='1360'
            break
        fi
    done
    WireGuard_Interface_MTU=$((${MTU_Preset} - 80))
    log INFO "WireGuard MTU: ${WireGuard_Interface_MTU}"
}

Generate_WireGuardProfile_Interface() {
    Get_WireGuard_Interface_MTU
    log INFO "WireGuard profile (${WireGuard_ConfPath}) generation in progress..."
    cat <<EOF >${WireGuard_ConfPath}
# Generated by P3TERX/warp.sh
# Visit https://github.com/P3TERX/warp.sh for more information

[Interface]
PrivateKey = ${WireGuard_Interface_PrivateKey}
Address = ${WireGuard_Interface_Address}
DNS = ${WireGuard_Interface_DNS}
MTU = ${WireGuard_Interface_MTU}
EOF
}

Generate_WireGuardProfile_Interface_Rule_TableOff() {
    cat <<EOF >>${WireGuard_ConfPath}
Table = off
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv4_nonGlobal() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUP = ip -4 route add default dev ${WireGuard_Interface} table ${WireGuard_Interface_Rule_table}
PostUP = ip -4 rule add from ${WireGuard_Interface_Address_IPv4} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -4 rule delete from ${WireGuard_Interface_Address_IPv4} lookup ${WireGuard_Interface_Rule_table}
PostUP = ip -4 rule add fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -4 rule delete fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostUP = ip -4 rule add table main suppress_prefixlength 0
PostDown = ip -4 rule delete table main suppress_prefixlength 0
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv6_nonGlobal() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUP = ip -6 route add default dev ${WireGuard_Interface} table ${WireGuard_Interface_Rule_table}
PostUP = ip -6 rule add from ${WireGuard_Interface_Address_IPv6} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -6 rule delete from ${WireGuard_Interface_Address_IPv6} lookup ${WireGuard_Interface_Rule_table}
PostUP = ip -6 rule add fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostDown = ip -6 rule delete fwmark ${WireGuard_Interface_Rule_fwmark} lookup ${WireGuard_Interface_Rule_table}
PostUP = ip -6 rule add table main suppress_prefixlength 0
PostDown = ip -6 rule delete table main suppress_prefixlength 0
EOF
}

Generate_WireGuardProfile_Interface_Rule_DualStack_nonGlobal() {
    Generate_WireGuardProfile_Interface_Rule_TableOff
    Generate_WireGuardProfile_Interface_Rule_IPv4_nonGlobal
    Generate_WireGuardProfile_Interface_Rule_IPv6_nonGlobal
}

Generate_WireGuardProfile_Interface_Rule_IPv4_Global_srcIP() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Interface_Rule_IPv6_Global_srcIP() {
    cat <<EOF >>${WireGuard_ConfPath}
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18
EOF
}

Generate_WireGuardProfile_Peer() {
    cat <<EOF >>${WireGuard_ConfPath}

[Peer]
PublicKey = ${WireGuard_Peer_PublicKey}
AllowedIPs = ${WireGuard_Peer_AllowedIPs}
Endpoint = ${WireGuard_Peer_Endpoint}
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
    Check_WARP_Client
    if [[ ${WARP_Client_Status} = active ]]; then
        Get_WARP_Proxy_Port
        WARP_Proxy_Status=$(curl -sx "socks5h://127.0.0.1:${WARP_Proxy_Port}" ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2)
    else
        unset WARP_Proxy_Status
    fi
    case ${WARP_Proxy_Status} in
    on)
        WARP_Proxy_Status_en="${FontColor_Green}${WARP_Proxy_Port}${FontColor_Suffix}"
        WARP_Proxy_Status_zh="${WARP_Proxy_Status_en}"
        ;;
    plus)
        WARP_Proxy_Status_en="${FontColor_Green}${WARP_Proxy_Port}(WARP+)${FontColor_Suffix}"
        WARP_Proxy_Status_zh="${WARP_Proxy_Status_en}"
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
    Check_Network_Status_IPv4
    if [[ ${IPv4Status} = on ]]; then
        WARP_IPv4_Status=$(curl -s4 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2)
    else
        unset WARP_IPv4_Status
    fi
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
        Check_Network_Status_IPv4
        if [[ ${IPv4Status} = on ]]; then
            WARP_IPv4_Status_en="Normal"
            WARP_IPv4_Status_zh="正常"
        else
            WARP_IPv4_Status_en="${FontColor_Red}Unconnected${FontColor_Suffix}"
            WARP_IPv4_Status_zh="${FontColor_Red}未连接${FontColor_Suffix}"
        fi
        ;;
    esac
    Check_Network_Status_IPv6
    if [[ ${IPv6Status} = on ]]; then
        WARP_IPv6_Status=$(curl -s6 ${CF_Trace_URL} --connect-timeout 2 | grep warp | cut -d= -f2)
    else
        unset WARP_IPv6_Status
    fi
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
        Check_Network_Status_IPv6
        if [[ ${IPv6Status} = on ]]; then
            WARP_IPv6_Status_en="Normal"
            WARP_IPv6_Status_zh="正常"
        else
            WARP_IPv6_Status_en="${FontColor_Red}Unconnected${FontColor_Suffix}"
            WARP_IPv6_Status_zh="${FontColor_Red}未连接${FontColor_Suffix}"
        fi
        ;;
    esac
    if [[ ${IPv4Status} = off && ${IPv6Status} = off ]]; then
        log ERROR "Cloudflare WARP network anomaly, WireGuard tunnel established failed."
        Disable_WireGuard
        exit 1
    fi
}

Check_ALL_Status() {
    Check_WARP_Client_Status
    Check_WARP_Proxy_Status
    Check_WireGuard_Status
    Check_WARP_WireGuard_Status
}

Print_WARP_Client_Status() {
    log INFO "Status check in progress..."
    sleep 3
    Check_WARP_Client_Status
    Check_WARP_Proxy_Status
    echo -e "
 ----------------------------
 WARP Client\t: ${WARP_Client_Status_en}
 SOCKS5 Port\t: ${WARP_Proxy_Status_en}
 ----------------------------
"
    log INFO "Done."
}

Print_WARP_WireGuard_Status() {
    log INFO "Status check in progress..."
    Check_WireGuard_Status
    Check_WARP_WireGuard_Status
    echo -e "
 ----------------------------
 WireGuard\t: ${WireGuard_Status_en}
 IPv4 Network\t: ${WARP_IPv4_Status_en}
 IPv6 Network\t: ${WARP_IPv6_Status_en}
 ----------------------------
"
    log INFO "Done."
}

Print_ALL_Status() {
    log INFO "Status check in progress..."
    Check_ALL_Status
    echo -e "
 ----------------------------
 WARP Client\t: ${WARP_Client_Status_en}
 SOCKS5 Port\t: ${WARP_Proxy_Status_en}
 ----------------------------
 WireGuard\t: ${WireGuard_Status_en}
 IPv4 Network\t: ${WARP_IPv4_Status_en}
 IPv6 Network\t: ${WARP_IPv6_Status_en}
 ----------------------------
"
}

View_WireGuard_Profile() {
    Print_Delimiter
    cat ${WireGuard_ConfPath}
    Print_Delimiter
}

Check_WireGuard_Peer_Endpoint() {
    if ping -c1 -W1 ${WireGuard_Peer_Endpoint_IP4} >/dev/null 2>&1; then
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_IPv4}"
    elif ping6 -c1 -W1 ${WireGuard_Peer_Endpoint_IP6} >/dev/null 2>&1; then
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_IPv6}"
    else
        WireGuard_Peer_Endpoint="${WireGuard_Peer_Endpoint_Domain}"
    fi
}

Set_WARP_IPv4() {
    Install_WireGuard
    Get_IP_addr
    Load_WGCF_Profile
    if [[ ${IPv4Status} = off && ${IPv6Status} = on ]]; then
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_64}"
    else
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_46}"
    fi
    WireGuard_Peer_AllowedIPs="${WireGuard_Peer_AllowedIPs_IPv4}"
    Check_WireGuard_Peer_Endpoint
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv4_addr} ]]; then
        Generate_WireGuardProfile_Interface_Rule_IPv4_Global_srcIP
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
    if [[ ${IPv4Status} = off && ${IPv6Status} = on ]]; then
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_64}"
    else
        WireGuard_Interface_DNS="${WireGuard_Interface_DNS_46}"
    fi
    WireGuard_Peer_AllowedIPs="${WireGuard_Peer_AllowedIPs_IPv6}"
    Check_WireGuard_Peer_Endpoint
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv6_addr} ]]; then
        Generate_WireGuardProfile_Interface_Rule_IPv6_Global_srcIP
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
    WireGuard_Interface_DNS="${WireGuard_Interface_DNS_46}"
    WireGuard_Peer_AllowedIPs="${WireGuard_Peer_AllowedIPs_DualStack}"
    Check_WireGuard_Peer_Endpoint
    Generate_WireGuardProfile_Interface
    if [[ -n ${IPv4_addr} ]]; then
        Generate_WireGuardProfile_Interface_Rule_IPv4_Global_srcIP
    fi
    if [[ -n ${IPv6_addr} ]]; then
        Generate_WireGuardProfile_Interface_Rule_IPv6_Global_srcIP
    fi
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Set_WARP_DualStack_nonGlobal() {
    Install_WireGuard
    Get_IP_addr
    Load_WGCF_Profile
    WireGuard_Interface_DNS="${WireGuard_Interface_DNS_46}"
    WireGuard_Peer_AllowedIPs="${WireGuard_Peer_AllowedIPs_DualStack}"
    Check_WireGuard_Peer_Endpoint
    Generate_WireGuardProfile_Interface
    Generate_WireGuardProfile_Interface_Rule_DualStack_nonGlobal
    Generate_WireGuardProfile_Peer
    View_WireGuard_Profile
    Enable_WireGuard
    Print_WARP_WireGuard_Status
}

Menu_Title="${FontColor_Yellow_Bold}Cloudflare WARP 一键安装脚本${FontColor_Suffix} ${FontColor_Red}[${shVersion}]${FontColor_Suffix} by ${FontColor_Purple_Bold}P3TERX.COM${FontColor_Suffix}"

Menu_WARP_Client() {
    clear
    echo -e "
${Menu_Title}

 -------------------------
 WARP 客户端状态 : ${WARP_Client_Status_zh}
 SOCKS5 代理端口 : ${WARP_Proxy_Status_zh}
 -------------------------

管理 WARP 官方客户端：

 ${FontColor_Green_Bold}0${FontColor_Suffix}. 返回主菜单
 -
 ${FontColor_Green_Bold}1${FontColor_Suffix}. 开启 SOCKS5 代理
 ${FontColor_Green_Bold}2${FontColor_Suffix}. 关闭 SOCKS5 代理
 ${FontColor_Green_Bold}3${FontColor_Suffix}. 重启 WARP 官方客户端
 ${FontColor_Green_Bold}4${FontColor_Suffix}. 卸载 WARP 官方客户端
"
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    0)
        Start_Menu
        ;;
    1)
        Enable_WARP_Client_Proxy
        ;;
    2)
        Disconnect_WARP
        ;;
    3)
        Restart_WARP_Client
        ;;
    4)
        Uninstall_WARP_Client
        ;;
    *)
        log ERROR "无效输入！"
        sleep 2s
        Menu_WARP_Client
        ;;
    esac
}

Menu_WARP_WireGuard() {
    clear
    echo -e "
${Menu_Title}

 -------------------------
 WireGuard 状态 : ${WireGuard_Status_zh}
 IPv4 网络状态  : ${WARP_IPv4_Status_zh}
 IPv6 网络状态  : ${WARP_IPv6_Status_zh}
 -------------------------

管理 WARP WireGuard：

 ${FontColor_Green_Bold}0${FontColor_Suffix}. 返回主菜单
 -
 ${FontColor_Green_Bold}1${FontColor_Suffix}. 查看 WARP WireGuard 日志
 ${FontColor_Green_Bold}2${FontColor_Suffix}. 重启 WARP WireGuard 服务
 ${FontColor_Green_Bold}3${FontColor_Suffix}. 关闭 WARP WireGuard 网络
"
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    0)
        Start_Menu
        ;;
    1)
        Print_WireGuard_Log
        ;;
    2)
        Restart_WireGuard
        ;;
    3)
        Disable_WireGuard
        ;;
    *)
        log ERROR "无效输入！"
        sleep 2s
        Menu_Other
        ;;
    esac
}

Start_Menu() {
    log INFO "正在检查状态..."
    Check_ALL_Status
    clear
    echo -e "
${Menu_Title}

 -------------------------
 WARP 客户端状态 : ${WARP_Client_Status_zh}
 SOCKS5 代理端口 : ${WARP_Proxy_Status_zh}
 -------------------------
 WireGuard 状态 : ${WireGuard_Status_zh}
 IPv4 网络状态  : ${WARP_IPv4_Status_zh}
 IPv6 网络状态  : ${WARP_IPv6_Status_zh}
 -------------------------

 ${FontColor_Green_Bold}1${FontColor_Suffix}. 安装 Cloudflare WARP 官方客户端
 ${FontColor_Green_Bold}2${FontColor_Suffix}. 自动配置 WARP 客户端 SOCKS5 代理
 ${FontColor_Green_Bold}3${FontColor_Suffix}. 管理 Cloudflare WARP 官方客户端
 -
 ${FontColor_Green_Bold}4${FontColor_Suffix}. 安装 WireGuard 相关组件
 ${FontColor_Green_Bold}5${FontColor_Suffix}. 自动配置 WARP WireGuard IPv4 网络
 ${FontColor_Green_Bold}6${FontColor_Suffix}. 自动配置 WARP WireGuard IPv6 网络
 ${FontColor_Green_Bold}7${FontColor_Suffix}. 自动配置 WARP WireGuard 双栈全局网络
 ${FontColor_Green_Bold}8${FontColor_Suffix}. 管理 WARP WireGuard 网络
"
    unset MenuNumber
    read -p "请输入选项: " MenuNumber
    echo
    case ${MenuNumber} in
    1)
        Install_WARP_Client
        ;;
    2)
        Enable_WARP_Client_Proxy
        ;;
    3)
        Menu_WARP_Client
        ;;
    4)
        Install_WireGuard
        ;;
    5)
        Set_WARP_IPv4
        ;;
    6)
        Set_WARP_IPv6
        ;;
    7)
        Set_WARP_DualStack
        ;;
    8)
        Menu_WARP_WireGuard
        ;;
    *)
        log ERROR "无效输入！"
        sleep 2s
        Start_Menu
        ;;
    esac
}

Print_Usage() {
    echo -e "
Cloudflare WARP Installer [${shVersion}]

USAGE:
    bash <(curl -fsSL git.io/warp.sh) [SUBCOMMAND]

SUBCOMMANDS:
    install         Install Cloudflare WARP Official Linux Client
    uninstall       uninstall Cloudflare WARP Official Linux Client
    restart         Restart Cloudflare WARP Official Linux Client
    proxy           Enable WARP Client Proxy Mode (default SOCKS5 port: 40000)
    unproxy         Disable WARP Client Proxy Mode
    wg              Install WireGuard and related components
    wg4             Configuration WARP IPv4 Global Network (with WireGuard), all IPv4 outbound data over the WARP network
    wg6             Configuration WARP IPv6 Global Network (with WireGuard), all IPv6 outbound data over the WARP network
    wgd             Configuration WARP Dual Stack Global Network (with WireGuard), all outbound data over the WARP network
    wgx             Configuration WARP Non-Global Network (with WireGuard), set fwmark or interface IP Address to use the WARP network
    rwg             Restart WARP WireGuard service
    dwg             Disable WARP WireGuard service
    status          Prints status information
    version         Prints version information
    help            Prints this message or the help of the given subcommand(s)
    menu            Chinese special features menu
"
}

cat <<-'EOM'

[0;1;35;95m__[0m        [0;1;34;94m__[0;1;35;95m_[0m    [0;1;33;93m_[0;1;32;92m__[0;1;36;96m_[0m  [0;1;34;94m_[0;1;35;95m__[0;1;31;91m_[0m    [0;1;32;92m_[0;1;36;96m__[0m           [0;1;36;96m_[0m        [0;1;32;92m_[0m [0;1;36;96m_[0m           
[0;1;31;91m\[0m [0;1;33;93m\[0m      [0;1;34;94m/[0m [0;1;35;95m/[0m [0;1;31;91m\[0m  [0;1;32;92m|[0m  [0;1;36;96m_[0m [0;1;34;94m\[0;1;35;95m|[0m  [0;1;31;91m_[0m [0;1;33;93m\[0m  [0;1;36;96m|_[0m [0;1;34;94m_[0;1;35;95m|_[0m [0;1;31;91m_[0;1;33;93m_[0m  [0;1;32;92m_[0;1;36;96m__[0;1;34;94m|[0m [0;1;35;95m|_[0m [0;1;31;91m_[0;1;33;93m_[0m [0;1;32;92m_|[0m [0;1;36;96m|[0m [0;1;34;94m|[0m [0;1;35;95m_[0;1;31;91m__[0m [0;1;33;93m_[0m [0;1;32;92m_[0;1;36;96m_[0m 
 [0;1;33;93m\[0m [0;1;32;92m\[0m [0;1;36;96m/[0;1;34;94m\[0m [0;1;35;95m/[0m [0;1;31;91m/[0m [0;1;33;93m_[0m [0;1;32;92m\[0m [0;1;36;96m|[0m [0;1;34;94m|_[0;1;35;95m)[0m [0;1;31;91m|[0m [0;1;33;93m|_[0;1;32;92m)[0m [0;1;36;96m|[0m  [0;1;34;94m|[0m [0;1;35;95m|[0;1;31;91m|[0m [0;1;33;93m'_[0m [0;1;32;92m\[0;1;36;96m/[0m [0;1;34;94m__[0;1;35;95m|[0m [0;1;31;91m__[0;1;33;93m/[0m [0;1;32;92m_`[0m [0;1;36;96m|[0m [0;1;34;94m|[0m [0;1;35;95m|[0;1;31;91m/[0m [0;1;33;93m_[0m [0;1;32;92m\[0m [0;1;36;96m'_[0;1;34;94m_|[0m
  [0;1;36;96m\[0m [0;1;34;94mV[0m  [0;1;35;95mV[0m [0;1;31;91m/[0m [0;1;33;93m_[0;1;32;92m__[0m [0;1;36;96m\[0;1;34;94m|[0m  [0;1;35;95m_[0m [0;1;31;91m<[0;1;33;93m|[0m  [0;1;32;92m_[0;1;36;96m_/[0m   [0;1;35;95m|[0m [0;1;31;91m|[0;1;33;93m|[0m [0;1;32;92m|[0m [0;1;36;96m|[0m [0;1;34;94m\_[0;1;35;95m_[0m [0;1;31;91m\[0m [0;1;33;93m||[0m [0;1;32;92m([0;1;36;96m_|[0m [0;1;34;94m|[0m [0;1;35;95m|[0m [0;1;31;91m|[0m  [0;1;32;92m__[0;1;36;96m/[0m [0;1;34;94m|[0m   
   [0;1;34;94m\[0;1;35;95m_/[0;1;31;91m\_[0;1;33;93m/_[0;1;32;92m/[0m   [0;1;34;94m\_[0;1;35;95m\_[0;1;31;91m|[0m [0;1;33;93m\_[0;1;32;92m\_[0;1;36;96m|[0m     [0;1;31;91m|_[0;1;33;93m__[0;1;32;92m|_[0;1;36;96m|[0m [0;1;34;94m|_[0;1;35;95m|_[0;1;31;91m__[0;1;33;93m/\[0;1;32;92m__[0;1;36;96m\_[0;1;34;94m_,[0;1;35;95m_|[0;1;31;91m_|[0;1;33;93m_|[0;1;32;92m\_[0;1;36;96m__[0;1;34;94m|_[0;1;35;95m|[0m   
                                                                    
Copyright (C) P3TERX.COM | https://github.com/P3TERX/warp.sh

EOM

if [ $# -ge 1 ]; then
    Get_System_Info
    case ${1} in
    install)
        Install_WARP_Client
        ;;
    uninstall)
        Uninstall_WARP_Client
        ;;
    restart)
        Restart_WARP_Client
        ;;
    proxy | socks5 | s5)
        Enable_WARP_Client_Proxy
        ;;
    unproxy | unsocks5 | uns5)
        Disconnect_WARP
        ;;
    wg)
        Install_WireGuard
        ;;
    wg4 | 4)
        Set_WARP_IPv4
        ;;
    wg6 | 6)
        Set_WARP_IPv6
        ;;
    wgd | d)
        Set_WARP_DualStack
        ;;
    wgx | x)
        Set_WARP_DualStack_nonGlobal
        ;;
    rwg)
        Restart_WireGuard
        ;;
    dwg)
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
        log ERROR "Invalid Parameters: $*"
        Print_Usage
        exit 1
        ;;
    esac
else
    Print_Usage
fi
