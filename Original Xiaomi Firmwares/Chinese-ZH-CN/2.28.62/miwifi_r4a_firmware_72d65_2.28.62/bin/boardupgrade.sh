#!/bin/sh
#

. /lib/upgrade/common.sh

klogger(){
	local msg1="$1"
	local msg2="$2"

	if [ "$msg1" = "-n" ]; then
		echo  -n "$msg2" >> /dev/kmsg 2>/dev/null
	else
		echo "$msg1" >> /dev/kmsg 2>/dev/null
	fi

	return 0
}

hndmsg() {
	if [ -n "$msg" ]; then
		echo "$msg" >> /dev/kmsg 2>/dev/null
		if [ `pwd` = "/tmp" ]; then
			rm -rf $filename 2>/dev/null
		fi
		exit 1
	fi
}



board_prepare_upgrade() {

	#protect self from oom
	echo -1000 > /proc/$$/oom_score_adj

	#ease memory pressure
	sync

	wifi down
	rmmod mt7603e
	rmmod mt76x2e

	if [ -f "/etc/init.d/sysapihttpd" ] ;then
	    /etc/init.d/sysapihttpd stop 2>/dev/null
	fi

	# gently stop pppd, let it close pppoe session
	ifdown wan
	timeout=5
	while [ $timeout -gt 0 ]; do
	    pidof pppd >/dev/null || break
	    sleep 1
	    let timeout=timeout-1
	done

	# clean up upgrading environment
	# call shutdown scripts with some exceptions
	wait_stat=0
	klogger "Calling shutdown scripts"
	for i in /etc/rc.d/K*; do
		# filter out K01reboot-wdt and K99umount
		echo "$i" | grep -q '[0-9]\{1,100\}reboot-wdt$'
		if [ $? -eq 0 ]
		then
			klogger "$i skipped"
			continue
		fi
		echo "$i" | grep -q '[0-9]\{1,100\}umount$'
		if [ $? -eq 0 ]
		then
			klogger "$i skipped"
			continue
		fi

		if [ ! -x "$i" ]
		then
			continue
		fi

		# wait for high-priority K* scripts to finish
		echo "$i" | grep -qE "K9"
		if [ $? -eq 0 ]
		then
			if [ $wait_stat -eq 0 ]
			then
				wait
				sleep 2
				wait_stat=1
			fi
			$i shutdown 2>&1
		else
			$i shutdown 2>&1 &
		fi
	done

	# try to kill all userspace processes
	# at this point the process tree should look like
	# init(1)---sh(***)---flash.sh(***)
	for i in $(ps w | grep -v "sh" | grep -v "PID" | awk '{print $1}'); do
	        if [ $i -gt 100 ]; then
		        kill -9 $i 2>/dev/null
	        fi
	done
}

board_start_upgrade_led() {
	gpio l 8 0 4000 0 0 0 # blue: off
	gpio l 10 10 10 1 0 4000 # yellow: blink
	gpio l 6 0 4000 0 0 0 # red: off
}


upgrade_write_mtd() {
	target_os="OS1"

	klogger "Close /dev/watchdog..."
	echo 'V' > /dev/watchdog

	[ -f uboot.bin ] && {
		klogger "Updating boot..."
		mtd write uboot.bin Bootloader || msg="Upgrade uboot Failed!!!"
	}

	[ -f firmware.bin ] && {
		klogger "Updating firmware..."
		mtd write firmware.bin "$target_os" || msg="Upgrade firmware Failed!!!"
	}

	hndmsg
}

board_system_upgrade() {
	local filename=$1

	mkxqimage -x $filename
	[ "$?" = "0" ] || {
		klogger "cannot extract files"
		rm -rf $filename
		exit 1
	}

	upgrade_write_mtd

	return 0

}
