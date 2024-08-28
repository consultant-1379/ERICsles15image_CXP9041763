test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile
# Upgrade the RPMs
zypper --gpg-auto-import-keys refresh
#zypper -n up
#cat << EOF > /etc/sysconfig/network/ifcfg-eth0
#STARTMODE=auto
#BOOTPROTO=dhcp
#EOF

echo "blacklist floppy" | sudo tee /etc/modprobe.d/blacklist-floppy.conf

# Blank out the udev rules
/bin/echo -n > /etc/udev/rules.d/70-persistent-net.rules
/bin/echo -n > /lib/udev/rules.d/75-persistent-net-generator.rules

echo -e 'nameserver 159.107.173.12\nnameserver 159.107.173.3' > resolv.conf


# Make sure cloud-init starts on boot
#systemctl enable --now cloud-init-local cloud-init cloud-config cloud-final

echo "GRUB_TERMINAL=\"console serial\"" >> /etc/default/grub
sed -i '/^GRUB_CMDLINE_LINUX=/ s/""/"console=tty0 console=ttyS0,115200"/' /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
# Configure dhclient for dhcp
sed -i 's/^DHCLIENT_BIN=.*/DHCLIENT_BIN="dhclient"/' /etc/sysconfig/network/dhcp
sed -i 's/^WAIT_FOR_INTERFACES=.*/WAIT_FOR_INTERFACES="10"/' /etc/sysconfig/network/config
sed -i 's/^DHCLIENT_WAIT_AT_BOOT=.*/DHCLIENT_WAIT_AT_BOOT="5"/' /etc/sysconfig/network/dhcp
sed -i 's/^DHCLIENT_USER_OPTIONS=.*/DHCLIENT_USER_OPTIONS="-1"/' /etc/sysconfig/network/dhcp
cat << EOF > /etc/dhclient.conf
timeout 5
retry 2
reboot 2
select-timeout 0
initial-interval 2
backoff-cutoff 2
EOF

ln -s /usr/bin/python3 /usr/bin/python
# Add NCM group and user
groupadd -g 7654 nmc
useradd -gnmc -c "Ericsson NCM User" -d /opt/ericsson/iptnms -p '16bjLjhZakyzU' -s /bin/csh iptnms
unlink /sbin/pidof
echo 'if [[ $@ == "systemd" ]]; then echo 1; else command /sbin/killall5 "$@"; fi;' > /sbin/pidof
chmod 755 /sbin/pidof
zypper --no-gpg-checks --non-interactive install ERICenmconfiguration_CXP9031455 ERIClitpvmmonitord_CXP9031644 ERICvmsshkeyservice_CXP9034113 EXTRserverjre_CXP9035480 ERICconsulconfig_CXP9033977 ERICsimpleavailabilitymanageragents_CXP9034284 EXTRjbossncm_CXP9038859
# Remove nameserver from resolv.conf
/bin/sed -i '/^nameserver.*$/d' /etc/resolv.conf

echo "AcceptEnv SOURCE_IP" >> /etc/ssh/sshd_config

# TORF-706305 RHEL SSH server config change to use strong ciphers, kex and macs algorithms
echo "ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" >> /etc/ssh/sshd_config
echo "macs hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/sshd_config
echo "kexalgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256" >> /etc/ssh/sshd_config
echo "ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" >> /etc/ssh/ssh_config
echo "macs hmac-sha2-256,hmac-sha2-512" >> /etc/ssh/ssh_config
sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#GSSAPIKeyExchange no/GSSAPIKeyExchange no/g' /etc/ssh/sshd_config

##TORF-675966 start the rjio logging service on boot up ##
/bin/systemctl daemon-reload
/bin/systemctl enable rjio-logging.service
