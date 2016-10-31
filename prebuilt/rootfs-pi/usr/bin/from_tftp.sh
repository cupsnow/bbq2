REMOTE=192.168.1.47
ret=0

ip_alloc() {
  ADDRFILTER="s/.*inet *addr\:\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\).*/\1/p"
  ADDR="`/sbin/ifconfig | sed -n -e "$ADDRFILTER"`"
  echo "ADDR='$ADDR'"

  LOFILTER="-e s/^127.*/&/p"
  LO="`echo -n "$ADDR" | sed -n "$LOFILTER"`"
  echo "LO='$LO'"

  IPFILTER1="-e s/^127.*//p"
  IPFILTER2="-e s/^169\.254.*//p"
  IP="`echo -n "$ADDR" | sed "$IPFILTER1"`"
  echo "IP='$IP'"
  IP="`echo -n "$IP" | sed "$IPFILTER2"`"
  echo "IP='$IP'"

  [ -n "$IP" ] && return 0

  udhcpc -i eth2 -q
  ERRNO=$?
  [ "$ERRNO" != "0" ] && log_error "failed dhcp"
  return $ERRNO
}

help() {
  echo "usage: $1 [files...]"
  echo "IP=$IP"
  return 0
}

tx() {
  if [ -e $1 ] ; then
    if [ -e $1~ ] ; then
      rm -f $1~
      echo "removed old $1~"
    fi
#     mv $1 $1~
#     echo "renamed $1 to $1~"
  fi
  tftp -g -r $1 $REMOTE
  ret=$?
  if [ "$ret" -ne "0" ]; then
    return $ret
  fi
  chmod +x $1
  ls -l $1
  return 0
}

if [ "$#" -eq "0" ] ; then
  help $0
  exit 1
fi

ip_alloc || exit $?

for arg in $* ; do
  tx $arg
  ret=$?
  if [ "$ret" -ne "0" ] ; then
    echo failed to get \"$arg\"
    exit $ret
  fi
done

exit 0
