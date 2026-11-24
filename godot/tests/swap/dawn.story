=== meta
start w_open
start-place dock
end-title 끝
end-text The end.

=== hints
Look around.

=== place dock
name 부두
sub The dock
art jeong
desc Morning.
spot "Boat" 30 60 -> w_boat

=== scene w_open
nari: {배}...
(A boat is coming in.)

=== scene w_boat
nari: {가요}.
(You get on.)
! finish chapter
