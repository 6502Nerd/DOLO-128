 ;TO START TYPE
 ;_start()
 ;
 ;** PLOT SHAPE S,R @ X,Y **
 ;** NOT SPRITES **
 def_plotShape(x,y,s,r)
   local x1,y1,x2,y2,x3,y3,x4,y4,p
   p=shapeP[s]
   x1=x+shapeX1[s,r]:y1=y+shapeY1[s,r]
   x2=x+shapeX2[s,r]:y2=y+shapeY2[s,r]
   x3=x+shapeX3[s,r]:y3=y+shapeY3[s,r]
   x4=x+shapeX4[s,r]:y4=y+shapeY4[s,r]
   plot x1,y1,p
   plot x2,y2,p
   plot x3,y3,p
   plot x4,y4,p
 enddef
 ;
 def_eraseShape(x,y,s,r)
   local x1,y1,x2,y2,x3,y3,x4,y4,p
   p=32
   x1=x+shapeX1[s,r]:y1=y+shapeY1[s,r]
   x2=x+shapeX2[s,r]:y2=y+shapeY2[s,r]
   x3=x+shapeX3[s,r]:y3=y+shapeY3[s,r]
   x4=x+shapeX4[s,r]:y4=y+shapeY4[s,r]
   plot x1,y1,p
   plot x2,y2,p
   plot x3,y3,p
   plot x4,y4,p
 enddef
 ;
 ;** SHOW NEXT SHAPE **
 def_showNext(sns)
   local p
   p=shapeP[sns]
   plot 1,3,"    ":plot 1,4,"    "
   plot 1+mapX1[sns,1], 3+mapY1[sns,1],p
   plot 1+mapX2[sns,1], 3+mapY2[sns,1],p
   plot 1+mapX3[sns,1], 3+mapY3[sns,1],p
   plot 1+mapX4[sns,1], 3+mapY4[sns,1],p
 enddef
 ;
 ;** STAMP SHAMP IN MAP **
 def_stampShape(x,y,s,r)
   local x1,y1,x2,y2,x3,y3,x4,y4,p
   x1=x+mapX1[s,r]:y1=y+mapY1[s,r]
   x2=x+mapX2[s,r]:y2=y+mapY2[s,r]
   x3=x+mapX3[s,r]:y3=y+mapY3[s,r]
   x4=x+mapX4[s,r]:y4=y+mapY4[s,r]
   p=shapeP[s]
   tempLine$=left(gameMap$[y1],x1-1)+chr(p)+right(gameMap$[y1],sizeXp2-x1):gameMap$[y1]=tempLine$
   tempLine$=left(gameMap$[y2],x2-1)+chr(p)+right(gameMap$[y2],sizeXp2-x2):gameMap$[y2]=tempLine$
   tempLine$=left(gameMap$[y3],x3-1)+chr(p)+right(gameMap$[y3],sizeXp2-x3):gameMap$[y3]=tempLine$
   tempLine$=left(gameMap$[y4],x4-1)+chr(p)+right(gameMap$[y4],sizeXp2-x4):gameMap$[y4]=tempLine$
   lineCount[y1]=lineCount[y1]+1
   lineCount[y2]=lineCount[y2]+1
   lineCount[y3]=lineCount[y3]+1
   lineCount[y4]=lineCount[y4]+1
   plot gameXOffm2+x1,gameYOffm2+y1,p
   plot gameXOffm2+x2,gameYOffm2+y2,p
   plot gameXOffm2+x3,gameYOffm2+y3,p
   plot gameXOffm2+x4,gameYOffm2+y4,p
   spritepos 0,0,0xd0
 enddef
 ;
 ;** CHECK SHAPE IN MAP **
 def_checkShape(x,y,s,r)
   if mid(gameMap$[y+mapY1[s,r]],x+mapX1[s,r],1)<>" ":return 0:endif
   if mid(gameMap$[y+mapY2[s,r]],x+mapX2[s,r],1)<>" ":return 0:endif
   if mid(gameMap$[y+mapY3[s,r]],x+mapX3[s,r],1)<>" ":return 0:endif
   if mid(gameMap$[y+mapY4[s,r]],x+mapX4[s,r],1)<>" ":return 0:endif
   return -1
 enddef
 ;** DRAW TETRIS GAME AREA **
 def_drawGamePanel(x,y)
   local q
   for q=2,sizeY+1,1
     plot x,y+q-2,gameMap$[q]
   next
 next
 enddef
 ;
 ;** DRAW BORDER **
 def_border(bx,by,bw,bh)
 local i
 for i=by,by+bh-1,1
  plot bx,i,132:plot bx+bw-1,i,132
 next
 plot bx,by+bh-1,130:plot bx+bw-1,by+bh-1,131
 for i=bx+1,bx+bw-2,1
  plot i,by+bh-1,132
 next
 enddef
 ;
 ;** DRAW TOP SCORES **
 def_drawTopScores()
 local i,s,y
 for i=1,7,1
  s=topScore[i]:y=i*2+2
  plot 24,y,topName$[i]
  if s<1000:printat 28,y,s:else:printat 27,y,s:endif
 next
 enddef
 ;
 ;** DRAW STATUS LINE **
 def_drawStatusLine()
   printat 0,0,"SCORE:",score
   printat 12,0,"LINES:",lines
   printat 23,0,"LEVEL:",level
 enddef
 ;** DRAW GAME SCREEN **
 def_drawScreen()
   _drawStatusLine()
   _border(gameXOff-1,gameYOff,sizeX+2,sizeY+1)
   plot 1,2,"NEXT":plot 0,2,128:plot 5,2,129
   _border(0,3,6,3)
   plot 2,7,"STATS":plot 0,7,128:plot 1,7,132:plot 7,7,132:plot 8,7,129
   _border(0,8,9,15)
   plot 25,2,"TOP 7":plot 23,2,128:plot 31,2,129:plot 24,2,132:plot 30,2,132
   _border(23,3,9,16)
   _drawTopScores()
 enddef
 ;
 ;** ANIMATE SHAPE **
 def_animateShape(ss)
   local spX,spY,ss
   spX=(0+(1*8))*2:spY=(255+(3*8))*2
   _plotShape(spX/2,spY/2,ss,1)
   plot 1,3,"    ":plot 1,4,"    "
   sound 0,20,0:sound 1,100,0:play 1,1,4,1000
   repeat
     spX=spX+12:spY=spY-1
     _plotShape(spX/2,spY/2,ss,1):_scrollMessage()
   until spX==208
 enddef
 ;
 ;** NEW SHAPE AT TOP **
 def_newShape()
   ;_animateShape(ns)
   sx=5:sy=2:ss=ns:sr=1:ns=rnd(0)\7+1
   _showNext(ns)
   _plotShape(sx+sprXOff, sy+sprYOff, ss, sr)
   stat[ss]=stat[ss]+1
   plot ss, 21-((stat[ss]-1)/8),128+(8*ss)+((stat[ss]-1)\8)
 enddef
 ;
 ;** CLEAR GAME MAP **
 def_initGameMap()
   local p,q,c
   for q=2,sizeY+1,1
     gameMap$[q]=blankLine$
     lineCount[q]=0
   next
   gameMap$[1]=fillLine$:gameMap$[sizeY+2]=fillLine$
 enddef
 ;
 ;** SCROLL MESSAGE **
 def_scrollMessage()
   if elapsed(messageTimer)>8
     reset messageTimer
     plot 1,23,mid(message$,messageIdx,30)
     messageIdx=messageIdx+1
     if messageIdx>((len(message$)-30)):messageIdx=1:endif
   endif
 enddef
 ;
 ;** PLAY MUSIC **
 def_playTune()
   if elapsed(musicTimer)>noteDelay
     music 1,3,note[noteIndex],0:play 1,0,1,2000
     reset musicTimer:noteDelay=delay[noteIndex]*3
     noteIndex=noteIndex+1:if note[noteIndex]==999:noteIndex=1:endif
   endif
 enddef
 ;
 ;**ONE GO OF THE GAME**
 def_startGame()
   dead=0:noteDelay=0:noteIndex=1:reset musicTimer
   repeat
     _newShape()
     if _checkShape(sx,sy,ss,sr)==0
       dead=1:spritepos 0,0,0xd0
     else
       stop=0
       reset dropTimer:reset moveTimer
       repeat
         _scrollMessage():if musicFlag:_playTune():endif
         if elapsed(moveTimer)>moveSpeed
           reset moveTimer
           or=sr:ox=sx:oy=sy
           if stick(64) & _checkShape(sx-1,sy,ss,sr):sx=sx-1:endif
           if stick(32) & _checkShape(sx+1,sy,ss,sr):sx=sx+1:endif
           if stick(8) & _checkShape(sx,sy+1,ss,sr):reset dropTimer:sy=sy+1:endif
           if stick(128)
             if fire==0
               or=sr:sr=(sr\4)+1:fire=1
               if _checkShape(sx,sy,ss,sr)==0:sr=or:endif
             endif
           else
             fire=0
           endif
           if (ox<>sx)|(oy<>sy)|(or<>sr)
             _eraseShape(ox+sprXOff, oy+sprYOff, ss, or)
             _plotShape(sx+sprXOff, sy+sprYOff, ss, sr)
           endif
         endif
         if elapsed(dropTimer)>dropSpeed
           reset dropTimer
           if _checkShape(sx,sy+1,ss,sr)
             _eraseShape(sx+sprXOff, sy+sprYOff, ss, sr)
             sy=sy+1:_plotShape(sx+sprXOff, sy+sprYOff, ss, sr)
           else:_stampShape(sx,sy,ss,sr):stop=1:_checkLineFull():endif
         endif
       until stop
     endif
   until dead
  _checkTop()
 enddef
 ;
 ;** START A GAME **
 def_start()
   _init():cls
   repeat
     _drawScreen()
     plot gameXOff+0,gameYOff,"PRESS FIRE"
     plot gameXOff+0,gameYOff+1," TO START "
     messageIdx=1:reset messageTimer
     repeat
       _scrollMessage()
       if musicFlag
         plot gameXOff+0,gameYOff+2,"MUSIC: ON "
       else
         plot gameXOff+0,gameYOff+2,"MUSIC: OFF"
       endif
       if stick(64):musicFlag=0:endif
       if stick(32):musicFlag=1:endif
     until stick(128)
     score=0:level=1:dropSpeed=60:moveSpeed=4:lines=0
     plot 6,0,"    ":plot 18,0,"   ":plot 29,0,"   "
     _drawStatusLine()
     ; Clear Stats Line
     for i=8,21,1:plot 1,i,"       ":next
     _initStats():_initGameMap()
     ; Clear Game Area
     for i=gameYOff,gameYOff+sizeY-1,1:plot gameXOff,i,"          ":next
     ns=rnd(0)\7+1
     _startGame()
   until 0
 enddef
 ;
 ;** INIT STATS TABLE **
 def_initStats()
   for i=1,7,1
     stat[i]=0
   next
 enddef
 ;
 ;** KILL A LINE **
 def_killLine(l)
   local l,x,c
   sound 0,20,0:sound 1,300,0:play 1,1,1,1000
   while l>2
     lineCount[l]=lineCount[l-1]
     gameMap$[l]=gameMap$[l-1]
     plot gameXOffm2+1,l+gameYOffm2,gameMap$[l-1]
     l=l-1
   wend
   lineCount[2]=0
   gameMap$[2]=blankLine$:plot gameXOffm2+1,2,gameMap$[2]
 enddef
 ;
 ;** CHECK LINE FULL **
 def_checkLineFull()
   local x,y,count,bonus
   y=sizeY+1:bonus=1
   while y>1
     if lineCount[y]==sizeX
       _killLine(y):score=score+((sizeYp2-y)*bonus):bonus=bonus+1:lines=lines+1
       if (lines\10)==0:level=level+1
         if dropSpeed>0:dropSpeed=dropSpeed*80/100:endif
       endif
       _drawStatusLine()
     else
       y=y-1
     endif
   wend
 enddef
 ;
 ;** CHECK TOP TABLE **
 def_checkTop()
   i=1
   while i<8 & score<topScore[i]
     i=i+1
   wend
   ; if in the top 7 then make space
   if i<=7
     _topScoreSound()
     j=7
     while j>i
       topScore[j]=topScore[j-1]
       topName$[j]=topName$[j-1]
       j=j-1
     wend
     topScore[i]=score
     topName$[i]="   "
     _drawTopScores()
     _enterTopScore(i)
   endif
 enddef
 ;
 ; Top score sound effect
 def_topScoreSound()
   local i
   for i=50,300,2:sound 1,350-i,15:next
   for i=50,300,2:sound 1,i,15:next
   sound 1,0,0
 enddef
 ;
 ; Enter initials in to top score table
 def_enterTopScore(i)
   local i,y,pos,char
   pos=1:char=32:y=i*2+2:reset timer
   tempName[1]=32:tempName[2]=32:tempName[3]=32
   repeat
     _scrollMessage()
     if elapsed(timer) & 8
       plot 23,20,"  ENTER  ":plot 23,21,"INITIALS!"
     else
       plot 23,20,"         ":plot 23,21,"         "
     endif
     if elapsed(timer) & 32
       plot 23+pos,y,167
     else
       plot 23+pos,y,tempName[pos]
     endif
     if elapsed(timer) & 16
       if stick(127)
         reset timer
         plot 23+pos,y,tempName[pos]
         if stick(64) & (pos>1):pos=pos-1:endif
         if stick(32) & (pos<3):pos=pos+1:endif
         if stick(8)
           tempName[pos]=tempName[pos]-1
           if tempName[pos]==31:tempName[pos]=90:endif
           if tempName[pos]==64:tempName[pos]=32:endif
         endif
         if stick(16)
           tempName[pos]=tempName[pos]+1
           if tempName[pos]==91:tempName[pos]=32:endif
           if tempName[pos]==33:tempName[pos]=65:endif
         endif
       endif
     endif
   until stick(128)
   topName$[i]=chr(tempName[1])+chr(tempName[2])+chr(tempName[3])
   plot 24,y,topName$[i]
   plot 23,20,"         ":plot 23,21,"         "
 enddef
 ;
 ;** INITIALISE **
 def_init()
   local i
   reset t:r=rnd(t)
   mode 2:cursor 1:colour 32,1,1
   sizeX=10:sizeY=20:bgcol=1:fgcol=4:blcol=15
   colour 16,blcol,bgcol:colour 32,blcol,bgcol:for s=0,15,1:colour s,fgcol,bgcol:next
   plot 10,11,"PLEASE  WAIT":plot 10,12,"INITIALISING"
   chdir "/font":font "conapt.fbd"
   for i=0x2000,0x23ff,1
     v=i&4
     if (v<4):vpoke i,0xb1:else:vpoke i,0x31:endif
   next
   for i=0x2400,0x27ff,1
     vpoke i,0xe1
   next
   gameXOff=11:gameYOff=2
   sprXOff=gameXOff-2:sprYOff=gameYOff-2
   sizeXp2=sizeX+2:sizeYp2=sizeY+2:sizeXp1=sizeX+1:sizeYp1=sizeY+1
   gameXOffm2=gameXOff-2:gameYOffm2=gameYOff-2
   dim gameMap$[sizeX+2+1,sizeY+2],lineCount[sizeY+2],tempLine$[sizeX+2+1]
   dim blankLine$[sizeX+2+1]:blankLine$=chr(132)+"          "+chr(132)
   dim fillLine$[sizeX+2+1]:fillLine$="************"
   dim shapeP[7],shapeC[7]
   dim shapeX1[7,4],shapeY1[7,4]
   dim shapeX2[7,4],shapeY2[7,4]
   dim shapeX3[7,4],shapeY3[7,4]
   dim shapeX4[7,4],shapeY4[7,4]
   dim mapX1[7,4],mapY1[7,4]
   dim mapX2[7,4],mapY2[7,4]
   dim mapX3[7,4],mapY3[7,4]
   dim mapX4[7,4],mapY4[7,4]
   dim stat[7],topName$[4,7],topScore[7],tempName[3],message$[255]
   for s=1,7,1
     topName$[s]="AAA":topScore[s]=(8-s)*100
     read shapeP[s],shapeC[s]
     for i=0,7,1
       vpoke 0x2000+8*shapeP[s]+i,shapeC[s]
     next
     for r=1,4,1
       read mapX1[s,r],mapY1[s,r]
       read mapX2[s,r],mapY2[s,r]
       read mapX3[s,r],mapY3[s,r]
       read mapX4[s,r],mapY4[s,r]
       shapeX1[s,r]=mapX1[s,r]
       shapeX2[s,r]=mapX2[s,r]
       shapeX3[s,r]=mapX3[s,r]
       shapeX4[s,r]=mapX4[s,r]
       shapeY1[s,r]=mapY1[s,r]
       shapeY2[s,r]=mapY2[s,r]
       shapeY3[s,r]=mapY3[s,r]
       shapeY4[s,r]=mapY4[s,r]
     next
   next
   ; Custom graphics definitions
   repeat
     read s
     if s<>0
       for r=0,7,1
         read d
         vpoke (s*8)+r,d
       next
     endif
   until s==0
   ; Blocks definitions 1 line per char line
   for s=0,6,1
     for r=0,7,1
       a=(136+r+(8*s))*8
       for l=0,7,1
         if l<(7-r)
           vpoke a+l,0
           vpoke 0x2000+a+l,0x10+bgcol
         else
           vpoke 0x2000+a+l,shapeC[s+1]
           if (l==(7-r))|(l==7)
             vpoke a+l,0
           else
             vpoke a+l,126
           endif
         endif
       next
     next
   next
   ; Load music data
   dim note[120],delay[120]
   repeat
     read note[noteIndex],delay[noteIndex]
     noteIndex=noteIndex+1
   until note[noteIndex-1]==999
   musicFlag=1
   ; Scroll message
   message$=           "                              "
   message$=message$ + "*By @6502Nerd*   Programmed in"
   message$=message$ + " dflat, a custom BASIC for the"
   message$=message$ + " HB-BBC128 a custom 65c02 comp"
   message$=message$ + "uter using TMS9918 video, AY-3"
   message$=message$ + "8910 sound, 128KB RAM, 64KB RO"
   message$=message$ + "M, 1GB SD, in a BBC case!     "
   message$=message$ + "                              "
 enddef
 ;shape data
 ;shape 1: long bar (dark green)
 data 143,0xc3
 data 0,0,1,0,2,0,3,0
 data 0,0,0,1,0,2,0,3
 data 0,0,1,0,2,0,3,0
 data 0,0,0,1,0,2,0,3
 ;shape 2: square (dark blue)
 data 151,0x45
 data 0,0,1,0,0,1,1,1
 data 0,0,1,0,0,1,1,1
 data 0,0,1,0,0,1,1,1
 data 0,0,1,0,0,1,1,1
 ;shape 3: L (light blue)
 data 159,0x54
 data 0,0,1,0,2,0,0,1
 data 0,0,1,0,1,1,1,2
 data 2,0,0,1,1,1,2,1
 data 0,0,0,1,0,2,1,2
 ;shape 3: reverse L (dark red)
 data 167,0x69
 data 0,0,0,1,1,1,2,1
 data 0,0,0,1,0,2,1,0
 data 0,0,1,0,2,0,2,1
 data 1,0,1,1,1,2,0,2
 ;shape 4: S (cyan)
 data 175,0x75
 data 1,0,2,0,0,1,1,1
 data 0,0,0,1,1,1,1,2
 data 1,0,2,0,0,1,1,1
 data 0,0,0,1,1,1,1,2
 ;shape 5: Z (yellow)
 data 183,0xab
 data 0,0,1,0,1,1,2,1
 data 1,0,1,1,0,1,0,2
 data 0,0,1,0,1,1,2,1
 data 1,0,1,1,0,1,0,2
 ;shape 6: T (fuschia)
 data 191,0xd5
 data 0,0,1,0,2,0,1,1
 data 1,0,1,1,1,2,0,1
 data 1,0,0,1,1,1,2,1
 data 0,0,0,1,0,2,1,1
 ;custom graphics
 ;Char 128-135
 ;top left round
 data 128
 data 0b00011111
 data 0b01111111
 data 0b01111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 ;top right round
 data 129
 data 0b11111000
 data 0b11111110
 data 0b11111110
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 ;bottom left round
 data 130
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b01111111
 data 0b01111111
 data 0b00011111
 ;bottom right round
 data 131
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111110
 data 0b11111110
 data 0b11111000
 ; solid block
 data 132
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 data 0b11111111
 ; end of UDG
 data 0
 ;
 ; Tune data = pitch,duration
 data 13,4, 11,4, 13,4, 8,4, 4,4, 8,4, 1, 8
 data 13,4, 11,4, 13,4, 8,4, 4,4, 8,4, 1, 8
 data 13,4, 15,4, 16,4, 15,4, 16,4, 13,4, 15,4, 13,4, 15,4
 data 11,4, 13,4, 11,4, 13,4, 9,4, 13,8
 data 13,4, 11,4, 13,4, 8,4, 4,4, 8, 4, 1, 8
 data 13,4, 11,4, 13,4, 8,4, 4,4, 8, 4, 1, 8
 data 13,4, 15,4, 16,4, 15,4, 16,4, 13,4, 15,4, 13,4, 15,4
 data 11,4, 13,4, 11,4, 13,4, 15,4, 16,8
 data 20,4, 18,4, 20,4, 16,4, 11,4, 16,4, 8,8
 data 20,4, 18,4, 20,4, 16,4, 11,4, 16,4, 8,8
 data 20,4, 22,4, 23,4, 22,4, 23,4, 20,4, 22,4, 20,4, 22,4
 data 18,4, 20,4, 18,4, 20,4, 16,4, 20,8
 data 20,4, 18,4, 20,4, 16,4, 11,4, 16,4, 8,8
 data 20,4, 18,4, 20,4, 16,4, 11,4, 16,4, 8,8
 data 20,4, 22,4, 23,4, 22,4, 23,4, 20,4, 22,4, 20,4, 22,4
 data 18,4, 20,4, 18,4, 15,4, 18,4, 20,8
 data 999,0

