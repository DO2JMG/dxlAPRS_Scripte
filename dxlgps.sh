#!/bin/bash

workingdir="$( cd "$(dirname "$0")" ; pwd -P )"
source ${workingdir}/ws-options.conf
piddir=${workingdir}/pidfiles
bindir=${workingdir}/bin
caldir=${workingdir}/calibrations
FIFOPATH=${workingdir}/fifos

beaconfile=${workingdir}/beacon.txt
commentfile=${workingdir}/comment.txt


GPS2APRS=${bindir}/gps2aprs

command -v ${GPS2APRS} >/dev/null 2>&1 || { echo "I miss " ${GPS2APRS} >&2; exit 1; }


function startgps2aprs {
  echo "Start gps2aprs"
  ${GPS2APRS} -f 0 -i "/>" -I ${objectcall} -l 1 -N 127.0.0.1:4030 -n 5 -t /dev/ttyACM0:9600 -0 30 -b 15 -g 10 -D -r 127.0.0.1:4030 2>&1 > /dev/null &
  gps_pid=$!
  echo $gps_pid > $PIDFILE
}

function sanitycheck {
# check pidfiles in piddir
  shopt -s nullglob # no error if no PIDFILE
  for f in ${piddir}/*.pid; do
  pid=`cat $f`
    if [ -f /proc/$pid/exe ]; then ## pid is running?
      echo "$(basename $f) ok pid: $pid"
    else ## pid not running
      echo "$(basename $f) died"
      rm $f
    fi
  done
}


function checkproc {
#checks if prog is running or not
  if [ -s $PIDFILE ];then ##have PIDFILE
    pid=`cat $PIDFILE`
    if [ -f /proc/$pid/exe ]; then ## pid is running?
      return 0
    else ## pid not running
      return 1
    fi
  else ## no PIDFILE
    return 1
  fi
}


tnow=`date "+%x_%X"`
echo $tnow

### kill procs
if [ "x$1" == "xstop" ];then
  killall gps2aprs

  sanitycheck
  exit 0
fi

# ## check for udpgate
LOGFILE=/tmp/gps2aprs.log
PIDFILE=${piddir}/gps2aprs.pid

checkproc
returnval=$?
if [ $returnval -eq 1 ];then
  : > ${LOGFILE}
  startgps2aprs
fi

sanitycheck

exit 0

