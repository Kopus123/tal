# ===================================================================
#  탈 · WORLD  (shared by every chapter: no plot in here)
#
#  This file: the game's title, the chapter list, the cast, every word
#  and its picture and meaning, grammar notes, names, and the village map.
#  Each chapter has its own file (prologue.story, ch1.story ...) with
#  its places, scenes, clues and hints.
#
#  THE STORY FORMAT, COMPLETE.  The game reads it in js/core/parse.js.
#  Lines starting with # are notes.  After any change run:
#  python tools/check_story.py   and   python tools/playtest.py
#
#  ------------------------------------------------ words in any text
#    {word}                 a tappable word (needs an entry under === words)
#    {surface|entry}        shown as "surface", opens the notebook page "entry"
#    names and sounds       anything listed under === names is tappable by itself
#    \n                     a line break inside a line
#
#  ------------------------------------------------ this file (the world)
#    === meta               lang ko / title / village / blurb
#    === chapters           id | title | subtitle | file | continues
#                           ("continues" = plays on from the file above as one chapter)
#    === map                pin PLACE X% Y%
#    === cast               key | name | color | voice rate pitch | look
#    === words              word = picture [+past] [+future] [+not]      (pictures: js/icons.js)
#                           piece = (grammar)                            (explained under === grammar)
#    === grammar            piece | what it does          (shown when you tap the piece)
#    === tells              piece | what it gives away    (shown once you catch it on the case board)
#    === endings            ending | note                 (the notebook's Grammar tab)
#    === meanings           word | short English meaning  (Check my guess, and under case-board blanks)
#    === names              name | name or sound | what tapping it says
#    === pattern ID         title / note / need N / plain > changed    (the notebook's Patterns tab)
#
#  ------------------------------------------------ a chapter file
#    === meta               lang / start SCENE / start-place PLACE / end-title / end-text
#    === hints              if COND: text      (the first one that fits is the hint; a last plain line = fallback)
#    === deduce             ID [final] if COND | sentence with {blank} words | what it means once solved
#                           add  | needs A "what this proof is" + B/B2 "..."   for proof (evidence or statement
#                           ids; B/B2 = either one).  "final" ends the chapter when solved.
#    === evidence           id | label | picture | what it is | Korean written on it (optional)
#    === place NAME         name / sub / art KEY (js/art.js) / ambient / travel no
#                           first SCENE (plays the first time you arrive) / always SCENE (every time)
#                           desc [if COND:] text                 (the first one that fits is shown)
#                           spot "Label" X Y -> SCENE [if COND]  (also  => place NAME   and   => phone)
#                           glow WORD X Y [R] [H]                (the ring when someone says WORD)
#    === phone ID           name / avatar LETTER COLOR / on-open effects
#                           day[@COND] text / them[@COND] TIME text / me[@COND] TIME text / sys[@COND] text
#                           voice[@COND] TIME WHO text    (a voicemail: sound only)
#                           note[@COND] text              (@COND = only once COND is true)
#    === examine ID         art KEY / compare KEY / prompt text
#                           detail ID X Y R [key] | what you notice [! effects]    (key = must be found)
#    === scene NAME         a block of lines; each line below is one beat
#
#  ------------------------------------------------ lines in a scene
#    who: 한국어             someone speaks (who = a key from the cast; sign = something written)
#    who[worried]: ...      with a face: neutral happy worried surprised sad
#    who[audio]: ...        you only hear it; the text appears after you act  (who[sad audio] works too)
#    who@ja: ...            a line in another language (default: meta "lang")
#    (English)              what you SEE them do, attached to the line above
#    ~ English              narration
#    ! effect; effect       runs when the beat above starts (list below)
#    * 한국어 -> TARGET      a choice you say out loud        [if COND] [! effects] may follow
#    * [Action] -> TARGET   a choice you do
#    -> TARGET              where to go when the beat ends (otherwise: the next line)
#    <- TARGET              rewind: that was a wrong turn, back to the decision
#    @card 제목 | 부제        full-screen title card
#    @build prompt          sentence tiles:   tiles: a | b | c    answer: a | b -> TARGET    miss -> TARGET
#    @type prompt [| who]   typed answer:     answer: 한국어 -> TARGET (several allowed)     miss -> TARGET
#                           (who = the person who answers small talk like hello and thanks)
#    @number prompt | kind  number pad (kind: time won phone count):   answer: 9:00 -> TARGET   miss -> TARGET
#    @present prompt        show evidence:    show: ID -> TARGET     miss -> TARGET
#    @contradict prompt     pick two that clash:   pair: A + B -> TARGET (statement or evidence ids)   miss -> TARGET
#    @examine ID            a close-up from === examine ID
#    @camera [X Y |] prompt aim the camera at X Y and shoot       @photo text    look at the photo
#
#    TARGET   a scene NAME, NAME.2 for its 2nd beat, or  COND ? A : B
#
#  ------------------------------------------------ effects (after "!")     add  if COND  to any of them
#    set FLAG, FLAG         switch flags on (unset = off).  g:FLAG = a village flag, kept between chapters
#    place PLACE            move to a place           led TEXT     the bus sign
#    toast TEXT             a short message           learn ...    old, does nothing
#    give ID, ID            hand over evidence (with a message)     have ID, ID    the same, silently
#    statement ID           save the line above as a statement
#    mixup RIGHT / HEARD    record a mishearing in the notebook
#    money +500 | -200 | =1000         rel WHO +1         item +NAME | -NAME
#                           these three happen once per beat, however often you pass it;
#                           end with "each time" for a price paid on every visit: money -1500 each time
#
#  ------------------------------------------------ conditions (after "if", "@" on phone lines, "?" in targets)
#    FLAG   !FLAG   A&B     a flag is on / off / both           @PLACE   you are at that place
#    allSolved              every deduction on the board (except the final one) is solved
#    money>=500   day>=3    numbers compare with  >=  <=  >  <  =        (also rel:WHO>=2, has:NAME>=2)
#    time:morning           also afternoon, evening, night
#    g:FLAG                 a village flag            rel:WHO    friendship            has:NAME   you own it
#    flags the game sets by itself:  started, solved_ID (deduction), read_ID and vm_ID (phone thread read /
#    voicemail heard), st_ID (statement saved), ev_ID (evidence held), ex_EXAMINE_DETAIL (detail noticed).
#    The phone button appears once the story sets hasPhone.
#
#  New effects and conditions are added in js/core/rules.js (or a file like js/core/world.js);
#  the checker reads them from there.
# ===================================================================

