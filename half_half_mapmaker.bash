#!/bin/bash
#Run as ./half_half_maps.com data.star


angpix=1.255 #pixel size of input data star
threads=24 #threads for each relion_reconstruct job
prefix="vol" #prefix for output files

#Shouldn't need to alter anything further down

data_star="$@"

rand_field=`grep _rlnRandomSubset "$@" | awk 'BEGIN {FS="#"} ; {print $2}'`

#get header
awk '{if (NF<=2) {print}}' < $data_star > head.tmp

#get body
awk '{if (NF>2) {print}}' < $data_star > body.tmp

wait

#shuffle body
shuf -o body_shuf.tmp body.tmp

#split into two files (xaa and xab)
split --number l/2 body_shuf.tmp

wait

awk -v rand_field=$rand_field '{if ($rand_field==1) {print}}' xaa > half1_half1.tmp

awk -v rand_field=$rand_field '{if ($rand_field==2) {print}}' xaa > half1_half2.tmp

awk -v rand_field=$rand_field '{if ($rand_field==1) {print}}' xab > half2_half1.tmp

awk -v rand_field=$rand_field '{if ($rand_field==2) {print}}' xab > half2_half2.tmp

wait

cat head.tmp half1_half1.tmp > ${prefix}_half1_half1.star

cat head.tmp half1_half2.tmp > ${prefix}_half1_half2.star

cat head.tmp half2_half1.tmp > ${prefix}_half2_half1.star

cat head.tmp half2_half2.tmp > ${prefix}_half2_half2.star

wait

relion_reconstruct --i ${prefix}_half1_half1.star --o ${prefix}_half1_half1_class001_unfil.mrc --angpix $angpix --ctf --j $threads >& half1_half1.log &

relion_reconstruct --i ${prefix}_half1_half2.star --o ${prefix}_half1_half2_class001_unfil.mrc --angpix $angpix --ctf --j $threads >& half1_half2.log &

relion_reconstruct --i ${prefix}_half2_half1.star --o ${prefix}_half2_half1_class001_unfil.mrc --angpix $angpix --ctf --j $threads >& half2_half1.log &

relion_reconstruct --i ${prefix}_half2_half2.star --o ${prefix}_half2_half2_class001_unfil.mrc --angpix $angpix --ctf --j $threads >& half2_half2.log &

rm xaa

rm xab

rm body.tmp

rm body_shuf.tmp

rm head.tmp

rm half?_half?.tmp
