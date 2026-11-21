# ===================================================================
#  탈 · THE VILLAGE ON FREE DAYS   (format reference: top of world.story)
#  No plot here. This is where you are between chapters: the clock runs,
#  people follow their own days (story/people/), and you can talk to them.
# ===================================================================

=== meta
lang ko
start v_first
start-place madang
home madang

=== hints
if clock&time:night: It's late. Go to bed in the courtyard, and see who is around tomorrow.
People are in different places at different times of day. Tap the clock to see the day, wait a while to move it on, and talk to whoever you find.

=== place madang
music calm
sound birds
name 마당
sub The courtyard
art madang
ambient leaves
desc if time:night: The courtyard at night. One window is still lit.
desc if time:evening: The courtyard in the evening light. The day is winding down.
desc if time:morning: The courtyard. Morning sun on the roof tiles.
desc The courtyard, warm and quiet in the afternoon.
spot "Workshop" 82 52 => place gongbang
spot "Front gate" 10 84 => place golmok
glow 마당 50 88 46 10
glow 방 45 52 12

=== place gongbang
light indoors
music calm
sound room
name 공방
sub 할머니's workshop
art gongbang
ambient dust
desc The workshop. Masks on every wall, all grinning.
spot "Back to the courtyard" 50 92 => place madang
glow 탈 50 40 30

=== place golmok
music calm
sound birds
name 골목
sub The alley
art golmok
ambient leaves
desc if time:night: The alley, lit by the last few lanterns.
desc The alley outside the gate. The path splits left and right.
spot "Left path" 14 76 => place sanqil
spot "Right path" 86 76 => place sikdang if !time:night
spot "Right path, past the dark restaurant" 86 76 => place jeong if time:night
spot "Front gate" 50 92 => place madang
spot "Village hall" 50 40 => place hall
glow 오른쪽 86 76 10
glow 왼쪽 14 76 10

=== place hall
light indoors
music calm
sound room
name 마을회관
sub The village hall
art hall
ambient dust
closed time:night | The village hall is locked for the night.
desc The village hall. Cushions, a kettle that's always warm, and the notice board by the door.
spot "Notice board" 52 34 => board
spot "Back to the alley" 12 88 => place golmok
glow 마을 18 16 12

=== place sanqil
music calm
sound wind
name 산길
sub The mountain path
art san
ambient leaves
desc The path up the mountain. Pine needles underfoot. The climb can wait for another day.
spot "Go back down" 50 88 => place golmok
glow 산 50 30 22

=== place sikdang
light indoors
music calm
sound room
name 식당
sub The little restaurant
art sikdang
ambient dust
closed time:night | The restaurant is dark and the door is locked. Closed for the night.
desc The restaurant. It smells of sesame oil.
spot "Bus stop" 85 40 => place jeong
spot "Order food" 50 84 -> v_food
spot "Back to the alley" 12 88 => place golmok
glow 김밥 11 23 7
glow 떡볶이 26 23 7
glow 라면 40 23 7
glow 비빔밥 55 23 7

=== place jeong
music calm
sound birds
name 버스 정류장
sub The bus stop
art jeong
ambient leaves
desc if time:night: The bus stop. The last bus has gone.
desc The bus stop at the edge of the village. Behind it, a dirt path drops down toward the water.
spot "Route map" 28 45 -> v_jmap
spot "Path behind the bus stop" 40 62 => place gang
spot "Take the bus" 72 72 -> v_bus if !time:night
spot "Back to the restaurant" 12 88 => place sikdang if !time:night
spot "Back to the alley" 12 88 => place golmok if time:night
glow 버스 정류장 24 45 12

=== place gang
music calm
sound river
name 강
sub The river
art river
ambient leaves
desc if time:night: The river at night. You can hear it more than see it.
desc The river. Reeds, flat stones, and the wooden bridge further down.
spot "Back to the bus stop" 12 88 => place jeong
glow 강 50 74 22
glow 다리 82 40 13

=== scene v_first
! time go
~ A new morning in 청솔마을. Nothing is chasing you today.
~ People are about. Where they are changes with the time of day: tap the clock in the corner to see the day, and "Wait a while" to move it on.
~ Talk to whoever you find. What you say to people matters, and they open up as they get to know you.

=== place bus
light indoors
music none
sound bus
name 버스
sub On the bus
art bus
travel no
glow 시장 50 11 16
glow 박물관 50 11 16

=== place sijang
music none
sound market
name 시장
sub The market
art market
ambient dust
travel no
closed !time:morning&!time:afternoon | The market has packed up for the day.
desc if on:market: Market day! The aisles are packed and everyone is shouting prices.
desc The market. Fish on ice, mountains of cabbage, and the stall full of paint pots and wood.
spot "호떡 cart" 24 70 -> v_snack
spot "Take the bus back" 78 88 -> v_back
glow 시장 50 40 30

