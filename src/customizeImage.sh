#! /bin/bash

echo "Run customize scripts here"
UBUNTUUSER="ubuntu"
PASSWORD="ubuntu"

useradd -s /bin/bash -d /home/"$UBUNTUUSER" -m -G sudo "$UBUNTUUSER"
usermod -p $(echo "$PASSWORD" | openssl passwd -1 -stdin) "$UBUNTUUSER"
echo "$UBUNTUUSER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

echo "$(hostname -I | cut -d\  -f1) $(hostname)" | tee -a /etc/hosts

ls -lh /etc/resolv.conf
unlink /etc/resolv.conf
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf

mv /etc/apt/apt.conf.d/70debconf /etc/apt/apt.conf.d/70debconf.bak
ex +"%s@DPkg@//DPkg" -cwq /etc/apt/apt.conf.d/70debconf
dpkg-reconfigure debconf -f noninteractive -p critical

apt install -y git

mkdir -p /home/"$UBUNTUUSER"/udpdiscovery/src
cp -vr /repo/src/scripts /home/"$UBUNTUUSER"
mv -v /home/"$UBUNTUUSER"/scripts/README.md /home/"$UBUNTUUSER"/scripts/Versions.txt /home/"$UBUNTUUSER"
mv -v /home/"$UBUNTUUSER"/scripts/udpdiscovery-server.go /home/"$UBUNTUUSER"/udpdiscovery/src
mv -v /home/"$UBUNTUUSER"/scripts/udpdiscovery.service /lib/systemd/system

chown -hR "$UBUNTUUSER":"$UBUNTUUSER" /home/"$UBUNTUUSER"/*
chmod a+x /home/"$UBUNTUUSER"/scripts/*
chmod 755 /lib/systemd/system/udpdiscovery.service

case $# in
	0)
		echo "---------------------------------------------------------"
		echo "3.1 Clone repo connectedhomeip and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu &&
			       git clone https://github.com/project-chip/connectedhomeip.git &&
			       cd /home/ubuntu/connectedhomeip
			       ./scripts/checkout_submodules.py --shallow --platform linux"
		echo "---------------------------------------------------------"
		echo "3.2 Clone repo ot-br-posix and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/openthread/ot-br-posix.git &&
			       cd /home/ubuntu/ot-br-posix
                               git submodule update --init"

		# Clone repo zap and update submodule
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/project-chip/zap.git"
		shift
		;;
	1)
		echo "---------------------------------------------------------"
		echo "3.1 Clone repo connectedhomeip and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu &&
			       git clone https://github.com/project-chip/connectedhomeip.git &&
			       cd /home/ubuntu/connectedhomeip
			       git checkout $1 &&
			       ./scripts/checkout_submodules.py --shallow --platform linux"

		echo "3.2 Clone repo ot-br-posix and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/openthread/ot-br-posix.git &&
			       cd /home/ubuntu/ot-br-posix
                               git submodule update --init"

		# Clone repo zap and update submodule
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/project-chip/zap.git"
		shift
		;;
	2)
		echo "---------------------------------------------------------"
		echo "3.1 Clone repo connectedhomeip and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu &&
			       git clone https://github.com/project-chip/connectedhomeip.git &&
			       cd /home/ubuntu/connectedhomeip
			       git checkout $1 &&
			       ./scripts/checkout_submodules.py --shallow --platform linux"

		echo "---------------------------------------------------------"
		echo "3.2 Clone repo ot-br-posix and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/openthread/ot-br-posix.git &&
			       cd /home/ubuntu/ot-br-posix
			       git checkout $2 &&
                               git submodule update --init"

		# Clone repo zap and update submodule
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/project-chip/zap.git"
		shift
		;;
	3)
		echo "---------------------------------------------------------"
		echo "3.1 Clone repo connectedhomeip and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu &&
			       git clone https://github.com/project-chip/connectedhomeip.git &&
			       cd /home/ubuntu/connectedhomeip
			       git checkout $1 &&
			       ./scripts/checkout_submodules.py --shallow --platform linux"
		echo "---------------------------------------------------------"
		echo "3.2 Clone repo ot-br-posix and update submodule"
		echo "---------------------------------------------------------"
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/openthread/ot-br-posix.git &&
			       cd /home/ubuntu/ot-br-posix
			       git checkout $2 &&
                               git submodule update --init"

		# Clone repo zap and update submodule
		runuser -l "$UBUNTUUSER" -c   "cd /home/ubuntu
			       git clone https://github.com/project-chip/zap.git &&
			       cd /home/ubuntu/zap
			       git checkout $3"
		shift
		;;
	*)
		echo "Never happen"
		shift
		;;
esac

# Add aliases for matterTool.sh and setupOTBR.sh
echo "---------------------------------------------------------"
echo "3.3 Add aliases for matterTool.sh and setupOTBR.sh"
echo "---------------------------------------------------------"
echo '# Matter related alias' | tee -a /home/$UBUNTUUSER/.bashrc
echo "alias mattertool='source /home/ubuntu/scripts/matterTool.sh'" | tee -a /home/"$UBUNTUUSER"/.bashrc
echo "alias otbrsetup='source /home/ubuntu/scripts/setupOTBR.sh'" | tee -a /home/"$UBUNTUUSER"/.bashrc
echo "alias updatetool='source /home/ubuntu/scripts/updateTool.sh'" | tee -a /home/"$UBUNTUUSER"/.bashrc
echo "alias rebuild='source /home/ubuntu/scripts/rebuild.sh'" | tee -a /home/"$UBUNTUUSER"/.bashrc
echo "export ZAP_DEVELOPMENT_PATH=/home/ubuntu/zap" | tee -a /home/"$UBUNTUUSER"/.bashrc

# Prerequisites installation
echo "---------------------------------------------------------"
echo "3.4 Install prerequisites"
echo "---------------------------------------------------------"
runuser -l "$UBUNTUUSER"  -c  'cd /home/ubuntu/scripts
			       ./prerequisite.sh
			       rm -f prerequisite.sh'
				
# Customization clean-up
echo "---------------------------------------------------------"
echo "3.5 Clean up customization"
echo "---------------------------------------------------------"

cd /home/ubuntu/connectedhomeip/out/standalone && find . -maxdepth 1 ! -name chip-tool -exec rm -fr {} \;
cd /home/ubuntu/connectedhomeip/out/ota-provider && find . -maxdepth 1 ! -name chip-ota-provider-app -exec rm -fr {} \;
cd /home/ubuntu/connectedhomeip && find . -maxdepth 1 ! -name out -exec rm -fr {} \;
sh -c 'echo 3 > /proc/sys/vm/drop_caches'
cd /home/ubuntu && rm -rf ./.cache/* ./.cipd-cache-dir/* ./zap ./ot-br-posix

# Change PasswordAuthentication to yes
sed -i 's|^Include /etc/ssh/ssh_config.d/\*.conf|#Include /etc/ssh/ssh_config.d/*.conf|' /etc/ssh/sshd_config

chmod a-x ./scripts/matterTool.sh
mv /etc/apt/apt.conf.d/70debconf.bak /etc/apt/apt.conf.d/70debconf
rm -f /etc/resolv.conf
ln -s ../run/systemd/resolve/resolv.conf /etc/resolv.conf
echo "127.0.1.1 $UBUNTUUSER" | tee -a /etc/hosts
#exit
o/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf