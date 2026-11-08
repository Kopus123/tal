# ===================================================================
#  탈 · CHAPTER 1   (format reference: top of world.story)
#  SPOILERS below.
# ===================================================================

=== meta
start c1_open
start-place madang
end-title 1장 끝
end-text 할머니 is safe, for now. But someone climbed the mountain in the dark, and he knows which mask is the real one. The story continues soon.

=== hints
if !sawFake: Look closely at the mask on the courtyard floor.
if !read_threat: 할머니's phone just buzzed. Tap the phone icon in the top-right corner.
if !showed: 수진 should see what came in on 할머니's phone. Talk to her and show her.
if !talkedOwner: Two 김밥. Who was the second one for? The restaurant owner might remember.
if !marketDone&!paid: The restaurant owner said the woman at the market knows. The bus stops at the market. Maybe buy something from her first.
if !marketDone: She's ready to talk now. Ask her about 할머니.
if !metGramps: The woman at the market told you where to find him. Try the path behind the bus stop.
if !toldMountain: He won't talk. Maybe something you could show him would change his mind.
if !solved_d7: Put what 할아버지 told you together on the case board before you set off.
if !metHalmeoni: You worked out where she is. Up the mountain path, and keep climbing.
if !hidden: Someone with a light is coming. Don't let them see you.
if !allSolved: Open the case board (the board button at the top) and answer the questions you can see.
if !solved_q8: What did 할머니 say about the mask in the museum?
Chapter 1 is done. Look back through your notebook while you wait for Chapter 2.

=== deduce
d1 if sawFake | The mask on the gate is {가짜}. 할머니 {만들었어요} it herself, last night. | Wet paint, fresh shavings, and no chip in the eyebrow.
d2 if read_threat | Someone wants the {진짜} mask, at the {다리}, tonight at 9. | And somehow they know the one on the gate is fake.
d3 if marketDone | Yesterday she got off at the {시장}, not at the museum, and met {할아버지} there. | The second 김밥 was for him. They ate it together at the market.
d4 if marketDone&sawBag | She bought {나무} and {빨간} {물감} there, to make the copy. | The bag under her workbench came from that same stall.
d5 if sawMan | The night before, a {남자} with a {불} was waiting on the {다리}. | Maybe the same person who sent the message.
d6 if doubtMuseum | The museum's mask has no chip in its eyebrow. Maybe it's {가짜} too. | Then which one is the real one?
d7 if toldMountain | 할머니 is hiding at the {절}, up on the {산}. | 할아버지 finally told you.
d8 final if hidden | The real mask is with {할머니}. The one in the {박물관} is {가짜}. | And the man in the dark knows it.

=== evidence
letter | {편지} | letter | 할머니's letter. The reason you came to 청솔마을. | {학생}, 청솔마을{에} {오세요}. {탈}{은|은/는}... {비밀}{이에요}.
photo79 | {사진} · 1979 | photo | A faded photo from the workshop: a young woman with a grinning mask pushed up on her head. Look closely and the mask has a small chip in its left eyebrow. |
couplephoto | {사진} · {버스 정류장} | photo | The couple's selfie at the bus stop. Behind them, a little blurry: 할머니, holding a bundle in red cloth. |
note | {찾지 마세요} | letter | The note tucked into the mask on the gate. Shaky handwriting. | {찾지 마세요}.
fakemask | {가짜} {탈} | fake | The mask from the gate. Fresh wood, wet red paint, and no chip in the eyebrow. |
threat | {핸드폰} · 010-4417-0923 | phone | This morning's message to 할머니's phone. | {진짜} {탈} {주세요}. {오늘} {밤} {9시}. {다리}.
paintbag | {시장} · {빨간} {물감} | bag | From under the workbench: an open pot of red paint, and a paper bag stamped with the market's name. | 청솔 {시장}
sketch | {나무} · 30cm | wood | 할머니's pencil sketch of the mask, with the size of the wood block she needed. | {나무} · 30cm
bootprint | {다리} · ? | man | By the bridge: a big bootprint, and the round mark a heavy flashlight leaves when it's stood on its end. |
# ------------------------------------------------------------ places

=== place madang
name 마당
sub The courtyard, the next morning
art madang_mask
ambient leaves
desc The courtyard, the morning after. The mask lies on the wooden floor. 수진 sits next to it.
spot "The mask" 58 70 -> c1_mask
spot "Talk to 수진" 30 66 -> c1_sjhub
spot "Back wall" 92 62 -> c1_wall
spot "Workshop" 82 46 => place gongbang
spot "Front gate" 10 84 => place golmok
glow 탈 58 70 7
glow 손 30 64 8
glow 집 50 45 20

