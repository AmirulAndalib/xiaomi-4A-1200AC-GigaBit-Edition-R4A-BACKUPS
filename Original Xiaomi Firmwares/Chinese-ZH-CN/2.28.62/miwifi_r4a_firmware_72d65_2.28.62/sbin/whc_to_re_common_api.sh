#!/bin/sh
# Copyright (C) 2015 Xiaomi
#

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
    logger -p info -t whc_to_re "$1"
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



OPT=$1
#main
whc_to_re_log "$OPT"

case $OPT in
    log_upload)
        call_re_upload_log $1
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