=== meta
lang ko
title 탈
village 청솔마을
blurb A mystery in Korean. Nobody will translate for you. Tap any word to see a picture of it, and work out the rest from what people do.

=== chapters
# id       | title    | subtitle | file           | continues (blank = starts a new chapter)
prologue   | 1장      | 탈       | prologue.story
ch1        | 1장      | 탈       | ch1.story      | continues

=== map
# pin PLACE X% Y%  (places show on the map once you've been there)
pin madang 40 50
pin gongbang 50 44
pin golmok 34 60
pin sanqil 16 27
pin sikdang 51 70
pin jeong 61 74
pin museum 86 30
pin gang 79 55
pin jeol 9 14
pin sijang 84 79

=== cast
# key      | name          | color    | voice  rate  pitch | look (see js/people.js)
sujin      | 수진          | #3f8b77  | SunHi  +0%   +0Hz  | hair=bun hc=#2a1d18 top=#c7d3cf wear=cardigan
halmeoni   | 할머니        | #8a6a9a  | SunHi  -14%  -28Hz | hair=grandma hc=#d8d4ce top=#8a6a9a wear=hanbok extra=wrinkles skin=#e2bf9c
yuna       | 유나          | #c26a86  | SunHi  +8%   +25Hz | hair=long hc=#3a2418 top=#e9a3b4 wear=hanbok extra=flower
minsu      | 민수          | #4f6ea8  | InJoon +0%   +0Hz  | hair=short hc=#1f1a18 top=#9fb7d9 wear=hanbok
ajeossi    | 식당 아저씨   | #8a5a34  | InJoon -6%   -18Hz | hair=short hc=#6f6a66 top=#7d8a96 wear=apron extra=stubble skin=#dcb08a
staff      | 박물관 직원   | #6a6f7d  | SunHi  -3%   -12Hz | hair=long hc=#1f1a18 top=#2d3f66 wear=blazer extra=glasses
ajumma     | 시장 아주머니 | #b5653d  | SunHi  +4%   -6Hz  | hair=bun hc=#3a2a20 top=#d9822b wear=apron extra=wrinkles skin=#e0b98f
stranger   | ???           | #2a2a2a  | InJoon -10%  -14Hz
junho      | 준호          | #4f6ea8  | InJoon +6%   +12Hz
haraboji   | 할아버지      | #6b7a5a  | InJoon -12%  -26Hz | hair=short hc=#e4e0da top=#6b7a5a wear=plain extra=wrinkles,stubble skin=#d9b38e
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
9시 = clock
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
할아버지 = grandpa
학생 = student
괜찮아요 = okay
새 = new
가짜 = fake
진짜 = real
밤 = night
다리 = bridge
강 = river
몰라요 = dontknow
누구 = who
절 = temple
손 = hand
만들었어요 = make +past
뒤에 = behind
빨간 = red
물감 = paint
나무 = wood
얼마예요 = howmuch
천 원 = won
아주머니 = ajumma
아저씨 = ajeossi
불 = light
숨어요 = hide
알아요 = know
친구 = friend
먹었어요 = eat +past
안녕 = wave
남자 = man
집 = home
좋은 = good
물고기 = fish
전화 = call
편지 = letter
비밀 = secret
오세요 = come
감사합니다 = thanks
고맙습니다 = thanks
줘 = please
명함 = card
서울 = city
바꿨어요 = swap +past
장화 = boots
기차표 = ticket
마을 = village
옛날 = clock +past
나쁜 = good +not
사람 = youngman
받아요 = call
팔아요 = won
눈썹 = eyebrow
하나 = nat1
한 = nat1
둘 = nat2
두 = nat2
셋 = nat3
세 = nat3
넷 = nat4
다섯 = nat5
여섯 = nat6
일곱 = nat7
여덟 = nat8
아홉 = nat9
열 = nat10
열한 = nat11
열두 = nat12
공 = sino0
일 = sino1
이 = sino2
삼 = sino3
사 = sino4
오 = sino5
육 = sino6
칠 = sino7
팔 = sino8
구 = sino9
십 = sino10
백 = sino100
천 = sino1000
만 = sino10000
시 = clock
분 = minute
반 = half
몇 = howmany
원 = won
경찰 = police
혼자 = alone
가져와 = bring
와 = come
다음 = next
와요 = come
아들 = youngman
매일 = calendar
제 = me
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
하고 = (grammar)
을/를 = (grammar)
요 = (grammar)
는데요 = (grammar)
거든요 = (grammar)
낚시 = fish

