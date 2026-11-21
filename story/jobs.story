# ===================================================================
#  탈 · JOBS FROM THE NOTICE BOARD   (format: js/core/jobs.js; story format: top of world.story)
#  Small investigations for free days. Part of the village chapter (world.story: village.story + jobs.story).
#  SPOILERS: the answers are below.
#  Everything a job sets (flags, evidence, statements) starts with its id and "_", so a retry starts clean.
# ===================================================================

=== evidence
bag_note | {가방} · {메모} | letter | The note from the board: a red bag, left at the restaurant last night. | {빨간} {가방}{을|을/를} {찾아요}.
bag_bag | {빨간} {가방} | bag | A small red bag with a museum keyring. |
key_note | {열쇠} · {메모} | letter | 수진's note: the workshop key is missing. | {공방} {열쇠}{가|이/가} {없어요}!
letter_letter | {편지} | letter | A letter with no name on it. Found on the floor of the market. | {내일} {저녁}{에} {강}{에서} {같이} {낚시} {해}! {큰} {물고기} {잡았어}!
cash_note | {돈} · {메모} | won | 아주머니's note: her cash box is short. | {돈}{이|이/가} {없어요}!

# ------------------------------------------------------------ 1. the red bag (easy)
=== job bag
title 잃어버린 가방 | The lost bag
level easy
client staff
pay 5000
thanks 2
note Someone left a red bag at the restaurant last night, and now it's gone.
start bag_start
ask ajeossi bag_ajeossi
ask jiho bag_jiho
ask staff bag_staff

=== scene bag_start
~ You unpin a neat little note. There's a museum stamp in the corner.
sign: {빨간} {가방}{을|을/를} {찾아요}. {어제} {저녁}{에} {식당}{에} {있었어요}. ― {박물관}
! give bag_note
~ The restaurant seems like the place to start asking.

