# ===================================================================
#  탈 · TEST AREA: THE NIGHT STAKEOUT   (Godot only; format: top of world.story)
#  Reach it from Chapters > Night stakeout.
#  Step one: just the night alley, made to look right. The sneaking comes back once the scene is good.
# ===================================================================

=== meta
lang ko
start so_open
start-place so_alley
home so_alley

=== evidence
flashlight | Flashlight | light | Your flashlight. |

=== hints
Nothing to do here yet: it's just the night alley for now.

=== place so_alley
name 골목
sub The alley, at night
art golmok_night
light own
ambient fireflies
# the lanterns on the string, and the window at the end of the alley
lamp 2.5 31.0 20 #ff9a6a
lamp 14.0 33.6 20 #8fe0c0
lamp 25.5 32.4 20 #ffd27a
lamp 37.0 29.2 20 #a8c0ff
lamp 48.5 28.6 20 #ff9a6a
lamp 60.0 31.6 20 #8fe0c0
lamp 71.5 33.7 20 #ffd27a
lamp 83.0 31.9 20 #a8c0ff
lamp 94.5 28.8 20 #ff9a6a
lamp 50 45 11 #ffc070 steady
music calm
sound night
travel no

=== scene so_open
! time stop; time set night; have flashlight
~ [Test area] The alley, at night. Just the scene for now.
