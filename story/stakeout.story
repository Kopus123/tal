# ===================================================================
#  탈 · TEST AREA: THE NIGHT STAKEOUT   (Godot only; format: top of world.story)
#  Reach it from Chapters > Night stakeout.
#  Listen over the wall, photograph them, don't get caught, then answer three questions on the board.
# ===================================================================

=== meta
lang ko
start so_open
start-place so_alley
home so_alley
end-title 끝 · the stakeout
end-text You know who they were after, where, and you have them on film. You got all of it with your ears and one camera.

=== evidence
flashlight | Flashlight | light | Your flashlight. |

=== hints
if !so_heard: Somebody's talking behind the right-hand wall. Get up there, near them, and listen.
if so_spooked&!st_h_where: They've gone in, and they said something you never caught. They won't be back tonight: try the night again (the button, or ☰ > Restart).
if so_spooked&!st_h_who: They've gone in, and they said something you never caught. They won't be back tonight: try the night again (the button, or ☰ > Restart).
if !st_h_where: There's more to hear. Stay up there, near them, and keep listening.
if !st_h_who: There's more to hear. Stay up there, near them, and keep listening.
if !solved_k1: You have sounds on your case board. Play them again: which one answers which question?
if !solved_k2: You have sounds on your case board. Play them again: which one answers which question?
if so_spooked&!solved_k3: A sound isn't proof of who was there. A picture is. (No good picture of them? They won't be back tonight: try the night again, the button or ☰ > Restart.)
if !solved_k3: A sound isn't proof of who was there. A picture is.
You have it all. Look at your case board once more.

# the case: you answer by ear (a sound has no words on it) and by photo. h_... = a line you heard clearly
=== deduce
k1 if so_heard | {다리} | Where they're meeting. | needs h_where "Where?"
k2 if so_heard | {할머니} | Who knows where the mask is. | needs h_who "Who knows?"
k3 if so_heard | {밤} | Who was in the courtyard. | needs s_meeting "Who did you see?"
k4 final if solved_k1&solved_k2&solved_k3 | {탈} | They want the real mask, and they think 할머니 knows where it is. | Heard and photographed.

=== questions
k1 | {어디}{에서} {만나요}? | Where are they meeting?
k2 | {누가|누구} {알아요}? | Who knows?
k3 | {누구}{를|을/를} {봤어요}? | Who did you see?

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
~ [Test area] The alley, at night. Somebody is meeting somebody behind the right-hand wall.

# ------------------------------------------------------------ overheard (never played as a scene: the courtyard voices)
=== scene so_talk
stranger[audio]: {진짜} {탈}... {어디}{에} {있어요}?
stranger_b[audio]: {몰라요}.
stranger[audio]: {할머니}{가|이/가} {알아요}.
! statement h_who
stranger_b[audio]: {오늘} {밤}{에}?
! statement h_when
stranger[audio]: {네}. {다리}{에서}. {혼자} {와}.
! statement h_where

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
