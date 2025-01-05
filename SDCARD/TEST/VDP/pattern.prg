def_test()
hires 0xf1:colour 32,15,1
pixmode 2
for y=0,191,1:for x=0,254,2
  point x+y\2,y
next:next
repeat
  for y=0,191,1
    line 0,y,255,y
  next
until 0
enddef
