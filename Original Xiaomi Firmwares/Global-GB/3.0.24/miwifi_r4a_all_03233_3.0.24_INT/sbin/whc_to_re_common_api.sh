#!/bin/sh
# Copyright (C) 2015 Xiaomi
#
. /lib/xqwhc/xqwhc_public.sh

RETRY_MAX=3
TOUT=5
RET_OK="success"

HARDWARE=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`

my_usage()
{
    echo "$0:"
    echo "    log_upload     : send log update message to RE"
    echo "    format: $0 log_upload [log_key]"
    echo "    other: usage."
    return;
}

whc_to_re_log()
{
    logger -s -p info -t whc_to_re "$1"
}


__if_whc_re()
{
    tbus list "$1" -v 2>/dev/null | grep -qE "whc_quire[:\",]+" || return 1
    return 0
}

## notify REs with precompose cmd, if re exist&active
# 1. get and validate WHC_RE active in tbus list, exclude repeater & xiaomi_plc
# 2. run tbus cmd
notify_re()
{
    local re_list="`tbus list 2>/dev/null | grep -v netapi | grep -v "master@"`"
    [ -z "$re_list" ] && whc_to_re_log " $cmd $jmsg, NO find valid re on tbus, ignore!"

    for re in $re_list; do
        __if_whc_re "$re" || continue
        buff=""
        res=""
        for ii in `seq 1 1 $RETRY_MAX`; do
            buff="`timeout -t 3 tbus call $re $cmd \"$jmsg\" 2>&1`"
            res="`json_get_value "$buff" "return"`"
            whc_to_re_log " tbus ret=$buff;$res"

            if [ "$res" = "$RET_OK" ]; then
                whc_to_re_log " $cmd $jmsg notify RE <$re> success on $ii "
                break;
            else
                whc_to_re_log " $cmd $jmsg notify RE <$re> fail with $res on $ii time"
                [ "$RETRY_MAX" -le "$ii" ] && {
                    fail=$((fail + 1))
                    whc_to_re_log " ***exception: $cmd $jmsg notify RE <$re> fail RETRY_MAX($RETRY_MAX), give up!!! "
                }   
                sleep 1
            fi  
        done
    done

    return 0
}


# send log update message to RE
call_re_upload_log()
{
    local key=$1
    tbus list | grep -v netapi | grep -v master | while read a
    do
        if [ "$HARDWARE" == "D01" ]; then
            if [ "$key" != "" ]; then
                whc_to_re_log "CMD: tbus call -t 5 $a common_set {\"log_upload\":\"$key\"}"
                local ret=$(tbus call -t 5 $a common_set {\"log_upload\":\"$key\"})
                #bind_log "client bind return: $ret"
                if [ $? -ne 0 ];
                then
                    echo "[tbus call $a common_set {log_upload}] error!"
                    return 1
                fi
            else
                whc_to_re_log "get log key=NULL error!"
            fi
        else
            whc_to_re_log "hardware="$HARDWARE" do not support."
        fi
    done
    return
}

# send log update message to RE
tell_re_do_action()
{
    local msg="$1"
    tbus list | grep -v netapi | grep -v master | while read a
    do
        if [ "$HARDWARE" == "D01" ]; then
            if [ "$msg" != "" ]; then
                whc_to_re_log "CMD: tbus call -t 5 $a common_set {\"action\":$msg}"
                local ret=$(tbus call -t 10 $a common_set {\"action\":$msg})
                local ok=$(echo $ret |grep "success")
                #parse ret value
                if [ "$ok" == "" ];
                then
                    whc_to_re_log "[tbus call $a common_set {action}] error!"
                    return 1
                fi
            else
                whc_to_re_log "get action msg=NULL error!"
            fi
        else
            whc_to_re_log "hardware="$HARDWARE" do not support."
        fi
    done
    return
}

whcal iscap || {
    whc_to_re_log " error, whc_to_re_common_api scr ONLY call on cap!"
    exit 1
}

OPT=$1
#main
whc_to_re_log "$OPT"

cmd="common_set"
jmsg=""

case $OPT in
    log_upload)
        call_re_upload_log $1
        return $?
    ;;
    gw_update)
        newgw="$2"
        jmsg="{\"newgw\":\"$newgw\"}"
    ;;

    action)
        whc_to_re_log "$2"
        tell_re_do_action "$2"
        return $?
    ;;

    test)
        whc_to_re_log "=============== common api test "
        return $?
    ;;

    *)
        my_usage
        return 0
    ;;
esac

notify_re
return $?

