 def_xmodem(f$)
 redim f$[20]
 ; protocol definitions
 SOH=0x01:EOT=0x04:ACK=0x06:NAK=0x15:ETB=0x17:CAN=0x18:C=0x43
 ; create buffer space and get the address
 dim buff$[134]:buff=buff$
 if fcreate(f$)
   ; send C request for XmodemCRC start
   device 0
   repeat
     print chr(C)
     for byte=buff,buff+133,1
       poke byte,key(1)
     next
   until peek(buff)==SOH
   print chr(ACK)
   fclose
   device -1
   println peek(buff)," ",peek(buff+1)," ",peek(buff+2)
   for byte=buff+3,buff+130,1
     print chr(peek(buff))
   next
   println
   println peek(buff+131)," ",peek(buff+132)
 endif
