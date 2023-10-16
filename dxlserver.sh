#!/bin/bash

workingdir="$( cd "$(dirname "$0")" ; pwd -P )"
source ${workingdir}/ws-options.conf
piddir=${workingdir}/pidfiles
bindir=${workingdir}/bin
caldir=${workingdir}/calibrations
FIFOPATH=${workingdir}/fifos

beaconfile=${workingdir}/beacon.txt
commentfile=${workingdir}/comment.txt
rinexfile=${workingdir}/rinex.txt

SONDEMOD=${bindir}/sondemod
UDPGATE=${bindir}/udpgate4
UDPGATERS=${bindir}/udpgate4
UDPBOX=${bindir}/udpbox

command -v ${SONDEMOD} >/dev/null 2>&1 || { echo "I miss " ${SONDEMOD} >&2; exit 1; }
command -v ${UDPGATE} >/dev/null 2>&1 || { echo "I miss " ${UDPGATE} >&2; exit 1; }
command -v ${UDPBOX} >/dev/null 2>&1 || { echo "I miss " ${UDPBOX} >&2; exit 1; }

function startudpgate {
  echo "Start udpgate4"
  ${UDPGATE} -v -R 127.0.0.1:4011:4010 -s ${gatewaycall} -n 10:${beaconfile} -l 7:/tmp/aprs.log -g ${aprsserver}:14580 -H 2880 -B 2880 -I 0 -t 14580 -w 14501 -D ${workingdir}/www -p ${aprspass} 2>&1 > /dev/null &
  udpg_pid=$!
  echo $udpg_pid > $PIDFILE
}

function startudpgatesecond {
  echo "Start udpgate4 second"
  ${UDPGATE} -v -R 127.0.0.1:4012:4050 -s ${gatewaycall} -n 10:${beaconfile} -l 7:/tmp/aprs.log -g ${aprsserversecond}:${aprssecondport} -p ${aprspass} 2>&1 > /dev/null &
  udpgsecond_pid=$!
  echo $udpgsecond_pid > $PIDFILE
}

function startsmod {
  echo "Start sondemod"
  ${SONDEMOD} -X ${workingdir}/encrypt.txt -x ${workingdir}/rinex.txt -J 127.0.0.1:4099 -t ${commentfile} -v -V -o 40000 -I ${objectcall} -r 127.0.0.1:4010 -b 20 -B 5 -A 2000 -L 6=DFM06,7=PS15,A=DFM09,B=DFM17,C=DFM09P,D=DFM17,FF=DFMx -d -p 2  2>&1 >> ${LOGFILE} &
  
  smod_pid=$!
  echo $smod_pid > $PIDFILE
}

function startudpbox {
  echo "Start udpbox"

  ${UDPBOX} -v -R 127.0.0.1:4030 -l 127.0.0.1:4010 -l 127.0.0.1:4050 2>&1 >> ${LOGFILE} &
  ubox_pid=$!
  echo $ubox_pid > $PIDFILE
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
  killall sondemod
  killall udpgate4
  killall udpbox
  sanitycheck
  exit 0
fi

# ## check for udpbox
LOGFILE=/tmp/udpbox.log
PIDFILE=${piddir}/udpbox.pid

checkproc
returnval=$?
if [ $returnval -eq 1 ];then
  : > ${LOGFILE}
 # startudpbox
fi

# ## check for udpgate
LOGFILE=/tmp/udpgate.log
PIDFILE=${piddir}/udpgate4.pid

checkproc
returnval=$?
if [ $returnval -eq 1 ];then
  : > ${LOGFILE}
  startudpgate
fi

if [[ ${aprssecond} == "on" ]];then
  # ## check for seond udpgate
  LOGFILE=/tmp/udpgatesecond.log
  PIDFILE=${piddir}/udpgate4second.pid
  
  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    : > ${LOGFILE}
    startudpgatesecond
  fi
fi
 
### check for sondemod 
cd ${caldir}
LOGFILE=/tmp/sondemod.log
PIDFILE=${piddir}/sondemod.pid

checkproc
returnval=$?
if [ $returnval -eq 1 ];then
  : > ${LOGFILE}
  startsmod
fi

sanitycheck

exit 0

