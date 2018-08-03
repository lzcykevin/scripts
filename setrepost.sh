#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

HaProxy_file="/etc/haproxy"
HaProxy_cfg_file="/etc/haproxy/haproxy.cfg"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#检查系统
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	#bit=`uname -m`
}
# 安装bbr
install_bbr(){
	if [[ ${release}  == "debian" ]]; then
		if [[ cat /etc/issue | grep -q -E -i "9" ]]; then
			dversion=9
		elif cat /proc/version | grep -q -E -i "debian"; then
			dversion=9
		fi
		
		if [[ ${dversion} == 9 ]]; then
			echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
			echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
			sysctl -p
			echo -e "	设置bbr成功 使用 lsmod | grep bbr 查看 \033[41;37m ${HaProxy_port} \033[0m" && exit 1
		fi
	fi
	
	echo -e "	不支持非debian 9系统 \033[41;37m ${HaProxy_port} \033[0m" && exit 1
}
# 设置转发
Set_forwarding_port(){
	stty erase '^H' && read -p "请输入 iptables 欲转发至的 远程端口 [1-65535] (支持端口段 如 2333-6666, 被转发服务器):" forwarding_port
	[[ -z "${forwarding_port}" ]] && echo "取消..." && exit 1
	echo && echo -e "	欲转发端口 : ${Red_font_prefix}${forwarding_port}${Font_color_suffix}" && echo
}
Set_forwarding_ip(){
		stty erase '^H' && read -p "请输入 iptables 欲转发至的 远程IP(被转发服务器):" forwarding_ip
		[[ -z "${forwarding_ip}" ]] && echo "取消..." && exit 1
		echo && echo -e "	欲转发服务器IP : ${Red_font_prefix}${forwarding_ip}${Font_color_suffix}" && echo
}
Set_local_port(){
	echo -e "请输入 iptables 本地监听端口 [1-65535] (支持端口段 如 2333-6666)"
	stty erase '^H' && read -p "(默认端口: ${forwarding_port}):" local_port
	[[ -z "${local_port}" ]] && local_port="${forwarding_port}"
	echo && echo -e "	本地监听端口 : ${Red_font_prefix}${local_port}${Font_color_suffix}" && echo
}
Set_local_ip(){
	stty erase '^H' && read -p "请输入 本服务器的 网卡IP(注意是网卡绑定的IP，而不仅仅是公网IP，回车自动检测外网IP):" local_ip
	if [[ -z "${local_ip}" ]]; then
		local_ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
		if [[ -z "${local_ip}" ]]; then
			echo "${Error} 无法检测到本服务器的公网IP，请手动输入"
			stty erase '^H' && read -p "请输入 本服务器的 网卡IP(注意是网卡绑定的IP，而不仅仅是公网IP):" local_ip
			[[ -z "${local_ip}" ]] && echo "取消..." && exit 1
		fi
	fi
	echo && echo -e "	本服务器IP : ${Red_font_prefix}${local_ip}${Font_color_suffix}" && echo
}

Set_Config(){
	Set_forwarding_port
	Set_forwarding_ip
	Set_local_port
	Set_local_ip
	echo && echo -e "——————————————————————————————
	请检查 iptables & haProxy 端口转发规则配置是否有误 !\n
	本地监听端口    : ${Green_font_prefix}${local_port}${Font_color_suffix}
	服务器 IP\t: ${Green_font_prefix}${local_ip}${Font_color_suffix}\n
	欲转发的端口    : ${Green_font_prefix}${forwarding_port}${Font_color_suffix}
	转发类型\t: ${Green_font_prefix}${forwarding_type}${Font_color_suffix}
——————————————————————————————\n"
	stty erase '^H' && read -p "请按任意键继续，如有配置错误请使用 Ctrl+C 退出。" var
}

