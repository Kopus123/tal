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
scene alley
light own
music calm
sound night
travel no

=== scene so_open
! time stop; time set night; have flashlight
~ [Test area] The alley, at night. Just the scene for now.
