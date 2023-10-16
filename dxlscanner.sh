#!/bin/bash

workingdir="$( cd "$(dirname "$0")" ; pwd -P )"
source ${workingdir}/ws-options.conf
piddir=${workingdir}/pidfiles
bindir=${workingdir}/bin


SCANNER=${bindir}/scanner

command -v ${SCANNER} >/dev/null 2>&1 || { echo "Ich vermisse " ${SCANNER} >&2; exit 1; }


function startscanner {
  echo "Starte scanner $i"

  ${SCANNER} -p ${lport} -u ${uport} -f ${sf} -s 1500 -v -o ${SDRCFG} -b ${file_blacklist} -w ${file_whitelist} -q 50 -n ${level} &

  scanner_pid=$!
  echo $scanner_pid > $PIDFILE
  sleep 2

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
    pid=$(cat $PIDFILE)
    if [ -f /proc/$pid/exe ]; then ## pid is running?
      return 0
    else ## pid not running
      return 1
    fi
  else ## no PIDFILE
    return 1
  fi
}

### kill procs
if [ "x$1" == "xstop" ];then
  killall scanner

  sanitycheck
  exit 0
fi

for i in ${activesdr[@]}; do 
  eval lport="\${$i[lport]}"
  eval uport="\${$i[uport]}"
  eval sf="\${$i[sf]}"
  eval level="\${$i[level]}"

  SDRCFG=${workingdir}/sdrcfg-${i}.txt
  PIDFILE=${piddir}/scanner-${i}.pid

  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    startscanner
  fi

done