=== scene bag_ajeossi
ajeossi: {빨간} {가방}? 아, {네}! {봤어요}.
(He points at the corner table, by the window.)
ajeossi: {어제} {저녁}{에}... {아이}{가|이/가} {가져갔어요}.
! statement bag_kid
(He shrugs. He thought the kid's mum had sent them.)

=== scene bag_jiho
jiho: {가방}? {몰라}! {나} {안} {봤어}!
! statement bag_lie
(He says it very fast, and doesn't look at you.)
* [Point out what doesn't add up] -> bag_press if st_bag_kid
* [Leave it] -> bag_leave

=== scene bag_leave
jiho: {안녕}!
(He's gone before you can say anything else.)

=== scene bag_press
@contradict Something he said doesn't fit. What does it clash with?
pair: bag_lie + bag_kid -> bag_caught
miss -> bag_wrong

=== scene bag_wrong
jiho[surprised]: {뭐}? {아니야}!
(He runs off, offended. Nobody's going to tell you anything today.)
! job fail

=== scene bag_caught
jiho[sad]: ...{미안해}.
(He pulls the red bag out from under his jacket.)
jiho: {빨간} {가방}... {예뻐}...
(He wanted to see what it felt like to carry something that nice. That's all.)
! give bag_bag
~ Now to give it back to the person who lost it.

=== scene bag_staff
staff[worried]: {제} {가방}...?
-> ev_bag_bag ? bag_return : bag_wait

=== scene bag_wait
staff[worried]: {아직} {없어요}...
(She's trying not to look at the empty hook by the door.)

=== scene bag_return
@present Show her what you found.
show: bag_bag -> bag_done
miss -> bag_notit

=== scene bag_notit
staff: ...{아니요}. {그거} {아니에요}.

=== scene bag_done
staff[happy]: 아! {제} {가방}! {고마워요}! {정말} {고마워요}!
(She hugs it. Then, embarrassed, she straightens up and bows.)
! job done

# ------------------------------------------------------------ 2. the workshop key (easy)
=== job key
title 사라진 열쇠 | The missing key
level easy
client sujin
pay 4000
thanks 3
note 수진 can't find the workshop key. Retrace her steps.
start key_start
ask sujin key_sujin
ask ajumma key_ajumma
ask haraboji key_haraboji
ask ajeossi key_ajeossi

=== scene key_start
~ The note is in 수진's handwriting, and it looks like it was written in a hurry.
sign: {공방} {열쇠}{가|이/가} {없어요}! ― 수진
! give key_note
~ She'll be around the house somewhere.

=== scene key_sujin
sujin[worried]: {열쇠}... {없어요}. {아침}{에} {시장}{에} {갔어요}. {낮}{에} {식당}{에} {갔어요}.
! statement key_said
sujin: {어디} {있어요}?
* {시장}{에} {있어요} -> key_wrong if key_asked
* {식당}{에} {있어요} -> key_wrong if key_asked
* {강}{에} {있어요} -> key_right if key_asked
* [I don't know yet] -> key_wait

=== scene key_wait
sujin: {네}... {고마워요}.
(She goes back to turning out her pockets, for the fourth time.)

=== scene key_wrong
~ You both go and look. You search everywhere. No key.
sujin[sad]: {없어요}...
(She's too tired to keep looking today.)
! job fail

=== scene key_ajumma
! set key_asked
ajumma: 수진? {오늘}{은|은/는} {안} {왔어요}. {어제} {왔어요}!
! statement key_market

=== scene key_ajeossi
! set key_asked
ajeossi: 수진? {네}, {낮}{에} {김밥} {먹었어요}. {열쇠}? {몰라요}.
! statement key_lunch

=== scene key_haraboji
! set key_asked
haraboji: {아침}{에}... 수진{이|이/가} {왔어요}. {강}{에서} {물고기} {봤어요}.
! statement key_river
(He nods at the flat stones where people sit to watch the water.)

=== scene key_right
sujin[surprised]: {강}? ... 아! {맞아요}! {시장}{은|은/는}... {어제}{예요|이에요}!
(She went to the river this morning, not the market. She'd mixed up the days.)
~ You walk down together. Between two flat stones, glinting in the water: the key.
sujin[happy]: {고마워요}!!
! job done

# ------------------------------------------------------------ 3. the gimbap thief (easy)
=== job gimbap
title 김밥 도둑 | The gimbap thief
level easy
client ajeossi
pay 6000
thanks 2
note Every evening, a roll of gimbap goes missing from the restaurant. Who's taking it?
start gimbap_start
ask ajeossi gimbap_ajeossi
ask jiho gimbap_jiho
ask haraboji gimbap_haraboji
ask ajumma gimbap_ajumma

=== scene gimbap_start
~ This note is greasy and written in big angry letters.
sign: {김밥} {도둑}! {매일} {저녁}! ― {식당}
~ Talk to the restaurant 아저씨. Then ask around.

=== scene gimbap_ajeossi
ajeossi: {매일} {저녁}{에} {김밥}{이|이/가} {없어요}!
(He slaps the counter by the back door.)
ajeossi: {누구}{예요|이에요}?
* 지호{예요|이에요} -> gimbap_wrong if gimbap_asked
* 수진{이에요} -> gimbap_wrong if gimbap_asked
* {고양이}{예요|이에요} -> gimbap_right if gimbap_asked
* [I don't know yet] -> gimbap_wait

=== scene gimbap_wait
ajeossi: {빨리} {찾아요}!

=== scene gimbap_wrong
ajeossi[surprised]: {정말}?
(He marches off to give them a piece of his mind. It doesn't go well. Nobody took anything.)
ajeossi[sad]: ...{아니에요}.
! job fail

=== scene gimbap_jiho
! set gimbap_asked
jiho: {김밥}? {나} {안} {먹었어}! {나} {김밥} {싫어}!
! statement gimbap_jiho
(He pulls a face. That, at least, sounds true.)

=== scene gimbap_haraboji
! set gimbap_asked
haraboji: {저녁}{에}... {고양이}{가|이/가} {와요}. {물고기}{를|을/를} {좋아해요}.
! statement gimbap_cat
(He looks at his bucket, then very hard at the reeds.)

=== scene gimbap_ajumma
! set gimbap_asked
ajumma: {고양이}? {네}! {매일} {저녁}, {식당} {뒤에} {있어요}.
! statement gimbap_back

=== scene gimbap_right
ajeossi[surprised]: {고양이}?!
~ You wait by the back door. Right on time, a skinny orange cat slips in, takes a roll of 김밥 in its teeth and strolls out.
ajeossi[happy]: 하하하!
(He laughs until he has to sit down. Then he puts a little dish out by the door.)
! job done

# ------------------------------------------------------------ 4. a letter with no name (medium)
=== job letter
title 이상한 편지 | A letter with no name
level medium
client ajumma
pay 7000
thanks 2
note A letter was found on the market floor. No name on it. Work out who it's meant for, and give it to them.
start letter_start
ask ajumma letter_ajumma
ask sujin letter_sujin
ask ajeossi letter_ajeossi
ask haraboji letter_haraboji
ask jiho letter_give_jiho
ask staff letter_give_staff

=== scene letter_start
~ The note on the board says: found at the market, ask 아주머니. Next to it, she's pinned a copy of the letter.
sign: {내일} {저녁}{에} {강}{에서} {같이} {낚시} {해}! {큰} {물고기} {잡았어}!
! give letter_letter
~ No name, no signature. Just that.

=== scene letter_ajumma
ajumma: {편지}? {시장}{에} {있었어요}. {누구} {편지}{예요|이에요}?
(She's itching to know. She also can't read it without her glasses.)

=== scene letter_sujin
! set letter_asked
sujin: {해}... {잡았어}... {이거}{는|은/는} {친구}{한테}... {아이}{한테}...
(She taps the endings. Casual Korean: you write like that to a friend, or a grown-up writes like that to a kid. Not to the restaurant 아저씨.)
! statement letter_casual

=== scene letter_ajeossi
! set letter_asked
ajeossi: {낚시}? {할아버지}{는|은/는} {매일} {저녁} {낚시} {해요}. 지호{하고} {같이}!
! statement letter_fishing

=== scene letter_haraboji
! set letter_asked
haraboji[surprised]: ...!
(He sees the letter, goes red to the ears, and becomes extremely interested in his fishing line.)
haraboji: {몰라요}. {몰라요}.
~ He knows exactly what it is. He's just not going to say.

=== scene letter_give_jiho
~ Give 지호 the letter? (Ask around first, so you're sure.)
* [Give it to him] -> letter_right if letter_asked
* [Not yet] -> letter_notyet

=== scene letter_give_staff
~ Give her the letter? (Ask around first, so you're sure.)
* [Give it to her] -> letter_wrong if letter_asked
* [Not yet] -> letter_notyet

=== scene letter_notyet
~ You put the letter back in your pocket.

=== scene letter_wrong
staff: ...{낚시}? {저}{는|은/는} {낚시} {안} {해요}...
(She hands it back, puzzled, and asks around about it herself. By evening the whole village has an opinion, and the letter is nowhere to be seen.)
! job fail

=== scene letter_right
jiho[surprised]: {나}? ...{큰} {물고기}?!
(He reads it twice, then whoops so loudly a bird flies off the roof.)
jiho[happy]: {할아버지}! {내일}! {낚시}!
~ He's off at a run towards the river. You go and tell 아주머니 where her mystery letter ended up.
! job done

# ------------------------------------------------------------ 5. the cash box (medium)
=== job cash
title 돈이 없어요 | The short cash box
level medium
client ajumma
pay 8000
thanks 3
note 아주머니's cash box is short at the end of the day. Work out how much is missing, and who still owes her.
start cash_start
ask ajumma cash_ajumma
ask ajeossi cash_ajeossi
ask sujin cash_sujin
ask staff cash_staff

=== scene cash_start
~ 아주머니's note, underlined three times.
sign: {돈}{이|이/가} {없어요}! ― {시장}
! give cash_note
~ Go and ask her at the market. You'll need to count.

=== scene cash_ajumma
ajumma: {배추}{는|은/는} {하나}{에} {삼}{천} {원}{이에요}.
ajumma: {오늘}{은|은/는} {배추} {세} {개} {팔았어요}.
! statement cash_sold
ajumma[worried]: {그런데} {돈}{은|은/는}... {육}{천} {원}...
! statement cash_box
* [Tell her how much is missing] -> cash_count if st_cash_sold
* [Go and ask the customers first] -> cash_later

=== scene cash_later
ajumma: {네}! {빨리}{요}!

=== scene cash_count
@number How much is missing from the box? | won
answer: 3000 -> cash_who
miss -> cash_badsum

=== scene cash_badsum
ajumma[surprised]: {네}?
(She counts it out on her fingers in front of you, twice, and gets a different number from yours. She gives up on you for today.)
! job fail

=== scene cash_who
ajumma: {네}! {삼}{천} {원}! {누구}{예요|이에요}?
* {아저씨}{예요|이에요} -> cash_wrong if cash_asked
* 수진{이에요} -> cash_right if cash_asked
* {박물관} {직원}{이에요} -> cash_wrong if cash_asked
* [I'm not sure yet] -> cash_later

=== scene cash_wrong
ajumma[surprised]: {정말}?
(She goes to ask, very loudly. They paid. Everyone is offended, including her.)
! job fail

=== scene cash_ajeossi
! set cash_asked
ajeossi: {배추}? {네}, {두} {개} {샀어요}. {육}{천} {원} {줬어요}.
! statement cash_ajeossi

=== scene cash_sujin
! set cash_asked
sujin: {배추}? {네}, {하나} {샀어요}! {돈}{은|은/는}... 어...
(Her face goes slowly pink.)
sujin: {내일}... {내일} {줘요}!
! statement cash_sujin

=== scene cash_staff
! set cash_asked
staff: {배추}{요}? {저}{는|은/는} {배추} {안} {샀어요}.
! statement cash_staff

=== scene cash_right
ajumma[happy]: 수진{이|이/가}? 하하하!
~ 수진 comes running down to the market with 3,000원 in her hand, apologizing all the way. 아주머니 gives her an extra cabbage for her trouble.
! job done
