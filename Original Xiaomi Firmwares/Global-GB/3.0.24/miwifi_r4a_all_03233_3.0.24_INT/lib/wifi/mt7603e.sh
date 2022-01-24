#!/bin/sh
append DRIVERS "mt7603e"

. /lib/wifi/ralink_common.sh

prepare_mt7603e() {
	prepare_ralink_wifi mt7603e
}

scan_mt7603e() {
	scan_ralink_wifi mt7603e mt7603e
}

disable_mt7603e() {
	disable_ralink_wifi mt7603e
}

enable_mt7603e() {
	enable_ralink_wifi mt7603e mt7603e
}

detect_mt7603e() {
	detect_ralink_wifi mt7603e mt7603e
}


