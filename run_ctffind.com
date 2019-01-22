#!/bin/bash
#
#For running on non-gain-corrected TIF movies, with separate gain reference:
#find ./ -maxdepth 1 -name "*tif" -print | parallel -j 40 './run_ctffind.com {/}' >& log &
#
#If run using the above method, it may miss a handful of files on the first run. 
#That's okay - just run it without parallel afterwards to clean up the scraps, e.g.:
#./run_ctffind.com *tif >& log &
#
#After completion, combine per-mic star files as follows (this example also sorts by CTF fit res):
#
#cat starfile_header.txt > ctffind_out.star
#cat *ctf.star | awk 'NF==11{print}{}' | sort -k11n >> ctffind_out.star
#
#
#To stop, make a file called "stop" in the working directory, e.g. "touch stop"
#(You will still need to kill the launch script if using parallel, e.g. "killall perl")
#
#Script will add two extra columns - _rlnCrossCorrelation and _rlnIceIntensity.
#These are useful for sorting the files (to identify poor CTF fits and icy mics)
#But they are not read by RELION, so you may want to delete these labels from the header before importing.
#
###########Parameters###########

APIX=1.06              #Pixel size (A)
FRAMES=50              #No. frames in each stack
TOTAL_DOSE=71                #Total accumulated dose (e- per A^2)
AKV=300.0                 #Acc. voltage (kV)
INITIAL_DOSE=0.0        #Pre-exposure dose (e- per A^2)
GAIN_REF=gain_ref.mrc   #Gain reference (mrc format)
CS=2.7
AC=0.07
AVE_FRAMES=1            #Frames to average for ctf determination. 4e-/A^2 worth a good starting point. If using raw (unaligned_ movies maybe 1 is better.
CTFFIND_COMMAND="ctffind"
DSTEP=5.0 #Detector pixel size (um)

#ctffind_params
RES_LOW=30.0
RES_HIGH=4
SPECTRUM_SIZE=1024
MIN_DEF=2000.0
MAX_DEF=30000.0
SEARCH_STEP=500.0
EXPECTED_ASTIG=500.0
THREADS=24

###### Nothing below here should need alteration #######

DOSE=`echo "$TOTAL_DOSE/$FRAMES" | bc -l`
DSTEP_A=`echo "$DSTEP*10000" | bc -l`
MAG=`echo "$DSTEP_A/$APIX" | bc -l`
SCRIPT_PID=`echo $$`

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
_rlnFinalResolution #11
_rlnCrossCorrelation #12
_rlnIceIntensity #13 """ > starfile_header.txt

for i in "$@"
do

if [[ -f "${i%.tif}_ctf.star" ]] && [[ -f "${i%.tif}_ctf.star" ]] && [[ `cat "${i%.tif}_ctf.txt" | wc -l` == 6 ]]; then
echo "Output files already exist!"
else

#Run ctffind
$CTFFIND_COMMAND << eof
${i}
YES
$AVE_FRAMES
${i%.tif}_ctf.mrc
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
NO
YES
$EXPECTED_ASTIG
NO
YES
YES
NO
$GAIN_REF
NO
NO
$THREADS
eof


wait

if [[ `cat ${i%.tif}_ctf.txt | wc -l` == 6 ]]; then
def1=$( tail -n1 ${i%.tif}_ctf.txt | awk '{print $2}' )
def1_A=`echo "$def1"`
def1=`echo "$def1*0.0001" | bc -l`
def1=$( printf "%1.1f" $def1 )

def2=$( tail -n1 ${i%.tif}_ctf.txt | awk '{print $3}' )
def2_A=`echo "$def2"`
def2=`echo "$def2*0.0001" | bc -l`
def2=$( printf "%1.1f" $def2 )

def_ang=$( tail -n1 ${i%.tif}_ctf.txt | awk '{print $4}' )

res=$( tail -n1 ${i%.tif}_ctf.txt | awk '{print $7}' )
res_A=`echo "$res"`
res=$( printf "%1.1f" $res )

ccc=$( tail -n1 ${i%.tif}_ctf.txt | awk '{print $6}' )

tail -n6 ${i%.tif}_ctf_avrot.txt | awk '
{
    for (i=1; i<=NF; i++)  {
        a[NR,i] = $i
    }
}
NF>p { p = NF }
END {
    for(j=1; j<=p; j++) {
        str=a[1,j]
        for(i=2; i<=NR; i++){
            str=str" "a[i,j];
        }
        print str
    }
}' > tmp1

ice_intensity=`grep "0.271436" tmp1 | awk '{print $3}' | bc -l`

if (( $(echo "$ice_intensity > 2.0" | bc -l ) )); then
echo "${i} ${ice_intensity}" >> icy_list.txt
fi

cat starfile_header.txt > ${i%.tif}_ctf.star
echo "${i%.tif}_DW.mrc   ${i%.tif}_ctf.mrc      ${def1_A}       ${def2_A}       ${def_ang}      ${AKV}  ${CS}   ${AC}   ${MAG}  ${DSTEP}        ${res_A}    ${ccc}      ${ice_intensity}" >> ${i%.tif}_ctf.star

else

echo """Hmmm, ${i} looks like it failed CTFFIND... :-(
Oh well, moving on..."""
fi

if [[ -f "stop" ]]; then
echo "Stopping..."
echo "Stopped."
kill "$SCRIPT_PID"
fi

wait
fi
done
