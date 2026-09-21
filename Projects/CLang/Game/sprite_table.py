import math

samples=256
cx=(128-8)
cy=(96-8)
sx=(256/2-8)
sy=(192/2-8)
print("_x_coord:")
for angle in range(samples):
    if angle % 16 == 0:
        print(" .byte ", end="")
    v=math.cos(math.radians((angle*360)/samples))
    print(int(v*sx+cx), end="")
    if angle % 16 != 15:
        print(",", end="")
    else:
        print("")

print("_y_coord:")
for angle in range(samples):
    if angle % 16 == 0:
        print(" .byte ", end="")
    v=math.sin(math.radians((angle*360)/samples))
    print(int(v*sy+cy), end="")
    if angle % 16 != 15:
        print(",", end="")
    else:
        print("")

