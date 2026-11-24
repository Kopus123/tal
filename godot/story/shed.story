# ===================================================================
#  탈 · TEST AREA: THE ESCAPE ROOM   (format reference: top of world.story)
#  A work in progress, not part of the story yet. Reach it from Menu > Jump ahead > Test areas
#  (Playtest tools on in Settings). [placeholder] marks what's meant to be replaced.
#
#  Night. Nothing is labelled ("mode explore"): you find things by tapping the picture.
#  Your flashlight is in your pockets: switch it on to see in the dark and read things.
#  Other things you find go in your pockets too: tap one to hold it, then tap where to use it.
#
#  THE ORDER THINGS HAVE TO HAPPEN IN:
#    window: the numbers on the sign outside (사 칠 일 구) .... the drawer code
#    workbench, flashlight on: the drawer ..................... a screwdriver
#    workbench, flashlight on: the note on the wall ........... "oil first, then the hammer"
#    workbench, flashlight on: the newer floorboard + screwdriver  a small key
#    shelf: the toolbox + the small key ....................... oil + hammer
#    door: oil on the hinges, THEN the hammer ................. the door comes off
#  Hammer before oil: the pins won't move (the note warned you). Oil on the window latch:
#  the latch turns, but the window is nailed shut from outside.
# ===================================================================

=== meta
pockets flashlight, sh_driver, sh_key, sh_oil, sh_hammer
lang ko
start sh_open
start-place shed
home shed

=== hints
if !lit&!drawerOpen: It's too dark to see much. Your flashlight is in your pockets, under the picture.
if !sawSign: The door won't budge. Look around: what can you see through the window?
if !drawerOpen: The workbench drawer has a four-number lock. Did you see four numbers anywhere?
if !ev_sh_key: Shine your light around the workbench, low down. Something there is newer than the rest.
if !boxOpen: The toolbox on the shelf has a little padlock.
if !oiled: The note over the workbench says what to do first.
if !free: Now the hammer.
You're out. (End of the test area: Menu > Jump ahead > Leave the test area.)

=== evidence
flashlight | Flashlight | light | Your flashlight. You never go anywhere without it. |
sh_note | {먼저} {기름} | letter | The note pinned over the workbench. Shaky handwriting. | {먼저} {기름}. {다음} {망치}.
sh_driver | Screwdriver | screwdriver | A screwdriver from the workbench drawer. |
sh_key | {열쇠} | key | A small key from under a floorboard. |
sh_oil | {기름} | oil | A can of oil from the toolbox. |
sh_hammer | {망치} | hammer | A heavy hammer from the toolbox. |

# ------------------------------------------------------------ the shed
=== place shed
light own
mode explore
dark 0.86
music tense
sound wind
name 창고
sub The shed
art shed
moon 81 25 0.55 1.1
travel no
desc if free: The door is off its hinges. Cold air is coming in.
desc Dark. A little moonlight comes in through one dirty window. It smells of rust and old paint.
spot "Door" 50 49 => place sh_door
spot "Window" 81 25 => place sh_window
spot "Workbench" 17 58 => place sh_bench
spot "Note above the workbench" 17 43 => place sh_bench
spot "Shelf" 85 55 => place sh_shelf

=== place sh_door
light own
mode explore
dark 0.8
back shed
music tense
sound wind
name 문
sub The door
art shed_door
travel no
desc if free: The door leans against the wall. The doorway is open.
desc if oiled: Oil drips from the hinges. Rust runs down the wood in orange streaks.
desc The door. Heavy planks.
spot "Top hinge" 36 21 -> sh_oil if hold:sh_oil&!oiled
spot "Top hinge" 36 21 -> sh_hammer_ok if hold:sh_hammer&oiled&!free
spot "Top hinge" 36 21 -> sh_hammer_early if hold:sh_hammer&!oiled
spot "Top hinge" 36 21 -> sh_hinge if !free
spot "Bottom hinge" 36 71 -> sh_oil if hold:sh_oil&!oiled
spot "Bottom hinge" 36 71 -> sh_hammer_ok if hold:sh_hammer&oiled&!free
spot "Bottom hinge" 36 71 -> sh_hammer_early if hold:sh_hammer&!oiled
spot "Bottom hinge" 36 71 -> sh_hinge if !free
spot "Handle" 64 51 -> sh_handle if !free
spot "Doorway" 50 50 -> sh_out if free

=== place sh_window
light own
mode explore
dark 0.45
back shed
music tense
sound wind
name 창문
sub The window
art shed_window
moon 30 30 0.5 2.2
travel no
desc A small window in a heavy wooden frame. Outside: weeds, a broken fence, nobody.
spot "Latch" 50 51 -> sh_latch_oil if hold:sh_oil&!latchOiled
spot "Latch" 50 51 -> sh_latch2 if latchOiled
spot "Latch" 50 51 -> sh_latch
spot "Glass" 28 30 -> sh_glass
spot "Sign" 67 63 -> sh_sign

