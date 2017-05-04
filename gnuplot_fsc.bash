#!/bin/bash
#run as ./gnuplot_fsc.bash relion_post.star
#plots Res. vs corrected FSC (assuming these are in 3rd and fourth columns of star file)
file1="$@"
awk 'NR > 3 {if (NF > 6) print 1.0/$3,$4}' $file1 > ${file1}.tmp
gnuplot<<EOF
        set size square
        set ylabel "FSC"
        set xlabel "Res. (1/Å)"
        set term svg fname "Arial" fsize 12 round dashed
	set output "${file1}_fsc.svg"
	set xrange [0.025:0.304]
	set yrange [-0.01:1.0]
        set xtics nomirror out scale 0.5 ("40.0" 1/40.0, "20.0" 2/40.0, "13.3" 3/40.0, "10.0" 4/40.0, "8.0" 5/40.0, "6.7" 6/40.0, "5.7" 7/40.0, "5.0" 8/40.0, "4.4" 9/40.0, "4.0" 10/40.0, "3.6" 11/40.0, "3.3" 12/40.0)
        set ytics nomirror out scale 0.5
	set ytics scale 0.5 add ("0.143" 0.143)
	set border 3
	plot "${file1}.tmp" using 1:2 with lines lc "blue" lw 3 notitle
EOF