=== grammar
# piece | what it does (shown when you tap it)
이에요 | "is / am / are". Goes at the very end: 학생이에요 = (I) am a student. After a word ending in a vowel it shrinks to 예요: 어디예요? = where is it?
아니에요 | "is not / am not". 왼쪽 아니에요 = it's not the left.
입니다 | A formal "is". Announcements and signs use it: 이번 정류장은 박물관입니다.
이/가 | Subject marker. Sticks to whoever or whatever is doing something or being described: 할머니가 없어요 = grandma isn't here. 이 after a consonant, 가 after a vowel.
은/는 | Topic marker, like "as for ___". Sticks to what the sentence is about, and often contrasts it with something else: 여기는 마당이에요. 은 after a consonant, 는 after a vowel.
에 | "at / in / to" a place, or "at" a time: 방에 없어요 = not in the room. 아침에 = in the morning.
에서 | "at" the place where something happens, or "from": 박물관에서 만나요 = let's meet at the museum.
도 | "also / too / either": 마당에도 없어요 = not in the courtyard either.
의 | Possessive, like 's: 할머니의 공방 = grandma's workshop.
으로 | "toward" or "by way of": 오른쪽으로 가요 = go to the right. After a vowel it's just 로.
하고 | "with" or "and" (casual): 친구하고 = with a friend. 누구하고? = with who?
을/를 | Object marker. Sticks to the thing being done to: 물감을 샀어요 = bought paint. 을 after a consonant, 를 after a vowel.
요 | The polite ending, stuck onto almost anything: 할머니요? = (do you mean) grandma? After a word ending in a consonant it's often 이요: 선생님이요?
는데요 | "...but" / "well...". A soft ending that trails off and leaves something unsaid: 아는데요... = I do know, but... After a noun it's 인데요: 진짜인데요 = it's real, but...
거든요 | "You see," / "because". Gives a reason, often one nobody asked for: 바쁘거든요 = I'm busy, you see.

