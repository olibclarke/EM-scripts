#!/bin/bash
#Usage: ./rename_files.com 17feb*mrc
#Output: {prefix}_00001.mrc, {prefix}_00002.mrc, etc
PREFIX="mic"
N=1
for i in "$@" #For file in pattern supplied on command line (e.g.17feb*mrc)
do
printf -v J "%05d" $N #Pad counter with zeroes to fixed width
rename "s/.*\./${PREFIX}_${J}\./" ${i} #Rename each file to PREFIX_number.SUFFIX
N=$((N+1)) #Increment counter
done
