# ===================================================================
#  탈 · LITTLE THINGS THAT HAPPEN AROUND THE VILLAGE   (format: js/core/villagers.js, "encounters")
#  Part of the village chapter (world.story: village.story + jobs.story + encounters.story).
#  Each day 2 or 3 of these are picked, each at one of its "at"s; walk in at that time and it plays.
#  Rewards here repeat, so they end in "each time" and stay small.
# ===================================================================

# ------------------------------------------------------------ a hiker who can't find the bus stop
=== encounter hiker_way
at morning golmok
at afternoon golmok
scene enc_hiker_way

=== scene enc_hiker_way
~ A man in a red jacket and enormous hiking boots is standing in the alley, turning his map around and around.
hiker: {저기요}! {버스 정류장}{은|은/는} {어디}{예요|이에요}?
* {오른쪽}{이에요} -> enc_hiker_right
* {왼쪽}{이에요} -> enc_hiker_left
* {몰라요} -> enc_hiker_dunno

=== scene enc_hiker_right
hiker[happy]: {오른쪽}! {감사합니다}!
(He bows, presses a 1,000원 note into your hand before you can say no, and clomps off to the right.)
! money +1000 each time

=== scene enc_hiker_left
hiker: {왼쪽}? {네}, {감사합니다}!
~ He heads off left, up the mountain path, very confidently. You realize a moment too late. That's the way up, not the way out.

=== scene enc_hiker_dunno
hiker: 아... {네}.
(He goes back to turning his map around.)

# ------------------------------------------------------------ the same hiker, at the timetable
=== encounter hiker_bus
at morning jeong
scene enc_hiker_bus

=== scene enc_hiker_bus
~ The man in the red jacket is at the bus stop, squinting at the timetable.
sign: {시장} {버스}: 9:00 · 13:00 · 17:00
~ It's a little after nine. The morning bus has just gone.
hiker: {저기요}... {다음} {버스}{는|은/는} {몇} {시}{예요|이에요}?
@number Tell him when the next one comes. | time
answer: 13:00 -> enc_hiker_bus_ok
answer: 1:00 -> enc_hiker_bus_ok
miss -> enc_hiker_bus_miss

=== scene enc_hiker_bus_miss
hiker: ...{네}?
(He looks from you to the timetable and back, then works it out himself.)
hiker: 아, {한} {시}! {감사합니다}.

=== scene enc_hiker_bus_ok
hiker[happy]: {한} {시}! {감사합니다}!
(He sits down on the bench to wait, and shares a tangerine with you while he does.)

# ------------------------------------------------------------ 지호 tests you
=== encounter jiho_quiz_cat
at afternoon golmok
at evening jeong
scene enc_jiho_cat

=== scene enc_jiho_cat
~ 지호 jumps out from behind a wall with a drawing held up in front of him: four legs, whiskers, a tail.
jiho: {이거} {뭐}{예요|이에요}? {뭐}{예요|이에요}?
* {고양이}{예요|이에요} -> enc_jiho_cat_ok
* {물고기}{예요|이에요} -> enc_jiho_cat_no
* {가방}{이에요} -> enc_jiho_cat_no

=== scene enc_jiho_cat_ok
jiho[happy]: {잘해}! {고양이}!
(He looks genuinely impressed. Then he runs off to find a harder one.)
! rel jiho +1 each time

=== scene enc_jiho_cat_no
jiho: {아니야}! {고양이}! {고양이}!
(He meows at you, to make sure.)

=== encounter jiho_quiz_bag
at afternoon golmok
at evening jeong
scene enc_jiho_bag

=== scene enc_jiho_bag
~ 지호 again, with a new drawing: a square thing with a handle.
jiho: {이거}{는|은/는}? {이거}{는|은/는}?
* {편지}{예요|이에요} -> enc_jiho_bag_no
* {가방}{이에요} -> enc_jiho_bag_ok
* {버스}{예요|이에요} -> enc_jiho_bag_no

=== scene enc_jiho_bag_ok
jiho[happy]: {맞아요}! ... {잘해}!
(He checks the back of the drawing, as if the answer might be written there. It is.)
! rel jiho +1 each time

=== scene enc_jiho_bag_no
jiho: {아니야}~ {가방}!
(He swings the drawing back and forth like a bag, very slowly, so you'll get it next time.)

# ------------------------------------------------------------ 할아버지's catch
=== encounter haraboji_count
at morning gang
at afternoon gang
scene enc_harabeoji_count

=== scene enc_harabeoji_count
~ 할아버지 waves you over to his bucket. It's full of fish, flipping and splashing.
(You count them: one, two, three... seven.)
haraboji[happy]: {물고기}! {몇} {마리}?
* {다섯} {마리} -> enc_harabeoji_no
* {일곱} {마리} -> enc_harabeoji_ok
* {아홉} {마리} -> enc_harabeoji_no

=== scene enc_harabeoji_ok
haraboji[happy]: {일곱} {마리}! {네}!
(He looks prouder than you've ever seen him. Then he tips them all back into the river, one at a time.)
! rel haraboji +1 each time

=== scene enc_harabeoji_no
haraboji: ...{아니요}. {하나}, {둘}, {셋}...
(He counts them out for you on his fingers, slowly, all the way to 일곱. Native numbers: for counting things.)
