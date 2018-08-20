# get scripts 
wget http://update.aegis.aliyun.com/download/uninstall.sh && chmod +x uninstall.sh && bash uninstall.sh
wget -N --no-check-certificate https://raw.githubusercontent.com/lzcykevin/setrepost/master/bashrc
wget -N --no-check-certificate https://softs.loan/Bash/haproxy.sh && chmod +x haproxy.sh
wget -N --no-check-certificate https://softs.loan/Bash/iptables-pf.sh && chmod +x iptables-pf.sh

# update and install tools
apt -y update
apt -y upgrade
apt -y install net-tools nload dstat htop

# rm aliyun
rm -rf /usr/sbin/aliyun*
rm -rf /usr/local/aegis
rm -rf /usr/local/share/aliyun-assist
rm -rf /usr/local/lib/python2.7/dist-packages/cloud_init-0.7.6-py2.7.egg/cloudinit/aliyun*
rm -rf /usr/local/lib/python2.7/dist-packages/cloud_init-0.7.6-py2.7.egg/cloudinit/distros/aliyun*

# install bashrc
rm -rf .bashrc && mv bashrc .bashrc && source .bashrc

# open bbr
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
