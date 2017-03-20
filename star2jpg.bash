#!/bin/bash
#run as ./star2jpg.com data.star

RADIUS=175 #particle radius in pixels

MIC_FIELD=`grep _rlnMicrographName "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
X_FIELD=`grep _rlnCoordinateX "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
Y_FIELD=`grep _rlnCoordinateY "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
PMAX_FIELD=`grep _rlnMaxValueProbDistribution "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
NSS_FIELD=`grep _rlnNrOfSignificantSamples "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
DEF_FIELD=`grep _rlnDefocusU "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
PART_FIED=`grep _rlnImageName "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`

awk -v mic_field=$MIC_FIELD '(NF>=3){print $mic_field}' "$@" | sort | uniq > tmp_mic_list
sed -i '/^$/d' tmp_mic_list

mkdir jpg_out

while read line; do
  mic_name=$(cut -d ' ' -f$MIC_FIELD <<< $line)
  mrc2tif -S -C ${mic_name} tmp.tif
  mic_name=${mic_name##*/}
  convert -contrast-stretch -4%x0.5% -auto-gamma -brightness-contrast 10x60 -resize 20% -rotate 180 -flop tmp.tif ${mic_name%.mrc}.jpg
  cp ${mic_name%.mrc}.jpg ${mic_name%.mrc}_orig.jpg
  grep $mic_name "$@" > single_mic.star
  particle_count=`cat single_mic.star | wc -l`
  pmax_sum=0.0
  nss_sum=0
  while read line2; do
   x_coord=$(cut -d ' ' -f$X_FIELD <<< $line2)
   y_coord=$(cut -d ' ' -f$Y_FIELD <<< $line2)
   pmax=$(cut -d ' ' -f$PMAX_FIELD <<< $line2)
   defocus=$(cut -d ' ' -f$DEF_FIELD <<< $line2)
   x_coord=`echo "$x_coord*0.2" | bc -l`
   y_coord=`echo "$y_coord*0.2" | bc -l`
   part_name=$(cut -d ' ' -f$PART_FIED <<< $line2)
   part_no=$(cut -d '@' -f1 <<< $part_name)
   part_no=$((10#$part_no))
   edge=`echo "$x_coord+($RADIUS*0.2)" | bc -l`
   convert -stroke Firebrick -strokewidth 0.5 -fill none -draw "circle ${x_coord},${y_coord} ${edge},${y_coord}" -fill Firebrick -annotate +$edge+$y_coord "${part_no}" ${mic_name%.mrc}.jpg ${mic_name%.mrc}.jpg
  done < single_mic.star
  nss_ave=`awk -v nss_field=$NSS_FIELD '{ sum += $nss_field } END { if (NR > 0) print sum / NR }' single_mic.star`
  nss_ave=$( printf "%4.1f" $nss_ave )
  pmax_ave=`awk -v pmax_field=$PMAX_FIELD '{ sum += $pmax_field } END { if (NR > 0) print sum / NR }' single_mic.star`
  pmax_ave=$( printf "%3.4f" $pmax_ave )
  defocus=`echo "$defocus*0.0001" | bc -l`
  defocus=$( printf "%1.1f" $defocus )
  convert -gravity northwest -pointsize 20 -annotate 0x0+0+15 "Defocus: ${defocus}µm, Mean Pmax: ${pmax_ave}, Mean NSS: ${nss_ave}, ${particle_count} particles" ${mic_name%.mrc}.jpg ${mic_name%.mrc}.jpg
  montage -geometry +2+2 -background '#000000' ${mic_name%.mrc}_orig.jpg ${mic_name%.mrc}.jpg ${mic_name%.mrc}.jpg
  mv ${mic_name%.mrc}.jpg ./jpg_out
  rm ${mic_name%.mrc}_orig.jpg
done < tmp_mic_list
