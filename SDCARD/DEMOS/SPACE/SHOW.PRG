def_show()
 hires 0xf1
 colour 32,1,1
 a=1
 repeat
  vload 0,dec(a)
  a=a+1:if a>14:a=1:endif
  i=0:repeat:i=i+1:k=key(0)
  until (i>5000)|(k<>0)
 until k==13
enddef

