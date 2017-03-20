#!/bin/bash
#Run as ./project.bash map.mrc
#Useful to generate stack of projections in various orientations

#Reminder; Euler angles defined such that rot is rotation about initial z; tilt is rotation about new y (y'),
#and psi is rotation about final z (z"). So no need to alter psi for purposes of generating templates (as 
#it will only affect 2D orientation of final template, which doesn't matter when searching)

APIX=4.28 #pixel size of input model

#Change these depending on symm
angles_rot=( 0 22.5 45 67.5)
angles_tilt=( 0 22.5 45 67.5 90 )

touch tmp.star

echo "
data_

loop_
_rlnImageName #1" > tmp.star
wait
for rot in ${angles_rot[@]}
do
for tilt in ${angles_tilt[@]}
do
relion_project --i "$@" --rot ${rot} --tilt ${tilt} --psi 0 --xoff 0 --yoff 0 --ctf --o ${rot}_${tilt}_0.mrc --angpix ${APIX}
wait
echo "${rot}_${tilt}_0.mrc" >> tmp.star
wait
done
done
relion_stack_create --i tmp.star --o out_stack
