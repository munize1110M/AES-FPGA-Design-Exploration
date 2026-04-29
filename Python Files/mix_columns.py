from BitVector import *
def mix_columns(state):
    """
    Performs the MixColumns transformation.
    Multiplies each column by the fixed AES matrix in GF(2^8).
    """
    # The irreducible polynomial from your script
    AES_modulus = BitVector(bitstring="100011011") #
    
    new_state = [ [0]*4 for _ in range(4) ]
    
    for c in range(4):
        # Extract the current column
        col = [state[r][c] for r in range(4)]
        
        # Convert integers to BitVectors for GF multiplication
        bv_col = [BitVector(intVal=x, size=8) for x in col]
        
        # Helper for GF multiplication (bv * constant)
        def gf_mul(bv, factor):
            if factor == 1: return bv
            if factor == 2: return bv.gf_multiply_modular(BitVector(intVal=2), AES_modulus, 8)
            if factor == 3: return bv.gf_multiply_modular(BitVector(intVal=3), AES_modulus, 8)
            return BitVector(intVal=0)

        # AES MixColumns Matrix multiplication logic
        # New Row 0 = (2*b0) ^ (3*b1) ^ (1*b2) ^ (1*b3)
        new_state[0][c] = int(gf_mul(bv_col[0], 2) ^ gf_mul(bv_col[1], 3) ^ bv_col[2] ^ bv_col[3])
        # New Row 1 = (1*b0) ^ (2*b1) ^ (3*b2) ^ (1*b3)
        new_state[1][c] = int(bv_col[0] ^ gf_mul(bv_col[1], 2) ^ gf_mul(bv_col[2], 3) ^ bv_col[3])
        # New Row 2 = (1*b0) ^ (1*b1) ^ (2*b2) ^ (3*b3)
        new_state[2][c] = int(bv_col[0] ^ bv_col[1] ^ gf_mul(bv_col[2], 2) ^ gf_mul(bv_col[3], 3))
        # New Row 3 = (3*b0) ^ (1*b1) ^ (1*b2) ^ (2*b3)
        new_state[3][c] = int(gf_mul(bv_col[0], 3) ^ bv_col[1] ^ bv_col[2] ^ gf_mul(bv_col[3], 2))

    return new_state