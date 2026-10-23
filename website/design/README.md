# Design assets

Sources for the artwork the site uses. The site never bakes data into these;
every number is HTML.

## Blender: `blender/comb_tiles.py`

Renders the comb's hex tiles, flat-top prisms seen straight down with an
orthographic camera so each image is exactly W x 0.866W and lines up with the
CSS hex clip.

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P design/blender/comb_tiles.py -- <out dir>
```

Run it on the Mac (Cycles on Metal). Copy `tile-{dark,alt,head,lit,kernel}.webp`
into `public/comb/`.

| Tile | Used for |
|---|---|
| `tile-dark` | test cells |
| `tile-alt` | alternate test rows, so each zigzag row reads as one band |
| `tile-head` | distro head cells |
| `tile-lit` | the best result in a row (ruby rim) |
| `tile-kernel` | the kernel cell, a cut ruby |

## Glaxnimate: `glaxnimate/comb-lattice.svg`

The hex lattice behind each comb: every comb cell plus two fading rings of
ghost cells, drawn with the Glaxnimate MCP (`glaxnimate_create_svg`). Units:
one cell is 100 wide. Comb cell (column 0, row 0) has its top-left corner at
(150, 216.51), which `_comb_lattice.html.erb` and the `.comb-lattice` CSS use
to align it. Every path carries `pathLength="1"` and `data-ring` (0 comb cell,
1 and 2 ghost rings) for the GSAP draw-on.
