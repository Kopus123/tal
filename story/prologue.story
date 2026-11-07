# ===================================================================
#  탈 · PROLOGUE  (story file — the game reads this at startup)
#
#  Quick reference
#    === scene NAME        a block of lines; each line is one beat
#    who: 한국어            someone speaks (who = a key from the cast)
#    (English)             what you SEE them do, attached to the line above
#    ~ English             narration beat
#    ! effect; effect      runs when the beat above starts
#                          set FLAG | unset FLAG | learn WORD, WORD | place PLACE
#                          led TEXT | toast TEXT     (add "if COND" to any effect)
#    * 한국어 -> TARGET     a choice the player says out loud
#    * [Action] -> TARGET  a choice the player does
#    -> TARGET             jump when the beat ends (NAME, or NAME.2 for its 2nd beat)
#    TARGET can be  "COND ? A : B".  COND = flag, !flag, @place, joined with &
#    {word}                tappable word.  {surface|notebook entry} when they differ
#    @build / tiles: / answer: / miss ->     sentence-building moment
#    @camera / @photo                        special beats
# ===================================================================

=== meta
title 탈
village 청솔마을
blurb A mystery in Korean. Nobody will translate for you. Tap any word to see a picture of it, and work out the rest from what people do.
start evening
start-place night
end-title 프롤로그 끝
end-text 할머니 is out there somewhere, and she doesn't want to be found. Someone else wants her mask. Chapter 1 picks up the next morning.

=== cast
# key      | name          | color    | voice  rate  pitch
sujin      | 수진          | #3f8b77  | SunHi  +0%   +0Hz
halmeoni   | 할머니        | #8a6a9a  | SunHi  -14%  -28Hz
yuna       | 유나          | #c26a86  | SunHi  +8%   +25Hz
minsu      | 민수          | #4f6ea8  | InJoon +0%   +0Hz
ajeossi    | 식당 아저씨   | #8a5a34  | InJoon -6%   -18Hz
staff      | 박물관 직원   | #6a6f7d  | SunHi  -3%   -12Hz
bus        | 안내 방송     | #2a2a2a  | Hyunsu -5%   +0Hz
you        |               |          | Hyunsu -8%   +0Hz
word       |               |          | SunHi  -15%  +0Hz
sign       |               |          | SunHi  -10%  +0Hz

=== words
# word = picture  (+past, +future, +not are badges added to the picture)
할머니 = grandma
엄마 = woman
오빠 = youngman
저 = me
우리 = two
같이 = together
선생님 = teacher
봤어요 = eye +past
네 = yes
아니요 = no
정말 = bang
어디 = where
없어요 = exists +not
있어요 = exists
있었어요 = exists +past
방 = room
마당 = yard
이상해요 = strange
핸드폰 = phone
여기 = here
그 = that
이거 = this
찾아요 = search
찾지 마세요 = search +not
공방 = workshop
탈 = mask
예뻐요 = pretty
고마워요 = thanks
잘 자요 = sleep
축제 = festival
오늘 = today
어제 = calendar +past
내일 = calendar +future
아침 = morning
시 = clock
저기요 = excuse
안녕하세요 = wave
어서 오세요 = welcome
사진 = photo
찍어 주세요 = camera
주세요 = please
배고파요 = hungry
김치 = kimchi
식당 = restaurant
김밥 = gimbap
떡볶이 = tteokbokki
라면 = ramen
비빔밥 = bibimbap
물 = water
맛있어요 = yum
매워요 = spicy
짜요 = salty
두 개 = twoitems
샀어요 = bag +past
버스 = bus
버스 정류장 = busstop
정류장 = stop
이번 = now
탔어요 = board +past
내려요 = getoff
옆에 = beside
오른쪽 = right
왼쪽 = left
가요 = go
빨리 = fast
산 = mountain
시장 = market
영화관 = cinema
박물관 = museum
지하철역 = subway
만나요 = meet
안 = not
왔어요 = come +past
이에요 = (grammar)
아니에요 = (grammar)
입니다 = (grammar)
이/가 = (grammar)
은/는 = (grammar)
에 = (grammar)
에서 = (grammar)
도 = (grammar)
의 = (grammar)
으로 = (grammar)

