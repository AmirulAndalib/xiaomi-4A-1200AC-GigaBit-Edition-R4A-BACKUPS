#!/bin/sh

wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
wan_check_exist=`ps | grep "pppoe_check" | grep -v grep`
[ -n $wan_port ] || exit 0

[ $wan_port = $PORT_NUM -a $LINK_STATUS = "linkup" ] && {
    [ -z "$wan_check_exist" ] && /usr/sbin/pppoe_check trafficd &
    pidof udhcpc >/dev/null || exit 0
    logger -p warn -t "trafficd" "run wwdog because wan port up"
    pidof wwdog >/dev/null || /usr/sbin/wwdog
    exit 0
}

[ $wan_port = $PORT_NUM -a $LINK_STATUS = "linkdown" ] && {
    [ -z "$wan_check_exist" ] && /usr/sbin/pppoe_check trafficd &
    pidof udhcpc > /dev/null || exit 0
    . /lib/xq-misc/phy_switch.sh
    if ! sw_wan_link_detect; then
	logger -p warn -t "trafficd" "port wan is unplugged"
	ifup wan
    fi
    exit 0
}
