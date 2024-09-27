10 def_start()
20 dim a$[40]
25 dim b$[40]
26 datetime a$
30 repeat
40  datetime b$
42  if b$<>a$
43   println b$
44   a$=b$
45  endif
60 until 0
70 enddef