=== tells
# piece | what it gives away (appears in the notebook once you catch it on the case board)
는데요 | Trailing off. The words say yes, the ending says "but...". When someone is sure, they don't need it.
거든요 | An excuse nobody asked for. People explain themselves like this when they're covering for something.

=== endings
# shown in the notebook's Grammar tab
-요 | The polite ending. Almost everything people say to you ends in 요. Without it, speech sounds casual.
-아요 / -어요 | Present tense, polite: 가요 = (I) go, 있어요 = there is.
-았어요 / -었어요 | Past tense: it already happened. 있어요 → 있었어요. The ochre ↺ badge on a picture means this.
-요? | The same ending, as a question. Just raise your voice at the end: 봤어요? = did you see?
-아 / -어 (no 요) | Casual speech. Between friends it's warm; from a stranger it's rude, even threatening. 가져와 = bring it. 와 = come.
-세요 | A polite request: 가져오세요 = please bring. 어서 오세요 = welcome (literally "come quickly").
주세요 | "Please give" or "please do (for me)": 물 주세요 = water, please. 사진 찍어 주세요 = please take a photo.
-지 마세요 | "Please don't": 찾지 마세요 = don't look for (me).
안 + verb | Makes it "not": 안 왔어요 = didn't come.
-입니다 | Formal version of 이에요, for announcements and signs.
시 | o'clock. Hours use the native Korean numbers, not the ones for counting money: 9시 = 아홉 시, not 구 시.

