#!/bin/sh
# Copyright (C) 2016 Xiaomi
#

# for d01, called by trafficd handle whc_sync

USE_ENCODE=1


whcal isre || exit 0

. /lib/xqwhc/xqwhc_public.sh

xqwhc_lock="/var/run/xqwhc_wifi.lock"
cfgf="/var/run/trafficd_whc_sync"
cfgf_fake="/var/run/trafficd_whc_sync_fake"
son_changed=0   # wifi change, need wifi reset
sys_changed=0
B64_ENC=0

SUPPORT_GUEST_ON_RE=0   # for now, we only support guest network on CAP. so we don not handle guest opts

wifi_parse()
{
    # wifi-iface options, both sta and ap
    local ssid_enc="`cat $cfgf | grep -w "ssid" | awk -F ":=" '{print $2}'`"
    local pswd_enc="`cat $cfgf | grep -w "pswd" | awk -F ":=" '{print $2}'`"
    local ssid="$ssid_enc"
    local pswd="$pswd_enc"
    if [ "$USE_ENCODE" -gt 0 ]; then
        ssid="$(base64_dec "$ssid_enc")"
        pswd="$(base64_dec "$pswd_enc")"
    fi
    local mgmt="`cat $cfgf | grep -w "mgmt" | awk -F ":=" '{print $2}'`"
    local hidden="`cat $cfgf | grep -w "hidden" | awk -F ":=" '{print $2}'`"

    [ -z "$ssid" ] && {
        WHC_LOGE " trafficd_whc_sync, wifi options invalid ignore!"
        cp "$cfgf" "$cfgf_fake"
        return 1
    }

    for i in `seq 0 1 3`; do
        ssid_cur="`uci -q get wireless.@wifi-iface[$i].ssid`"
        pswd_cur="`uci -q get wireless.@wifi-iface[$i].key`"
        mgmt_cur="`uci -q get wireless.@wifi-iface[$i].encryption`"
        hidden_cur="`uci -q get wireless.@wifi-iface[$i].hidden`"
        [ -z "$hidden_cur" ] && hidden_cur=0

        [ "$ssid_cur" != "$ssid" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, ssid change $ssid_cur -> $ssid"
            uci set wireless.@wifi-iface[$i].ssid="$ssid"
        }
        [ "$pswd_cur" != "$pswd" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, pswd change $pswd_cur -> $pswd"
            uci set wireless.@wifi-iface[$i].key="$pswd"
        }
        [ "$mgmt_cur" != "$mgmt" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, mgmt change $mgmt_cur -> $mgmt"
            uci set wireless.@wifi-iface[$i].encryption="$mgmt"
        }
        [ "$hidden_cur" != "$hidden" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, hidden change $hidden_cur -> $hidden"
            uci set wireless.@wifi-iface[$i].hidden="$hidden"
        }
    done


    # wifi-device options
    local txp_2="`cat $cfgf | grep -w "txpwr_2g" | awk -F ":=" '{print $2}'`"
    local ch_2="`cat $cfgf | grep -w "ch_2g" | awk -F ":=" '{print $2}'`"
    [ -z "$ch_2" -o "0" = "$ch_2" ] && ch_2="auto"
    local bw_2="`cat $cfgf | grep -w "bw_2g" | awk -F ":=" '{print $2}'`"
    local txp_2_cur="`uci -q get wireless.wifi0.txpwr`"
    local ch_2_cur="`uci -q get wireless.wifi0.channel`"
    [ -z "$ch_2_cur" -o "0" = "$ch_2_cur" ] && ch_2_cur="auto"
    local bw_2_cur="`uci -q get wireless.wifi0.bw`"
    [ -z "$bw_2_cur" ] && bw_2_cur=0

    [ "$ch_2" != "$ch_2_cur" ] && {
        uci set wireless.wifi0.channel="$ch_2"
        # check real channel, if SAME then should save one wifi reset
        local ch_2_act="`iwlist wl1 channel | grep -Eo "\(Channel.*\)" | grep -Eo "[1-9]+"`"
        [ "$ch_2" != "$ch_2_act" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, wifi0 dev change channel $ch_2_act -> $ch_2 "
        }
    }

    [ "$txp_2" != "$txp_2_cur" -o "$bw_2" != "$bw_2_cur" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, wifi0 dev change $txp_2_cur:$bw_2_cur -> $txp_2:$bw_2 "
        uci set wireless.wifi0.txpwr="$txp_2"
        uci set wireless.wifi0.bw="$bw_2"
    }

    local txp_5="`cat $cfgf | grep -w "txpwr_5g" | awk -F ":=" '{print $2}'`"
    local ch_5="`cat $cfgf | grep -w "ch_5g" | awk -F ":=" '{print $2}'`"
    local bw_5="`cat $cfgf | grep -w "bw_5g" | awk -F ":=" '{print $2}'`"
    local txbf="`cat $cfgf | grep -w "txbf" | awk -F ":=" '{print $2}'`"
    #[ -z "$txbf" ] && txbf=3

    local txp_5_cur="`uci -q get wireless.wifi1.txpwr`"
    local ch_5_cur="`uci -q get wireless.wifi1.channel`"
    local bw_5_cur="`uci -q get wireless.wifi1.bw`"
    [ -z "$bw_5_cur" ] && bw_5_cur=0
    local txbf_cur="`uci -q get wireless.wifi1.txbf`"
    [ -z "$txbf_cur" ] && txbf_cur=3

    [ "$ch_5" != "$ch_5_cur" ] && {
        uci set wireless.wifi1.channel="$ch_5"
        # check real channel, if SAME then should save one wifi reset
        local ch_5_act="`iwlist wl0 channel | grep -Eo "\(Channel.*\)" | grep -Eo "[1-9]+"`"
        [ "$ch_5" != "$ch_5_act" ] && {
            son_changed=1
            WHC_LOGI " trafficd_whc_sync, wifi1 dev change channel $ch_5_act -> $ch_5 "
        }
    }
    [ "$txp_5" != "$txp_5_cur" -o "$bw_5" != "$bw_5_cur" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, wifi1 dev change $txp_5_cur:$bw_5_cur -> $txp_5:$bw_5"
        uci set wireless.wifi1.txpwr="$txp_5"
        uci set wireless.wifi1.bw="$bw_5"
    }

    [ -n "$txbf" -a "$txbf" -ne "$txbf_cur" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, wifi1 dev change txbf [$txbf_cur] -> [$txbf]"
        uci set wireless.wifi1.txbf="$txbf"
    }
    uci commit wireless && sync

    return 0;
}

