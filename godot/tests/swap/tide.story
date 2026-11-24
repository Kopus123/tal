=== meta
start t_open
start-place dock
end-title 끝
end-text Done.

=== hints
if !metBom: Try the lighthouse.
Look around.

=== deduce
q1 if metBom | The light went out because of the {배}. | Because it did. | needs s_bom "Who saw it?"
q2 final if ended | It was {봄}. | It just was.

=== questions
q1 | {누구}? | Who was it?

=== evidence
rope | {배} · 1 | letter | A wet rope. |
bolt | {불} · 2 | light | A bolt from the lamp. |

=== place dock
name 부두
sub The dock
art jeong
desc A small dock.
spot "Lighthouse" 70 30 => place lamp
spot "Rope" 30 60 -> t_rope

=== place lamp
name 등대
sub The lighthouse
art gang
desc A lighthouse.
first t_bom
spot "Back to the dock" 12 88 => place dock
spot "봄" 50 50 -> t_again if metBom
spot "봄" 50 50 -> t_bom if !metBom
spot "Lamp" 76 34 -> t_lamp if metBom

=== statement s_bom

=== scene t_open
@card 1화 | 등대
nari: {안녕하세요}! {등대}{는|은/는} {여기}...
(She points up the hill.)
* {안녕하세요}! -> t_hi
* [Wave] -> t_hi

=== scene t_hi
nari: {가요}!
(She hurries off.)

=== scene t_rope
~ A wet rope.
! give rope

=== scene t_bom
bom: {누구}?
(An old man at the door.)
@type Say hello. | bom
answer: {안녕하세요} -> t_bom2
miss -> t_bomno

=== scene t_bomno
bom: {누구}?
~ Say hello: 안녕하세요.
<- t_bom.2

=== scene t_bom2
bom: {배}... {불}...
(He shrugs.)
! set metBom; statement s_bom; give bolt

=== scene t_again
bom: ...
(He looks at the sea.)
@present Show him something.
show: rope -> t_rope2
miss -> t_no

=== scene t_rope2
bom: {배}!
(He knows that rope.)

=== scene t_no
bom: {누구}?
<- t_again.2

=== scene t_lamp
~ The lamp is warm.
! set ended
~ That's all for tonight.
! finish chapter
