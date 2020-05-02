#!/bin/bash

# set about:config?filter=ui.key.menuAccessKeyFocuses
# to false for wordwise to work in Firefox

function uninstall {
	typeset -l dename
	dename=$(./system-config/dename.sh | cut -d " " -f1)

	while true; do
	read -rep $'\nPress R to restore your original shortcuts.\nPress F to reset to factory shortcuts. (f/r)\n' yn
		case $yn in
			[Ff]* ) yn="f"; break;;
			[Rr]* ) yn="r";break;;
			* ) echo "Please answer yes or no.";;
		esac
	done

	if [ "$yn" == "f" ];then
		echo "Reset to factory shortcuts"
		if [ "$dename" == "gnome" ];then
			echo "Resetting DE hotkeys..."
			echo "gsettings reset-recursively org.gnome.desktop.wm.keybindings"
			gsettings reset-recursively org.gnome.desktop.wm.keybindings
			echo "gsettings reset-recursively org.gnome.mutter.keybindings"
			gsettings reset-recursively org.gnome.mutter.keybindings
		elif [ "$dename" == "kde" ];then
			echo "Resetting DE hotkeys..."
			mv ~/.config/kwinrc ~/.config/kwinrc.kinto
			mv ~/.config/kglobalshortcutsrc ~/.config/kglobalshortcutsrc.kinto
		elif [ "$dename" == "xfce" ];then
			echo "Resetting DE hotkeys..."
			cp /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
		fi
	elif [ "$yn" == "r" ]; then
		echo "Restore original user shortcuts"
		if [ "$dename" == "gnome" ]; then
			echo "Restoring DE hotkeys..."
			wmkeys=$(ls | grep -m1 "keybinding")
			mutterkeys=$(ls | grep -m1 "mutter")
			if [[ ${#wmkeys} > 0 ]]; then
				echo "dconf load /org/gnome/desktop/wm/keybindings/ < $wmkeys"
				dconf load /org/gnome/desktop/wm/keybindings/ < "$wmkeys"
			else
				echo "Gnome Desktop keybindings backup not found..."
			fi
			if [[ ${#mutterkeys} > 0 ]]; then
				echo "dconf load /org/gnome/mutter/keybindings/ < $mutterkeys"
				dconf load /org/gnome/mutter/keybindings/ <"$mutterkeys"
			fi
			if [[ ${#wmkeys} > 0 ]] || [[ ${#mutterkeys} > 0 ]]; then
				echo "Gnome hotkeys have been successfully restored."
			fi
		elif [ "$dename" == "kde" ]; then
			echo "Restoring DE hotkeys..."
			kwinkeys = $(ls | grep -m1 "kwinrc")
			kdekeys = $(ls | grep -m1 "kglobalshortcutsrc")
			cp ./"$kdekeys" ~/.config/kglobalshortcutsrc
			cp ./"$kwinkeys" ~/.config/kwinrc
		elif [ "$dename" == "xfce" ]; then
			echo "Restoring DE hotkeys..."
			xfcekeys = $(ls | grep -m1 "xfce4-keyboard")
			cp ./"$xfcekeys" ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
		fi
	fi
}

if [ $# -eq 0 ]; then
	echo "Install Kinto - xkeysnail (udev)"
	echo "  1) Windows & Mac (HID driver)"
	echo "  2) Mac Only & VMs on Macbooks"
	echo "  3) Chromebook"
	echo "  4) Uninstall"

	read n

	set "$n"
fi

if [[ $1 == "1" || $1 == "2" || $1 == "3" || $1 == "winmac" || $1 == "mac" || $1 == "chromebook" ]]; then
	while true; do
	read -rep $'\nExperimental Support for Firefox/Chrome Back/Forward hotkeys (Cmd+Left/Right)?\n(Keys could get stuck, switch windows or press ctrl &/or super to release) (y/n)\n' yn
	case $yn in
		[Yy]* ) exp='/sbin/runuser -l {username} -c "export DISPLAY={displayid};/home/{username}/.config/kinto/caret_status_xkey.sh\&";'; expsh='"/home/{username}/.config/kinto/caret_status_xkey.sh"'; break;;
		[Nn]* ) exp=" "; expsh=" " break;;
		# * ) echo "Please answer yes or no.";;
	esac
	done
	sudo systemctl enable xkeysnail >/dev/null 2>&1
	if ! [ -x "$(command -v inotifywait)" ]; then
		echo "Will need to install inotify-tools to restart key remapper live for config file changes..."
		sudo ./system-config/unipkg.sh inotify-tools
	fi
	if ! [ -x "$(command -v pip3)" ]; then
		echo "Will need to install python3-pip..."
		sudo ./system-config/unipkg.sh python3-pip
	fi
	
	# echo "Transferring files..."
	mkdir -p ~/.config/kinto
	
	# KDE xhost fix
	mkdir -p ~/.kde/Autostart
	echo -e '#!/bin/sh\rxhost +SI:localuser:root' > ~/.kde/Autostart/kintohost.sh
	chmod +x ~/.kde/Autostart/kintohost.sh

	# KDE startup - xhost fix
	yes | cp -rf ./xkeysnail-config/xkeysnail.desktop ~/.config/autostart/xkeysnail.desktop

	yes | cp -rf ./xkeysnail-config/xkeystart.sh ~/.config/kinto/xkeystart.sh
	yes | cp -rf ./xkeysnail-config/kinto.py ./xkeysnail-config/kinto.py.new
	yes | cp -rf ./xkeysnail-config/limitedadmins ./xkeysnail-config/limitedadmins.new
	yes | cp -rf ./xkeysnail-config/prexk.sh ~/.config/kinto/prexk.sh
	yes | cp -rf ./system-config/caret_status_xkey.sh ~/.config/kinto/caret_status_xkey.sh
	yes | cp -rf ./xkeysnail-config/xkeysnail.service ./xkeysnail-config/xkeysnail.service.new
	# yes | cp -rf ./xkeysnail-config/xkeysnail.timer ~/.config/systemd/user/xkeysnail.timer
	sed -i "s#{experimental-caret}#$exp#g" ./xkeysnail-config/xkeysnail.service.new
	if [ "$expsh" != " " ];then
		sed -i "s#{kill-caret}#/usr/bin/pkill -f $expsh#g" ./xkeysnail-config/xkeysnail.service.new
	else
		sed -i "s#{kill-caret}#$expsh#g" ./xkeysnail-config/xkeysnail.service.new
	fi
	sed -i "s/{username}/`whoami`/g" ./xkeysnail-config/xkeysnail.service.new
	sed -i "s#{xhost}#`which xhost`#g" ./xkeysnail-config/xkeysnail.service.new
	sed -i "s/{username}/`whoami`/g" ./xkeysnail-config/limitedadmins.new
	sed -i "s#{systemctl}#`which systemctl`#g" ./xkeysnail-config/limitedadmins.new
	sudo chown root:root ./xkeysnail-config/limitedadmins.new
	sudo mv ./xkeysnail-config/limitedadmins.new /etc/sudoers.d/limitedadmins
	sed -i "s#{systemctl}#`which systemctl`#g" ~/.config/autostart/xkeysnail.desktop
	sed -i "s#{xhost}#`which xhost`#g" ~/.config/autostart/xkeysnail.desktop
	sed -i "s/{username}/`whoami`/g" ~/.config/kinto/prexk.sh
	sed -i "s/{displayid}/`echo "$DISPLAY"`/g" ./xkeysnail-config/xkeysnail.service.new
	sed -i "s/{displayid}/`echo "$DISPLAY"`/g" ~/.config/kinto/prexk.sh
elif ! [[ $1 == "4" || $1 == "uninstall" ]]; then
	echo "Expected argument was not provided"
fi

if [[ $1 == "1" || $1 == "winmac" ]]; then
	echo '1' | sudo tee -a /sys/module/hid_apple/parameters/swap_opt_cmd;echo 'options hid_apple swap_opt_cmd=1' | sudo tee -a /etc/modprobe.d/hid_apple.conf;sudo update-initramfs -u -k all
	perl -pi -e "s/(# )(.*)(# WinMac)/\$2\$3/g" ./xkeysnail-config/kinto.py.new
elif [[ $1 == "2" || $1 == "mac" ]]; then
	perl -pi -e "s/(# )(.*)(# Mac)/\$2\$3/g" ./xkeysnail-config/kinto.py.new
elif [[ $1 == "3" || $1 == "chromebook" ]]; then
	perl -pi -e "s/(# )(.*)(# Chromebook)/\$2\$3/g" ./xkeysnail-config/kinto.py.new
	perl -pi -e "s/(\w.*)(# Default)/# \$1\$2/g" ./xkeysnail-config/kinto.py.new
fi

if [[ $1 == "1" || $1 == "2" || $1 == "3" || $1 == "winmac" || $1 == "mac" || $1 == "chromebook" ]]; then
	mv ./xkeysnail-config/kinto.py.new ~/.config/kinto/kinto.py
	sudo mv ./xkeysnail-config/xkeysnail.service.new /etc/systemd/system/xkeysnail.service 
	xhost +SI:localuser:root
	git clone --depth 1 https://github.com/rbreaves/xkeysnail.git
	cd xkeysnail
	giturl=$(git ls-remote --get-url)
	if [ "$geturl" != "https://github.com/rbreaves/xkeysnail.git" ];then
		cd ..
		rm -rf ./xkeysnail
		git clone --depth 1 https://github.com/rbreaves/xkeysnail.git
		cd xkeysnail
	fi
	git pull origin master
	sudo pip3 install --upgrade .
	sudo systemctl enable xkeysnail.service
	sudo systemctl daemon-reload
	sudo systemctl restart xkeysnail

	echo -e "Adding xhost fix...\n"

	LINE='xhost +SI:localuser:root'

	if [ ! -e "~/.xprofile" ]; then
		# Ubuntu xhost fix
		echo "$LINE" > ~/.xprofile
		# echo "$LINE" > ~/.xinitrc
	fi
	# Ubuntu xhost fix
	grep -qF -- "$LINE" ~/.xprofile || echo "$LINE" >> ~/.xprofile
	# KDE xhost fix
	# grep -qF -- "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
	# grep -qF -- "$LINE" ~/.xinitrc || echo "$LINE" >> ~/.xinitrc

	# remove kintox11 login startup
	if test -f "~/.config/autostart/kinto.desktop"; then
		rm ~/.config/autostart/kinto.desktop
	fi

	echo -e "Kinto install is \e[1m\e[32mcomplete\e[0m.\n"
	if `sudo systemctl is-active --quiet xkeysnail`;then
		echo -e "Kinto \e[1m\e[32mxkeysnail service is running\e[0m.\n"
		echo "Commands for controlling Kinto's xkeysnail service"
		echo "sudo systemctl restart xkeysnail"
		echo "sudo systemctl stop xkeysnail"
		echo "sudo systemctl start xkeysnail"
		echo "sudo systemctl status xkeysnail"
	else
		echo -e "Kinto \e[1m\e[91mxkeysnail service has failed.\e[0m"
		echo "You can run 'sudo systemctl status xkeysnail' for more info"
	fi
elif ! [[ $1 == "4" || $1 == "uninstall" ]]; then
	echo "Expected argument was not provided"
else
	echo "Uninstalling Kinto - xkeysnail (udev)"
	uninstall
	# Undo Apple keyboard cmd & alt swap
	if test -f "/sys/module/hid_apple/parameters/swap_opt_cmd" && [ `cat /sys/module/hid_apple/parameters/swap_opt_cmd` == "1" ]; then
		echo '0' | sudo tee -a /sys/module/hid_apple/parameters/swap_opt_cmd
		echo 'options hid_apple swap_opt_cmd=0' | sudo tee -a /etc/modprobe.d/hid_apple.conf
		sudo update-initramfs -u -k all
	fi
	sudo systemctl stop xkeysnail
	sudo systemctl disable xkeysnail
	sudo rm /etc/sudoers.d/limitedadmins
	rm ~/.config/autostart/xkeysnail.desktop
	rm -rf ~/.config/kinto
fi