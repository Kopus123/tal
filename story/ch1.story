# ===================================================================
#  탈 · CHAPTER 1   (format reference: top of world.story)
#  SPOILERS below.
# ===================================================================

=== meta
start c1_open
start-place madang
end-title 1장 끝
end-text 할머니 is safe, for now. But someone is climbing the mountain in the dark, and they know which mask is the real one. Chapter 2 picks up on the mountain.

=== hints
if !sawFake: Look closely at the mask on the courtyard floor.
if !read_threat: 할머니's phone just buzzed. Tap the phone icon in the top-right corner.
if !showed: Show 수진 what the message says.
if !talkedOwner: Two 김밥. Who was the second one for? The restaurant owner might remember.
if !metGramps: The restaurant owner told you where to find him. Try the path behind the bus stop.
if !toldMountain: He won't talk. Maybe the message on 할머니's phone would change his mind.
if !metHalmeoni: The old man told you where to go. Up the mountain path, and keep climbing.
if !allSolved: Open the case board (the board button at the top) and answer the questions you can see.
if !solved_q5: What did 할머니 say about the mask in the museum?
Chapter 1 is done. Look back through your notebook while you wait for Chapter 2.

=== case
q1 가짜 if sawFake | Is the mask on the gate the real one? | Wet paint, and no chip in the eyebrow. 할머니 carved it last night.
q2 다리 if read_threat | Where does the stranger want the mask tonight? | The bridge, at 9 tonight.
q3 할아버지 if talkedOwner | Who was the second 김밥 for? | An old man who fishes by the river.
q4 산 if toldMountain | Where is 할머니? | Up the mountain, at the little temple.
q5 가짜 final if metHalmeoni | What is the mask in the museum? | A copy. 할머니 has the real one, and someone knows it.

# ------------------------------------------------------------ places

=== place madang
name 마당
sub The courtyard, the next morning
art madang_mask
ambient leaves
desc The courtyard, the morning after. The mask lies on the wooden floor. 수진 sits next to it, not touching it.
spot "The mask" 58 70 -> c1_mask
spot "Talk to 수진" 30 66 -> c1_sj1 if !sawFake
spot "Talk to 수진" 30 66 -> c1_sj2 if sawFake&!read_threat
spot "Show 수진 the message" 30 66 -> c1_show if read_threat&!showed
spot "Talk to 수진" 30 66 -> c1_sj4 if showed
spot "Workshop" 82 52 => place gongbang
spot "Front gate" 10 84 => place golmok
glow 탈 58 70 7
glow 손 34 62 8

=== place gongbang
name 공방
sub 할머니's workshop
art gongbang
ambient dust
desc The workshop. Something here has changed since yesterday.
spot "Workbench" 50 80 -> c1_bench
spot "Empty hook" 50 40 -> c1_hook
spot "Back to the courtyard" 50 92 => place madang
glow 탈 50 40 30

=== place golmok
name 골목
sub The alley
art golmok
ambient leaves
desc The alley outside the gate. The festival lanterns are still up from last night.
spot "Left path" 14 76 => place sanqil
spot "Right path" 86 76 => place sikdang
spot "Front gate" 50 92 => place madang
glow 오른쪽 86 76 10
glow 왼쪽 14 76 10

=== place sanqil
name 산길
sub The mountain path
art san
ambient leaves
desc if toldMountain: The path keeps climbing past the trail marker, into the pines. Somewhere up there is a temple.
desc A quiet path up the mountain. It climbs on past the trail marker, but you have no reason to follow it.
spot "Keep climbing" 50 30 => place jeol if toldMountain
spot "Go back down" 50 88 => place golmok
glow 산 50 30 22
glow 절 50 22 14

=== place sikdang
name 식당
sub The little restaurant
art sikdang
ambient dust
first c1_k1
desc The restaurant. The owner keeps glancing at the window.
spot "Talk to the owner" 50 52 -> c1_ktalk
spot "Bus stop" 85 40 => place jeong
spot "Back to the alley" 12 88 => place golmok
glow 김밥 11 23 7
glow 버스 정류장 85 30 9
glow 강 85 40 12

