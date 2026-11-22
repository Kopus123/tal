# ===================================================================
#  탈 · TEST AREA: THE CASE BOARD LAB   (Godot only; format: top of world.story, plus the board sections below)
#  Trying out the new case board (Ideas doc: "Case board rethink"). Built from the prologue's real evidence.
#  Reach it from Chapters > Case board lab.
#
#  THE BOARD SECTIONS (new):
#    === card ID                 something you can pin up
#    say WHO FACE | 한국어         a statement: who said it, with the face they made (the picture on the card)
#    thing ICON | label | 한국어    a thing (evidence); the Korean written on it, if any
#    person WHO                  a person (their face)
#    place ART | 한국어 | English   a place (its drawing)
#    time ICON | 한국어            a time
#    note COLOR | 한국어 | English  a sticky note in your own hand (a question you're asking: pink, yellow, blue)
#    person WHO missing          the missing-person poster in the middle of it all
#    at X Y                      where it goes up (percent across, down); otherwise the first free spot
#    start                       you have it from the beginning (otherwise "! card ID" gives it)
#    pinned                      it starts pinned up (everything else goes up loose: pin it with a thumbtack)
#
#    === unlock ID               when ALL these strings are on the board, the effects happen. Silently:
#    when A-B, C-D               you find out by noticing a new option, like in real life.
#    ! effects
#
#  Cards go up loose; a thumbtack pins one, and only pinned cards can have strings. Taking a string down frays it
#  (a frayed one snaps); pulling a tack out bends it. More string (실) and thumbtacks (압정) from the shop:
#  ask in Korean, pay on the number pad.
# ===================================================================

=== meta
lang ko
start lab_open
start-place lab
home lab

=== hints
if !go_busstop: Who saw 할머니 this morning, and how did she leave? What you pin together tells the game what you understood.
if !go_museum: Where was she supposed to be at nine? Her calendar and the museum's text both say.
if !tolddone: Tell 수진 what you've worked out. Only when your board really says it.
Nothing more to find in the lab.

# ------------------------------------------------------------ the cards
=== card c_sujin
at 0 0
say sujin sad | {아니요}... {할머니}{가|이/가} {없어요}. {방}{에} {없어요}. {마당}{에}{도} {없어요}.
start

=== card c_calendar
at 21 48
thing calendar | {달력} | {오늘}: {축제}, {9시} {박물관}
start

=== card c_text
at 76 42
thing phone | {박물관} · {핸드폰} | 김순자 {선생님}, {내일} {아침} {9시}, {박물관}{에서} {만나요}!
start

=== card p_halmeoni
at 47 40
person halmeoni missing
start
pinned

=== card p_sujin
at 1 45
person sujin
start

=== card pl_madang
at 0 100
place madang | {마당} | the courtyard
start

=== card pl_sikdang
at 26 99
place sikdang | {식당} | the restaurant
start

=== card pl_museum
at 80 100
place museum | {박물관} | the museum
start

=== card t_morning
at 31 2
time morning | {아침}
start

=== card t_nine
at 99 3
time clock | {9시}
start

# the questions you're asking (your own sticky notes)
=== card q_where
at 56 0
note pink | {할머니}, {어디}{예요|이에요}? | Where is she?
at 58 4
start
pinned

=== card q_nine
at 99 50
note yellow | {9시}{에} {어디}? | Where was she at nine?
at 60 40
start
pinned

=== card c_owner_here
say ajeossi surprised | 순자 {할머니}{요}? {네}, {아침}{에} {여기} {있었어요}.

=== card c_owner_bus
say ajeossi worried | {버스} {탔어요}.

=== card p_ajeossi
person ajeossi

=== card pl_busstop
place jeong | {버스 정류장} | the bus stop

=== card c_couple
say yuna surprised | {할머니}{요}? 음... 아! {네}! {아침}{에} {봤어요}!

=== card c_photo
thing photo | {사진} · {버스 정류장} |

=== card p_couple
person yuna

=== card c_staff
say staff surprised | 김순자 {선생님}{이요|요}? {아니요}... {안} {왔어요}.

=== card p_staff
person staff

# ------------------------------------------------------------ what the board opens (silently)
# 아저씨 says she got on the bus: pin that to her and to the bus stop, and you can go there
=== unlock busstop
when c_owner_bus-p_halmeoni, c_owner_bus-pl_busstop
! set go_busstop

# her calendar and the museum's text both say 9 o'clock at the museum: pin either to the museum and to the time
# ...or to your question: where is she?
=== unlock busstop_q
when c_owner_bus-q_where, c_owner_bus-pl_busstop
! set go_busstop

=== unlock museum
when c_text-pl_museum, c_text-t_nine
! set go_museum

=== unlock museum2
when c_calendar-pl_museum, c_calendar-t_nine
! set go_museum

# ...or to your question: where was she at nine?
=== unlock museum_q
when c_text-pl_museum, c_text-q_nine
! set go_museum

=== unlock museum_q2
when c_calendar-pl_museum, c_calendar-q_nine
! set go_museum

# the whole story: she was at the restaurant in the morning, got on the bus, and never reached the museum
=== unlock story
when c_owner_here-pl_sikdang, c_owner_bus-pl_busstop, c_staff-pl_museum
! set knows_story

