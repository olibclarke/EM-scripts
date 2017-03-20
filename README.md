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
