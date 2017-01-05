#!/bin/sh

ifce=wlan0

dhcpd_conf=/etc/udhcpd.conf
dhcpd_pid=/var/run/udhcpd.pid
dhcpd_ip=192.168.2.1

ap_pid=/var/run/hostapd.pid
ap_cfg=/etc/hostapd.conf
ap_ctrl=/var/run/hostapd

sta_pid=/var/run/wpa_supplicant.pid
sta_cfg=/etc/wpa_supplicant.conf
sta_ctrl=/var/run/wpa_supplicant

log_debug() {
  echo "$*"
}

# kill_pid a b c
# argc: 3, argv: a b c
kill_pid() {
  [ -z "$*" ] && return 0
  ret=1
  for i in "$@"; do
    if [ -e ${i} ]; then
      kill `cat $i`
      [ $? -eq 0 ] && ret=0
    fi
  done
  return $ret
}

dhcpd() {
  ifconfig $ifce $dhcpd_ip
  udhcpd ${dhcpd_conf}
}

dhcpc() {
  udhcpc -i $ifce -q
}

sta() {
  wpa_supplicant -i${ifce} -P${sta_pid} -c${sta_cfg} -C${sta_ctrl} -B
}

ap() {
  hostapd -i ${ifce} -P ${ap_pid} -g ${ap_ctrl} -B ${ap_cfg}
}

help() {
cat << eolll
  $0 [kill] [ap|sta|help]
eolll
}

case $1 in
kill)
  case $2 in
  ap)
    kill_pid $ap_pid
    ;;
  sta)
    kill_pid $sta_pid
    ;;
  dhcpd)
    kill_pid $dhcpd_pid
    ;;
  *)
    kill_pid $ap_pid $sta_pid $dhcpd_pid
    ;;
  esac
  ;;
ap)
  $0 kill && sleep 1
  $1
  dhcpd
  ;;
sta)
  $0 kill && sleep 1
  $1
#  dhcpc
  ;;
*)
  help
  ;;
esac