plc_parse()
{
    . /lib/xqwhc/plc_lal.sh
    nmk="$(plc_calc_nmkpwd)"

    local nmk_cur="`uci -q get plc.config.NetworkPassWd`"

    [ "$nmk_cur" != "$nmk" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, plc nmk change $nmk_cur -> $nmk"
        uci set plc.config.NetworkPassWd="$nmk"
        uci commit plc
    }

    return 0
}

guest_parse()
{
    local gst_sect="guest"

    local disab="`cat $cfgf | grep -w "gst_disab" | awk -F ":=" '{print $2}'`"
    [ -z "$disab" ] && disab=0
    local ssid_enc="`cat $cfgf | grep -w "gst_ssid" | awk -F ":=" '{print $2}'`"
    local pswd_enc="`cat $cfgf | grep -w "gst_pswd" | awk -F ":=" '{print $2}'`"
    local ssid="$ssid_enc"
    local pswd="$pswd_enc"
    if [ "$USE_ENCODE" -gt 0 ]; then
        ssid="$(base64_dec "$ssid_enc")"
        pswd="$(base64_dec "$pswd_enc")"
    fi
    local mgmt="`cat $cfgf | grep -w "gst_mgmt" | awk -F ":=" '{print $2}'`"

    [ -z "$ssid" ] && {
        WHC_LOGE " trafficd_whc_sync, guest options invalid ignore!"
        cp "$cfgf" "$cfgf_fake"
        return 1
    }

    # if guest section no exist, create first
    local disab_cur=0
    local ssid_cur=""
    local pswd_cur=""
    local mgmt_cur=""

    if uci -q get wireless.$gst_sect >/dev/null 2>&1; then
        disab_cur="`uci -q get wireless.$gst_sect.disabled`"
        [ -z "$disab_cur" ] && disab_cur=0;
        ssid_cur="`uci -q get wireless.$gst_sect.ssid`"
        pswd_cur="`uci -q get wireless.$gst_sect.key`"
        mgmt_cur="`uci -q get wireless.$gst_sect.encryption`"
    else
        WHC_LOGI " trafficd_whc_sync, guest section newly add, TODO son options"
        disab_cur=1;
        uci set wireless.$gst_sect=wifi-iface
        uci set wireless.$gst_sect.device='wifi0'
        uci set wireless.$gst_sect.mode='ap'
        uci set wireless.$gst_sect.ifname='wl3'
        ##### TODO, guest iface options
    fi

    [ "$ssid_cur" != "$ssid" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, guest ssid change $ssid_cur -> $ssid"
        #uci set wireless.$gst_sect.ssid="$ssid"
    }
    [ "$pswd_cur" != "$pswd" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, guest pswd change $pswd_cur -> $pswd"
        uci set wireless.$gst_sect.key="$pswd"
    }
    [ "$mgmt_cur" != "$mgmt" ] && {
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, guest mgmt change $mgmt_cur -> $mgmt"
        uci set wireless.$gst_sect.encryption="$mgmt"
    }
    
    if [ "$disab_cur" != "$disab" ]; then
        son_changed=1
        WHC_LOGI " trafficd_whc_sync, guest disab change $disab_cur -> $disab"
        uci set wireless.$gst_sect.disabled="$disab"
    else
        [ "$disab" = 1 -a "$son_changed" -gt 0 ] && {
            WHC_LOGI " trafficd_whc_sync, guest disab, with option change, ignore reset"
            son_changed=0
        }
    fi

    uci commit wireless && sync

    return 0
}

