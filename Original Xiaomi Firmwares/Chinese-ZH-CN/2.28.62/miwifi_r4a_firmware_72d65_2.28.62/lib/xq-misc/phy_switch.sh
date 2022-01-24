#!/bin/sh

. /lib/functions.sh
config_load misc

# power on all lan port
sw_start_lan() {
    config_get power_reg sw_reg sw_power
    config_get up_val sw_reg sw_power_up
    config_get lan_ports sw_reg sw_lan_ports
    for p in $lan_ports
    do
	mii_mgr -s -p $p -r $power_reg -v $up_val >/dev/null
    done
}

# power off all lan port
sw_stop_lan() {
    config_get power_reg sw_reg sw_power
    config_get down_val sw_reg sw_power_down
    config_get lan_ports sw_reg sw_lan_ports
    for p in $lan_ports
    do
	mii_mgr -s -p $p -r $power_reg -v $down_val >/dev/null
    done
}

# detect link on wan port
sw_wan_link_detect() {
    config_get wan_port sw_reg sw_wan_port
    /usr/sbin/ethstt 2>&1 | grep -e"^port $wan_port" | grep -q "up"
}

# count link on all lan port
sw_lan_count() {
    config_get lan_ports sw_reg sw_lan_ports
    /usr/sbin/ethstt 2>&1 | grep -e"^port [$lan_ports]" | grep "up" | wc -l
}

# is wan port enable gigabytes?
sw_is_wan_giga() {
    config_get wan_port sw_reg sw_wan_port
    mii_mgr -g -p $wan_port -r 9 |grep -q -i 0600
}

# set gigabyte on/off for wan
# sw_set_wan_giga on
# sw_set_wan_giga off
sw_set_wan_giga() {
    config_get wan_port sw_reg sw_wan_port
    config_get reg_config sw_reg sw_phy_config
    config_get reg_neg sw_reg sw_phy_autoneg
    if [ "$1" = 'on' ]; then
    mii_mgr -s -p $wan_port -r $reg_neg -v 600 >/dev/null
    mii_mgr -s -p $wan_port -r $reg_config -v 1240 >/dev/null
    else
    mii_mgr -s -p $wan_port -r $reg_neg -v 0 >/dev/null
    fi

}

# wan port 100M or 10M?
sw_is_wan_100m() {
    config_get wan_port sw_reg sw_wan_port
	config_get neg_val sw_reg sw_neg_100
    mii_mgr -g -p $wan_port -r 4 |grep -q -i $neg_val
}
sw_is_wan_10m(){
    config_get wan_port sw_reg sw_wan_port
	config_get neg_val sw_reg sw_neg_10
    mii_mgr -g -p $wan_port -r 4 |grep -q -i $neg_val
}

# set wan port to 100M or 10M
# sw_set_wan_100m 100
# sw_set_wan_100m 10
sw_set_wan_100m() {
    config_get wan_port sw_reg sw_wan_port
    config_get reg_speed sw_reg sw_phy_speed
    config_get reg_neg sw_reg sw_phy_autoneg
    config_get reg_config sw_reg sw_phy_config
    if [ "$1" = '100' ]; then
	config_get neg_val sw_reg sw_neg_100
    else
	config_get neg_val sw_reg sw_neg_10
    fi
    mii_mgr -s -p $wan_port -r $reg_speed -v $neg_val >/dev/null
    mii_mgr -s -p $wan_port -r $reg_neg -v 0 > /dev/null
    mii_mgr -s -p $wan_port -r $reg_config -v 1240 >/dev/null
}

# issue re-negation on wan
sw_reneg_wan() {
    config_get wan_port sw_reg sw_wan_port
    config_get reg_config sw_reg sw_phy_config
    mii_mgr -s -p $wan_port -r $reg_config -v 1240 >/dev/null
}
