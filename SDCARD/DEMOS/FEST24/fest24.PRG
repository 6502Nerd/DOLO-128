; Demo for retro computer festival
; 2024
def_init()
  hires 0xf1
  colour 32,3,1
  chdir "/data/image"
  vload 0,"may4"
  plot 128-29*4,184,"RETRO COMPUTER FEST 9-10 NOV"
enddef