=== place gongbang
name 공방
sub 할머니's workshop
art gongbang
ambient dust
desc The workshop. Something here has changed since yesterday.
spot "Workbench" 50 80 -> c1_bench
spot "Sketch on the wall" 14 38 -> c1_sketch
spot "Empty hook" 50 40 -> c1_hook
spot "Back to the courtyard" 50 92 => place madang
glow 탈 50 40 30
glow 나무 50 82 14
glow 물감 50 82 14

=== place golmok
name 골목
sub The alley
art golmok
ambient leaves
desc The alley outside the gate. The festival lanterns are still up from last night.
spot "The couple" 50 62 -> c1_o1 if !sawMan
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
desc if solved_d7: The path keeps climbing past the trail marker, into the pines. She's up there.
desc if toldMountain: The path keeps climbing into the pines. But where exactly is she? Work it out on the case board first.
desc A quiet path up the mountain. It climbs on past the trail marker, but you have no reason to follow it yet.
spot "Trail marker" 58 64 -> c1_marker
spot "Keep climbing" 50 30 => place jeol if solved_d7
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
spot "Talk to the owner" 50 52 -> c1_ktalk if !talkedOwner
spot "Talk to the owner" 50 52 -> c1_kafter if talkedOwner
spot "Order from the menu" 22 22 -> c1_korder
spot "Bus stop" 85 40 => place jeong
spot "Back to the alley" 12 88 => place golmok
glow 김밥 11 23 7
glow 떡볶이 26 23 7
glow 라면 40 23 7
glow 비빔밥 55 23 7
glow 버스 정류장 85 30 9
glow 시장 85 40 10

=== place jeong
name 버스 정류장
sub The bus stop
art jeong
ambient leaves
desc if knowRiver: The bus stop. Behind it, a dirt path drops down toward the water.
desc The bus stop at the edge of the village.
spot "Route map" 28 45 -> c1_jmap
spot "Wait for the bus" 72 72 -> c1_b0
spot "Path behind the bus stop" 40 62 => place gang if knowRiver
spot "Back to the restaurant" 12 88 => place sikdang
glow 버스 정류장 24 45 12
glow 뒤에 40 62 12

=== place bus
name 버스
sub On the bus
art bus
travel no
glow 시장 50 11 16
glow 영화관 50 11 16
glow 박물관 50 11 16
glow 지하철역 50 11 16

=== place sijang
name 시장
sub The market
art market
ambient dust
travel no
first c1_m1
desc The market. Fish on ice, mountains of cabbage, and the stall full of paint pots and wood.
spot "The paint stall" 66 56 -> c1_mbuy if !paid
spot "The paint stall" 66 56 -> c1_mtalk if paid&!marketDone
spot "The paint stall" 66 56 -> c1_mafter if marketDone
spot "Fish stall" 18 60 -> c1_mfish
spot "Take the bus back" 78 88 -> c1_mback
glow 나무 72 50 9
glow 물감 60 50 9
glow 빨간 60 50 9
glow 아주머니 66 60 9
glow 천 원 66 60 9

=== place museum
name 박물관
sub The museum
art museum
ambient dust
travel no
first c1_mu1
desc The museum, quiet as ever. The big glass case glows at the far wall.
spot "The big glass case" 24 42 -> c1_mucase
spot "Front desk" 66 62 -> c1_mudesk
spot "Take the bus back" 78 88 -> c1_mback
glow 탈 24 42 16

=== place gang
name 강
sub The river
art river
ambient leaves
first c1_g1
desc The river. Reeds, flat stones, and the wooden bridge further down. The old man is still fishing.
spot "The old man" 64 60 -> c1_ghub if toldMountain
spot "The old man" 64 60 -> c1_gtalk if !toldMountain
spot "The bridge" 82 40 -> c1_bridge
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
desc The dark temple. Somewhere close, a man is breathing.
spot "할머니" 58 66 -> c1_jend
glow 할머니 58 66 10
glow 탈 58 70 7
glow 절 50 38 22
glow 불 12 92 10

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
them@marketDone 13:05 {할머니}!! {전화} {주세요}!!

