#!/bin/sh
# Copyright (C) 2016 Xiaomi
#
#set -x
. /lib/functions.sh

bind_log()
{
    echo "$1"
    logger -p warn -t bind "$1"
}

# parse json code
parse_json()
{
    # {"code":0,"data":{"bind":1,"admin":499744955}}
    echo "$1" | awk -F "$2" '{print$2}'|awk -F "" '{print $3}'
}

# do on client, after get his signatures
check_my_bind_status()
{
    local bind_status=$(timeout -t 5 matool --method api_call --params "/device/minet_get_bindinfo" 2>/dev/null)
    if [ $? -ne 0 ];
    then
        echo "[matool --method minet_get_bindinfo] error!"
        return 2
    fi
    # {"code":0,"data":{"bind":1,"admin":499744955}}
    local code=$(parse_json $bind_status "code")
    if [ -n "$code" ] && [ $code -eq 0 ]; then
        bind_log "code: $code"
        local bind=$(parse_json $bind_status "bind")
        bind_log "my bind_status: $bind"
        return $bind
    else
        return 0
    fi
}

bind_remote_client()
{
    local HardwareVersion=$1
    local SN=$2
    local ROM=$3
    local IP=$4
    local RECORD=$5
    local Channel=$(uci get /usr/share/xiaoqiang/xiaoqiang_version.version.CHANNEL)

    # 1. get signature for client
    bind_log "HardwareVersion: $HardwareVersion"
    bind_log "SN: $SN"
    bind_log "ROM: $ROM"
    bind_log "IP: $IP"
    bind_log "My Channel: $Channel"
    # get signatures for client
    # matool --method sign --params "{SN}&{HardwareVersion}&{ROM}&{Channel}"
    #matool --method sign --params "{$SN}&{$HardwareVersion}&{$ROM}&{$Channel}"
    local signature=$(timeout -t 5 matool --method sign --params "$SN&$HardwareVersion&$ROM&$Channel" 2>/dev/null)
    #echo "matool --method sign --params \"{$SN}&{$HardwareVersion}&{$ROM}&{$Channel}\""
    if [ $? -ne 0 ];
    then
        echo "[matool --method sign] error!"
        return 1
    fi
    #bind_log "get signature: $signature"

    # 2. sent my device ID and signature to client
    #tbus call 192.168.31.73 bind '{"action":1,"msg":"hello"}'
    #signature="582e7ad35a1479f9f3e2cb7f0855b5549b0e1501"
    #IP="192.168.31.73"
    local deviceID=$(uci get messaging.deviceInfo.DEVICE_ID 2>/dev/null)
    #bind_log "get deviceID: $deviceID"

    bind_log "CMD: tbus call -t 10 $IP bind  {\"record\":\"$RECORD\",\"deviceID\":\"$deviceID\",\"sign\":\"$signature\"}"
    local ret=$(tbus call -t 10 $IP bind {\"record\":\"$RECORD\",\"deviceID\":\"$deviceID\",\"sign\":\"$signature\"})
    #bind_log "client bind return: $ret"
    if [ $? -ne 0 ];
    then
        echo "[tbus call $IP bind] error!"
        return 1
    fi
    #bind_log "timeout -t 5 tbus call $IP bind "\'{\"action\":1,\"deviceID\":\"$deviceID\",\"sign\":\"$signature\"}\'""
}

# do on client, after get his signatures
bind_me()
{
    #matool --method joint_bind --params {device_id} {sign}
    local device_id=$1
    local sign=$2
    local record=$3
    bind_log "get master deviceID: $device_id"
    bind_log "get master sign: $sign"
    bind_log "get master record: $record"
    bind_log "cmd: timeout -t 5 matool --method joint_bind --params "$device_id" "$sign" 2>/dev/null"
    local bind_ret=$(timeout -t 5 matool --method joint_bind --params "$device_id" "$sign" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "[method joint_bind] error!"
        return 0
    else
        # update bind record according to master bind info.
        uci set bind.info.status=1
        uci set bind.info.record=$record
        uci set bind.info.remoteID=$device_id
        uci commit bind
        echo "[method joint_bind] ok!"

        # push xqwhc setkv on bind success
        logger -p 1 -t "xqwhc_push" " RE push xqwhc kv info on bind success"
        sh /usr/sbin/xqwhc_push.cron now &
    fi

    local deviceID=$(uci get messaging.deviceInfo.DEVICE_ID 2>/dev/null)
    bind_log "get new deviceID: $deviceID"
    # check new status
    check_my_bind_status
}


OPT=$1
#bind_log "OPT: $OPT"

echo  $OPT
case $OPT in
    bind_remote)
        #1. check bind status
        check_my_bind_status
        if [ $? -eq 1 ]; then
            bind_remote_client "$2" "$3" "$4" "$5" "$6"
        fi
        return 0
        ;;
    bind_me)
        #check_my_bind_status
        # just do when not binded
        #if [ $? -eq 0 ]; then
        #    bind_me "$2" "$3" "$4"
        #fi
        # bind all the time
        bind_me "$2" "$3" "$4"
        return 0
        ;;
    *)
        return 0
        ;;
esac


