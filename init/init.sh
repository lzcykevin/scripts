apt -y update
apt -y upgrade
apt -y install net-tools nload dstat htop screen git gcc 


# open bbr
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# echo name
echo -e "aq" > /etc/hostname
echo -e "< A quick brown fox jumps over the lazy dog. >" > /etc/motd

# init bash
wget -N --no-check-certificate https://raw.githubusercontent.com/lzcykevin/setrepost/master/bashrc/bashrc
rm -rf .bashrc && mv bashrc .bashrc && source .bashrc
