#!/bin/bash

${workingdir}="$( cd "$(dirname "$0")" ; pwd -P )"

cd /tmp

url=ftp://gssc.esa.int/gnss/data/daily/$(date +%Y)/$(date +%j)/brdc$(date +%j)0.$(date +%y)n.gz

echo $url

if [[ $(wget $url -O-) ]] 2>/dev/null
then
  rm ${workingdir}/rinex.txt
  wget $url
  gzip -f -d brdc$(date +%j)'0.'$(date +%y)n.gz
  mv -f brdc$(date +%j)'0.'$(date +%y)n ${workingdir}/rinex.txt
fi
