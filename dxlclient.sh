#!/bin/bash

workingdir="$( cd "$(dirname "$0")" ; pwd -P )"
source ${workingdir}/ws-options.conf
bindir=${workingdir}/bin
piddir=${workingdir}/pidfiles
FIFOPATH=${workingdir}/fifos

SDRTST=${bindir}/sdrtst
SONDEUDP=${bindir}/sondeudp
RTL_TCP=rtl_tcp

# check if all bins are available
if  [ $(command -v ${RTL_TCP}) ]; then
	RTL_TCP=$(command -v ${RTL_TCP})
else 
	echo "Ich vermisse rtl_tcp" >&2; 
	exit 1; 
fi

command -v ${SONDEUDP} >/dev/null 2>&1 || { echo "I miss " ${SONDEUDP} >&2; exit 1; }
command -v ${SDRTST} >/dev/null 2>&1 || { echo "I miss " ${SDRTST} >&2; exit 1; }

# functions

function startsondeudp {
  echo "Starte sondeudp $i"

  ${SONDEUDP} -f 26000 -o ${FIFO} -I ${objectcall} -u 127.0.0.1:40000 -M 127.0.0.1:${scan_soneudp} -c 0 -v -n 0 -W 5 2>&1 >> ${LOGFILE} &

  echo $sudp_pid > $PIDFILE
  sleep 1
}


function startrtltcp {
  echo "Starte rtl_tcp $i"
  ${RTL_TCP} -s 2048000 -p ${port} -g ${gain} -P ${ppm} -d ${device} 2>&1 >> ${LOGFILE} &
  rtltcp_pid=$!
  echo $rtltcp_pid > $PIDFILE
  sleep 2
  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    echo "rtl_tcp ${device} Start Failed"
    exit 1
  fi
  
}


function startsdrtst {
  echo "Starte sdrtst $i"

  ${SDRTST} -t 127.0.0.1:${port} -c ${SDRCFG} -k -a 15 -e -r 26000 -Z 100 -s ${FIFO} -L 127.0.0.1:${scan_sdrtst} 2>&1 >> ${LOGFILE} &

  sdrtst_pid=$!
  echo $sdrtst_pid > $PIDFILE
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

function killrtltcp {
  # check pidfiles in piddir
  shopt -s nullglob # no error if no PIDFILE
  for f in ${piddir}/rtl_tcp*.pid; do
  pid=$(cat $f)
    if [ -f /proc/$pid/exe ]; then ## pid is running?
    returnval=1
    echo -n "Killing $f "
    until [ $returnval -eq 0 ]; do
      kill -9 $pid
      returnval=$?
      echo -n "."
      sleep 1
    done
    echo ""

    fi
  done
}


tnow=`date "+%x_%X"`
echo $tnow

### kill procs
if [ "x$1" == "xstop" ];then
  echo "auch rtl_tcp? (y/N)"
  read -n 1 quest

  killall sondeudp
  killall sdrtst

  case $quest in
    y|Y|z|Z|j|J)
      killrtltcp
    ;;
  esac
  sanitycheck
  exit 0
fi


### check for sondeudp
for i in ${activesdr[@]}; do 

  eval scan_soneudp="\${$i[scan_soneudp]}" 
  
  FIFO=${FIFOPATH}/multichan-${i}
  LOGFILE=/tmp/sondeudp-${i}.log

  if [ ! -p "$FIFO" ]; then
    mkfifo $FIFO
  fi

  PIDFILE=${piddir}/sondeudp-${i}.pid
  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    startsondeudp
  fi

done


### check for rtl_tcp
for i in ${activesdr[@]}; do

  ## get sdr config
  eval device="\${$i[device]}" 
  eval ppm="\${$i[ppm]}" 
  eval gain="\${$i[gain]}" 
  eval port="\${$i[port]}"
 
  PIDFILE=${piddir}/rtl_tcp-${i}.pid
  LOGFILE=/tmp/rtl_tcp-${i}.log

  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    startrtltcp
  fi

done


### check for sdrtst
for i in ${activesdr[@]}; do

  ## get sdr config
  eval port="\${$i[port]}" 
  eval scan_sdrtst="\${$i[scan_sdrtst]}" 

  FIFO=${FIFOPATH}/multichan-${i}
  SDRCFG=${workingdir}/sdrcfg-${i}.txt
  PIDFILE=${piddir}/sdrtst-${i}.pid
  LOGFILE=/tmp/sdrtst-${i}.log

  checkproc
  returnval=$?
  if [ $returnval -eq 1 ];then
    startsdrtst
  fi

done

exit 0
