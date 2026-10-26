import math

samples=128
wave_height=60;
sy=(wave_height/2)

print("_y_sin:")
for angle in range(samples):
    if angle % 16 == 0:
        print(" .byte ", end="")
    v=math.sin(math.radians((angle*360)/samples))
    v=int(v*sy)
    if v < 0:
        v=256+v
    print(v, end="")
    if angle % 16 != 15:
        print(",", end="")
    else:
        print("")

print("_scrn_off_l:")
print(" .byte ", end="")
for offset in range(32):
    print((offset*32)%256, end="")
    if offset != 31:
        print(",", end="")
    else:
        print("")
print("_scrn_off_h:")
print(" .byte ", end="")
for offset in range(32):
    print((offset*32)//256, end="")
    if offset != 31:
        print(",", end="")
    else:
        print("")

