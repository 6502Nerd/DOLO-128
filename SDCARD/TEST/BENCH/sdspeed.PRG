10 def_start()
20 hires 0x11
25 chdir "/data/image"
30 reset t
40 for i=0,19,1
50  vload 0,"snowman.vim"
60 next
70 t=elapsed(t)
80 mode 0
90 println t
100 cursor 0
110 enddef