# ------------------------------------------------------------ places
=== place lab
mode board
light own
music none
sound room
name 연구실
sub The case board lab
art gongbang
desc Your case board. Pin cards up with thumbtacks, tie string between what belongs together. Nobody tells you when you're right: go and see what's changed.
spot "Restaurant" 10 10 => place sikdang
spot "Bus stop" 20 10 => place jeong if go_busstop
spot "Museum" 30 10 => place museum if go_museum
spot "Courtyard" 40 10 => place madang
spot "The shop" 50 10 => place shop

=== place madang
back lab
music calm
sound birds
name 마당
sub The courtyard
art madang
travel no
always lab_madang

=== place sikdang
back lab
light indoors
music calm
sound room
name 식당
sub The little restaurant
art sikdang
travel no
always lab_sikdang

=== place jeong
back lab
music calm
sound birds
name 버스 정류장
sub The bus stop
art jeong
travel no
always lab_jeong

=== place shop
back lab
music none
sound market
name 가게
sub The shop
art market
travel no
always lab_shop

=== place museum
back lab
light indoors
music none
sound room
name 박물관
sub The museum
art museum
travel no
always lab_museum

# ------------------------------------------------------------ scenes
=== scene lab_open
~ [Test area] 할머니 is missing. You have 수진's words, a calendar from the workshop, and a text on 할머니's phone.
~ Pin cards up with thumbtacks, then tie string between what belongs together. When your strings show you've understood something, new places open up. Nobody tells you when; you'll notice.

=== scene lab_back
~ You head back to your board.
! place lab

=== scene lab_sikdang
ajeossi[surprised]: 순자 {할머니}{요}? {네}, {아침}{에} {여기} {있었어요}.
! card c_owner_here, p_ajeossi
ajeossi: {김밥} {두 개} {샀어요}.
ajeossi[worried]: {버스} {탔어요}.
(He points through the window at the bus stop next door.)
! card c_owner_bus, pl_busstop
* [Accuse him of hiding her] -> lab_accuse if !accused
* [Thank him and go back] -> lab_back

=== scene lab_accuse
! set accused; rel ajeossi =0; set g:rep_down
~ You tell him you think he knows where she is. That he's hiding her.
ajeossi[sad]: {네}...?
(His face closes like a door. He turns back to his stove and doesn't look at you again.)
~ He'll remember this. So will the village.
! place lab

=== scene lab_jeong
yuna[surprised]: {할머니}{요}? 음... 아! {네}! {아침}{에} {봤어요}!
! card c_couple, p_couple
yuna: {오빠}, {사진}! {그} {사진}!
(He shows you a selfie at this bus stop. Behind them, a little blurry: 할머니, holding a bundle in red cloth.)
! card c_photo
-> lab_back

=== scene lab_museum
staff[surprised]: 김순자 {선생님}{이요|요}? {아니요}... {안} {왔어요}.
! card c_staff, p_staff
-> lab_back

=== scene lab_madang
sujin[worried]: {할머니}... {어디}{예요|이에요}?
* [Tell her what you've worked out] -> knows_story ? lab_tell : lab_wrong
* [Not yet] -> lab_back

=== scene lab_tell
~ You tell her: 할머니 had breakfast at the restaurant, got on the bus at the stop, and never reached the museum.
sujin[surprised]: {버스}...? {박물관}{에} {안} {왔어요}...?
(She sits down hard on the step. Then she looks at you differently: like someone who can actually help.)
! set tolddone; rel sujin +3
-> lab_back

=== scene lab_wrong
~ You tell her what you think. It doesn't hold together, and she can hear it.
sujin[sad]: ...{아니요}.
(She doesn't believe you. You've cost yourself some of her trust.)
! rel sujin -2; set g:rep_down
-> lab_back

# ------------------------------------------------------------ the shop: string and thumbtacks cost effort, and Korean
=== scene lab_shop
ajumma[happy]: {어서 오세요}! {뭐} {드릴까요}?
(Spools of thread and little boxes of thumbtacks hang behind the counter.)
@build Ask for what you need.
tiles: {실} | {압정} | {주세요} | {김밥} | {물}
answer: {실} | {주세요} -> shop_string
answer: {압정} | {주세요} -> shop_tacks
miss -> shop_huh

=== scene shop_huh
ajumma[surprised]: {네}?
(She looks at the shelf, then back at you.)
-> lab_back

=== scene shop_string
ajumma: {실}? {네}! {오}{백} {원}{이에요}.
(She holds up a spool of red thread.)
-> shop_string_pay

=== scene shop_string_pay
@number Pay her. | won
answer: 500 -> shop_string_ok
miss -> shop_string_wrong

=== scene shop_string_wrong
ajumma: {아니요}~ {오}{백} {원}!
(She taps the price card.)
-> shop_string_pay

=== scene shop_string_ok
! money -500 each time; supply string
ajumma[happy]: {감사합니다}!
-> lab_back

=== scene shop_tacks
ajumma: {압정}? {네}! {천} {원}{이에요}.
(A little box of five thumbtacks.)
-> shop_tacks_pay

=== scene shop_tacks_pay
@number Pay her. | won
answer: 1000 -> shop_tacks_ok
miss -> shop_tacks_wrong

=== scene shop_tacks_wrong
ajumma: {아니요}~ {천} {원}!
(She holds up one finger and taps the price card.)
-> shop_tacks_pay

=== scene shop_tacks_ok
! money -1000 each time; supply tacks
ajumma[happy]: {감사합니다}!
-> lab_back
