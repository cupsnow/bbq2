#!/bin/sh

check_err() {
  [ "$?" = "0" ] || [ "$?" -eq 0 ] && return 0
  echo "ERROR: $*"
  exit 1
}

# duty_cycle  enable      period      polarity

PWMCHIPDIR=/sys/class/pwm/pwmchip0
PERIOD=5000000

duty=10
[ -n "$1" ] && duty=$1
[ $duty -gt 100 ] && duty=100

if [ ! -d ${PWMCHIPDIR}/pwm0 ]; then
  echo 0 > ${PWMCHIPDIR}/export
  check_err "FAIL: alloc pwm0"
fi

duty_val=$(($duty * $PERIOD / 100))

echo 0 > ${PWMCHIPDIR}/pwm0/enable
echo inversed > ${PWMCHIPDIR}/pwm0/polarity
echo $PERIOD > ${PWMCHIPDIR}/pwm0/period
echo $duty_val > ${PWMCHIPDIR}/pwm0/duty_cycle
echo 1 > ${PWMCHIPDIR}/pwm0/enable

echo "Ok: $duty% ($duty_val / $PERIOD)"
