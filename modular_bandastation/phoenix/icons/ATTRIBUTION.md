# Phoenix equipment sprites

`phoenix_equipment.dmi` contains four original-to-this-module equipment states:

| State | Appearance |
| --- | --- |
| `capsule_empty` | Empty preservation chamber |
| `capsule_occupied` | Preserved amber arthropod behind the glass |
| `adaptation_on` | Powered adaptation workstation |
| `adaptation_off` | Unpowered workstation with dark display and specimen well |

The designs and state variants were generated with OpenAI imagegen for this
project on 2026-11-03. They were converted to the native 32×32 grid with
nearest-neighbor sampling, binary transparency and a shared 64-color palette
without dithering. State variants retain identical housing pixels: only the
capsule window or the workstation's display/well changes. These are not claimed
as hand-drawn artwork by a named human artist.

Visual references were existing artwork in this repository at revision
`2d436bd4180eb8817375a0e1c81b78fba15bf6a7`, by /tg/station, BandaStation and
their contributors:

- `icons/obj/machines/stasis.dmi`: `stasis`.
- `icons/obj/machines/cloning.dmi`: `pod_0`, `scanner`, `infuser`.
- `icons/obj/machines/biogenerator.dmi`: `biogenerator`, `biogenerator_o_screen`.
- `icons/obj/science/vatgrowing.dmi`: `microscope`, `growing_vat`.
- `icons/obj/machines/research.dmi`: `protolathe`.
- `icons/obj/machines/computer.dmi`: `rdcomp`.

The reference sprites supplied the station's perspective, materials and pixel
scale. Their sprite pixels were not pasted into the equipment DMI. No artwork
from another codebase was imported.

This resource follows the repository's asset license,
[Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/),
as declared in the root README.md.

## Amber weaver sprites

`phoenix_weaver.dmi` contains `weaver`, `weaver_larva`, `weaver_cocoon` and
their `_dead` states. The adult and larval forms each have four directions;
cocoons have one. All frames are 32×32 with binary transparency and a shared
64-color opaque palette, without dithering or runtime tint/scaling.

The current six forms were generated for this project with OpenAI imagegen on
2026-11-03, then sampled to the native grid and packed into DMI. They replace
the earlier top-down artwork. Cardinal views use the station's elevated
three-quarter projection: front and rear views are foreshortened, while east
and west show the flank, belly and short prolegs. Directions were generated
as separate views, without quarter-turn rotations of the front frame. The
species deliberately uses rounded silkworm segments rather than a cockroach
silhouette.

Additional local visual references at the revision above, by /tg/station,
BandaStation and their contributors:

- `icons/mob/simple/animal.dmi`: `mouse_gray`, `chick`, `lizard`, for the
  camera, low body proportions and cardinal views.
- `icons/mob/simple/pets.dmi`: `snail`, for a long body with a visible flank
  in side views and a shortened front/rear projection.
- This module's `phoenix_equipment.dmi`: `capsule_occupied`, for the established
  amber color link.

No existing mob pixels were pasted into the new sprites. The weaver resource
follows the same CC BY-SA 3.0 asset license described above.

## Documentation previews

The PNGs in `../docs/` are documentation only. Equipment and creature previews
render the native DMI frames, plus existing repository artwork from
`icons/turf/floors.dmi` (`floor`), `icons/mob/human/human.dmi` (`human_basic`),
the animal references listed above and the equipment reference DMIs listed
above. Credit for those existing pixels remains with /tg/station, BandaStation
and their contributors under the same CC BY-SA 3.0 license. The UI previews
are screenshots of this module's built TGUI interfaces using test data.