=== place jeong
name 버스 정류장
sub The bus stop
art jeong
ambient leaves
desc if knowRiver: The bus stop. Behind it, a dirt path drops down toward the water.
desc The bus stop at the edge of the village.
spot "Path behind the bus stop" 40 62 => place gang if knowRiver
spot "Back to the restaurant" 12 88 => place sikdang
glow 버스 정류장 24 45 12

=== place gang
name 강
sub The river
art river
ambient leaves
first c1_g1
desc The river. Reeds, flat stones, and the wooden bridge further down. The old man is still fishing.
spot "The old man" 64 60 -> metGramps&!toldMountain&read_threat ? c1_gshow : c1_gtalk
spot "Back to the bus stop" 12 88 => place jeong
glow 강 50 74 22
glow 다리 82 40 13
glow 할아버지 64 60 9

=== place jeol
name 절
sub The temple on the mountain
art temple
ambient motes
travel no
first c1_j1
desc The little temple at dusk. Far below, a light is moving on the path.
spot "할머니" 58 66 -> c1_jend
glow 할머니 58 66 10
glow 탈 58 70 7
glow 절 50 38 22

# ------------------------------------------------------------ phone
=== phone junho
name 준호 💙
avatar 준 #4f6ea8
day {어제}
them 21:40 {할머니}! {내일} {축제} {사진} {찍어 주세요} 📸
me 21:52 {네} ^^
day {오늘}
them 07:30 {할머니}?? {어디}{예요|이에요}?
sys 📞 ✖ 07:31
them@threatSent 09:40 {할머니}... {괜찮아요}?

=== phone museum
name 청솔 박물관
avatar 박 #6a6f7d
day {어제}
them 18:02 김순자 {선생님}, {내일} {아침} {9시}, {박물관}{에서} {만나요}!
me 18:30 {네}! {내일} {만나요}.

=== phone unknown
name 010-4417-0923
avatar ? #3a3f4a
on-open set read_threat if threatSent
day {어제}
them 23:51 {탈} {주세요}.
them 23:58 {탈} {주세요}.
day@threatSent {오늘}
them@threatSent 09:12 {진짜} {탈} {주세요}.
them@threatSent 09:13 {오늘} {밤} {9시}. {다리}.
note@threatSent They know. Somehow they know the mask on the gate isn't the real one.

