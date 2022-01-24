#!/bin/sh
# mi_iptv

WAN_IFNAME="eth1"
LAN_IFNAME="eth2 eth3 eth4"

iptv_logger() {
    echo "mi_iptv: $1" > /dev/console
    #logger -t mi_iptv "$1"
}

iptv_usage() {
    echo "usage: ./mi_iptv.sh on|off"
    echo "value: on -- enable iptv "
    echo "value: off -- disable iptv"
    echo ""
}

restore6855Esw()
{
        echo "restore GSW to dump switch mode"
        #port matrix mode
        switch reg w 2004 ff0000 #port0
        switch reg w 2104 ff0000 #port1
        switch reg w 2204 ff0000 #port2
        switch reg w 2304 ff0000 #port3
        switch reg w 2404 ff0000 #port4
        switch reg w 2504 ff0000 #port5
        switch reg w 2604 ff0000 #port6
        switch reg w 2704 ff0000 #port7

        #LAN/WAN ports as transparent mode
        switch reg w 2010 810000c0 #port0
        switch reg w 2110 810000c0 #port1
        switch reg w 2210 810000c0 #port2
        switch reg w 2310 810000c0 #port3
        switch reg w 2410 810000c0 #port4
        switch reg w 2510 810000c0 #port5
        switch reg w 2610 810000c0 #port6
        switch reg w 2710 810000c0 #port7

        #clear mac table if vlan configuration changed
        switch clear
}

set_iptv()
{
        lan_vid=$1
        wan_vid=$2

        #clear vlan2
        if [ "$wan_vid" != "1" -a "$wan_vid" != "2" ]; then
		switch vlan set 1 2 00000000
        fi

        #LAN/WAN ports as security mode
        switch reg w 2004 ff0003 #port0
        switch reg w 2104 ff0003 #port1
        switch reg w 2204 ff0003 #port2
        switch reg w 2304 ff0003 #port3
        switch reg w 2404 ff0003 #port4
        switch reg w 2504 ff0003 #port5
        #LAN/WAN ports as transparent port
        switch reg w 2010 810000c0 #port0
        switch reg w 2110 810000c0 #port1
        switch reg w 2210 810000c0 #port2
        switch reg w 2310 810000c0 #port3
        switch reg w 2410 81000400 #port4
        switch reg w 2510 810000c0 #port5
        #switch reg w 2610 81000000 #port6
        switch reg w 2610 810000c0 #port6 set as transparent mode.
        #set CPU/P7 port as user port
        switch reg w 2710 81000000 #port7

        #switch reg w 2604 20ff0003 #port6, Egress VLAN Tag Attribution=tagged
        #set port6 as transparent prot after use 2 GMACS.
        switch reg w 2604 ff0003 #port6,set as security port.
        switch reg w 2704 20ff0003 #port7, Egress VLAN Tag Attribution=tagged
        switch reg w 2610 81000000 #port6

        TMP=`expr 65536 + $lan_vid`
        LAN_PVID=`printf %x $TMP`
        TMP=`expr 65536 + $wan_vid`
        WAN_PVID=`printf %x $TMP`
        #set PVID
        switch reg w 2014 $LAN_PVID #port0
        switch reg w 2114 $LAN_PVID #port1
        switch reg w 2214 $LAN_PVID #port2
        switch reg w 2314 $LAN_PVID #port3
        switch reg w 2414 $WAN_PVID #port4
        switch reg w 2514 $WAN_PVID #port5
        switch reg w 2614 $LAN_PVID #port6

        #VLAN member port
        switch vlan set 0 $lan_vid 11110011
        switch vlan set 1 $wan_vid 00001101
        switch tag on 4
        echo "lan_vid: $lan_vid:$LAN_PVID  wan_vid: $wan_vid:$WAN_PVID"
        switch clear
}

iptv_clean_internet_vlan()
{
        if [ -f "/proc/vlan_enable" ]; then
                echo 0 > /proc/vlan_enable
        fi
        restore6855Esw
        #LAN/WAN ports as security mode
        switch reg w 2004 ff0003 #port0
        switch reg w 2104 ff0003 #port1
        switch reg w 2204 ff0003 #port2
        switch reg w 2304 ff0003 #port3
        switch reg w 2404 ff0003 #port4
        switch reg w 2504 ff0003 #port5
        #LAN/WAN ports as transparent port
        switch reg w 2010 810000c0 #port0
        switch reg w 2110 810000c0 #port1
        switch reg w 2210 810000c0 #port2
        switch reg w 2310 810000c0 #port3
        switch reg w 2410 810000c0 #port4
        switch reg w 2510 810000c0 #port5
        #switch reg w 2610 81000000 #port6
        switch reg w 2610 810000c0 #port6 set as transparent mode.
        #set CPU/P7 port as user port
        switch reg w 2710 81000000 #port7

        #switch reg w 2604 20ff0003 #port6, Egress VLAN Tag Attribution=tagged
        #set port6 as transparent prot after use 2 GMACS.
        switch reg w 2604 ff0003 #port6,set as security port.
        switch reg w 2704 20ff0003 #port7, Egress VLAN Tag Attribution=tagged
        switch reg w 2610 81000000 #port6

        #set PVID
        switch reg w 2014 10001 #port0
        switch reg w 2114 10001 #port1
        switch reg w 2214 10001 #port2
        switch reg w 2314 10001 #port3
        switch reg w 2414 10002 #port4
        switch reg w 2514 10002 #port5
        switch reg w 2614 10001 #port6
        #VLAN member port
        switch vlan set 0 1 11110011
        switch vlan set 1 2 00001101

        switch clear
}

iptv_do_internet_vlan(){
        local internet_tag=$(uci -q get mi_iptv.settings.internet_tag)
        local internet_vid=$(uci -q get mi_iptv.settings.internet_vid)
        local wan_ifname=$WAN_IFNAME
        local internet_vif=""

        if [ "$internet_tag" != "1" ]; then
                return
        fi

        [ $internet_vid -le 0 -o $internet_vid -gt 4094 ] && {
                iptv_logger "invalid internet_vid $internet_vid"
                return
        }

        local wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
        if [ $wan_port != 4 ]; then
                iptv_logger "Wan port is not 4"
                return
        fi

        if [ -f "/proc/vlan_enable" ]; then
                echo 1 > /proc/vlan_enable
        fi

        restore6855Esw
        if [ "$internet_vid" == "1" ]; then
                set_iptv 2 $internet_vid
        else
                set_iptv 1 $internet_vid
        fi

}

iptv_off() {
	iptv_clean_internet_vlan
}

iptv_to_lanap() {
        local internet_tag=$(uci -q get mi_iptv.settings.internet_tag)

        if [ "$internet_tag" != "1" ]; then
                return
        fi

        iptv_clean_internet_vlan
}

iptv_to_ap() {
        local internet_tag=$(uci -q get mi_iptv.settings.internet_tag)

        if [ "$internet_tag" != "1" ]; then
                return
        fi

        iptv_do_internet_vlan
}

iptv_on() {
	iptv_do_internet_vlan
}

mi_iptv_lock="/var/run/mi_iptv.lock"
trap "lock -u $mi_iptv_lock; exit 1" SIGHUP SIGINT SIGTERM
lock $mi_iptv_lock

case "$1" in
	on)
		iptv_on
		;;
	off)
		iptv_off
		;;
	iptv_lanap)
		iptv_to_lanap
		;;
	iptv_ap)
		iptv_to_ap
		;;
	restart)
		iptv_off
		iptv_on
		;;
	*)
		iptv_usage
		;;
esac

lock -u $mi_iptv_lock

return 0
