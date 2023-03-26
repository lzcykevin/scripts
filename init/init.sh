###########################################################################
apt update -y
apt upgrade -y
apt install net-tools nload dstat vnstat htop screen git gcc pigz -y

###########################################################################
# Set sysctl.conf 
echo -e "Set sysctl.conf" 
cat >>/etc/sysctl.conf<<EOF

# bbr
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# FS
fs.file-max = 10000000
fs.nr_open = 10000000

# TCP
net.ipv4.tcp_synack_retries = 2 
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_mem = 786432 1697152 1945728
net.ipv4.tcp_rmem = 4096 4096 16777216
net.ipv4.tcp_wmem = 4096 4096 16777216
net.ipv4.ip_local_port_range = 1024 65535 

net.core.rmem_default = 699040
net.core.rmem_max = 50331648
net.core.wmem_default = 131072
net.core.wmem_max = 33554432
net.core.somaxconn = 65535

kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 4294967295
kernel.shmall = 26843545

# Forward
net.ipv4.ip_forward=1
EOF
sysctl -p
echo -e "\033[32m Setted sysctl.conf \033[0m\n"

###########################################################################
echo -e "Set limits.conf"
cat >>/etc/security/limits.conf<<EOF
*soft nofile 10000000
*hard nofile 10000000
* soft nproc 10000000
* hard nproc 10000000
EOF
echo -e "\033[32m Setted limits.conf \033[0m\n"

###########################################################################
# ssh prot
echo -e "Set sshd port"
 sed -i "s/#Port 22/Port 521/" /etc/ssh/sshd_config
echo -e "\033[32m Setted sysctl.conf \033[0m\n"

###########################################################################
# echo name
echo -e "Set hostname"
echo -e "aq" > /etc/hostname
echo -e "< A quick brown fox jumps over the lazy dog. >" > /etc/motd
echo -e "\033[32m Setted hostname\033[0m\n"

###########################################################################
# init bash
echo -e "Set bashrc"
wget -N --no-check-certificate https://raw.githubusercontent.com/lzcykevin/setrepost/master/bashrc/bashrc
rm -rf .bashrc 
mv bashrc .bashrc
source .bashrc
echo -e "\033[32m Setted bashrc\033[0m\n"