=== place sh_bench
light own
mode explore
dark 0.9
back shed
music tense
sound wind
name 작업대
sub The workbench
art shed_bench
travel no
desc A workbench, thick with sawdust.
spot "Note" 50 22 -> sh_note if lit
spot "Drawer" 50 63 -> sh_drawer if lit&!drawerOpen
spot "Drawer" 50 63 -> sh_drawer_dark if !lit&!drawerOpen
spot "Drawer" 50 63 -> sh_drawer_empty if drawerOpen
spot "Floorboard" 71 91 -> sh_board_ok if lit&hold:sh_driver&!ev_sh_key
spot "Floorboard" 71 91 -> sh_board if lit&!ev_sh_key

=== place sh_shelf
light own
mode explore
dark 0.88
back shed
music tense
sound wind
name 선반
sub The shelf
art shed_shelf
travel no
desc Shelves of old paint tins and rope.
spot "Toolbox" 50 42 -> sh_box_ok if hold:sh_key&!boxOpen
spot "Toolbox" 50 42 -> sh_box if !boxOpen
spot "Toolbox" 50 42 -> sh_box_empty if boxOpen

# ------------------------------------------------------------ scenes
=== scene sh_open
! time stop; time set night; have flashlight
@card 시험 | 창고
~ [Placeholder story] Something about the mask leads you out of the village at night, to an old shed at the end of an overgrown track. Nobody around for miles.
~ You step inside.
~ Behind you, the door slams shut.
! sfx slam
~ Outside, metal scrapes on metal. The latch dropping into place.
! sfx clunk
~ You push. You pull. Nothing.
! place shed

=== scene sh_handle
! sfx clunk
~ You rattle the handle. The door shifts a few millimeters and stops dead. Something is holding it from outside.
~ You put your eye to the crack by the handle. Moonlight, and a black iron latch, dropped into its hook on the outside. You can't reach it from in here.

=== scene sh_hinge
~ A long iron hinge, rusted almost solid. A pin runs down through it. If the pins came out, the door would come off.
! unset hold

=== scene sh_hammer_early
! sfx clunk; unset hold
~ You swing. The hammer bounces off with a clang that stings your whole arm. The pin hasn't moved at all: it's rusted in.
~ The note over the workbench said something about this.

=== scene sh_oil
! sfx creak; set oiled; unset hold
~ You pour oil over both hinges, right into the joints, and wait. Orange rust runs down the wood. Somewhere inside the iron, something creaks.

=== scene sh_hammer_ok
! sfx clunk; unset hold
~ You set the hammer under the top pin and hit it. Once, twice. On the third swing it slides up and out. Then the bottom one.
! sfx slam; set free
~ The door sags, swings loose on the latch side, and crashes down against the frame. There's a gap. Night air.

=== scene sh_out
~ You squeeze through the gap and out into the dark.
~ [Placeholder] What you find outside, and what it has to do with the mask, goes here.
~ (End of the test area. Menu > Jump ahead > Leave the test area.)

=== scene sh_latch
! unset hold
~ The latch between the two halves of the window. It's rusted into one solid lump. It won't turn.

=== scene sh_latch_oil
! sfx creak; set latchOiled; unset hold
~ You work oil into the latch. After a while it turns, grinding.
~ You push the window. It doesn't move. Through the glass you can see the heads of nails: it's been nailed shut from outside.

=== scene sh_latch2
~ The latch turns now. The window still doesn't budge. Nailed shut from outside.

=== scene sh_glass
! sfx clunk; unset hold
~ You knock on the glass. Thick, old, and solid. You hit it harder with the side of your fist. It doesn't even rattle.

=== scene sh_sign
~ Out past the weeds, a sign hangs on the broken fence. In the moonlight you can just about read it.
sign: {사} {칠} {일} {구}
(Four numbers painted by hand. [Placeholder: words around the numbers later.])
! set sawSign

=== scene sh_note
sign: {먼저} {기름}. {다음} {망치}.
(A scrap of paper pinned over the workbench. Shaky handwriting, like whoever wrote it was in a hurry.)
! give sh_note

=== scene sh_drawer_dark
~ A drawer. There's some kind of lock on it, but it's too dark to see how it works.

=== scene sh_drawer
~ The drawer has a lock with four little number wheels.
@number Try a code. | count
answer: 4719 -> sh_drawer_ok
miss -> sh_drawer_no

=== scene sh_drawer_no
! sfx click
~ Click. Nothing. The drawer stays shut.

=== scene sh_drawer_ok
! sfx click
~ The last wheel clicks into place, and the drawer slides open. Inside, in the sawdust: a screwdriver.
! give sh_driver; set drawerOpen

=== scene sh_drawer_empty
~ The drawer is empty now. Sawdust and a dead spider.

=== scene sh_board
! unset hold
~ One floorboard under the bench is paler than the rest. Newer. It's held down by two screws.

=== scene sh_board_ok
! unset hold
~ Two screws, and the board lifts. Underneath, in the dust: a small key.
! give sh_key

=== scene sh_box
! unset hold
~ A metal toolbox with a little padlock on it.

=== scene sh_box_ok
! sfx click; unset hold
~ The little key turns. Inside: a can of oil and a heavy hammer.
! give sh_oil, sh_hammer; set boxOpen

=== scene sh_box_empty
~ The toolbox is empty now.