=== place museum
light indoors
music none
sound room
name 박물관
sub The museum
art museum
ambient dust
travel no
closed !time:morning&!time:afternoon | The museum doors are locked. It's closed for the day.
desc The museum, cool and quiet. The big glass case glows at the far wall.
spot "Take the bus back" 78 88 -> v_back
glow 탈 24 42 16

=== scene v_jmap
sign: 청솔마을 → {시장} → {영화관} → {박물관} → {지하철역}
(The route map. One fare, 1,500원, however far you ride. Press the stop button before the stop you want.)

=== scene v_bus
! place bus; led 청솔마을
~ The bus comes rattling along the river road. A ride is 1,500원, however far you go.
* [Pay and get on · 1,500원] -> v_r1 if !time:evening&money>=1500 ! money -1500 each time
* [It's evening: the buses only come back from town now] -> v_stay if time:evening&money>=1500
* [You can't afford the fare] -> v_broke if money<1500
* [Stay here] -> v_stay

=== scene v_broke
~ You count your coins. Not enough. The driver shrugs and the doors hiss shut.
~ The notice board in the village hall has small jobs that pay.
! place jeong

=== scene v_stay
~ You wave the bus on.
! place jeong

=== scene v_r1
! place bus
bus: {다음} {정류장}{은|은/는} {시장}{입니다}.
! led 시장
* [🔔 Press the stop button] -> v_tomarket
* [Stay on] -> v_r2

=== scene v_r2
! place bus
bus: {다음} {정류장}{은|은/는} {영화관}{입니다}.
! led 영화관
* [🔔 Press the stop button] -> v_cinema
* [Stay on] -> v_r3

=== scene v_r3
! place bus
bus: {다음} {정류장}{은|은/는} {박물관}{입니다}.
! led 박물관
* [🔔 Press the stop button] -> v_tomuseum
* [Stay on] -> v_r4

=== scene v_r4
! place bus
bus: {다음} {정류장}{은|은/는} {지하철역}{입니다}.
! led 지하철역
* [🔔 Press the stop button] -> v_subway
* [Stay on] -> v_r5

=== scene v_r5
! place bus
bus: {다음} {정류장}{은|은/는} 청솔마을{입니다}.
! led 청솔마을
* [🔔 Press the stop button] -> v_home
* [Stay on] -> v_loop

=== scene v_loop
~ The bus turns around at the end of the village road and heads back into town. The driver gives you a look in the mirror.
-> v_r1

=== scene v_tomarket
~ You press the bell and hop off into the noise of the market.
! place sijang

=== scene v_tomuseum
~ You press the bell and hop off in front of the big glass building.
! place museum

=== scene v_cinema
~ You press the bell, then look out at the cinema: posters for an action film you couldn't follow yet. Not today. You stay in your seat.
-> v_r3

=== scene v_subway
~ You press the bell, then look out at the subway station: trains to the city, crowds. Nothing for you there. You stay in your seat.
-> v_r5

=== scene v_home
~ You press the bell and hop off at the village.
! place jeong

=== scene v_back
~ The bus toward the village pulls up. 1,500원, however far you go.
* [Pay and get on · 1,500원] -> v_r2 if @sijang&money>=1500 ! money -1500 each time
* [Pay and get on · 1,500원] -> v_r4 if @museum&money>=1500 ! money -1500 each time
* [Walk back along the river road] -> v_walk

=== scene v_walk
~ You walk back along the river road. It's a long way, and the day moves on without you.
! time +1 each time; place jeong

# ------------------------------------------------------------ food: order in Korean, pay with the number pad
=== scene v_food
ajeossi: {어서 오세요}! {뭐} {드릴까요}?
* {김밥} {주세요} -> v_food_k if money>=3000
* {떡볶이} {주세요} -> v_food_t if money>=4000
* {라면} {주세요} -> v_food_r if money>=4500
* {비빔밥} {주세요} -> v_food_b if money>=8000
* [Not today] -> v_food_no

=== scene v_food_no
ajeossi: {네}~ {다음}{에} {오세요}!

=== scene v_food_k
ajeossi: {김밥}? {네}! {삼}{천} {원}{이에요}.
-> v_food_k_pay

=== scene v_food_k_pay
@number Pay him. | won
answer: 3000 -> v_food_k_ok
miss -> v_food_k_miss

=== scene v_food_k_miss
ajeossi[surprised]: {아니요}~ {삼}{천} {원}!
(He holds up three fingers and laughs.)
-> v_food_k_pay

=== scene v_food_k_ok
! money -3000 each time
ajeossi[happy]: {감사합니다}!
~ The 김밥 comes cut into neat little rounds. You eat every one.
-> v_food_end

=== scene v_food_t
ajeossi: {떡볶이}? {사}{천} {원}{이에요}. {매워요}!
-> v_food_t_pay

=== scene v_food_t_pay
@number Pay him. | won
answer: 4000 -> v_food_t_ok
miss -> v_food_t_miss

=== scene v_food_t_miss
ajeossi[surprised]: {아니요}~ {사}{천} {원}!
(Four fingers.)
-> v_food_t_pay

=== scene v_food_t_ok
! money -4000 each time
ajeossi[happy]: {감사합니다}!
~ Red, sticky, and much spicier than it looked. Your eyes water. Worth it.
-> v_food_end

=== scene v_food_r
ajeossi: {라면}? {사}{천}{오}{백} {원}{이에요}.
-> v_food_r_pay

=== scene v_food_r_pay
@number Pay him. | won
answer: 4500 -> v_food_r_ok
miss -> v_food_r_miss

=== scene v_food_r_miss
ajeossi[surprised]: {아니요}~ {사}{천}{오}{백} {원}!
(He writes it on a napkin: 4,500.)
-> v_food_r_pay

=== scene v_food_r_ok
! money -4500 each time
ajeossi[happy]: {감사합니다}!
~ The 라면 arrives still bubbling, with an egg cracked in at the last second.
-> v_food_end

=== scene v_food_b
ajeossi: {비빔밥}? {팔}{천} {원}{이에요}.
-> v_food_b_pay

=== scene v_food_b_pay
@number Pay him. | won
answer: 8000 -> v_food_b_ok
miss -> v_food_b_miss

=== scene v_food_b_miss
ajeossi[surprised]: {아니요}~ {팔}{천} {원}!
(He taps the menu on the wall.)
-> v_food_b_pay

=== scene v_food_b_ok
! money -8000 each time
ajeossi[happy]: {감사합니다}!
~ A whole rainbow in a stone bowl, still sizzling. You mix it the way he shows you.
-> v_food_end

=== scene v_food_end
~ You sit back, full.
* [Buy 김밥 for the whole table · 3,000원] -> v_treat if here:ajumma&here:staff&money>=3000
* [Buy 김밥 for 아주머니's table · 3,000원] -> v_treat_am if here:ajumma&!here:staff&money>=3000
* [Buy 김밥 for 박물관 직원's table · 3,000원] -> v_treat_st if here:staff&!here:ajumma&money>=3000
* [Thank him] -> v_food_bye

=== scene v_treat
! money -3000 each time; rel staff +1 each time; rel ajumma +1 each time
~ You set a plate of 김밥 down where the others are sitting.
ajumma[happy]: {같이} {먹어요}!
staff[happy]: {고마워요}!
(For a few minutes it's just chopsticks and talking over each other.)
-> v_food_bye

=== scene v_treat_am
! money -3000 each time; rel ajumma +1 each time
~ You set a plate of 김밥 down in front of 아주머니.
ajumma[happy]: 아이고! {같이} {먹어요}!
(She pulls out the chair next to her before you can say no.)
-> v_food_bye

=== scene v_treat_st
! money -3000 each time; rel staff +1 each time
~ You set a plate of 김밥 down in front of the museum woman.
staff[happy]: {고마워요}!
(She looks surprised, then pleased, then pushes half of it back toward you.)
-> v_food_bye

=== scene v_food_bye
ajeossi[happy]: {잘} {먹었어요}? {또} {오세요}!

# ------------------------------------------------------------ a snack at the market
=== scene v_snack
~ A little cart at the edge of the market. Something sweet is frying in a lot of oil.
sign: {호떡} {천} {원}
* {호떡} {하나} {주세요} -> v_snack_pay if money>=1000
* [Maybe later] -> v_snack_no

=== scene v_snack_no
~ You walk on. The smell follows you for a while.

=== scene v_snack_pay
@number Pay for it. | won
answer: 1000 -> v_snack_ok
miss -> v_snack_miss

=== scene v_snack_miss
~ The cart man taps his sign and smiles: 천 원.
-> v_snack_pay

=== scene v_snack_ok
! money -1000 each time
~ It's too hot to eat. You eat it anyway. Brown sugar and cinnamon, all over your fingers.

# ------------------------------------------------------------ village events
# They happen whether you are there or not. Missed ones reach you as gossip.

=== event haggle
when on:market
at morning sijang
scene ev_haggle
missed sujin ev_haggle_told

=== scene ev_haggle
~ A crowd has gathered at the vegetable stall. The restaurant 아저씨 is holding up one enormous cabbage.
ajeossi: {얼마예요}?
ajumma: {만} {원}!
ajeossi[surprised]: {만} {원}?! {비싸요}! {비싸요}!
(He clutches his chest as if he has been stabbed.)
ajumma[happy]: {아니요}, {아니요}! {싸요}! {싸요}!
(She pats the cabbage like a beloved pet.)
~ It goes on like this for some time. In the end he pays, and they both look delighted.

=== event bigfish
when day=6
at evening gang
scene ev_bigfish
missed jiho ev_bigfish_told

=== scene ev_bigfish
~ The reeds splash. 할아버지's rod bends almost in half.
haraboji[surprised]: 어! 어!
(He's on his feet, pulling, for the first time since you've known him.)
haraboji[happy]: {물고기}! {큰} {물고기}!
(It's huge. He holds it up to you, beaming, and then, very carefully, lets it go.)
! set g:bigfish
