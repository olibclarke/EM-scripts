#!/bin/bash
#run as: ./convert_to_jpg *.mrc
for i in "$@" # for every item matching pattern suplied on command line do the following:
do
mrc2tif -S -C ${i} ${i%.mrc}.tif
convert -contrast-stretch -4%x0.5% -auto-gamma -brightness-contrast 10x20 -quality 100 -resize 20% ${i%.mrc}.tif ${i%.mrc}_enhanced.jpg
rm ${i%.mrc}.tif
done
