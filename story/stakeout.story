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

# they heard running in the alley (never played as a scene: a voice from the courtyard)
=== scene so_alarm
stranger_b[audio]: 쉿... {누구}{예요|이에요}?

# they saw you: one of them comes round into the alley after you (never played as a scene: voices in the alley)
=== scene so_chase
stranger[audio]: {누구}{예요|이에요}?!
stranger[audio]: 거기 서!

# he caught you before you got out of the alley: start again at the entrance
=== scene so_grabbed
~ A hand closes on your collar. The flashlight is right in your eyes.
stranger[audio]: {누구}{예요|이에요}?
~ You twist free and run, and don't stop until you're back at the entrance. (Next time: get out faster, or don't get seen.)

# you got out of the alley: they've gone inside, and the rest of what they were going to say is gone
=== scene so_got_away
~ You burst out of the alley and keep going. Nobody follows you past the corner.
~ Behind you, the courtyard has gone quiet. Whoever they were, they've gone inside. Whatever else they were going to say, you won't hear it tonight.
! set so_spooked
