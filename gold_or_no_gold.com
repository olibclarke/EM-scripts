#!/bin/bash
#if histogram is bimodal, guess that there is gold or carbon in frame, write to gold.lst
#Otherwise, write to no_gold.lst
touch no_gold.lst
touch gold.lst
for i in "$@" #For file in pattern supplied on command line (e.g.17feb*mrc)
do
clip histogram -s ${i} > histogram.tmp
tail -n1 histogram.tmp > histogram_cut.tmp
GOLD_QUERY=`cat histogram.tmp | wc -l`
if [[ ${GOLD_QUERY} == 3 ]]; then
  echo ${i} >> gold.lst
else
  echo ${i} >> no_gold.lst
fi
done
