#from BitVector import *

#AES_modulus = BitVector(bitstring="100011011") # Corresponds to 0x11B
import sys
from BitVector import *
AES_modulus = BitVector(bitstring="100011011")
subBytesTable = [] # SBox for encryption
invSubBytesTable = [] # SBox for decryption

sbox_matrix = []

def genTables():
    c = BitVector(bitstring="01100011")
    d = BitVector(bitstring="00000101")
    for i in range(0, 256):
        # For the encryption SBox
        a = BitVector(intVal = i, size=8).gf_MI(AES_modulus, 8) if i != 0 else BitVector(intVal=0)
        # For bit scrambling for the encryption SBox entries:
        a1,a2,a3,a4 = [a.deep_copy() for x in range(4)]
        a ^= (a1 >> 4) ^ (a2 >> 5) ^ (a3 >> 6) ^ (a4 >> 7) ^ c
        subBytesTable.append(int(a))
        # For the decryption Sbox:
        b = BitVector(intVal = i, size=8)
        # For bit scrambling for the decryption SBox entries:
        b1,b2,b3 = [b.deep_copy() for x in range(3)]
        b = (b1 >> 2) ^ (b2 >> 5) ^ (b3 >> 7) ^ d
        check = b.gf_MI(AES_modulus, 8)
        b = check if isinstance(check, BitVector) else 0
        invSubBytesTable.append(int(b))


if __name__ == "__main__":
    genTables()
    print ("SBox for Encryption:")
    #print (subBytesTable)
    #print ("\nSBox for Decryption:")
    #print (invSubBytesTable)
    temp = []
    count = 1
    for i in range(len(subBytesTable)):
        if count == 16:
            temp.append(subBytesTable[i])
            sbox_matrix.append(temp)
            temp = []
            count = 0
        else:
            temp.append(subBytesTable[i])
        count += 1

####################################################################################
############### SBOX_MATRIX HOLDS DECIAML SBOX VALUES IN 16x16 MATRIX ##############


    print("\n\n\n\n\n")
    for j in range(len(sbox_matrix)):
        print(sbox_matrix[j])
    print("\n\n", len(sbox_matrix))
    



    #genTables outputs to Decimal Values
        

