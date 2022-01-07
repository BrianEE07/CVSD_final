

def string2hex(s):
    hex_string = "0x"+s    
    an_integer = int(hex_string, 16)
    return an_integer

def s16(value):
    return -(value & 0x8000) | (value & 0x7fff)
            
ww = open("parsed.txt", "w")

with open("indata0.dat") as f:
    for prob in range(16):
        for line_number in range(17):
            l = f.readline()
            l.strip()
            ll = l.split("_")
            for i in range(len(ll)):
                if (line_number == 16):
                    ww.write(str(s16(string2hex(ll[i]))))
                    ww.write(" ")
                elif (i==15-line_number):
                    ww.write(str(s16(string2hex(ll[i]))/(2**14)))
                    ww.write(" ")
                else :
                    ww.write(str(s16(string2hex(ll[i]))))
                    ww.write(" ")
            ww.write("\n")
            
ww.close()
            
                
                