=== meanings
# word | short English meaning. Never shown in the story: only when you ask to check your own guess
# in the notebook, and as the hint under a blank on the case board.
할머니 | grandma
엄마 | mom
오빠 | big brother (what a girl calls an older guy she's close to)
저 | I, me (polite)
우리 | we, us
같이 | together
선생님 | teacher (respectful title for a master)
봤어요 | saw
네 | yes
아니요 | no
정말 | really
어디 | where
없어요 | isn't there, don't have
있어요 | is there, have
있었어요 | was there
방 | room
마당 | courtyard
이상해요 | it's strange
핸드폰 | phone
여기 | here
그 | that
이거 | this
찾아요 | look for, search
찾지 마세요 | don't look for (me)
공방 | workshop
탈 | mask
예뻐요 | pretty
고마워요 | thank you
잘 자요 | good night
축제 | festival
오늘 | today
어제 | yesterday
내일 | tomorrow
아침 | morning
9시 | 9 o'clock
저기요 | excuse me
안녕하세요 | hello
어서 오세요 | welcome
사진 | photo
찍어 주세요 | please take (a photo)
주세요 | please give me
배고파요 | I'm hungry
김치 | kimchi
식당 | restaurant
김밥 | gimbap
떡볶이 | tteokbokki
라면 | ramen
비빔밥 | bibimbap
물 | water
맛있어요 | delicious
매워요 | spicy
짜요 | salty
두 개 | two (of them)
샀어요 | bought
버스 | bus
버스 정류장 | bus stop
정류장 | stop (bus stop)
이번 | this (one), this time
탔어요 | got on, rode
내려요 | get off
옆에 | next to
오른쪽 | right
왼쪽 | left
가요 | go
빨리 | quickly, hurry
산 | mountain
시장 | market
영화관 | movie theater
박물관 | museum
지하철역 | subway station
만나요 | meet
안 | not
왔어요 | came
할아버지 | grandpa, old man
학생 | student
괜찮아요 | it's okay, are you okay
새 | new
가짜 | fake
진짜 | real
밤 | night
다리 | bridge
강 | river
몰라요 | I don't know
누구 | who
절 | temple
손 | hand
만들었어요 | made
뒤에 | behind
빨간 | red
물감 | paint
나무 | wood, tree
얼마예요 | how much is it
천 원 | 1,000 won
아주머니 | ma'am (middle-aged woman)
아저씨 | mister (middle-aged man)
불 | light, fire
숨어요 | hide
알아요 | know
친구 | friend
먹었어요 | ate
안녕 | hi, bye (casual)
남자 | man
집 | home, house
좋은 | good
물고기 | fish
전화 | phone call
편지 | letter
비밀 | secret
오세요 | please come
명함 | business card
서울 | Seoul
바꿨어요 | swapped, changed
장화 | rubber boots
기차표 | train ticket
마을 | village
옛날 | long ago
나쁜 | bad
사람 | person
받아요 | answer (a call), receive
팔아요 | sell
눈썹 | eyebrow
하나 | one (native)
한 | one (native, before a counter)
둘 | two (native)
두 | two (native, before a counter)
셋 | three (native)
세 | three (native, before a counter)
넷 | four (native)
다섯 | five (native)
여섯 | six (native)
일곱 | seven (native)
여덟 | eight (native)
아홉 | nine (native)
열 | ten (native)
열한 | eleven (native)
열두 | twelve (native)
공 | zero
일 | one (Sino)
이 | two (Sino)
삼 | three (Sino)
사 | four (Sino)
오 | five (Sino)
육 | six (Sino)
칠 | seven (Sino)
팔 | eight (Sino)
구 | nine (Sino)
십 | ten (Sino)
백 | hundred
천 | thousand
만 | ten thousand
시 | o'clock
분 | minute
반 | half
몇 | how many, what (number)
원 | won (money)
경찰 | police
혼자 | alone
가져와 | bring it (casual, rude)
와 | come (casual)
다음 | next
와요 | come, is coming
아들 | son
매일 | every day
제 | my (polite)
낚시 | fishing
줘 | give (casual, rude)
는데요 | the "...but" ending (trailing off)
감사합니다 | thank you (formal)
고맙습니다 | thank you (formal)
거든요 | the "you see" ending (an excuse)

=== names
# name | kind | what tapping it says (kind: name or sound). Keep these spoiler-free.
수진 | name | The woman who runs the guesthouse.
순자 | name | 할머니's first name.
김순자 | name | 할머니's full name. 김 is the family name.
준호 | name | Someone who texts 할머니's phone.
민수 | name | One of the couple visiting the village.
유나 | name | One of the couple visiting the village.
청솔마을 | name | The village. 마을 means village.
청솔 | name | The village's name. You see it on signs.
아이고 | sound | Oh dear! (a sigh when something is too much)
하하하 | sound | Ha ha ha.
하하 | sound | Ha ha.
어 | sound | Huh? / Oh? (surprised)
아 | sound | Ah! / Oh! (realizing something)
음 | sound | Hmm... (thinking)
와 | sound | Wow!

=== pattern past
title The ㅆ pattern
note People keep using these ㅆ versions whenever they talk about what already happened.
need 3
있어요 > 있었어요
사요 > 샀어요
타요 > 탔어요
와요 > 왔어요
보다 > 봤어요
만들어요 > 만들었어요
먹어요 > 먹었어요
