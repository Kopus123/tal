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
# what the two people in the courtyard say, over and over (a line every few seconds): scene so_talk
overhear so_talk
music calm
sound night
travel no

=== scene so_open
! time stop; time set night; have flashlight
~ [Test area] The alley, at night. Just the scene for now.

# ------------------------------------------------------------ overheard (never played as a scene: the courtyard voices)
=== scene so_talk
stranger[audio]: {진짜} {탈}... {어디}{에} {있어요}?
stranger_b[audio]: {몰라요}.
stranger[audio]: {할머니}{가|이/가} {알아요}.
stranger_b[audio]: {오늘} {밤}{에}?
stranger[audio]: {네}. {다리}{에서}. {혼자} {와}.
