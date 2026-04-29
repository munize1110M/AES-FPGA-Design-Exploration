statearray = [[0 for x in range(16)] for x in range(16)]


#for i in range(len(statearray)):
 #   print(str(statearray[i])+"\n")

temp_var = 0
print("\t\t\t---------- 16 x 16 S-Box Grid -----------\n")
for i in range(len(statearray)):
    for j in range(len(statearray[i])):
        temp_x = str(hex(i))
        temp_y = str(hex(j))
        string_adjusted_x = temp_x[2:]
        string_adjusted_y = temp_y[2:]
        statearray[i][j] = string_adjusted_x + string_adjusted_y   
        
    print(statearray[i])

## Converts hex string to int    
print(int(statearray[15][15], 16))
