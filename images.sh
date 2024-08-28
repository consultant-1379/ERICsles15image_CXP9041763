test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile
ln -s /etc/init.d /etc/rc.d/init.d
#zypper install -y ERICenmconfiguration_CXP9031455 ERIClitpvmmonitord_CXP9031644 ERICvmsshkeyservice_CXP9034113 EXTRserverjre_CXP9035480 ERICconsulconfig_CXP9033977 ERICsimpleavailabilitymanageragents_CXP9034284 EXTRjbossncm_CXP9038859
baseInsertService vmsshkeyservice on
baseInsertService vmmonitord on
baseInsertService sysstat
baseInsertService cloud-init-local
baseInsertService cloud-init
baseInsertService cloud-config
baseInsertService cloud-final
baseInsertService sshd
baseInsertService chrony
baseInsertService nfs
baseInsertService ddc


#part2
rm -f /etc/profile.d/alljava.csh
echo -e "#cloud-config\ndisable_network_activation: false\nbootcmd:\n- ifup all" >> /etc/cloud/cloud.cfg.d/network_active.cfg
## System ##
# TORF-178820
echo "net.ipv4.ip_local_port_range = 32810    60999" >>/etc/sysctl.conf
echo "#TORF-239129 - Prevent collision with clustered counter and lock mutlicast ports" >>/etc/sysctl.conf
echo "net.ipv4.ip_local_reserved_ports = 12987,55181,55511,55571,50691,53689,52679,58170,58171,58172,50558,56231,56234,54402,54502,55502" >>/etc/sysctl.conf

sed -i '$ i * soft core unlimited' /etc/security/limits.conf

sed -i '$a#Configuring Core Dumps' /etc/sysctl.conf
sed -i '$akernel.core_uses_pid = 1' /etc/sysctl.conf
sed -i '$akernel.core_pattern = /ericsson/enm/dumps/core.%h.%e.pid%p.usr%u.sig%s.tim%t' /etc/sysctl.conf
sed -i '$afs.suid_dumpable = 2' /etc/sysctl.conf
sed -i '$a# Configuring vm.swappiness' /etc/sysctl.conf
sed -i '$avm.swappiness = 10' /etc/sysctl.conf

# set default socket buffer settings.
echo 'net.core.rmem_max = 5242880' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 655360' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 5242880' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 655360' >> /etc/sysctl.conf
echo 'vm.min_free_kbytes = 262144' >> /etc/sysctl.conf

# Set net.ipv4.conf.all.arp_filter=1 in /etc/sysctl.conf
sed -i '$anet.ipv4.conf.all.arp_filter = 1' /etc/sysctl.conf

# Increase the ARP Cache size - Neighbour Table - Garbage Collection Threshold
# gc_thresh for IPv6
sed -i '$anet.ipv6.neigh.default.gc_thresh3 = 2048' /etc/sysctl.conf

## ENM Deployment ##
# Create cloud init user
groupadd -g 500 cloud-user
useradd -m -gcloud-user -u 500 -d /home/cloud-user cloud-user

# Give cloud-user a password to avoid cloud-init warnings on boot
echo 'cloud-user:123456' | chpasswd

# Add users and groups
groupadd enm
useradd -genm -d /home/enmadm enmadm
groupadd -g 205 jboss
useradd -gjboss -u 308 -d /home/jboss_user jboss_user

# Provide sudo rights
echo "#includedir /etc/sudoers.d" >> /etc/sudoers
echo 'cloud-user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/cloud-user
echo 'iptnms ALL=(ALL) NOPASSWD: /sbin/reboot' > /etc/sudoers.d/iptnms
chmod 0440 /etc/sudoers.d/*

# Technical debt - update the cloud.cfg to bring nfs mounts up before package-install
# Remove existing mount module
/bin/sed -i '/ - mounts/d' /etc/cloud/cloud.cfg
# Add back in now as first module ran in cloud_config
/bin/sed -i '/cloud_config_modules:/a \ - mounts' /etc/cloud/cloud.cfg

# TORF-178106: ability to reset VM root password to ATT preferred value
passwd -l root

# Remove cloud-init instances so it can be used on next customization
rm -rf /var/lib/cloud/instances


## Boot ##
# Blank out the udev rules
/bin/echo -n > /etc/udev/rules.d/70-persistent-net.rules
/bin/echo -n > /lib/udev/rules.d/75-persistent-net-generator.rules

# flush dead IP
/bin/sed -i '/^nameserver.*$/d' /etc/resolv.conf


## Log rotation
sed -i 's/^    size .*/    minsize 100M/' /etc/logrotate.d/syslog
sed -i 's/^    rotate .*/    rotate 14/' /etc/logrotate.d/syslog
sed -i '/^    dateext/d' /etc/logrotate.d/syslog
sed -i '/^    maxage .*/d' /etc/logrotate.d/syslog
sed -i '/{/a\
	            daily\
		                    nodelaycompress' /etc/logrotate.d/syslog


# Disable ssh
echo "sed -ir 's/^[#]\?PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config" > /var/tmp/sshcommands
# ciscat changes adding here as we need sshd restart
echo "echo 'IF YOU ARE NOT AN AUTHORIZED USER, PLEASE EXIT IMMEDIATELY.' >> /etc/motd" >> /var/tmp/sshcommands
echo "echo 'This computer system is for authorized use only' >> /etc/issue.d/10-SUSE" >> /var/tmp/sshcommands
echo "grep -q '^Banner /etc/issue' /etc/ssh/sshd_config || echo -e 'Banner /etc/issue' >> /etc/ssh/sshd_config" >> /var/tmp/sshcommands
echo "/sbin/service sshd restart" >> /var/tmp/sshcommands
echo "chmod 600 /var/log/secure" >> /var/tmp/sshcommands
chmod 755 /var/tmp/sshcommands
echo @reboot /var/tmp/sshcommands | crontab -

# Technical Debt: NTP Updates
echo "server ntp-server1" >> /etc/chrony.conf
echo "server ntp-server2" >> /etc/chrony.conf
echo "server ntp-server3" >> /etc/chrony.conf
echo "server ntp-server4" >> /etc/chrony.conf


## Small ENM ##
# Add in extra kernel module
cat << EOF > /etc/dracut.conf.d/00-custom.conf
add_drivers+=" vmw_pvscsi "
EOF
/sbin/mkinitrd

## Cloud ##
ln -s /usr/bin/cut /bin/cut
ln -s /usr/bin/nice /bin/nice
ln -s /usr/sbin/brctl /sbin/brctl
ln -s /usr/lib/systemd/system/cron.service /usr/lib/systemd/system/crond.service

# Implement TORF-56674
/bin/cp -f /dev/null /var/log/messages

# Remove old leases
rm -f /var/lib/dhcp/dhclient.eth0.*
rm -f /var/lib/dhcpcd/dhcpcd-eth0.*
chmod 600 /etc/securetty
chmod 400 /etc/shadow
chmod 400 /etc/gshadow
sed -i '/secure/i \$FileCreateMode 0600' /etc/rsyslog.d/20_rsys_server.conf
zypper removerepo --remote

rpm -e python-dummy --nodeps
