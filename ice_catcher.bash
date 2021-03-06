#! /bin/bash
#Run on *avrot.txt
#e.g.: ./ice_catcher.bash *avrot.txt
#A threshold of 2 seems to catch the worst offenders.
#Or just run with a threshold of -1 and take a look at the sorted file to figure out where to draw the line.
rm icy_list.txt
touch icy_list.txt
ice_threshold=-1
for i in "$@"
do
basename=${i%_ctf_avrot.txt}

tail -n6 ${i} | awk '
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

echo "ice_intensity=${ice_intensity}"
if (( $(echo "$ice_intensity > $ice_threshold" | bc -l ) )); then
echo "${basename} ${ice_intensity}" >> icy_list.txt
fi
done
sort -k2nr icy_list.txt > icy_list_sorted.txt