=== hints
if !intro: Listen to 수진. Watch what she does with her hands while she talks.
if !read_museum: 수진 gave you 할머니's phone. People text about their plans.
if !maskMissing: The workshop is where 할머니 spends her days.
if !sawPhoto: Head out the front gate. Someone in the village might have seen something.
if !talked&@golmok&heardDir: He said which way to go. Tap the couple if you want to hear it again.
if !talked&@golmok: Ask the couple where the bus stop is.
if !talked: The restaurant owner sees everyone who walks past. Try talking to him.
if !museumDone: She left on a bus. Her phone said where she was going. Listen for that stop.
if !allSolved: Open the case board. You have enough to answer the questions.
if !ending: You've learned what you can at the museum. Take the bus home.
if !solved_q5: Who wrote on the back of that photo in the workshop? What did 수진 just say?
The prologue is done. Look back through your notebook while you wait for Chapter 1.

=== pattern past
title The ㅆ pattern
note People keep using these ㅆ versions whenever they talk about this morning.
need 3
있어요 > 있었어요
사요 > 샀어요
타요 > 탔어요
와요 > 왔어요
보다 > 봤어요

=== case
q1 박물관 if read_museum | Where was 할머니 supposed to go this morning? | Her texts and her calendar both say the same place.
q2 탈 if maskMissing&sawPhoto | What did she take with her? | The mask from the empty hook, wrapped in red cloth.
q3 버스 if talked | How did she leave the village? | The restaurant owner watched her get on.
q4 아니요 if museumDone | Did she make it to the museum? | The museum never saw her.
q5 엄마 final if ending | Who is 할머니 to 수진? | Not just the village 할머니. Her mother.

# ------------------------------------------------------------ places
# spot "Label" X% Y% -> SCENE   (or => phone / => place NAME)   [if COND]
# glow WORD X% Y% R%            the spot lights up when someone says WORD

=== place night
name 마당
sub The courtyard, last night
art madang_eve
glow 마당 50 86 20
glow 방 45 52 12
glow 할머니 75 70 9
glow 탈 75 62 7

=== place madang
name 마당
sub The courtyard
art madang
desc The courtyard. Morning sun on the roof tiles. 수진 is pacing by the jars, calling neighbors on her own phone.
spot "Talk to 수진" 30 66 -> msj
spot "할머니's phone" 52 71 => phone
spot "Workshop" 82 52 => place gongbang
spot "Clay jars" 89 83 -> jars
spot "Front gate" 10 84 => place golmok
glow 핸드폰 52 71 6
glow 방 45 52 12
glow 마당 50 88 20

=== place gongbang
name 공방
sub 할머니's workshop
art gongbang
first g1
desc Masks on every wall, all grinning. One empty hook.
spot "Empty hook" 50 40 -> gh1
spot "Calendar" 87 30 -> gc1
spot "Old photo" 12 36 -> gp1
spot "Back to the courtyard" 50 90 => place madang
glow 탈 50 40 30
glow 축제 87 30 9
glow 오늘 87 30 9

=== place golmok
name 골목
sub The alley
art golmok
first o1
desc The alley outside the gate. Lanterns overhead. The path splits left and right.
spot "The couple" 50 62 -> oc1 if couple
spot "Left path" 14 76 => place sanqil
spot "Right path" 86 76 => place sikdang
spot "Front gate" 50 92 => place madang
glow 오른쪽 86 76 10
glow 왼쪽 14 76 10
glow 사진 50 62 9

=== place sanqil
name 산길
sub A mountain path
art san
always s1
desc A quiet path up the mountain. Pine needles underfoot. Nobody here.
spot "Go back down" 50 88 => place golmok
glow 산 50 30 22

=== place sikdang
name 식당
sub The little restaurant
art sikdang
first k1
desc A tiny restaurant that smells like sesame oil. The bus stop is right outside the window.
spot "Talk to the owner" 50 52 -> ktalk
spot "Order from the menu" 22 22 -> korder
spot "Bus stop" 85 40 => place jeong
spot "Back to the alley" 12 88 => place golmok
glow 김밥 11 23 7
glow 떡볶이 26 23 7
glow 라면 40 23 7
glow 비빔밥 55 23 7
glow 버스 정류장 85 30 9
glow 버스 85 30 9
glow 물 77 60 5

=== place jeong
name 버스 정류장
sub The bus stop
art jeong
desc A small bus stop at the edge of the village, right next to the restaurant.
spot "Route map" 28 45 -> jmap
spot "Wait for the bus" 72 72 -> b0
spot "Back to the restaurant" 12 88 => place sikdang
glow 버스 정류장 24 45 12