# ------------------------------------------------------------ morning
=== scene c1_open
@card 1장 | 두 개
! set hasPhone
~ The next morning. Nobody in the guesthouse really slept.
~ 수진 brought the mask in from the gate. It lies on the wooden floor of the courtyard, grinning at the sky.
sujin[sad]: {탈}... {할머니} {탈}{이에요}.
(She sits next to it but doesn't pick it up. She just keeps looking at it.)

=== scene c1_sj1
sujin[sad]: {할머니}... {괜찮아요}?
(She asks it to nobody in particular. Then her eyes go back to the mask on the floor.)

=== scene c1_mask
~ Up close, the mask looks perfect. Long eyebrows, a huge grin. Exactly like the one 할머니 showed you two nights ago.
* [Pick it up] -> c1_mask2
* [Leave it alone] -> c1_maskleave

=== scene c1_maskleave
~ You leave it where it is. 수진 doesn't seem to want anyone touching it.

=== scene c1_mask2
~ It's lighter than you expected, and it smells strongly of fresh wood. When you put it down, there's a red smear across your fingers.
sujin[surprised]: 어? {손}! {손}!
(She grabs your hand and turns it over. Red paint. Still wet.)
sujin[surprised]: {새} {탈}{이에요}! {새} {탈}!
(She knocks on the mask with one knuckle. It sounds hollow and new.)
sujin[worried]: {이거}{는|은/는} {가짜}{예요|이에요}. {가짜}!
(She runs into the workshop and comes back with the faded photo. In it, the old mask has a small chip missing from the left eyebrow. This one has no chip at all.)
sujin[worried]: {할머니}{가|이/가} {만들었어요}. {어제} {밤}{에}...
(She looks at the workshop door, then at the gate. 할머니 was here last night, close enough to touch.)
! set sawFake; toast New question on your case board.
~ In your pocket, 할머니's phone buzzes.
! set threatSent; toast New message on 할머니's phone.

=== scene c1_sj2
sujin[worried]: {가짜} {탈}... {진짜} {탈}{은|은/는} {어디}{예요|이에요}?
(She holds up the fake in one hand and makes an empty grab with the other.)

=== scene c1_show
~ You hold out 할머니's phone. 수진 takes it and reads.
sujin[surprised]: {진짜} {탈} {주세요}... {오늘} {밤}... {다리}?!
(The color drains out of her face.)
sujin[worried]: {누구}{예요|이에요}? {누구}?!
(She shouts it at the phone, as if it could answer.)
sujin: {김밥} {두 개}... {할머니}{는|은/는} {누구}{하고}...
(She stops, thinking. Then she shakes her head and gives the phone back.)
sujin[worried]: {우리} {같이} {찾아요}. {빨리}!
! set showed

=== scene c1_sj4
sujin[worried]: {김밥} {두 개}... {누구}{예요|이에요}?
(She's pacing again. The restaurant owner was the one who saw the 김밥.)

# ------------------------------------------------------------ workshop
=== scene c1_bench
~ Fresh wood shavings, still pale, piled under the bench. A pot of red paint with its lid off. One of the small carving knives is missing from the neat row.
~ Someone worked here last night, quietly, in the dark.

=== scene c1_hook
~ The hook in the middle of the wall is still empty. The real mask never came back here.

# ------------------------------------------------------------ restaurant
=== scene c1_k1
ajeossi[surprised]: {어서 오세요}! 아... {할머니}{는|은/는}...?
(He looks past you, at the door, hoping.)
* [Shake your head] -> c1_k2
* {네}! -> c1_kyes

=== scene c1_kyes
ajeossi[happy]: {네}?! {할머니}! {어디}{예요|이에요}? {어디}?
(He drops his cloth and hurries to the door. There's nobody there.)
ajeossi[sad]: ...{아니요}?
~ That was cruel. He really thought she was back.
<- c1_k1

=== scene c1_k2
ajeossi[sad]: {아니요}...?
(He nods slowly and goes back to wiping a counter that's already clean.)

=== scene c1_ktalk
@build Ask him about the second 김밥.
tiles: {누구} | {김밥}{이에요}? | {할머니} | {봤어요}? | {두 개} | {맛있어요}
answer: {누구} | {김밥}{이에요}? -> c1_kwho
answer: {두 개} | {누구} | {김밥}{이에요}? -> c1_kwho
answer: {할머니} | {봤어요}? -> c1_ksaw
miss -> c1_khuh

=== scene c1_ksaw
ajeossi[sad]: {오늘}{은|은/는}... {아니요}. {안} {왔어요}.
(He shakes his head.)
~ You knew that already. You wanted to know who the second 김밥 was for.
<- c1_ktalk

=== scene c1_khuh
ajeossi[surprised]: {네}?
(He tilts his head.)
~ He didn't follow. Try asking whose 김밥 it was.
<- c1_ktalk

=== scene c1_kwho
ajeossi[surprised]: {김밥} {두 개}? 아... {할아버지}! {할아버지} {김밥}{이에요}.
(He snaps his fingers.)
ajeossi: {할아버지}{는|은/는} {아침}{에} {강}{에} {있어요}. {강}!
(He mimes casting a fishing line and waiting.)
ajeossi: {강}{은|은/는} {버스 정류장} {뒤에} {있어요}.
(He points out the window, past the bus stop.)
! set talkedOwner, knowRiver; toast New question on your case board.

# ------------------------------------------------------------ river
=== scene c1_g1
~ Behind the bus stop, a dirt path drops down to the river. Reeds, flat stones, and a wooden bridge further down. An old man sits on a rock with a fishing rod.
haraboji: {누구}{예요|이에요}?
(He asks without looking up from the water.)
* {학생}{이에요}. -> c1_g2
* {할머니}{예요|이에요}. -> c1_gwrong1
* {가짜}{예요|이에요}. -> c1_gwrong2

=== scene c1_gwrong1
haraboji[surprised]: {할머니}? 하하...
(Now he does look up. He looks you over, slowly, from your shoes to your face.)
haraboji[happy]: {할머니}{가|이/가} {아니에요}. 하하하.
~ You are very clearly not a grandmother. Try again.
<- c1_g1.2

=== scene c1_gwrong2
haraboji[surprised]: {가짜}...?
(He frowns at you like you've said something very strange.)
~ Calling yourself fake was not the best start. Try again.
<- c1_g1.2

=== scene c1_g2
haraboji: {학생}... {네}.
(He nods once and goes back to watching his line.)
~ What do you ask him?
* {할머니} {봤어요}? -> c1_g3
* {강}{이에요}? -> c1_g2b
* {맛있어요}? -> c1_g2c

=== scene c1_g2b
haraboji: {네}. {강}{이에요}.
(He points at the river. Then at you. Then back at the river.)
~ Yes, it's a river. Ask him something more useful.
<- c1_g2.2

=== scene c1_g2c
haraboji[surprised]: {네}?
(He looks at his empty hands, then at you, completely lost.)
~ There's nothing to eat here. Try something else.
<- c1_g2.2

=== scene c1_g3
haraboji[worried]: ...{몰라요}.
(He doesn't look at you. His hands tighten on the rod.)
~ Next to him on the rock: two empty 김밥 wrappers, and a folded piece of red cloth.
haraboji[worried]: {몰라요}. {몰라요}.
(He says it again, quieter, like he's trying to convince himself.)
! set metGramps

=== scene c1_gtalk
haraboji[worried]: {몰라요}.
(He keeps his eyes on the water. If something could change his mind, it isn't anything you've said yet.)

=== scene c1_gshow
~ You hold out 할머니's phone with the message open. He squints at it.
haraboji[surprised]: {진짜} {탈}... {오늘} {밤}... {다리}?!
(He looks down the river at the wooden bridge. The fishing rod slips out of his hands and clatters on the rock.)
haraboji[worried]: {누구}{예요|이에요}? {누구}...?
(He grips your arm. Then he lets out a long breath.)
haraboji[sad]: {할머니}{는|은/는}... {산}{에} {있어요}.
(He points up at the mountain behind the village.)
haraboji: {산}{에} {절}{이|이/가} {있어요}. {절}{에} {있어요}. {빨리} {가요}!
(He makes the shape of a little roof with his hands. A temple, up the mountain path.)
! set toldMountain; toast New question on your case board.

# ------------------------------------------------------------ temple
=== scene c1_j1
~ The path climbs for a long time. By the time you reach the top, the sun is going down. A tiny temple sits between the pines, one lantern lit.
~ On its wooden step, wrapped in a blanket, sits a small old woman. In her lap is a bundle of red cloth.
halmeoni[surprised]: {누구}... {누구}{예요|이에요}?
(She clutches the bundle to her chest.)
* {저}{예요|이에요}! {학생}! -> c1_j2
* {가짜}{예요|이에요}. -> c1_jwrong

=== scene c1_jwrong
halmeoni[worried]: {가짜}...?!
(She shrinks back against the temple door, holding the bundle tighter.)
~ Wrong thing to say to someone hiding from a stranger. Try again.
<- c1_j1.3

=== scene c1_j2
halmeoni[happy]: 아... {학생}!
(She recognizes you, and her whole face relaxes.)
halmeoni[worried]: 수진{은|은/는}... {괜찮아요}?
* {네}, {괜찮아요}. -> c1_j3
* {아니요}... -> c1_j2b

=== scene c1_j2b
halmeoni[sad]: {아니요}... {네}...
(She closes her eyes for a moment. She knew.)
-> c1_j3

=== scene c1_j3
~ She unwraps the red cloth. Long eyebrows, a huge grin, and a small chip missing from the left eyebrow.
halmeoni: {이거}{는|은/는} {진짜} {탈}{이에요}.
(She runs her thumb along the old wood.)
halmeoni[worried]: {박물관} {탈}... {가짜}{예요|이에요}.
(She says it very quietly, as if it's dangerous to say out loud.)
! set metHalmeoni
~ Below you, on the dark mountain path, a flashlight is coming up. Slowly. Someone is climbing.
halmeoni[worried]: {누구}...?
(She grabs your sleeve.)
halmeoni[worried]: {빨리}! {빨리}!
! toast One question left on your case board.

=== scene c1_jend
halmeoni[worried]: {빨리}...
(She's watching the light on the path. It's getting closer.)