# 查看HaProxy列表
viewHaProxy(){
	check_HaProxy
	HaProxy_port=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23`
	HaProxy_ip=`cat ${HaProxy_cfg_file} | sed -n "16p" | awk '{print $3}'`
	ip=`wget -qO- -t1 -T2 ipinfo.io/ip`
	[[ -z $ip ]] && ip="VPS_IP"
	echo
	echo "——————————————————————————————"
	echo "	HaProxy 配置信息: "
	echo
	echo -e "	本地 IP : \033[41;37m ${ip} \033[0m"
	echo -e "	本地监听端口 : \033[41;37m ${HaProxy_port} \033[0m"
	echo
	echo -e "	欲转发 IP : \033[41;37m ${HaProxy_ip} \033[0m"
	echo -e "	欲转发端口 : \033[41;37m ${HaProxy_port} \033[0m"
	echo "——————————————————————————————"
	echo
}

# 启动aProxy
startHaProxy(){
	check_HaProxy
	PID=`ps -ef | grep "haproxy" | grep -v grep | grep -v "haproxy.sh" | awk '{print $2}'`
	[[ ! -z $PID ]] && echo -e "\033[41;37m [错误] \033[0m 发现 HaProxy 正在运行，请检查 !" && exit 1
	if [[ ${release}  == "centos" ]]; then
		cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
		if [[ $? = 0 ]]; then
			systemctl start haproxy.service
		else
			/etc/init.d/haproxy start
		fi
	else
		/etc/init.d/haproxy start
	fi
	sleep 2s
	PID=`ps -ef | grep "haproxy" | grep -v grep | grep -v "haproxy.sh" | awk '{print $2}'`
	[[ -z $PID ]] && echo -e "\033[41;37m [错误] \033[0m HaProxy 启动失败 !" && exit 1
	HaProxy_port_1=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23 | grep "-"`
	HaProxy_port=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23`
	if [[ ${HaProxy_port_1} = "" ]]; then
		iptables -I INPUT -p tcp --dport ${HaProxy_port} -j ACCEPT
	else
		HaProxy_port_1=`echo ${HaProxy_port_1} | sed 's/-/:/g'`
		iptables -I INPUT -p tcp --dport ${HaProxy_port_1} -j ACCEPT
	fi
	echo && echo "——————————————————————————————" && echo
	echo "	HaProxy 已启动 !"
	Save_iptables
	viewHaProxy
}

# 停止aProxy
stopHaProxy(){
	check_HaProxy
	PID=`ps -ef | grep "haproxy" | grep -v grep | grep -v "haproxy.sh" | awk '{print $2}'`
	[[ -z $PID ]] && echo -e "\033[41;37m [错误] \033[0m 发现 HaProxy 没有运行，请检查 !" && exit 1
	if [[ ${release}  == "centos" ]]; then
		cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
		if [[ $? = 0 ]]; then
			systemctl stop haproxy.service
		else
			/etc/init.d/haproxy stop
		fi
	else
		/etc/init.d/haproxy stop
	fi
	HaProxy_port_1=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23 | grep "-"`
	HaProxy_port=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23`
	if [[ ${HaProxy_port_1} = "" ]]; then
		iptables -D INPUT -p tcp --dport ${HaProxy_port} -j ACCEPT
	else
		HaProxy_port_1=`echo ${HaProxy_port_1} | sed 's/-/:/g'`
		iptables -D INPUT -p tcp --dport ${HaProxy_port_1} -j ACCEPT
	fi
	sleep 2s
	PID=`ps -ef | grep "haproxy" | grep -v grep | grep -v "haproxy.sh" | awk '{print $2}'`
	if [[ ! -z $PID ]]; then
		echo -e "\033[41;37m [错误] \033[0m HaProxy 停止失败 !" && exit 1
	else
		Save_iptables
		echo "	HaProxy 已停止 !"
	fi
}

restartHaProxy(){
# 检查是否安装
	check_HaProxy
	PID=`ps -ef | grep "haproxy" | grep -v grep | grep -v "haproxy.sh" | awk '{print $2}'`
	if [[ ! -z $PID ]]; then
		stopHaProxy
	fi
	startHaProxy
}

Add_forwarding(){
	check_iptables
	Set_Config
	local_port=$(echo ${local_port} | sed 's/-/:/g')
	forwarding_port_1=$(echo ${forwarding_port} | sed 's/-/:/g')
	Add_iptables "udp"
	Save_iptables
	
	check_HaProxy
	echo
	echo "——————————————————————————————"
	echo "      请检查 HaProxy 配置是否有误 !"
	echo
	echo -e "	本地监听端口 : \033[41;37m ${forwarding_port} \033[0m"
	echo -e "	欲转发 IP : \033[41;37m ${forwarding_ip} \033[0m"
	echo "——————————————————————————————"
	echo
	stty erase '^H' && read -p "请按任意键继续，如有配置错误请使用 Ctrl+C 退出。" var
	HaProxy_port_1=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23 | grep "-"`
	HaProxy_port=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23`
	if [[ ${HaProxy_port_1} = "" ]]; then
		iptables -D INPUT -p tcp --dport ${HaProxy_port} -j ACCEPT
	else
		HaProxy_port_1=`echo ${HaProxy_port_1} | sed 's/-/:/g'`
		iptables -D INPUT -p tcp --dport ${HaProxy_port_1} -j ACCEPT
	fi
	cat > ${HaProxy_cfg_file}<<-EOF
global

defaults
        log     global
        mode    tcp
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000

frontend ss-in1
    bind *:${forwarding_port}
    default_backend ss-out1

backend ss-out1
    server server1 ${forwarding_ip} maxconn 20480
EOF
	restartHaProxy
	
	clear && echo && echo -e "——————————————————————————————
	iptables & haProxy 端口转发规则配置完成 !\n
	本地监听端口    : ${Green_font_prefix}${local_port}${Font_color_suffix}
	服务器 IP\t: ${Green_font_prefix}${local_ip}${Font_color_suffix}\n
	欲转发的端口    : ${Green_font_prefix}${forwarding_port_1}${Font_color_suffix}
	欲转发 IP\t: ${Green_font_prefix}${forwarding_ip}${Font_color_suffix}
	转发类型\t: ${Green_font_prefix}${forwarding_type}${Font_color_suffix}
——————————————————————————————\n"
}

#检查是否安装iptables HaProxy
check_HaProxy(){
	HaProxy_exist=`haproxy -v`
	if [[ ${HaProxy_exist} = "" ]]; then
		echo -e "\033[41;37m [错误] \033[0m 没有安装HaProxy，请检查 !" && exit 1
	fi
}
check_iptables(){
	iptables_exist=$(iptables -V)
	[[ ${iptables_exist} = "" ]] && echo -e "${Error} 没有安装iptables，请检查 !" && exit 1
}

# 设置 防火墙规则
Add_iptables(){
	iptables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}":"${forwarding_port}"
	iptables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j SNAT --to-source "${local_ip}"
	echo "iptables -t nat -A PREROUTING -p $1 --dport ${local_port} -j DNAT --to-destination ${forwarding_ip}:${forwarding_port}"
	echo "iptables -t nat -A POSTROUTING -p $1 -d ${forwarding_ip} --dport ${forwarding_port_1} -j SNAT --to-source ${local_ip}"
	echo "${local_port}"
	iptables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
}
Del_iptables(){
	iptables -t nat -D POSTROUTING "$2"
	iptables -t nat -D PREROUTING "$2"
	iptables -D INPUT -m state --state NEW -m "$1" -p "$1" --dport "${forwarding_listen}" -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	else
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}

# 清空转发
Uninstall_forwarding_haProxy(){
	check_iptables
	echo -e "确定要清空 iptables 所有端口转发规则 ? [y/N]"
	stty erase '^H' && read -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		forwarding_text=$(iptables -t nat -vnL PREROUTING|tail -n +3)
		[[ -z ${forwarding_text} ]] && echo -e "${Error} 没有发现 iptables 端口转发规则，请检查 !" && exit 1
		forwarding_total=$(echo -e "${forwarding_text}"|wc -l)
		for((integer = 1; integer <= ${forwarding_total}; integer++))
		do
			forwarding_type=$(echo -e "${forwarding_text}"|awk '{print $4}'|sed -n "${integer}p")
			forwarding_listen=$(echo -e "${forwarding_text}"|awk '{print $11}'|sed -n "${integer}p"|awk -F "dpt:" '{print $2}')
			[[ -z ${forwarding_listen} ]] && forwarding_listen=$(echo -e "${forwarding_text}"| awk '{print $11}'|sed -n "${integer}p"|awk -F "dpts:" '{print $2}')
			# echo -e "${forwarding_text} ${forwarding_type} ${forwarding_listen}"
			Del_iptables "${forwarding_type}" "${integer}"
		done
		Save_iptables
		stopHaProxy
		echo > ${HaProxy_cfg_file}
		echo && echo -e "${Info} iptables & HaProxy 已清空 所有端口转发规则 !" && echo
	else
		echo && echo "清空已取消..." && echo
	fi
}

#安装iptables
install_iptables_haProxy(){
	iptables_exist=$(iptables -V)
	if [[ ${iptables_exist} != "" ]]; then
		echo -e "${Info} 已经安装iptables，继续..."
	else
		echo -e "${Info} 检测到未安装 iptables，开始安装..."
		if [[ ${release}  == "centos" ]]; then
			yum update
			yum install -y vim iptables
		else
			apt-get update
			apt-get install -y vim iptables
		fi
		iptables_exist=$(iptables -V)
		if [[ ${iptables_exist} = "" ]]; then
			echo -e "${Error} 安装iptables失败，请检查 !" && exit 1
		else
			echo -e "${Info} iptables 安装完成 !"
		fi
	fi
	echo -e "${Info} 开始配置 iptables !"
	Set_iptables
	echo -e "${Info} iptables 配置完毕 !"
	
	echo -e "=============================================="
	echo -e "==============install haProxy================="
	echo -e "=============================================="
	
	HaProxy_exist=`haproxy -v`
	if [[ ${HaProxy_exist} != "" ]]; then
		echo -e "\033[41;37m [错误] \033[0m 已经安装HaProxy，请检查 !" && exit 1
	fi
	if [[ ${release}  == "centos" ]]; then
		yum update && yum install -y vim haproxy
	else
		apt-get update && apt-get install -y vim haproxy
	fi
	chmod +x /etc/rc.local
	HaProxy_exist=`haproxy -v`
	if [[ ${HaProxy_exist} = "" ]]; then
		echo -e "\033[41;37m [错误] \033[0m 安装HaProxy失败，请检查 !" && exit 1
	else
		Set_iptables
		if [[ ${release}  == "centos" ]]; then
			cat /etc/redhat-release |grep 7\..*|grep -i centos>/dev/null
			if [[ $? = 0 ]]; then
				systemctl enable haproxy.service
			else
				chmod +x /etc/init.d/haproxy
				chkconfig --add haproxy
				chkconfig haproxy on
			fi
		else
			chmod +x /etc/init.d/haproxy
			update-rc.d -f haproxy defaults
		fi
# setHaProxy
	fi
}

# 查看转发
View_forwarding(){
	check_iptables
	forwarding_text=$(iptables -t nat -vnL PREROUTING|tail -n +3)
	[[ -z ${forwarding_text} ]] && echo -e "${Error} 没有发现 iptables 端口转发规则，请检查 !" && exit 1
	forwarding_total=$(echo -e "${forwarding_text}"|wc -l)
	forwarding_list_all=""
	for((integer = 1; integer <= ${forwarding_total}; integer++))
	do
		forwarding_type=$(echo -e "${forwarding_text}"|awk '{print $4}'|sed -n "${integer}p")
		forwarding_listen=$(echo -e "${forwarding_text}"|awk '{print $11}'|sed -n "${integer}p"|awk -F "dpt:" '{print $2}')
		[[ -z ${forwarding_listen} ]] && forwarding_listen=$(echo -e "${forwarding_text}"| awk '{print $11}'|sed -n "${integer}p"|awk -F "dpts:" '{print $2}')
		forwarding_fork=$(echo -e "${forwarding_text}"| awk '{print $12}'|sed -n "${integer}p"|awk -F "to:" '{print $2}')
		forwarding_list_all=${forwarding_list_all}"${Green_font_prefix}"${integer}".${Font_color_suffix} 类型: ${Green_font_prefix}"${forwarding_type}"${Font_color_suffix} 监听端口: ${Red_font_prefix}"${forwarding_listen}"${Font_color_suffix} 转发IP和端口: ${Red_font_prefix}"${forwarding_fork}"${Font_color_suffix}\n"
	done
	echo && echo -e "当前有 ${Green_background_prefix} "${forwarding_total}" ${Font_color_suffix} 个 iptables 端口转发规则。"
	echo -e ${forwarding_list_all}
	
	check_HaProxy
	HaProxy_port=`cat ${HaProxy_cfg_file} | sed -n "12p" | cut -c 12-23`
	HaProxy_ip=`cat ${HaProxy_cfg_file} | sed -n "16p" | awk '{print $3}'`
	ip=`wget -qO- -t1 -T2 ipinfo.io/ip`
	[[ -z $ip ]] && ip="VPS_IP"
	echo
	echo "——————————————————————————————"
	echo "	HaProxy 配置信息: "
	echo
	echo -e "	本地 IP : \033[41;37m ${ip} \033[0m"
	echo -e "	本地监听端口 : \033[41;37m ${HaProxy_port} \033[0m"
	echo
	echo -e "	欲转发 IP : \033[41;37m ${HaProxy_ip} \033[0m"
	echo -e "	欲转发端口 : \033[41;37m ${HaProxy_port} \033[0m"
	echo "——————————————————————————————"
	echo
}

check_sys
echo && echo -e "端口转发一键管理脚本
————————————
1 安装 iptables & HaProxy 
2 清空 iptables & HaProxy 端口转发
————————————
3 查看 iptables & HaProxy 端口转发
4 添加 iptables & HaProxy 端口转发
5 安装BBR 目前只支持DEBIAN 9
————————————
"&& echo
stty erase '^H' && read -p " 请输入数字 [1-4]:" num
case "$num" in
	1)
	install_iptables_haProxy
	;;
	2)
	Uninstall_forwarding_haProxy
	;;
	3)
	View_forwarding
	;;
	4)
	Add_forwarding
	;;
	5)
	install_bbr
	;;
	*)
	echo "请输入正确数字 [1-4]"
	;;
esac