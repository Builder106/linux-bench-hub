# DESIGN: LinuxBenchHub

The showcase for a monthly Phoronix Test Suite dataset: Ubuntu, Fedora and
Debian, each captured on x86_64 (GitHub-hosted Azure VMs) and arm64 (an Oracle
Cloud Ampere VM), four results per capture, every run recorded.

## Brief

| Field | Value | Source |
|---|---|---|
| Subject | LinuxBenchHub, an open benchmark dataset and the pipeline that captures it | repo README, JOURNAL.md |
| Audience | Linux users choosing a distro, engineers who read benchmarks critically, recruiters reading the owner's portfolio | inferred |
| Job | Answer "which distro is faster here, by how much, and how sure can I be?" from the real captures, and show how they were made | inferred from the project's purpose |
| Tone | Exact, plain, unhyped. An engineer's diagram, not a marketing page | inferred |

## Data source (canonical)

Every figure on the site comes from `benchmarks/<distro>[-arm64]/composite-latest.xml`,
the Phoronix Test Suite composite written by the capture workflow. The site
reads the XML directly: the Markdown writeups are a manual step that the
workflow never reruns, and they had drifted (Ubuntu x86's writeup held an arm64
capture). All six were written by Phoronix Test Suite 10.8.6. Latest captures at
the time of writing:

| Lane | Capture | Machine | Kernel, compiler |
|---|---|---|---|
| Ubuntu 26.04 x86_64 | lbh-ubuntu-ci-2026-09-01 | AMD EPYC 9V74, 2 cores / 4 threads | 6.17.0-1022-azure, GCC 15.2.0 |
| Fedora 44 x86_64 | lbh-fedora-ci-2026-09-01 | AMD EPYC 9V74, 2 cores / 4 threads | 6.17.0-1022-azure, GCC 16.2.1 |
| Debian 13 x86_64 | lbh-debian-ci-2026-09-01 | AMD EPYC 9V74, 2 cores / 4 threads | 6.17.0-1022-azure, GCC 14.2.0 |
| each distro, arm64 | 2026-08-01 | ARMv8 Neoverse-N1, 4 cores | 6.17.0-1018-oracle; GCC 15.2.0 (Ubuntu), 16.1.1 (Fedora), 14.2.0 (Debian) |

Fedora's 2026-09-01 capture has no Tinymembench results. The site shows that
lane as empty and says so; it never borrows an older run to fill it.

## Concepts considered

Rejected so far, with the reason, so later passes do not repeat them:

- **The rule** (every run a tick on a measuring rule): measuring is what every
  benchmark site does; nothing in it is Linux.
- **The stack as a table** (layers with a 24-cell chart grid on top): the idea
  was right, the drawing was a dashboard. The stack sat in the bottom fifth,
  the zero-based strips hid every difference, and nothing aligned.