=== phone museum
name 청솔 박물관
avatar 박 #6a6f7d
day {어제}
them 18:02 김순자 {선생님}, {내일} {아침} {9시}, {박물관}{에서} {만나요}!
me 18:30 {네}! {내일} {만나요}.
day@threatSent {오늘}
them@threatSent 10:20 {선생님}, {괜찮아요}? {박물관}{에} {안} {왔어요}...

=== phone unknown
name 010-4417-0923
avatar ? #3a3f4a
on-open set read_threat if threatSent; give threat if threatSent
day {어제}
them 23:51 {탈} {주세요}.
them 23:58 {탈} {주세요}.
day@threatSent {오늘}
them@threatSent 09:12 {진짜} {탈} {주세요}.
them@threatSent 09:13 {오늘} {밤} {9시}. {다리}.
note@threatSent They know. Somehow they know the mask on the gate isn't the real one.

# ------------------------------------------------------------ morning: the courtyard
=== scene c1_open
@card 다음 날 | The next morning
! set hasPhone; have letter, photo79, couplephoto, note
~ The next morning. Nobody in the guesthouse really slept.
~ 수진 brought the mask in from the gate. It lies on the wooden floor of the courtyard, grinning at the sky.
sujin[sad]: {탈}... {할머니} {탈}{이에요}.
(She sits next to it but doesn't pick it up. She just keeps looking at it.)

=== scene c1_sjhub
sujin: {네}?
(She looks up at you, eyes red.)
~ What do you ask her?
* {할머니} {어디}{예요|이에요}? -> c1_sjq1
* {탈}{이에요}? -> sawFake ? c1_sjq2b : c1_sjq2
* {괜찮아요}? -> c1_sjq3
* {김밥} {두 개}... {누구}{예요|이에요}? -> c1_sjq4 if showed
* [Show her something] -> c1_sjshow
* [Leave her be] -> c1_sjbye

=== scene c1_sjq1
sujin[sad]: {몰라요}... {정말} {몰라요}.
(She shakes her head slowly.)
sujin[worried]: {어제} {밤}{에}... {마당}{에} {있었어요}. {할머니}{는|은/는}... {없어요}.
(She points at the step where she sat. She waited out here all night, and never saw a thing.)
-> c1_sjhub.2

=== scene c1_sjq2
sujin[sad]: {네}. {할머니} {탈}... {축제} {탈}{이에요}.
(She reaches toward the mask, then pulls her hand back.)
-> c1_sjhub.2

=== scene c1_sjq2b
sujin[worried]: {아니요}! {가짜}{예요|이에요}. {진짜} {탈}{은|은/는}... {어디}{예요|이에요}?
(She holds up the fake in one hand and makes an empty grab with the other.)
-> c1_sjhub.2

=== scene c1_sjq3
sujin[sad]: {괜찮아요}? ...
(She tries to smile and doesn't quite manage it.)
sujin[sad]: {괜찮아요}. {괜찮아요}...
(She says it like she's telling herself, not you.)
-> c1_sjhub.2

=== scene c1_sjq4
sujin[worried]: {김밥} {두 개}... {몰라요}. {식당} {아저씨}{는|은/는} {알아요}.
(She points toward the front gate and the alley beyond it.)
-> c1_sjhub.2

=== scene c1_sjshow
@present Show 수진 something.
show: threat -> c1_show
show: fakemask -> c1_sjfake
show: letter -> c1_sjletter
miss -> c1_sjnope

=== scene c1_sjfake
sujin[sad]: {가짜}... {네}.
(She already knows. She doesn't want to look at it again.)
-> c1_sjhub.2

=== scene c1_sjletter
sujin[surprised]: {할머니}{의} {편지}...
(She reads it twice, mouthing the words. At 비밀 she stops.)
sujin[worried]: {비밀}...? {비밀}...
(She looks at you, then at the workshop. She had no idea.)
-> c1_sjhub.2

=== scene c1_sjnope
sujin: {네}...?
(She looks at it, then at you, not sure why you're showing her that.)
-> c1_sjhub.2

=== scene c1_sjbye
~ You leave her be for now.

=== scene c1_mask
~ Up close, the mask looks perfect. Long eyebrows, a huge grin. Exactly like the one 할머니 showed you two nights ago.
* [Pick it up] -> sawFake ? c1_maskagain : c1_mask2
* [Leave it alone] -> c1_maskleave

=== scene c1_maskleave
~ You leave it where it is. 수진 doesn't seem to want anyone touching it.

=== scene c1_maskagain
~ The paint has dried a little since this morning, but it still smells of fresh wood. No chip in the eyebrow. A good fake. A fast one.

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
! set sawFake; give fakemask
~ In your pocket, 할머니's phone buzzes.
! set threatSent; toast New message on 할머니's phone.

=== scene c1_show
sujin[surprised]: {진짜} {탈} {주세요}... {오늘} {밤}... {다리}?!
! set showed
(The color drains out of her face.)
sujin[worried]: {누구}{예요|이에요}? {누구}?!
(She shouts it at the phone, as if it could answer.)
sujin: {김밥} {두 개}... {할머니}{는|은/는} {누구}{하고}...
(She stops, thinking. Then she gives the phone back.)
sujin[worried]: {김밥}... {식당} {아저씨}{는|은/는} {알아요}. {우리} {같이} {찾아요}. {빨리}!

=== scene c1_wall
~ Behind the clay jars, on the old stone wall: a smear of red paint, and a few chips of stone knocked loose. Someone climbed over here in a hurry, with wet paint on their hands.
~ On the other side of the wall, a narrow path runs toward the mountain.
! set sawWall

# ------------------------------------------------------------ workshop
=== scene c1_bench
~ Fresh wood shavings, still pale, piled under the bench. One of the small carving knives is missing from the neat row. Next to it, a pot of paint with its lid off.
sign: {빨간} {물감}
(The label on the pot. The paint inside is the same red as the smear on your fingers.)
~ Under the bench lies a crumpled paper bag with a blue stamp on it.
sign: 청솔 {시장}
(A market bag.)
! set sawBag; give paintbag

=== scene c1_sketch
~ Pinned to the wall: a pencil sketch of the mask, from the front and from the side, covered in little numbers. In the corner, a drawing of a rough block, labeled in neat handwriting:
sign: {나무} · 30cm
(She planned this. Down to the size of the block of wood.)
! give sketch

=== scene c1_hook
~ The hook in the middle of the wall is still empty. The real mask never came back here.

# ------------------------------------------------------------ alley
=== scene c1_o1
~ The couple from yesterday is back in the alley, out of their hanbok now, rolling suitcases toward the bus stop.
yuna[happy]: 아! {안녕하세요}!
yuna[worried]: {할머니}... {찾아요}?
(She looks at your face, and her smile fades.)
* {네}... -> c1_o2
* {아니요}! -> c1_owrong

=== scene c1_owrong
yuna[surprised]: {아니요}? 아... {네}...
(She doesn't believe you for a second. You look like someone who hasn't slept, searching for someone.)
~ You are obviously still looking. Be honest with her.
<- c1_o1.3

=== scene c1_o2
minsu[worried]: {어제} {밤}{에}... {다리}{에} {남자}{가|이/가} {있었어요}.
(He mimes holding something in front of him and sweeping it slowly left and right.)
yuna[worried]: {남자}... {불}{이|이/가} {있었어요}. {이거}!
(She turns on her phone's flashlight and waves it around.)
yuna[worried]: {이상해요}...
(She rubs her arms like she's cold.)
! set sawMan
minsu[surprised]: 아! {버스}! {빨리}!
(Their bus is pulling in. They grab their suitcases.)
yuna[happy]: {고마워요}! {안녕}!
(She waves over her shoulder as they run.)

# ------------------------------------------------------------ mountain path
=== scene c1_marker
sign: ↑ {산} 1.2km · {절}
(The trail marker. Yesterday you only noticed the distance. Below it, a second word you hadn't read.)

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
@type Ask him who the second 김밥 was for.
answer: {누구} {김밥}{이에요}? -> c1_kwho
answer: {김밥} {두 개} {누구}{예요|이에요}? -> c1_kwho
answer: {할머니} {봤어요}? -> c1_ksaw
answer: {맛있어요} -> c1_kyum
miss -> c1_khuh
=== scene c1_ksaw
ajeossi[sad]: {오늘}{은|은/는}... {아니요}. {안} {왔어요}.
(He shakes his head.)
~ You knew that already. You wanted to know who the second 김밥 was for.
<- c1_ktalk

=== scene c1_kyum
ajeossi[happy]: {맛있어요}? 하하, {고마워요}!
(He looks delighted. You haven't eaten anything.)
~ Nice, but not the question.
<- c1_ktalk

=== scene c1_khuh
ajeossi[surprised]: {네}?
(He tilts his head.)
~ He didn't follow. Try asking whose 김밥 it was.
<- c1_ktalk

=== scene c1_kwho
ajeossi[surprised]: {김밥} {두 개}? 아... {할아버지}! {할아버지} {김밥}{이에요}.
(He snaps his fingers.)
ajeossi: {할아버지}{는|은/는} {할머니}{의} {친구}{예요|이에요}.
(He holds two fingers side by side. Old friends.)
* {할아버지}{는|은/는} {어디}{예요|이에요}? -> c1_kwhere

=== scene c1_kwhere
ajeossi: {할아버지}요? 음...
(He scratches his head.)
ajeossi[sad]: {몰라요}.
ajeossi: {시장} {아주머니}{는|은/는} {알아요}. {시장}! {아주머니}!
(He mimes someone selling things across a stall, then points at the bus stop through the window.)
! set talkedOwner

=== scene c1_kafter
ajeossi: {시장}! {시장} {아주머니}{는|은/는} {알아요}.
(He points at the bus stop again.)

=== scene c1_korder
@build The menu is on the wall. Order something.
tiles: {김밥} | {떡볶이} | {라면} | {비빔밥} | {물} | {주세요}
answer: {김밥} | {주세요} -> c1_kf
answer: {떡볶이} | {주세요} -> c1_kf
answer: {라면} | {주세요} -> c1_kf
answer: {비빔밥} | {주세요} -> c1_kf
answer: {물} | {주세요} -> c1_kwater
miss -> c1_kmiss

=== scene c1_kmiss
ajeossi[surprised]: {네}?
(He looks at the menu, then back at you.)
~ The food, then 주세요.
<- c1_korder

=== scene c1_kf
ajeossi[happy]: {네}! {여기} {있어요}.
(A minute later, a plate lands in front of you. He watches you eat, and for a moment he looks less worried.)
* {맛있어요}! -> c1_kgood
* {매워요}! -> c1_kspicy

=== scene c1_kgood
ajeossi[happy]: {고마워요}!

=== scene c1_kspicy
ajeossi[happy]: 하하! {물}! {물} {있어요}!
(He slides a cup of water across the counter.)

=== scene c1_kwater
ajeossi: {물}? {네}, {여기} {있어요}.

# ------------------------------------------------------------ bus
=== scene c1_jmap
sign: 청솔마을 → {시장} → {영화관} → {박물관} → {지하철역}
(The route map. The market is the very first stop.)

=== scene c1_b0
~ The bus rattles out of the village along the river road. The screen above the driver shows the stops.
! place bus; led 청솔마을
-> c1_bs1

=== scene c1_bs1
bus: {이번} {정류장}{은|은/는} {시장}{입니다}.
! led 시장
* [🔔 Press the stop button] -> c1_bo_market
* [Stay on] -> c1_bs2

=== scene c1_bs2
bus: {이번} {정류장}{은|은/는} {영화관}{입니다}.
! led 영화관
* [🔔 Press the stop button] -> c1_bo_cinema
* [Stay on] -> c1_bs3

=== scene c1_bs3
bus: {이번} {정류장}{은|은/는} {박물관}{입니다}.
! led 박물관
* [🔔 Press the stop button] -> c1_bo_museum
* [Stay on] -> c1_bs4

=== scene c1_bs4
bus: {이번} {정류장}{은|은/는} {지하철역}{입니다}.
! led 지하철역
* [🔔 Press the stop button] -> c1_bend
* [Stay on] -> c1_bend

=== scene c1_bo_market
~ You press the bell and hop off into the noise and smell of the market.
-> c1_market_in

=== scene c1_market_in
~ Fish on ice, cabbages stacked like walls, and people shouting prices.
! place sijang
-> sijang_visited ? c1_mafter_in : c1_m1

=== scene c1_bo_cinema
~ A movie theater with posters for an action film. Not today. You catch the next bus back and start over.
<- c1_b0

=== scene c1_bo_museum
~ You press the bell and hop off in front of the big glass building.
! place museum
-> museum_visited ? c1_mudesk : c1_mu1

=== scene c1_bend
~ The bus stops for good. Last stop. You ride back and try again.
<- c1_b0

=== scene c1_mback
~ You catch the bus back to the village.
! place jeong

# ------------------------------------------------------------ market
=== scene c1_m1
! set sijang_visited
~ In a narrow stall crammed with paint pots and blocks of wood sits a woman in a flowered apron, counting change.
ajumma[happy]: {어서 오세요}! {어서 오세요}!
(She waves you over to her stall.)
~ She's busy with customers. If you buy something, she'll have a minute for you.

=== scene c1_mafter_in
~ The woman at the paint stall waves when she sees you.

=== scene c1_mbuy
@build Buy something from her stall.
tiles: {빨간} | {물감} | {나무} | {주세요} | {얼마예요}? | {사진}
answer: {빨간} | {물감} | {주세요} -> c1_mprice
answer: {물감} | {주세요} -> c1_mprice
answer: {나무} | {주세요} -> c1_mprice
answer: {물감} | {얼마예요}? -> c1_mhow
answer: {나무} | {얼마예요}? -> c1_mhow
answer: {얼마예요}? -> c1_mhow
miss -> c1_mhuh

=== scene c1_mhuh
ajumma[surprised]: {네}?
(She waits, smiling politely, while you try again.)
~ Pick something from her stall, then 주세요.
<- c1_mbuy

=== scene c1_mhow
ajumma: {천 원}{이에요}. {천 원}!
(She holds up one finger, then taps the price card: 1,000.)
<- c1_mbuy

=== scene c1_mprice
ajumma[happy]: {네}! {천 원}{이에요}.
(She holds up one finger.)
* [Hand her a 10,000 won bill] -> c1_mbig
* [Hand her a 1,000 won bill] -> c1_mpaid
* [Hand her a 100 won coin] -> c1_msmall

=== scene c1_mbig
ajumma[surprised]: 만 원? 아이고...
(She digs through her cash box for change, sighing dramatically, then looks at the line of customers behind you.)
~ She said 천 원. One finger, one thousand. Try the right bill.
<- c1_mprice

=== scene c1_msmall
ajumma[surprised]: 백 원? {아니요}, {아니요}! {천 원}!
(She laughs and holds up one finger again.)
~ That's a hundred. She asked for a thousand.
<- c1_mprice

=== scene c1_mpaid
ajumma[happy]: {고마워요}!
(She wraps your purchase in newspaper and hands it over. Then she leans on her counter. She has a minute now.)
! set paid
-> c1_mtalk

=== scene c1_mtalk
~ What do you ask her?
* {할머니} {봤어요}? -> c1_m2
* {맛있어요}? -> c1_mwrong

=== scene c1_mwrong
ajumma[surprised]: {맛있어요}? 이거?
(She looks down at the pot of paint, then back at you, very concerned.)
~ Please don't eat the paint. Ask about 할머니.
<- c1_mtalk

=== scene c1_m2
ajumma[surprised]: 순자 {할머니}? {네}! {어제} {아침}{에} {왔어요}.
(She points at the ground in front of her stall. Right here.)
ajumma: {할아버지}{하고} {왔어요}. {김밥}{도} {먹었어요}. {여기}{에서}!
(She mimes two people sitting on the low stools, eating.)
ajumma: {할머니}{는|은/는} {나무}{하고} {빨간} {물감}{을|을/를} {샀어요}.
(She taps a block of wood and a pot of red paint. The same paint you just bought.)
ajumma[worried]: {이상해요}... {할머니}{는|은/는} {축제}{에} {안} {왔어요}.
(She frowns. Everyone expected 할머니 at the festival.)
* {할아버지}{는|은/는} {어디}{예요|이에요}? -> c1_m3

=== scene c1_m3
ajumma: {할아버지}? {강}! {아침}{에}{는|은/는} {강}{에} {있어요}.
(She mimes casting a fishing line.)
ajumma: {강}{은|은/는} {버스 정류장} {뒤에} {있어요}.
(She draws in the air: the bus stop, and a little path going down behind it.)
! set marketDone, knowRiver

=== scene c1_mafter
ajumma[happy]: {강}! {버스 정류장} {뒤에}!
(She waves her hand down and around: behind the bus stop.)

=== scene c1_mfish
~ A man in rubber boots is hosing down a tub of fish. He glances at you, sees you aren't buying, and goes back to his hose.
~ On the ice, a sign in thick marker:
sign: {물고기} · {오늘} {아침}
(Today's catch. Everything here was caught this morning.)

# ------------------------------------------------------------ museum
=== scene c1_mu1
! set museum_visited
~ The museum is as quiet as yesterday. The woman at the front desk stands up as soon as she sees you.
staff[surprised]: 아! {안녕하세요}... 김순자 {선생님}{은|은/는}...?
(She looks hopeful.)
* [Shake your head] -> c1_mu2

=== scene c1_mu2
staff[sad]: {아니요}...? {선생님}...
(She sits back down slowly and looks at the glass case at the far wall.)

=== scene c1_mudesk
staff[sad]: {선생님}... {괜찮아요}?
(She asks it softly, mostly to herself.)

=== scene c1_mucase
~ The big glass case. The old mask sits on its velvet stand: long eyebrows, a huge grin.
staff[happy]: {진짜} {탈}{이에요}! 1650! {진짜}!
(The woman from the desk has followed you. She says it proudly, tapping the glass.)
~ You look closer. The left eyebrow is perfect. Not a chip anywhere.
! set sawMuseumCase
@present Does anything you have not fit with what she's saying?
show: photo79 -> c1_mudoubt
show: fakemask -> c1_mufake
miss -> c1_munope

=== scene c1_mudoubt
staff[surprised]: 어?
(She takes the old photo and holds it up next to the glass. The chip in the eyebrow in 1979. No chip now.)
staff[worried]: {이상해요}... {진짜}... {진짜}{예요|이에요}...
(She says it again, but quieter, and she doesn't give the photo back right away.)
! set doubtMuseum

=== scene c1_mufake
staff[happy]: {가짜}? 하하. {아니요}! 1650! {진짜}!
(She taps the glass, very sure of herself.)

=== scene c1_munope
staff[happy]: {네}?
(She smiles politely. It doesn't mean anything to her.)

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
* {물고기} {있어요}? -> c1_g2c

=== scene c1_g2b
haraboji: {네}. {강}{이에요}.
(He points at the river. Then at you. Then back at the river.)
~ Yes, it's a river. Ask him something more useful.
<- c1_g2.2

=== scene c1_g2c
haraboji[happy]: {물고기}? {아니요}. 하하.
(He lifts his empty bucket to show you. For a second, he almost smiles.)
~ No fish today. And you didn't come here for fish.
<- c1_g2.2

=== scene c1_g3
haraboji[worried]: ...{몰라요}.
(He doesn't look at you. His hands tighten on the rod.)
~ Next to him on the rock: two empty 김밥 wrappers, and a folded piece of red cloth.
haraboji[worried]: {몰라요}. {몰라요}.
(He says it again, quieter, like he's trying to convince himself.)
! set metGramps
-> c1_gtalk.2

=== scene c1_gtalk
haraboji[worried]: {몰라요}.
(He keeps his eyes on the water. Nothing you say is going to change his mind. Something you show him might.)
@present Show him something.
show: threat -> c1_gshow
show: letter -> c1_gletter
show: couplephoto -> c1_gphoto
miss -> c1_gnope

=== scene c1_gletter
haraboji[sad]: {학생}... {편지}...
(He reads it slowly and hands it back, gently. He knows her handwriting.)
haraboji[worried]: ...{몰라요}.
~ It moved him. But not enough.
<- c1_gtalk.2

=== scene c1_gphoto
haraboji[surprised]: ...
(He stares at the blurry woman behind the couple for a long moment.)
haraboji[worried]: {몰라요}.
~ He knew she left. That isn't news to him.
<- c1_gtalk.2

=== scene c1_gnope
haraboji: {네}?
(He glances at it and goes back to his line.)
<- c1_gtalk.2
=== scene c1_gshow
~ He squints at the message.
haraboji[surprised]: {진짜} {탈}... {오늘} {밤}... {다리}?!
(He looks down the river at the wooden bridge. The fishing rod slips out of his hands and clatters on the rock.)
haraboji[worried]: {누구}{예요|이에요}? {누구}...?
(He grips your arm. Then he lets out a long breath.)
haraboji[sad]: {할머니}{는|은/는}... {산}{에} {있어요}.
(He points up at the mountain behind the village.)
haraboji: {산}{에} {절}{이|이/가} {있어요}. {절}{에} {있어요}. {빨리} {가요}!
(He makes the shape of a little roof with his hands. A temple, up the mountain path.)
! set toldMountain

=== scene c1_ghub
haraboji[worried]: {빨리}... {절}!
(He waves you toward the mountain, but he's still worried enough to answer a question or two.)
* {남자}... {다리}{에}...? -> c1_gq1 if sawMan
* {박물관} {탈}{은|은/는}...? -> c1_gq2 if sawMuseumCase
* {누구}{예요|이에요}? -> c1_gq3
* [Go] -> c1_gbye

=== scene c1_gq1
haraboji[worried]: {남자}...? {어제} {밤}{에}...?
(He looks down the river at the bridge for a long time.)
haraboji[sad]: {몰라요}... {정말} {몰라요}.
-> c1_ghub

=== scene c1_gq2
haraboji[surprised]: {박물관}...
(He looks away, too quickly, and busies himself with his line.)
haraboji: {할머니}{는|은/는} {알아요}. {저}{는|은/는}... {몰라요}.
(Grandma knows. He doesn't, or won't say.)
-> c1_ghub

=== scene c1_gq3
haraboji[sad]: {몰라요}. {누구}... {누구}{예요|이에요}...
(He shakes his head at the phone in your hand.)
-> c1_ghub

=== scene c1_gbye
haraboji: {빨리} {가요}.

=== scene c1_bridge
~ You walk down to the wooden bridge. In the morning light it's just a bridge: old planks, a rope rail, ducks underneath.
~ In the mud by the first post, though: a bootprint, bigger than yours, and the round mark of something set down. The kind of mark a heavy flashlight makes when you stand it on its end.
! give bootprint

# ------------------------------------------------------------ temple
=== scene c1_j1
~ The path climbs for a long time. By the time you reach the top, the sun is going down. A tiny temple sits between the pines, one lantern lit.
~ On its wooden step, wrapped in a blanket, sits a small old woman. In her lap is a bundle of red cloth.
halmeoni[surprised]: {누구}... {누구}{예요|이에요}?
(She clutches the bundle to her chest.)
@present Show her who you are.
show: letter -> c1_j2
miss -> c1_jwrong

=== scene c1_jwrong
halmeoni[worried]: {가짜}...?!
(She shrinks back against the temple door, holding the bundle tighter.)
~ That means nothing to her. She doesn't recognize you in the dark.
<- c1_j1.4

=== scene c1_j2
halmeoni[happy]: 아... {제} {편지}! {학생}!
(She recognizes her own handwriting, then you, and her whole face relaxes.)
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
~ You have so many questions.
* {누구}{예요|이에요}? {핸드폰}... -> c1_jq1
* {집}{에} {가요}! -> c1_jq2
* {할아버지}{는|은/는}... -> c1_jq3
* [Sit with her a moment] -> c1_jdusk

=== scene c1_jq1
halmeoni[worried]: {몰라요}... {남자}{예요|이에요}.
(She looks down the mountain toward the river.)
halmeoni[worried]: {박물관}... {아니요}. {몰라요}.
(She stops herself, and shakes her head hard.)
-> c1_j3.4

=== scene c1_jq2
halmeoni[sad]: {아니요}. {아니요}...
(She holds the bundle tighter. She won't go down the mountain while someone is hunting for it.)
halmeoni: {탈}... {집}{에}... {아니요}.
-> c1_j3.4

=== scene c1_jq3
halmeoni[happy]: {할아버지}... {친구}{예요|이에요}. {좋은} {친구}.
(For a moment she smiles, really smiles.)
-> c1_j3.4

=== scene c1_jdusk
~ You sit down next to her on the cold step. The sun slides behind the ridge. Below, the village lights come on one by one.
~ Then, on the dark mountain path, a light is coming up. Slowly. Someone is climbing.
halmeoni[worried]: {누구}...? {불}...!
(She grabs your sleeve and points at the light.)
~ The lantern on the temple eave is still burning. Anyone on the path can see it.
* [Call out to the light] -> c1_jcall
* [Blow out the lantern] -> c1_jdark
* [Run down the path toward it] -> c1_jrun

=== scene c1_jcall
~ You open your mouth to shout, and 할머니 claps a hand over it, eyes wide.
halmeoni[worried]: {아니요}! {아니요}!
~ Calling out to whoever is hunting her mask is a very bad idea.
<- c1_jdusk.4

=== scene c1_jrun
~ You take one step toward the path. 할머니 grabs your sleeve and pulls you back, hard.
halmeoni[worried]: {아니요}...
~ Running straight at a stranger in the dark won't help either of you.
<- c1_jdusk.4

=== scene c1_jdark
~ You blow out the lantern. Darkness. 할머니's breathing, fast and shallow.
halmeoni[worried]: {숨어요}! {빨리}!
(She pulls you behind the temple, into the pines.)
~ The light reaches the top of the path. It sweeps across the empty step, the dark doorway, the pines. It stops right next to your hiding place.
stranger: ...{할머니}?
(A man's voice. Calm. Too calm.)
stranger: {진짜} {탈}... {주세요}.
~ 할머니's hand finds yours in the dark and squeezes. Neither of you breathes.
! set hidden; toast One question left on your case board.

=== scene c1_jend
halmeoni[worried]: {숨어요}...
(A whisper. The light is still out there.)
