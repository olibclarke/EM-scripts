#!/bin/bash

###########Parameters###########

APIX=1.255              #Pixel size (A)
FRAMES=35              #No. frames in each stack
TOTAL_DOSE=50                #Total accumulated dose (e- per A^2)
AKV=300.0                 #Acc. voltage (kV)
INITIAL_DOSE=0.0        #Pre-exposure dose (e- per A^2)
GAIN_REF=average_gain_ref.mrc   #Gain reference (mrc format)
CS=2.26
AC=0.07
GPU=1
AVE_FRAMES=3            #Frames to average for ctf determination. 4e-/A^2 worth a good starting point.
KEEP_FRAMES=0    #switch to 1 if you want to keep the aligned movie (e.g. for later extraction of per particle movies)
UNBLUR_COMMAND="unblur_openmp_7_17_15.exe"
CTFFIND_COMMAND="ctffind"
SUMMOVIE_COMMAND="sum_movie_openmp_7_17_15.exe"
DSTEP=5.0 #Detector pixel size (um)

###### Nothing below here should need alteration #######
#To  run in parallel (on 12 cores):
#find ./ -maxdepth 1 -name "mic*mrc" -print | parallel -j 12 './unblur.com {/}' >& log &
#

DOSE=`echo "$TOTAL_DOSE/$FRAMES" | bc -l`
DSTEP_A=`echo "$DSTEP*10000" | bc -l`
MAG=`echo "$DSTEP_A/$APIX" | bc -l`

touch starfile_header.txt

echo """ 
data_

loop_
_rlnMicrographName #1
_rlnCtfImage #2
_rlnDefocusU #3
_rlnDefocusV #4
_rlnDefocusAngle #5
_rlnVoltage #6
_rlnSphericalAberration #7
_rlnAmplitudeContrast #8
_rlnMagnification #9
_rlnDetectorPixelSize #10
_rlnFinalResolution #11""" > starfile_header.txt

for i in "$@"
do

basename=`echo ${i} | cut -d'.' -f1`

if [[ -f "gc_${basename}_sum_pick.jpg" ]]; then
jpg_width=`identify -format '%w %h' gc_${basename}_sum_pick.jpg | awk '{print $1}'`
jpg_height=`identify -format '%w %h' gc_${basename}_sum_pick.jpg | awk '{print $2}'`
fi

if [[ -f "gc_${basename}_sum.mrc" ]] && [[ -f "gc_${basename}_sum_DW.mrc" ]] && [[  -f "gc_${basename}_sum_pick.mrc" ]] && [[ -f "gc_${basename}_sum_pick.jpg" ]] && [ $jpg_width == 1007 ] && [ $jpg_height == 512 ]; then
echo "Output files already exist!"
else
t=""

#if tif, convert to mrc
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

#if bzipped, unzip
if [ ${i: -3} == "bz2" ]; then
bzip2 -dk ${i}
i=${i%.bz2}
fi

#gain correct; truncate extreme values by replacing with mean
clip norm -m 2 -h 16 -s ${i} $GAIN_REF gc_${i}.mrc 

wait

#Make non-dose weighted aligned movie and sum
#(For CTF correction)
$UNBLUR_COMMAND << eof
gc_${i}.mrc
$FRAMES
gc_${i%.mrc}_sum.mrc
gc_${i%.mrc}_shifts.txt
$APIX
NO
YES
gc_${i%.mrc}_frames.mrc
NO
eof

wait

#ctffind_params

RES_LOW=30.0
RES_HIGH=3.4
SPECTRUM_SIZE=1024
MIN_DEF=5000.0
MAX_DEF=50000.0
SEARCH_STEP=500.0
EXPECTED_ASTIG=200.0

#Run ctffind
$CTFFIND_COMMAND << eof
gc_${i%.mrc}_frames.mrc
YES
$AVE_FRAMES
gc_${i%.mrc}_ctf.mrc
$APIX
$AKV
$CS
$AC
$SPECTRUM_SIZE
$RES_LOW
$RES_HIGH
$MIN_DEF
$MAX_DEF
$SEARCH_STEP
NO
YES
YES
$EXPECTED_ASTIG
NO
NO
eof


wait

#Make dose-weighted sum
#(For reconstruction/refinement)
$SUMMOVIE_COMMAND << eof
gc_${i}.mrc
$FRAMES
gc_${i%.mrc}_sum_DW.mrc
gc_${i%.mrc}_shifts.txt
gc_${i%.mrc}_sum_DW_frc.txt
1
$FRAMES
$APIX
YES
$DOSE
$AKV
0
YES
eof

wait

#Make sum with noise power not restored
#(For particle picking)
$SUMMOVIE_COMMAND << eof
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

# tail -n2 gc_${i%.mrc}_sum_gctf.star | head -n1 >> gctf_results.star
# 
def1=$( tail -n1 gc_${i%.mrc}_ctf.txt | awk '{print $2}' )
def1_A=`echo "$def1"`
def1=`echo "$def1*0.0001" | bc -l`
def1=$( printf "%1.1f" $def1 )

def2=$( tail -n1 gc_${i%.mrc}_ctf.txt | awk '{print $3}' )
def2_A=`echo "$def2"`
def2=`echo "$def2*0.0001" | bc -l`
def2=$( printf "%1.1f" $def2 )

def_ang=$( tail -n1 gc_${i%.mrc}_ctf.txt | awk '{print $4}' )

res=$( tail -n1 gc_${i%.mrc}_ctf.txt | awk '{print $7}' )
res_A=`echo "$res"`
res=$( printf "%1.1f" $res )

cat starfile_header.txt > gc_${i%.mrc}_ctf.star
echo "gc_${i%.mrc}_sum_DW.mrc	 gc_${i%.mrc}_ctf.mrc	${def1_A}	${def2_A}	${def_ang}	${AKV}	${CS}	${AC}	${MAG}	${DSTEP}	${res_A}" >> gc_${i%.mrc}_ctf.star

wait
mrc2tif -S -C gc_${i%.mrc}_sum_pick.mrc gc_${i%.mrc}_convert.tif
wait
mrc2tif gc_${i%.mrc}_ctf.mrc gc_${i%.mrc}_sum.ctf.tif
wait
convert -gravity northwest -pointsize 40 -resize x1024 -fill white -annotate 0x0+0+15 "Def ${def1} µm, ${def2} µm, Res ${res} Å" gc_${i%.mrc}_sum.ctf.tif gc_${i%.mrc}_sum.ctf.tif
wait
convert -contrast-stretch -4%x0.5% -auto-gamma -brightness-contrast 10x20 -resize x1024 gc_${i%.mrc}_convert.tif gc_${i%.mrc}_convert.tif
wait
convert gc_${i%.mrc}_convert.tif gc_${i%.mrc}_sum.ctf.tif -resize 50% +append  gc_${i%.mrc}_sum_pick.jpg
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

if [ ${KEEP_FRAMES} == 0 ]; then
rm gc_${i%.mrc}_frames.mrc
fi 
wait

fi
done

