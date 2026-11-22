# ===================================================================
#  탈 · TEST AREA: THE NIGHT STAKEOUT   (Godot only; format: top of world.story, plus the stakeout lines below)
#  Reach it from Chapters > Night stakeout.
#
#  A STAKEOUT PLACE (mode stakeout):
#    start X Y                  where you are when you come in (percent of the picture)
#    hide "Label" X Y           somewhere to hide. Tap it and you creep over; you're in the open on the way
#    walker X1 Y1 X2 Y2 SEC R [WHO]   someone walking their beat with a flashlight: there and back in SEC seconds;
#                               R = how far their light reaches (percent of the width). WHO = whose shape it is.
#    whisper "Label" -> SCENE [if COND]   what you overhear when you hide there (once)
#    caught SCENE               what happens when they catch you and you don't get away
#  Exits are ordinary spots ("=> place NAME"), labeled in Korean only: you have to read where you're going.
#  Being seen: a light on you while you're in the open fills the eye at the top. Your own flashlight lets
#  them see you from much further away. Full eye: they shout, and you run (tap left, right, left, right).
# ===================================================================

=== meta
lang ko
start so_open
start-place so_alley
home so_alley

=== evidence
flashlight | Flashlight | light | Your flashlight. On, you can see; on, they can see you. |

=== hints
if !meet: Someone's meeting someone tonight. Where would two people talk without being seen? Hide close and listen.
if !saw_meeting: You heard where. Go there, and stay out of the light.
Nothing more to find tonight.

# ------------------------------------------------------------ places
=== place so_alley
mode stakeout
name 골목
sub The alley, at night
art golmok_live
dark 0.82
music tense
sound night
travel no
start 50 93
hide "Behind the wall" 12 82
hide "The doorway" 88 78
walker 34 62 66 62 6 11 ajeossi
spot "시장" 50 57 => place so_market
spot "다리" 96 70 => place so_river
caught so_caught

=== place so_market
mode stakeout
name 시장
sub The market, shut for the night
art market_live
dark 0.85
music tense
sound night
travel no
start 92 92
hide "Under the stall" 22 76
hide "Behind the cabbages" 42 74
walker 28 66 78 66 7 12 ajeossi
whisper "Under the stall" -> so_whisper if !meet
spot "골목" 96 82 => place so_alley
caught so_caught

=== place so_river
mode stakeout
name 다리
sub The river, by the bridge
art river_live
dark 0.85
music tense
sound river
travel no
start 6 92
hide "The reeds" 16 84
hide "Under the bridge" 78 76
walker 52 64 86 64 8 12 ajeossi
whisper "The reeds" -> so_meeting if meet&!saw_meeting
spot "골목" 3 72 => place so_alley
subject s_bridge 76 42 12
caught so_caught

# ------------------------------------------------------------ scenes
=== scene so_open
! time stop; time set night; have flashlight
~ [Test area] Night. From the guesthouse window you saw a flashlight bob down the alley toward the market. Someone is meeting someone.
~ Find out where, and see it happen. Stay out of the light: tap somewhere to hide and you'll creep over, but you're in the open on the way.
~ Your flashlight lets you see. It also lets them see you, from much further away.

=== scene so_whisper
(Two voices, very close, on the other side of the stall. You hold your breath.)
someone[audio]: {9시}{에}... {다리}.
other[audio]: {네}. {혼자} {와}.
(Footsteps, going off in two directions.)
! set meet

=== scene so_meeting
(Two flashlights meet in the middle of the bridge. Their voices carry over the water.)
someone[audio]: {진짜} {탈}... {가져와}?
other[audio]: {아니요}. {내일}.
(One light goes back toward the village. The other stays on the bridge for a long time.)
! set saw_meeting
~ [Test area] That's the stakeout. Your camera works here too (📷), if you want the bridge on your board.

=== scene so_caught
~ A flashlight full in your face. A hand on your sleeve.
(You twist free and run, and don't stop until you're back in the alley.)
! place so_alley
