# ===================================================================
#  탈 · WORLD  (shared by every chapter: no plot in here)
#
#  This file: the game's title, the chapter list, the cast, every word
#  and its picture, grammar patterns, and the village map.
#  Each chapter has its own file (prologue.story, ch1.story ...) with
#  its places, scenes, clues and hints.
#
#  Chapter file quick reference
#    === meta              start SCENE / start-place PLACE / end-title / end-text
#    === place NAME        name, sub, art, ambient, first, always, travel no,
#                          desc [if COND:] text, spot "Label" X Y -> SCENE | => place NAME | => phone,
#                          glow WORD X Y R
#    === scene NAME        a block of lines; each line is one beat
#    who: 한국어            someone speaks (who = a key from the cast)
#    who[worried]: 한국어   ...with a face: neutral happy worried surprised sad
#    @card 제목 | 부제       full-screen title card (chapter openings)
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
#    === case              ID ANSWER [final] if COND | question | why   (final ends the chapter)
#    === hints / === phone NAME
# ===================================================================

=== meta
title 탈
village 청솔마을
blurb A mystery in Korean. Nobody will translate for you. Tap any word to see a picture of it, and work out the rest from what people do.

=== chapters
# id       | title    | subtitle | file (blank = coming soon)
prologue   | 프롤로그 | 탈       | prologue.story
ch1        | 1장      | ?        |

=== map
# pin PLACE X% Y%  (places show on the map once you've been there)
pin madang 40 50
pin gongbang 50 44
pin golmok 34 60
pin sanqil 16 27
pin sikdang 51 70
pin jeong 61 74
pin museum 86 30

=== cast
# key      | name          | color    | voice  rate  pitch | look (see js/people.js)
sujin      | 수진          | #3f8b77  | SunHi  +0%   +0Hz  | hair=bun hc=#2a1d18 top=#c7d3cf wear=cardigan
halmeoni   | 할머니        | #8a6a9a  | SunHi  -14%  -28Hz | hair=grandma hc=#d8d4ce top=#8a6a9a wear=hanbok extra=wrinkles skin=#e2bf9c
yuna       | 유나          | #c26a86  | SunHi  +8%   +25Hz | hair=long hc=#3a2418 top=#e9a3b4 wear=hanbok extra=flower
minsu      | 민수          | #4f6ea8  | InJoon +0%   +0Hz  | hair=short hc=#1f1a18 top=#9fb7d9 wear=hanbok
ajeossi    | 식당 아저씨   | #8a5a34  | InJoon -6%   -18Hz | hair=short hc=#6f6a66 top=#7d8a96 wear=apron extra=stubble skin=#dcb08a
staff      | 박물관 직원   | #6a6f7d  | SunHi  -3%   -12Hz | hair=long hc=#1f1a18 top=#2d3f66 wear=blazer extra=glasses
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

=== pattern past
title The ㅆ pattern
note People keep using these ㅆ versions whenever they talk about what already happened.
need 3
있어요 > 있었어요
사요 > 샀어요
타요 > 탔어요
와요 > 왔어요
보다 > 봤어요