=== place bus
name 버스
sub On the bus
art bus
glow 시장 50 11 16
glow 영화관 50 11 16
glow 박물관 50 11 16
glow 지하철역 50 11 16

=== place museum
name 박물관
sub The museum
art museum
desc if museumDone&allSolved: Your case notes are done. Time to go back to the village.
desc if museumDone: Cool, quiet, masks behind glass. Your case board is waiting.
desc Cool, quiet, full of masks behind glass.
spot "The big glass case" 24 42 -> mc1
spot "Front desk" 66 62 -> museumDone ? mur : mu3
spot "Take the bus home" 88 88 -> allSolved ? e1 : ewait if museumDone
glow 탈 24 42 16

=== place gate
name 대문
sub The front gate, evening
art gate
desc The front gate, lit by lanterns. The mask hangs there, grinning.
spot "The note" 70 72 -> enote
spot "수진" 22 66 -> esj
glow 탈 50 58 9
glow 엄마 22 80 9

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

=== phone museum
name 청솔 박물관
avatar 박 #6a6f7d
on-open toast New questions on your case board if !read_museum
day {어제}
them 18:02 김순자 {선생님}, {내일} {아침} 9{시}, {박물관}{에서} {만나요}!
me 18:30 {네}! {내일} {만나요}.

=== phone unknown
name 010-4417-0923
avatar ? #3a3f4a
day {어제}
them 23:51 {탈} {주세요}.
them 23:58 {탈} {주세요}.
note No name. Twice, just before midnight. She never answered.

# ------------------------------------------------------------ last night
=== scene evening
~ Cheongsol Village. Tiled roofs, stone walls, and a river that bends around the hills. People have lived here for six hundred years. These days, so do a lot of tourists.
~ The last bus drops you at the edge of the village after dark. You find the guesthouse by its lanterns.
sujin: {안녕하세요}! {저}{는|은/는} 수진{이에요}.
(A woman about your mom's age bows and takes your bag. She talks slowly, like she can tell you're still learning.)
sujin: {여기}{는|은/는} {마당}{이에요}. {마당}.
(She sweeps her arm across the courtyard.)
sujin: {여기}{는|은/는} {방}{이에요}. {방}!
(She slides open a paper door. Inside: a folded blanket, a low table, a lamp.)
halmeoni: {안녕하세요}~
(An old woman comes out of the workshop, brushing wood dust off her hands. She smiles with her whole face.)
sujin: {할머니}{예요|이에요}.
halmeoni: {이거} {탈}{이에요}. {탈}!
(She holds up a wooden mask with long eyebrows and a huge grin and puts it over her face. Then she peeks out from behind it and laughs.)
* {예뻐요}! -> evening2 ! learn 예뻐요
* [Laugh with her] -> evening2

=== scene evening2
halmeoni: {탈}... {예뻐요}! 하하.
(She carries the mask back into the workshop and hangs it in the middle of the wall, very carefully, like it matters more than the others.)
sujin: {잘 자요}!
(She points you to your room.)
~ You sleep well.
~ In the morning, someone is shouting in the courtyard.
-> m1

# ------------------------------------------------------------ morning
=== scene m1
sujin: {할머니}! {할머니}!
(수진 runs across the courtyard, sliding doors open one after another.)
! place madang
sujin: {할머니} {봤어요}?
(She stops in front of you, points at her own eyes, then sweeps her hand across the empty courtyard.)
* {네} -> m_yes
* {아니요} -> m3 ! learn 봤어요, 아니요
* [Shrug, confused] -> m_shrug

