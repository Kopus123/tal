# ===================================================================
#  탈 · TEST AREA: THE ESCAPE ROOM   (format reference: top of world.story)
#  A work in progress, not part of the story yet. Reach it from Menu > Jump ahead > Test areas
#  (Playtest tools on in Settings). Everything marked [placeholder] is meant to be replaced.
#
#  THE STRUCTURE (the order things have to happen in):
#    window: read the numbers on the fence outside ............ the drawer code
#    workbench: open the drawer with that code ................ flashlight + screwdriver
#    workbench: read the note on the wall ..................... "oil first, then the hammer"
#    dark corner: flashlight to see, screwdriver for the board . small key
#    shelf: small key opens the toolbox ....................... oil + hammer
#    door: oil the hinges, THEN knock the pins out ............ the door comes off. You're out.
#  Hammer before oil = the pins won't move (the note told you).
# ===================================================================

=== meta
lang ko
start sh_open
start-place shed
home shed

=== hints
if !sawSign: The door won't budge. Look around the whole shed: window, workbench, shelf, the dark corner.
if !drawerOpen: The workbench drawer has a four-number lock. Did you see four numbers anywhere?
if !ev_sh_key: The corner is too dark to see. Something from the drawer might help.
if !boxOpen: The toolbox on the shelf has a little padlock. You found a little key.
if !oiled: The note over the workbench says what to do first.
if !free: Now the hammer.
You're out. (End of the test area: Menu > Jump ahead > Leave the test area.)

=== evidence
sh_note | {먼저} {기름} | letter | The note pinned over the workbench. Shaky handwriting. | {먼저} {기름}. {다음} {망치}.
sh_light | Flashlight | light | A small flashlight from the workbench drawer. [placeholder] |
sh_driver | Screwdriver | make | A screwdriver from the workbench drawer. [placeholder] |
sh_key | {열쇠} | key | A small key from under the loose floorboard. |
sh_oil | {기름} | oil | A can of oil from the toolbox. |
sh_hammer | {망치} | hammer | A heavy hammer from the toolbox. |

# ------------------------------------------------------------ the shed (all placeholder art)
=== place shed
light own
music tense
sound wind
name 창고
sub The shed
art ph_shed
travel no
desc if free: The shed. The door is off its hinges, and daylight is coming in.
desc An old shed, dim and dusty. The door slammed shut behind you, and you heard the latch drop on the outside.
spot "Door" 50 44 => place sh_door
spot "Workbench" 18 64 => place sh_bench
spot "Shelf" 84 46 => place sh_shelf
spot "Window" 78 20 => place sh_window
spot "Dark corner" 20 88 => place sh_floor

=== place sh_door
light own
music tense
sound wind
name 문
sub The door
art ph_door
travel no
desc if free: The door leans against the wall. The doorway is open.
desc if oiled: The hinges are dripping with oil. Rust runs down the wood in orange streaks.
desc The door. Old planks, and two iron hinges rusted solid. The latch is on the outside, where you can't reach it.
spot "Handle" 72 54 -> sh_handle if !free
spot "Hinges" 22 50 -> sh_hinge if !free
spot "Go outside" 50 60 -> sh_out if free
spot "Back" 50 92 => place shed

=== place sh_bench
light own
music tense
sound wind
name 작업대
sub The workbench
art ph_bench
travel no
desc A workbench covered in sawdust. A note is pinned to the wall above it. The drawer has a lock with four little number wheels.
spot "Note on the wall" 50 24 -> sh_note
spot "Drawer" 50 70 -> sh_drawer if !drawerOpen
spot "Drawer" 50 70 -> sh_drawer_empty if drawerOpen
spot "Back" 50 92 => place shed

=== place sh_shelf
light own
music tense
sound wind
name 선반
sub The shelf
art ph_shelf
travel no
desc Shelves of old paint tins, rope, and a metal toolbox with a small padlock.
spot "Toolbox" 50 56 -> sh_box if !boxOpen
spot "Toolbox" 50 56 -> sh_box_empty if boxOpen
spot "Back" 50 92 => place shed

=== place sh_window
light own
music tense
sound wind
name 창문
sub The window
art ph_window
travel no
desc A small window with iron bars. Through the dirty glass: weeds, a broken fence, nobody.
spot "Sign on the fence" 50 44 -> sh_sign
spot "Back" 50 92 => place shed

