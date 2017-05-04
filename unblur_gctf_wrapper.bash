#!/bin/bash

###########Parameters###########

APIX=1.255              #Pixel size (A)
FRAMES=72              #No. frames in each stack
DOSE=1.4                #Dose per frame (e- per A^2)
AKV=300.0                 #Acc. voltage (kV)
INITIAL_DOSE=0.0        #Pre-exposure dose (e- per A^2)
GAIN_REF=gain_ref.mrc   #Gain reference (mrc format)
CS=2.26
GPU=1

###### Nothing below here should need alteration #######
#To  run in parallel (on 12 cores):
#find ./ -maxdepth 1 -name "mic*mrc" -print | parallel -j 12 './unblur.com {/}' >& log &
#

touch gctf_results.star

for i in "$@"
do

basename=`echo ${i} | cut -d'.' -f1`
if [[ -f "gc_${basename}_sum.mrc" ]] && [[ -f "gc_${basename}_sum_DW.mrc" ]] && [[  -f "gc_${basename}_sum_pick.mrc" ]] && [[ -f "gc_${basename}_sum_pick.jpg" ]]; then
echo "Output files already exist!"
else
#should probably add an if here to deal with tifs
t=""
if [ ${i: -3} == "tif" ]; then
tif2mrc ${i} ${i%.tif}.mrc
i=${i%.tif}.mrc
t=${i}
fi

if [ ${i: -4} == "tiff" ]; then
tif2mrc ${i} ${i%.tiff}.mrc
i=${i%.tiff}.mrc
t=${i}
fi

if [ ${i: -3} == "bz2" ]; then
bzip2 -dk ${i}
i=${i%.bz2}
fi

clip mult -m 2 ${i} $GAIN_REF gc_${i}.mrc #Gain correction

wait

#Make non-dose weighted sum
#(For CTF correction)
unblur_openmp_7_17_15.exe << eof
gc_${i}.mrc
$FRAMES
gc_${i%.mrc}_sum.mrc
gc_${i%.mrc}_shifts.txt
$APIX
NO
NO
NO
eof

wait

Gctf-v1.06_sm_30_cu8.0_x86_64 gc_${i%.mrc}_sum.mrc --gid $GPU --resH 5 --do_Hres_ref --ctfstar gc_${i%.mrc}_sum_gctf.star --apix $APIX --kV $AKV  --Cs $CS --ac 0.07 --do_EPA 1 --dstep 5.0 --do_validation --plot_res_ring
wait

#Make dose-weighted sum
#(For reconstruction/refinement)
sum_movie_openmp_7_17_15.exe << eof
gc_${i}.mrc
$FRAMES
gc_${i%.mrc}_sum_DW.mrc
gc_${i%.mrc}_shifts.txt
gc_${i%.mrc}_sum_DW_frc.txt
1
43
$APIX
YES
$DOSE
$AKV
0
YES
eof

#Make sum with noise power not restored
#(For particle picking)
sum_movie_openmp_7_17_15.exe << eof
gc_${i}.mrc
$FRAMES
gc_${i%.mrc}_sum_pick.mrc
gc_${i%.mrc}_shifts.txt
gc_${i%.mrc}_sum_pick_frc.txt
1
$FRAMES
$APIX
YES
$DOSE
$AKV
0
NO
eof

wait

tail -n2 gc_${i%.mrc}_sum_gctf.star | head -n1 >> gctf_results.star

def1=$( tail -n2 gc_${i%.mrc}_sum_gctf.star | head -n1 | awk '{print $3}' )

def1=`echo "$def1*0.0001" | bc -l`

def1=$( printf "%1.1f" $def1 )

def2=$( tail -n2 gc_${i%.mrc}_sum_gctf.star | head -n1 | awk '{print $4}' )

def2=`echo "$def2*0.0001" | bc -l`

def2=$( printf "%1.1f" $def2 )

res=$( tail -n2 gc_${i%.mrc}_sum_gctf.star | head -n1 | awk '{print $12}' )

res=$( printf "%1.1f" $res )

mv gc_${i%.mrc}_sum.ctf gc_${i%.mrc}_sum.ctf.mrc
wait
mrc2tif -S -C gc_${i%.mrc}_sum_pick.mrc gc_${i%.mrc}_convert.tif
wait
mrc2tif -S -C gc_${i%.mrc}_sum.ctf.mrc gc_${i%.mrc}_sum.ctf.tif
wait
convert -gravity northwest -pointsize 40 -annotate 0x0+0+15 "Def ${def1}µm, ${def2}µm, Res ${res} Å" gc_${i%.mrc}_sum.ctf.tif gc_${i%.mrc}_sum.ctf.tif
wait
convert -contrast-stretch -4%x0.5% -auto-gamma -brightness-contrast 10x20 -resize x1024 gc_${i%.mrc}_convert.tif gc_${i%.mrc}_sum.ctf.tif +append  gc_${i%.mrc}_sum_pick.jpg
wait
rm gc_${i%.mrc}_convert.tif
rm gc_${i%.mrc}_sum.ctf.tif

wait

if [[ -f gc_${i}.mrc ]]; then
rm gc_${i}.mrc
fi

wait
if [[ -f ${t} ]]; then
rm ${t}
fi
wait

fi
done