=== scene m_yes
sujin: {정말}요? {어디}{에서}요?
(Her face lights up and she waits for you to go on. But you haven't seen anyone this morning.)
-> m1.2

=== scene m_shrug
sujin: {할머니}... {봤어요}?
(She points at her eyes again, slower this time, then at the empty courtyard.)
-> m1.2

=== scene m3
sujin: {아니요}... {할머니}{가|이/가} {없어요}. {방}{에} {없어요}. {마당}{에}{도} {없어요}.
(She looks into 할머니's room again, then all around the courtyard. Her voice is shaking.)
sujin: {이상해요}... {할머니} {핸드폰}{이|이/가} {여기} {있어요}.
(She holds up a phone in a cracked, flower-patterned case and frowns at it.)
sujin: {우리} {같이} {찾아요}!
(She starts peering behind the big clay jars, then looks back at you and waves you over.)
* [Start searching with her] -> m6 ! learn 찾아요, 같이
* [Sit down on the step and wait] -> m5b

=== scene m5b
sujin: {아니요}, {아니요}! {같이} {찾아요}!
(She pulls you back up by the sleeve and points: the phone, the workshop door, the front gate.)
-> m3.3

=== scene m6
~ You nod. She looks relieved and presses 할머니's phone into your hands. It isn't locked.
! set intro

=== scene msj
sujin: {할머니}... {어디}{예요|이에요}?
(She's calling neighbors on her own phone now, talking more to herself than to you.)

=== scene jars
~ A row of big brown clay jars, the kind every old house keeps soy paste and chili paste in. You lift a couple of lids. No 할머니. Mostly a smell.

# ------------------------------------------------------------ workshop
=== scene g1
~ The workshop smells like cut wood. Dozens of wooden masks hang on the wall, all grinning at you.
sujin: {여기}{는|은/는} {할머니}{의} {공방}{이에요}.
(She brushes wood shavings off the workbench. Tiny carving knives sit in a neat row.)
sujin: {탈}... {탈}... 어? {탈}{이|이/가} {없어요}!
(She runs her finger along the masks and stops at an empty hook in the middle of the wall. The hook 할머니 hung her mask on last night.)
! set maskMissing; learn 탈

=== scene gh1
~ Going by the pale outline on the wood, this was the mask with the long eyebrows and the huge grin. Under the hook there's a little paper tag in neat handwriting:
sign: {축제} {탈}

=== scene gc1
sign: {오늘}: {축제} 🏮\n9{시} {박물관}
(A paper calendar on the wall. Today's date has been circled twice in red pen.)

=== scene gp1
~ A faded photo by the door: a young woman in hanbok with a grinning mask pushed up on top of her head. Someone wrote on the back in crayon, a long time ago:
sign: {엄마} ♡

# ------------------------------------------------------------ alley
=== scene o1
~ Outside the front gate, a narrow alley runs between old stone walls. Paper lanterns are strung overhead for the festival. A little way down, the path splits left and right.
yuna: {저기요}! {저기요}!
(A young couple in rented hanbok is waving at you. She's holding out her phone.)
yuna: {사진} {찍어 주세요}!
* [Take the phone and line up a photo] -> ocam
* [Point at yourself, confused] -> o3b
* [Keep walking] -> o3c

=== scene o3b
yuna: {사진}! {사진} {찍어 주세요}!
(She mimes pressing a shutter button, then points at the two of them.)
-> o1.3

=== scene o3c
~ You turn to leave. She looks so disappointed that you turn right back around.
-> o1.3

=== scene ocam
@camera Get them both in the frame and tap the shutter.
! learn 사진, 찍어 주세요
yuna: 와! {정말} {예뻐요}! {고마워요}!
(She zooms in on the photo and shows her boyfriend.)
minsu: {정말} {고마워요}.
(He gives you a small, polite bow. They seem friendly. Maybe they saw something.)
~ What do you ask them?
* {배고파요}? -> o6b
* {할머니} {봤어요}? -> o7 ! learn 할머니
* {김치} {있어요}? -> o6c

=== scene o6b
yuna: {배고파요}? {아니요}! 하하.
(She laughs. Not what you meant to ask.)
-> ocam.4

=== scene o6c
minsu: {김치}...? {식당}{에} {있어요}...?
(He looks puzzled and points vaguely down the alley.)
-> ocam.4

=== scene o7
yuna: {할머니}요? 음... 아! {네}! {아침}{에} {봤어요}!
(She taps her boyfriend's arm.)
yuna: {오빠}, {사진}! {그} {사진}!
(He scrolls back through their camera roll.)
! set sawPhoto
@photo A selfie of the two of them at a bus stop, grinning. Behind them, a little blurry: a small old woman holding a bundle wrapped in red cloth. It's 할머니.
minsu: {버스 정류장}{이에요}. {식당} {옆에} {있어요}.
(He points down the alley toward the fork.)
* {버스 정류장} {어디}{예요|이에요}? -> o11 ! learn 버스 정류장, 어디
* [Nod and thank them] -> o12

=== scene o11
minsu: {오른쪽}{으로} {가요}. {오른쪽}!
(He waves in the general direction of the fork. Honestly, both ways look the same to you.)
! set heardDir
-> o12

=== scene o12
yuna: {빨리} {가요}!
(She shoos you off, grinning.)
! set couple

=== scene oc1
minsu: {버스 정류장}{은|은/는} {오른쪽}{이에요}. {왼쪽} {아니에요}!
(He points again, more firmly this time.)
! set heardDir

=== scene s1
~ The path gets narrow and steep, climbing toward the mountain behind the village. Pine trees, a grassy grave mound, birds. No bus stop up here.
sign: ↑ {산} 1.2km
(A wooden trail marker.)

# ------------------------------------------------------------ restaurant
=== scene k1
~ Down the right-hand path, a tiny restaurant is tucked into an old hanok. A handwritten menu hangs on the wall. A man in a white apron is wiping the counter.
! learn 오른쪽 if heardDir
ajeossi: {어서 오세요}!
(He waves you in with the cloth, smiling.)

=== scene ktalk
@build Say something to him.
tiles: {할머니} | {봤어요}? | {안녕하세요} | {여기} | {있어요}? | {맛있어요}
answer: {할머니} | {봤어요}? -> talked ? k3r : k3
answer: {할머니} | {여기} | {있어요}? -> talked ? k3r : k3
answer: {안녕하세요} -> khi
miss -> khuh

=== scene khi
ajeossi: {네}, {안녕하세요}! 하하.
(He bows back, amused.)

=== scene khuh
ajeossi: {네}?
(He tilts his head and waits for you to try again.)

=== scene k3
ajeossi: 순자 {할머니}요? {네}, {아침}{에} {여기} {있었어요}.
(He nods at a stool by the window.)
ajeossi: {김밥} {두 개} {샀어요}.
(He holds up two fingers. Then, after a moment, holds them up again, like that part matters.)
ajeossi: {버스} {탔어요}.
(He points through the window at the bus stop right next door.)
! set talked
~
* {고마워요}! -> k7 ! learn 고마워요

=== scene k7
ajeossi: {네}~ {할머니} {빨리} {찾아요}!
(He goes back to wiping the counter, but he keeps glancing at the window.)

=== scene k3r
ajeossi: {할머니}{는|은/는} {버스} {탔어요}. {버스 정류장}{에서}!
(He points at the bus stop again.)

=== scene korder
@build The menu is on the wall. Order something.
tiles: {김밥} | {떡볶이} | {라면} | {비빔밥} | {물} | {주세요}
answer: {김밥} | {주세요} -> kf_gimbap
answer: {떡볶이} | {주세요} -> kf_tteok
answer: {라면} | {주세요} -> kf_ramen
answer: {비빔밥} | {주세요} -> kf_bibim
answer: {물} | {주세요} -> kwater
miss -> khuh

=== scene kf_gimbap
ajeossi: {네}! {김밥} {여기} {있어요}.
(A minute later, a plate lands in front of you.)
* {맛있어요}! -> kgood
* {짜요}! -> ksalty

=== scene kf_tteok
ajeossi: {네}! {떡볶이} {여기} {있어요}.
(A minute later, a plate lands in front of you.)
* {매워요}! -> kspicy
* {맛있어요}! -> kgood

=== scene kf_ramen
ajeossi: {네}! {라면} {여기} {있어요}.
(A minute later, a bowl lands in front of you.)
* {맛있어요}! -> kgood
* {짜요}! -> ksalty

=== scene kf_bibim
ajeossi: {네}! {비빔밥} {여기} {있어요}.
(A minute later, a bowl lands in front of you.)
* {맛있어요}! -> kgood
* {짜요}! -> ksalty

=== scene kwater
ajeossi: {물}? {네}, {여기} {있어요}.
(He fills a metal cup from a pitcher.)
! learn 물

=== scene kspicy
ajeossi: 하하! {매워요}? {물}! {물} {있어요}!
(He laughs and slides a cup of water across the counter.)
! learn 매워요

=== scene kgood
ajeossi: {고마워요}!
(He looks very pleased with himself.)
! learn 맛있어요

=== scene ksalty
ajeossi: {짜요}? {아니요}... {맛있어요}!
(He looks wounded and insists, very firmly.)

# ------------------------------------------------------------ bus
=== scene jmap
sign: 청솔마을 → {시장} → {영화관} → {박물관} → {지하철역}
(The route map. The bus makes four stops after the village.)

=== scene b0
~ The bus rattles out of the village along the river road. A screen above the driver shows the stops.
! place bus; led 청솔마을
-> bs1

=== scene bs1
bus: {이번} {정류장}{은|은/는} {시장}{입니다}.
(The screen blinks and a recorded voice comes over the speaker. You'll have to get off at the right stop.)
! led 시장
* 🔔 {내려요} -> bo_market
* [Stay on] -> bs2

=== scene bs2
bus: {이번} {정류장}{은|은/는} {영화관}{입니다}.
! led 영화관
* 🔔 {내려요} -> bo_cinema
* [Stay on] -> bs3

=== scene bs3
bus: {이번} {정류장}{은|은/는} {박물관}{입니다}.
! led 박물관
* 🔔 {내려요} -> bo_museum
* [Stay on] -> bs4

=== scene bs4
bus: {이번} {정류장}{은|은/는} {지하철역}{입니다}.
! led 지하철역
* 🔔 {내려요} -> bend
* [Stay on] -> bend

=== scene bo_market
~ You hop off into a crowded market. Fish, vegetables, grandmothers arguing over prices. None of them is yours. You catch the next bus and start over.
-> b0

=== scene bo_cinema
~ A movie theater with posters for an action film. Not what you're looking for. You catch the next bus and start over.
-> b0

=== scene bo_museum
~ You press the bell and hop off in front of a big glass building.
! learn 내려요, 박물관
-> mu1

=== scene bend
~ The bus stops for good and the driver switches off the engine. Everyone gets off. You missed your stop, so you ride back and try again.
-> b0

# ------------------------------------------------------------ museum
=== scene mu1
~ Inside, it's cool and quiet. Glass cases full of old masks line the walls. A woman at the front desk looks up.
! place museum
staff: {안녕하세요}! 청솔 {박물관}{이에요}.
-> mu3

=== scene mu3
@build Ask her about 할머니. (Her full name was in the museum's text: 김순자.)
tiles: 김순자 | {선생님} | {할머니} | {봤어요}? | {여기} | {있어요}?
answer: 김순자 | {선생님} | {봤어요}? -> mu4
answer: {할머니} | {봤어요}? -> mu4
answer: 김순자 | {선생님} | {여기} | {있어요}? -> mu4
answer: {할머니} | {여기} | {있어요}? -> mu4
answer: 김순자 | {봤어요}? -> mu4
answer: {선생님} | {봤어요}? -> mu4
miss -> muhuh

=== scene muhuh
staff: {네}?
(She smiles politely and waits.)
-> mu3

=== scene mu4
staff: 김순자 {선생님}이요? {아니요}... {안} {왔어요}.
(She checks her watch and frowns, then turns her monitor toward you: a calendar entry at 9:00, with 할머니's name on it.)
staff: {이상해요}...
(She dials a number and holds the phone to her ear. Far away, on a wooden step in a courtyard, a phone is ringing.)
! set museumDone
~ There's nothing more to learn here. Time to put the morning together on your case board.

=== scene mur
staff: {선생님}{이|이/가} {안} {왔어요}... {이상해요}.
(She's still holding the phone, still frowning.)

=== scene mc1
~ In the biggest case: a mask about three hundred and fifty years old. Long eyebrows, a huge grin. It looks exactly like the one 할머니 showed you last night.
sign: {탈} · 1650

=== scene ewait
~ Something doesn't add up yet. Open your case board and answer what you can first.

# ------------------------------------------------------------ evening
=== scene e1
~ By the time the bus drops you back in the village, the lanterns are lit. The festival has started without her. Somewhere across the river, drums.
! place gate; set ending
~ 수진 is standing at the front gate, perfectly still.
~ Hanging on the gate is a mask. Long eyebrows. A huge grin. The one from the empty hook. Tucked into its strap is a folded note.
sign: {찾지 마세요}.
(Shaky handwriting.)
sujin: {엄마}...
(She presses the note to her chest. She isn't talking to you.)
~ One question left on your case board.

=== scene enote
sign: {찾지 마세요}.
(You look at the note again. You know that first part from this morning.)

=== scene esj
sujin: {엄마}... {어디}{예요|이에요}...
(She hasn't moved from the gate.)
