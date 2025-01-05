100 def_stars(max, iterations)
110 hires 0xe1:colour 32,0,0
120 t=rnd(1234)
130 dim starX[max],starY[max],starZ[max],star2X[max],star2Y[max]
140 w=256:h=192
150 wh=w/2:hh=h/2
160 scale=50
170 for i=1,max,1
180  _generateStar(i)
190  star2X[i]=wh:star2Y[i]=1
200 next
210 for loop=1,iterations,1
220  for i=1,max,1
240   ox=star2X[i]:oy=h-star2Y[i]
250   star2X[i]=starX[i]*scale/starZ[i]+wh
260   star2Y[i]=starY[i]*scale/starZ[i]+hh
270   if(star2X[i]>0)&(star2X[i]<w)&(star2Y[i]>0)&(star2Y[i]<h)
275    pixmode 0:point ox,oy
280    pixmode 1
290    point star2X[i],h-star2Y[i]
300   else
305    pixmode 0:point ox,oy
310    starZ[i]=0:star2X[i]=wh:star2Y[i]=1
320   endif
330   starZ[i]=starZ[i]-10
340   if starZ[i]<=0
350    _generateStar(i)
360   endif
370  next
380 next
390 enddef
400 ;
410 def_generateStar(i)
420  m=i&3
430  starX[i]=rnd(0)\wh+1
440  starY[i]=rnd(0)\hh+1
450  if(m==1)|(m==2)
460   starY[i]=0-starY[i]
470  endif
480  if(m==2)|(m==3)
490   starX[i]=0-starX[i]
500  endif
550  starZ[i]=200+rnd(0)\56
560 enddef