The owner then set two constraints: build on the current site's look
(https://linuxbenchhub.vercel.app/), and make real assets in Blender and
Glaxnimate.

| | A. The comb | B. The banner, extended | C. The stack, as bands |
|---|---|---|---|
| Territory | how Linux works, drawn in the site's own hex language | the site's identity (Tux and the Ruby gem) | how Linux works |
| Idea | The live site's honeycomb, taken to its true geometry: one kernel cell under the middle column touches all three distro userland cells, and each test is a row of three touching cells | The banner's Tux and gem become a scene the data sits in | Horizontal layer bands with one test drawn large |
| Anchor | Docker shares the host kernel: all three x86_64 distros report 6.17.0-1022-azure, all three arm64 distros 6.17.0-1018-oracle | the existing banner art | same as A |
| Structure | one object (two combs, one per machine) | scene | one object |
| Scores | 5 / 5 / 4 / 1 / 5 | 3 / 4 / 3 / 3 / 3 | 4 / 4 / 4 / 1 / 4 |

**Chosen: A.** It keeps the current site's honeycomb, hex grid, Ruby red,
Geist and Tux, and it makes the hexagons mean something: in a flat-top
honeycomb, the cell under the middle column is physically adjacent to all
three columns' bottom cells. The kernel is shared because the geometry says so.

## Concept card

```
Idea:        Same kernel, three userlands, drawn as a honeycomb: one kernel cell touches all three
             distro columns, and every test is a row of three touching cells.
Metaphor:    the comb (the current site's hex tiles), built as the Linux stack
Signature:   the comb assembles from the kernel outward: the kernel cell (a Blender-rendered ruby
             hex prism) lands first with Tux on it, the three userland cells lock against it, then
             each test row fills in, best result first. Hovering a distro lights its column down
             to the kernel.
Emotion:     the old site, finally saying something: dense, warm, exact
Motion verb: lock into the comb (cells slide along hex edges and seat with a short settle)
Screenshot:  two combs side by side, each with a glowing ruby kernel cell touched by three
             columns; the C-Ray row shows Fedora 304.6 s, Debian 314.6 s, Ubuntu 366.1 s
Structure:   the site is the comb. Distro cells at the top of each column open that distro.
             Test row names open a test (the row pulls out of the comb and grows). The kernel cell
             opens the ledger of captures. One unit = a test row, a distro column or the kernel.
Escape hatch: The ledger (/compare/): every run as table rows, with links to each capture's XML
```

## Structure plan

Flat-top hexes, width W, height H = 0.866 W. Three columns per machine at
x = 0, 0.75W, 1.5W; the middle column sits H/2 lower. Rows from the top:

```
            col A (Ubuntu)   col B (Fedora)   col C (Debian)
   0.0H     distro head                       distro head
   0.5H                      distro head
   1.0H     memcpy                            memcpy
   1.5H                      memcpy
   ...      (memset, C-Ray, Aircrack-ng in the same zigzag)
   5.0H     userland (GCC)                    userland (GCC)
   4.5H                      userland (GCC)
   5.5H                      KERNEL (touches A5, B4, C5)
```

Each test row is a chevron of three touching cells. The best result in the
row gets the lit (ruby rim) tile; the others the dark tile. The two machines
are two combs side by side on desktop and stacked on phones, inside a faint
hex lattice (the current site's background) that continues the comb's grid.

```
DESKTOP 1440 x 900
| LinuxBenchHub                                        The ledger  Source on GitHub |
| Same kernel,          [ x86_64 comb ]                 [ arm64 comb ]              |
| three userlands.        test names on the left of the x86 comb                     |
| (lede, 3 lines)                                                                    |
| colophon line                                                                      |

 /                       both combs
 /tests/<test>/          that row pulled out and enlarged: raw strings and every run per cell
 /benchmarks/<distro>/   both combs with one column lit, plus its userland in full
 /compare/               the ledger
 404                     a comb with an empty kernel cell
```

## Assets

| ID | Route | What | Acceptance |
|---|---|---|---|
| tile-dark | Blender (headless on the build VM) | flat-top hex prism, obsidian with a warm bevel, rendered top-down orthographic, transparent WebP at 2x | edges align to the CSS hex within 1 px at 1440 and 390 |
| tile-lit | Blender | the same prism with a Ruby red rim light, for the best result in a row | as above |
| tile-kernel | Blender | a Ruby glass hex prism (the current banner's gem, as a hex) | as above; text over it passes AA |
| tux | Glaxnimate | the current site's Tux mark, re-authored with semantic IDs, sitting on the kernel cell; a short settle | static frame in the HTML; reduced-motion frame identical to the end frame |
| comb-lines | Glaxnimate | the hex lattice lines for each comb, drawn on in assembly order | pathLength draw-on; static in reduced motion |

Data never goes into an image: every number, name and tick is HTML over the
rendered tiles, so the monthly capture cannot leave a stale picture.

## Visual system

**Palette** (the current site's dark theme, kept; text tokens checked for AA):

| Role | Hex | Use |
|---|---|---|
| ground | `#0a0507` | page |
| panel | `#150c10` | lattice cells, fallback tile |
| line | `#3d1a1d` | lattice lines |
| ink | `#f0e4e6` | text |
| muted | `#b09a9e` | secondary text (the old `#7a5a60` failed AA and is retired) |
| ruby | `#cc342d` | best-in-row rim, kernel glass, focus ring |
| ruby-bright | `#f55a4d` | links |
| ubuntu / fedora / debian | `#e95420` / `#51a2da` / `#d8a04a` | the current site's distro colors (Debian stays amber so it never reads as ruby) |

**Type.** Geist for everything, Geist Mono only for raw strings, kernel and
compiler strings (the literal identifiers). Self-hosted. No small uppercase
mono labels.

| Level | Size |
|---|---|
| h1 | clamp(2.25rem, 1rem + 3vw, 4.25rem), 700, tracking -0.03em, line-height 0.95 |
| cell value | clamp(1.125rem, 0.8rem + 0.6vw, 1.5rem), 600, tabular |
| test names, distro names | 1rem, 600 |
| text | 1rem |
| small | 0.8125rem |

**Lines.** Only the lattice and the cells' own edges. No boxes, no cards, no
hairline around blocks, no chamfered panels (the current site's chamfers move
into the hexes themselves).

**References.** The current site (identity, honeycomb, hex lattice, Tux and
gem); the layered Linux architecture diagram (the meaning of the stack); AI in
Design Report 2026 (few type levels, large jump).

## Motion (GSAP only, native scroll)

- First load assembles each comb from the kernel outward: kernel tile scales
  in (0.5 s), Tux settles, userland cells lock in, then test rows top-down,
  each row's cells sliding in along their hex edges (0.45 s, 50 ms apart),
  values last. Lattice lines draw on behind them. Under 2 s.
- Opening a test: Flip carries the row's cells and ticks out of the comb into
  the enlarged row; back returns them.
- Hover: a distro head lights its column (others drop to the dark tile and muted
  text); a test name lifts its row.
- At rest the comb is still.
- Reduced motion: everything in place, no assembly, no Flip.

## Deletions proposed (not made)

See `.design-loop/2026-10-22-run-rule/deletions.md` for files the redesign no
longer uses. They stay in place until the owner approves removal.
