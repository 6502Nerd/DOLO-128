 def_rxa(a$)
 redim a$[20]
 _init(a$)
 if fcreate(f$)<>-1
   println "Error:",f$:abort
 endif
 ; Flush input & request start
 device 0:repeat:until key(0)==0
 print chr(C):dim buff[128]
 repeat
   header=key(1):crc=0:chksum=0
   if header==SOH
     blk=key(1):blk2=key(1)
     for byte=1,128,1
       buff[byte]=key(1)
     next
     chksum=(key(1)<<8)|(key(1))
     crc=_calcCRC():device 2
     for byte=1,128,1
       if buff[byte]<>ETX
       print chr(buff[byte]):endif
     next
   endif:device 0
   if chksum==crc
     print chr(ACK):else
     print chr(NACK):endif
 until header==EOT
 fclose:device -1
 enddef
 ;
 def_txa(a$)
 redim a$[20]
 _init(a$)
 if fcreate(f$)<>-1
   println "Error:",f$:abort
 endif
 ; Flush input & request start
 device 0:repeat:until key(0)==0
 print chr(C):dim buff[128]
 repeat
   header=key(1):crc=0:chksum=0
   if header==SOH
     blk=key(1):blk2=key(1)
     for byte=1,128,1
       buff[byte]=key(1)
     next
     chksum=(key(1)<<8)|(key(1))
     crc=_calcCRC():device 2
     for byte=1,128,1
       if buff[byte]<>ETX
       print chr(buff[byte]):endif
     next
   endif:device 0
   if chksum==crc
     print chr(ACK):else
     print chr(NACK):endif
 until header==EOT
 fclose:device -1
 enddef
 ;
 def_init(a$)
   ; protocol definitions
   SOH=0x01:EOT=0x04:ACK=0x06:NAK=0x15
   ETB=0x17:CAN=0x18:C=0x43:ETX=0x1a
 enddef
 ;
 def_calcCRC()
   local crc, byte, i
   crc=0
   for byte=1,128,1
     crc=crc^(buff[byte]<<8)
     for i=1,8,1
       if(crc&0x8000)
         crc=(crc<<1)^0x1021
       else
         crc=crc<<1
       endif
     next
   next
   return crc
 enddef
 ;
 def_rxaold(a$)
 redim a$[20]
 ; protocol definitions
 SOH=0x01:EOT=0x04:ACK=0x06:NAK=0x15:ETB=0x17:CAN=0x18:C=0x43:ETX=0x1a
 ; move the input string into a variable
 if fcreate(a$)
   ; Flush input then send C request for XmodemCRC start
   device 0:repeat:until key(0)==0
   print chr(C)
   repeat:header=key(1)
   if header==SOH
     block=key(1):block2=key(1)
     device 1:println block
     for byte=0,127,1
       device 0:a=key(1)
       device 2:if a<>ETX:print chr(a):endif
     next:device 0
     chksum=key(1):chksum2=key(1)
   endif
   print chr(ACK):until header==EOT
   fclose
   device -1
 enddef
 endif
 ;
 def_rxb(a$)
 redim a$[20]
 ; protocol definitions
 SOH=0x01:EOT=0x04:ACK=0x06:NAK=0x15:ETB=0x17:CAN=0x18:C=0x43:ETX=0x1a
 if fcreate(a$)
   ; Flush input then send C request for XmodemCRC start
   device 0:repeat:until key(0)==0
   print chr(C)
   repeat:header=key(1)
   if header==SOH
     block=key(1):block2=key(1)
     device 1:println block
     for byte=0,127,1
       device 0:a=key(1)
       device 2:print chr(a)
     next:device 0
     chksum=key(1):chksum2=key(1)
   endif
   print chr(ACK):until header==EOT
   fclose
   device -1
 enddef
;
 def_dump(f$)
 redim f$[20]
 a=fopen(f$):repeat:device 2:c=key(1):device 1:print chr(c):until c==0
 enddef
 ;
 def_dumpx(f$)
 redim f$[20]
 a=fopen(f$):repeat:device 2:c=key(1):device 1:print right(hex(c),2):until c==0
 enddef