system_parse()
{
    local timezone="`cat $cfgf | grep -w "timezone" | awk -F ":=" '{print $2}'`"
    local timezone_cur="`uci -q get system.@system[0].timezone`"
    [ "$timezone_cur" != "$timezone" ] && {
        sys_changed=1
        WHC_LOGI " trafficd_whc_sync, system timezone change $timezone_cur -> $timezone"
        uci set system.@system[0].timezone="$timezone"
        uci commit system
    }

    local ota_auto="`cat $cfgf | grep -w "ota_auto" | awk -F ":=" '{print $2}'`"
    [ -z "$ota_auto" ] && ota_auto=0
    local ota_auto_cur="`uci -q get otapred.settings.auto`"
    [ -z "$ota_auto_cur" ] && ota_auto_cur=0
    local ota_time="`cat $cfgf | grep -w "ota_time" | awk -F ":=" '{print $2}'`"
    local ota_time_cur="`uci -q get otapred.settings.time`"
    [ -z "$ota_time_cur" ] && ota_time_cur=4
    [ "$ota_auto" != "$ota_auto_cur" -o "$ota_time" != "$ota_time_cur" ] && {
        sys_changed=1
        WHC_LOGI " trafficd_whc_sync, system ota change $ota_auto_cur,$ota_time_cur -> $ota_auto,$ota_time"
        uci set otapred.settings.auto="$ota_auto"
        uci set otapred.settings.time="$ota_time"
        uci commit otapred
    }

    local led_blue="`cat $cfgf | grep -w "led_blue" | awk -F ":=" '{print $2}'`"
    [ -z "$led_blue" ] && led_blue=1
    local led_blue_cur="`uci -q get xiaoqiang.common.BLUE_LED`"
    [ -z "$led_blue_cur" ] && led_blue_cur=1
    [ "$led_blue" != "$led_blue_cur" ] && {
        sys_changed=0
        WHC_LOGI " trafficd_whc_sync, system led change $led_blue_cur -> $led_blue"
        uci set xiaoqiang.common.BLUE_LED="$led_blue"
        uci commit xiaoqiang
        [ "$led_blue" -eq 0 ] && {
            gpio_led blue off 
        } || {
            # led_blue on, let metric decide led beheave
            /etc/init.d/xqwhc restart
        }
    }

    return 0
}



# must call guest_parse first
[ "$SUPPORT_GUEST_ON_RE" -gt 0 ] && {
    guest_parse || exit $?
}
wifi_parse || return $?
plc_parse
system_parse

if [ "$sys_changed" -gt 0 ]; then
    WHC_LOGI " trafficd_whc_sync, sys_changed, restart ntp!"
    # wait son update and reconnect
    (sleep 60; ntpsetclock now) &
fi

if [ "$son_changed" -gt 0 ]; then
    WHC_LOGI " trafficd_whc_sync, son_changed, need reset son!"
    ( lock "$xqwhc_lock";
    /etc/init.d/repacd restart_in_re_mode;
    lock -u "$xqwhc_lock" ) &

else
    WHC_LOGD " trafficd_whc_sync, son NO change!"
fi

