#!/bin/sh
# Copyright (C) 2016 Xiaomi
#

# for p01, called by trafficd handle access
# abandon on d01 instead of checkMaclist() & setMaclist()

local raw_file="/tmp/run/maclist"

add_filter_raw()
{
	local policy="$1"
	local filter=""

	if [ 2 -eq "$policy" ]; then
		filter="deny"
	elif [ 1 -eq "$policy" ]; then
		filter="allow"
	else
		# policy = 0
		filter=""
	fi

	[ -f $raw_file ] && (rm -f $raw_file;sync)
	touch $raw_file
	echo "macfilter_raw $filter" >> $raw_file
	sync
}

add_list_raw()
{
	local mac="$1"
	echo "maclist_raw $mac" >> $raw_file
	sync
}

# check and launch a sync
sync_list()
{
	# only sync wifi maclist in mijia init_done
	local flag=`uci -q get mijia.common.init_done`
	[ -z "$flag" -o 0 -eq "$flag" ] && {
		#logger -p 4 -t "trafficd" "mijia not init_done, maclist sync ignore..."
		[ -f $raw_file ] && (rm -f $raw_file;sync)
		return 1
	}

	[ -f $raw_file ] || return 0

	# get new raw data
	local filter=`awk '/macfilter_raw/ {print $2}' $raw_file`
	[ -z "$filter" ] && filter=""
	local list=`awk '/maclist_raw/ {print $2}' $raw_file | awk '{printf "%s ",$1}' | sed "s/ $//"`
	[ -z "$list" ] && list=""
	[ -f $raw_file ] && (rm -f $raw_file;sync)

	# get active data
	local filter_now=`uci -q get wireless.@wifi-iface[0].macfilter`
	[ -z "$filter_now" ] && filter_now=""
	local list_now=`uci -q get wireless.@wifi-iface[0].maclist | sed "s/ $//"`
	[ -z "$list_now" ] && list_now=""

	local sync=0
	#echo "@@ filter={$filter}"
	#echo "@@ filter_now={$filter_now}"
	[ "$filter" != "$filter_now" ] && {
		sync=1
	}

	#echo "@@ maclist={$list}"
	#echo "@@ list_now={$list_now}"
	[ "$list" != "$list_now" ] && {
		sync=1
	}

	[ 0 -eq "$sync" ] && return 0

	#echo "@@@@ sync wireless maclist & reset wifi"
	logger -p 3 -t "trafficd" "sync wireless maclist & reset wifi"
	uci set wireless.@wifi-iface[0].macfilter="$filter"
	uci -q delete wireless.@wifi-iface[0].maclist
	for ii in $list; do
		uci add_list wireless.@wifi-iface[0].maclist="$ii"
	done
	uci commit wireless
	wifi &
	return 0
}

case $1 in
	filter_raw)
		shift
		add_filter_raw "$1"
		;;
	list_raw)
		shift
		add_list_raw "$1"
		;;

	sync_list)
		sync_list
		;;
esac