=== place sh_floor
light own
music tense
sound wind
name 구석
sub The dark corner
art ph_floor
travel no
desc if ev_sh_key: The corner. The loose board is lifted, and the hole underneath is empty.
desc if ev_sh_light: The flashlight picks out the floorboards. One of them is newer than the others, and screwed down.
desc Too dark to see anything back here.
spot "Floorboards" 50 64 -> sh_board if ev_sh_light&!ev_sh_key
spot "Back" 50 92 => place shed

# ------------------------------------------------------------ scenes
=== scene sh_open
! time stop; time set afternoon
@card 시험 | 창고
~ [Placeholder story] Something about the mask leads you out of the village, to an old shed at the end of an overgrown track. Nobody around for miles.
~ You step inside. Behind you the door swings shut with a bang, and outside, you hear the iron latch drop into place.
~ You push. You pull. The door doesn't move. The hinges are rusted solid.
! place shed

=== scene sh_handle
~ You rattle the handle. The door shifts a few millimeters and stops dead against the latch outside. It isn't opening from this side.

=== scene sh_hinge
~ Two iron hinges, rusted solid. Each has a pin you could knock out from underneath, if it would move.
* [Oil the hinges] -> sh_oil if ev_sh_oil&!oiled
* [Hit the pins with the hammer] -> sh_hammer_early if ev_sh_hammer&!oiled
* [Hit the pins with the hammer] -> sh_hammer_ok if ev_sh_hammer&oiled
* [Leave them] -> sh_hinge_bye

=== scene sh_hinge_bye
~ You leave them for now.

=== scene sh_hammer_early
~ You swing. The hammer bounces off with a clang that stings your whole arm. The pin hasn't moved at all: it's rusted in.
~ The note over the workbench said something about this.

=== scene sh_oil
~ You pour oil over both hinges, right into the joints, and wait. Orange rust runs down the wood.
! set oiled

=== scene sh_hammer_ok
~ You set the hammer under the top pin and hit it. Once, twice. On the third swing it slides up and out. Then the bottom one.
~ The door sags, swings out on the latch side, and drops against the frame. There's a gap. Daylight.
! set free

=== scene sh_out
~ You squeeze through the gap and out into the light.
~ [Placeholder] What you find outside, and what it has to do with the mask, goes here.
~ (End of the test area. Menu > Jump ahead > Leave the test area.)

=== scene sh_note
sign: {먼저} {기름}. {다음} {망치}.
(A scrap of paper pinned over the workbench. Shaky handwriting, like whoever wrote it was in a hurry.)
! give sh_note

=== scene sh_drawer
~ A drawer with a lock: four little wheels with numbers on them.
@number Try a code. | count
answer: 4719 -> sh_drawer_ok
miss -> sh_drawer_no

=== scene sh_drawer_no
~ Click. Nothing. The drawer stays shut.

=== scene sh_drawer_ok
~ The lock clicks, and the drawer slides open. Inside: a small flashlight and a screwdriver.
! give sh_light, sh_driver; set drawerOpen

=== scene sh_drawer_empty
~ The drawer is empty now. Sawdust and a dead spider.

=== scene sh_sign
~ Through the bars, on the broken fence outside, a sign. The paint is peeling, but you can still read it.
sign: {사} {칠} {일} {구}
(Four numbers painted by hand. [Placeholder: this becomes a real sign later, with words around the numbers.])
! set sawSign

=== scene sh_board
~ One board is newer than the others, held down by two screws.
* [Unscrew it] -> sh_board_ok if ev_sh_driver
* [Pull at it with your fingers] -> sh_board_no

=== scene sh_board_no
~ You pull until your fingertips hurt. The screws don't care.

=== scene sh_board_ok
~ Two screws, and the board lifts. Underneath, in the dust: a small key.
! give sh_key

=== scene sh_box
~ A metal toolbox with a little padlock.
* [Try the small key] -> sh_box_ok if ev_sh_key
* [Leave it] -> sh_box_bye

=== scene sh_box_bye
~ You leave it.

=== scene sh_box_ok
~ The key turns. Inside: a can of oil and a heavy hammer.
! give sh_oil, sh_hammer; set boxOpen

=== scene sh_box_empty
~ The toolbox is empty now.
