# EM-scripts

Various jiffies that I find useful for data processing.

`convert_to_jpg` uses ImageMagick to make a nice-looking jpg from an mrc.

`project_map` makes several projections of an input map in selected
orientations using relion_project, and generates a stack of these
projections for use as particle-picking templates.

`rename_files` renames a set of files to mic_00001.mrc, mic_00002.mrc,
etc.

`star2jpg` takes a relion-generated data.star as input and uses
ImageMagick to create jpgs of each mic with particle positions and
numbers indicated, and per-mic Pmax, NSS and defocus printed - useful
for post-refinement screening of mics, or as a sanity check to assess
junkiness of 2D/3D classes.

`unblur_gctf_wrapper` runs unblur and Gctf, and creates contrast-adjusted jpg images with defocus etc written for diagnosis/screening. Requires ImageMagick. You may need to edit the names of the unblur, summovie and gctf executables. Run on multiple cores using GNU parallel, e.g.: `find ./ -maxdepth 1 -name "mic*mrc" -print | parallel -j 12 './unblur.com {/}' >& log &`

`gnuplot_fsc` makes a pretty-ish FSC curve in SVG format from `relion_postprocess` star file using gnuplot.

`ice_catcher` tries to guess whether an image has crystalline ice. Input is \_avrot.txt files from CTFFIND.

`gold_or_no_gold` tries to guess whether an image has gold/carbon/vaccum present in the frame based on whether the histogram is bimodal or not.

`run_ctffind` runs ctffind on movies and generates some diagnostics (e.g. ice_catcher is integrated)
