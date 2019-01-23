#!/bin/bash
#run as ./star2jpg.com data.star

RADIUS=10 #particle radius in pixels

MIC_FIELD=`grep _rlnMicrographName "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
X_FIELD=`grep _rlnCoordinateX "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
Y_FIELD=`grep _rlnCoordinateY "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
DEF_FIELD=`grep _rlnDefocusU "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`
PART_FIELD=`grep _rlnImageName "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`

particle_threshold=10

awk -v mic_field=$MIC_FIELD '(NF>=3){print $mic_field}' "$@" | sort | uniq > tmp_mic_list
sed -i '/^$/d' tmp_mic_list

#check that we have Imagemagick etc:
hash convert 2>/dev/null || { echo >&2 "Can't find convert - check that ImageMagick is available"; exit 1; }


mkdir jpg_out


while read line; do
  mic_name=$(cut -d ' ' -f${MIC_FIELD} <<< $line)
  mic_name=${mic_name##*/}
  grep $mic_name "$@" > single_mic.star
  particle_count=`cat single_mic.star | wc -l`
  if (( ${particle_count} < ${particle_threshold} )); then
  mrc2tif -S -C ${mic_name} tmp.tif
  convert tmp.tif -morphology Convolve Gaussian:0x2 tmp.tif
  convert -contrast-stretch -4%x0.5% -auto-gamma -brightness-contrast 10x20 -resize 15% -rotate 180 -flop tmp.tif ${particle_count}p_${mic_name%.mrc}.jpg
  cp ${particle_count}p_${mic_name%.mrc}.jpg tmp_unlabeled.jpg
  touch tmp_cmd_file
  while read line2; do
   x_coord=$(cut -d ' ' -f${X_FIELD} <<< $line2)
   y_coord=$(cut -d ' ' -f${Y_FIELD} <<< $line2)
   defocus=$(cut -d ' ' -f${DEF_FIELD} <<< $line2)
   x_coord=`echo "$x_coord*0.15" | bc -l`
   y_coord=`echo "$y_coord*0.15" | bc -l`
   part_name=$(cut -d ' ' -f${PART_FIELD} <<< $line2)
   part_no=$(cut -d '@' -f1 <<< $part_name)
   part_no=$((10#$part_no))
   edge=`echo "$x_coord+($RADIUS*0.15)" | bc -l`
   echo "-draw \"circle ${x_coord},${y_coord} ${edge},${y_coord}\"" >> tmp_cmd_file
  done < single_mic.star
  defocus=`echo "$defocus*0.0001" | bc -l`
  defocus=$( printf "%1.1f" $defocus )
  convert -stroke Firebrick -strokewidth 2 -fill red @tmp_cmd_file -gravity northwest -fill RoyalBlue3 -stroke none -pointsize 20 -annotate 0x0+0+15 "Defocus: ${defocus}µm, ${particle_count} particles" ${particle_count}p_${mic_name%.mrc}.jpg ${particle_count}p_${mic_name%.mrc}.jpg
#  convert -gravity northwest -fill DarkBlue -pointsize 20 -annotate 0x0+0+15 "Defocus: ${defocus}µm, ${particle_count} particles" ${particle_count}p_${mic_name%.mrc}.jpg ${particle_count}p_${mic_name%.mrc}.jpg
  convert  ${particle_count}p_${mic_name%.mrc}.jpg tmp_unlabeled.jpg +append ${particle_count}p_${mic_name%.mrc}.jpg
  mv ${particle_count}p_${mic_name%.mrc}.jpg ./jpg_out
  rm tmp_unlabeled.jpg
  rm tmp_cmd_file
  fi
done < tmp_mic_list
