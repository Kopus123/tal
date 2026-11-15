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
spot "Right path" 86 76 => place sikdang
spot "Front gate" 50 92 => place madang
glow 오른쪽 86 76 10
glow 왼쪽 14 76 10

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
desc if time:night: The restaurant is dark. Closed for the night.
desc The restaurant. It smells of sesame oil.
spot "Bus stop" 85 40 => place jeong
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
spot "Path behind the bus stop" 40 62 => place gang
spot "Back to the restaurant" 12 88 => place sikdang
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
~ Talk to whoever you find. The first hello of the day counts, and people open up as they get to know you.
