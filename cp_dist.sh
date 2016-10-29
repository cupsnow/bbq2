#!/bin/bash

COLOR="\033[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"

ECHO="echo -e"

# assume $1 is level when $# more then 1
log_msg() {
  level=
  if [ $# -gt 1 ]; then
    level=$1
    shift
  fi
  case "$level" in
  1)
    $ECHO "${COLOR_RED}ERROR${COLOR}: $*"
    ;;
  *)
    $ECHO "${COLOR_GREEN}$*${COLOR}"
    ;;
  esac
}

log_error() {
  log_msg 1 "$*"
}

log_debug() {
  log_msg "$*"
}

show_help() {
cat <<EOF
SYNOPSIS
  $1 [OPTIONS]

OPTIONS
  -h, --help   Show help
  -s, --src=DIR
               Set partition source dir[<>]
  -t, --tgt=LABEL
               Set partition label[<>]
EOF
}


check_error() {
  [ "$?" = "0" ] && return 0
  log_error "$*"
  exit 1
}

cp_dist() {
  srcdir=$1
  destdir=$2
    echo -n "Copy $srcdir to $destdir: [y/N]: "
  read cp_root && cp_root=`echo $cp_root | tr '[:upper:]' '[:lower:]'`
  if [ "$cp_root" = "y" ]; then
    echo -n "Erase all in $destdir [y/N]: "
    read rm_all && rm_all=`echo $rm_all | tr '[:upper:]' '[:lower:]'`
    if [ "$rm_all" = "y" ]; then
      echo "Erasing all in $destdir (might ask sudo password)"
      sudo rm -rf ${destdir}/{*,.[!.]*}
      check_error "Failed to remove all in $destdir"
    fi
    echo "Copying $srcdir to $destdir"
    cp -a ${srcdir}/* ${destdir}/
  fi
}

OPT_SAVED="$*"

OPT_PARSED=`getopt -l "help,src:,tgt:," "hs:t:" $@`
r=$?
if [ ! "$r" = "0" ]; then
  show_help $0
  exit $r
fi

# re-assign positional parameter
eval set -- "$OPT_PARSED"
while true; do
#  log_debug "parse[$#] $*"
  case "$1" in
  -h|--help)
    show_help $0
    exit 1
    ;;
  -s|--src)
    SRC=$2
    shift
    ;;
  -t|--tgt)
    TGT=$2
    shift
    ;;
  --)
    if [ -z "$SRC" ]; then 
      SRC=$2
      shift
    fi
    if [ $# -lt 2 ]; then break; fi
    if [ -z "$TGT" ]; then 
      TGT=$2
      shift
    fi
    break
    ;;
  esac
  shift
done

if [ -z "$SRC" ]; then
  log_error "Missing source dir"
  show_help $0
  exit 1
fi

if [ -z "$TGT" ]; then
  log_error "Missing target label"
  show_help $0
  exit 1
fi

# PLATFORM=`cat Makefile | sed -n -e "s/^\\s*PLATFORM\\s*=\\s*\(.*\)\\s*$/\\1/p"`
# log_debug "PLATFORM: ${PLATFORM}"
cp_dist "$SRC" "/media/$USER/$TGT"
