#!/usr/bin/env bash

ROOT=`stack path --project-root`
EXAMPLES='boundingbox colormaps goo latex_basic latex_color latex_draw
          latex_wheel raster sphere blender_default_cube
          tut_glue_svg tut_glue_animate tut_glue_keyframe tut_glue_fourier
          tut_glue_physics tut_glue_latex tut_glue_povray
          tut_glue_povray_ortho tut_glue_potrace tut_glue_blender'

WIDTH=640
HEIGHT=$((WIDTH*9/16))
FPS=30

SRC_DIR=$ROOT/examples
DST_DIR=$ROOT/docs/rendered
OPTS="--fps $FPS --width $WIDTH --height $HEIGHT"

cat << EOF > $ROOT/docs/gallery.md
# Gallery
This file is auto-generated by docs/render_all.sh. DO NOT EDIT.

EOF

for e in $EXAMPLES; do
  cat << EOF >> $ROOT/docs/gallery.md
## $e

<details>
  <summary>View $e.hs</summary>
  <pre><code class="haskell">
  {!examples/$e.hs!}
  </code></pre>
</details>
<br/>
<video width="$WIDTH" height="$HEIGHT" muted autoplay loop>
  <source src="https://github.com/Lemmih/reanimate/raw/master/docs/rendered/$e.mp4">
</video>

<br/><hr><br/>

EOF

  SRC_FILE=$SRC_DIR/$e.hs
  DST_FILE=$DST_DIR/$e.mp4
  if [[ "$SRC_FILE" -nt "$DST_FILE" ]]; then
    stack $SRC_FILE render --compile -o $DST_FILE $OPTS
  fi
done
