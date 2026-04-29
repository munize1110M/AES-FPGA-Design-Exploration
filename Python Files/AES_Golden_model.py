'''import sys
from BitVector import *
import MI_algorithm as sbox
from key_expansion import get_round_keys

def add_round_key(state, round_key_matrix):
    """
    XORs the 4x4 state matrix with the 4x4 round key matrix.
    """
    for r in range(4):
        for c in range(4):
            state[r][c] ^= round_key_matrix[r][c]
    return state

def add_round_key_flat(state, flat_key):
    """
    XORs the 4x4 state matrix with a flat 16-byte key list.
    """
    for c in range(4):
        for r in range(4):
            # Mapping 1D key index to 2D state
            state[r][c] ^= flat_key[c * 4 + r]
    return state

#### First we must generate the SBox
orignal_key = 0xe4f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5




### Sample Key that im using for Testing:e4f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5

# In your other file (e.g., aes_cipher.py)
from key_expansion import get_round_keys

# Example usage:
keysize = 128
key_text = "mypassword12345"
round_keys = get_round_keys(keysize, key_text)

# Accessing the first round key (initial XOR)
initial_key = round_keys[0] 
print(f"First Key: {initial_key.get_bitvector_in_hex()}")

# Using it in a loop
for round_num in range(1, 11):
    current_round_key = round_keys[round_num]
    print(current_round_key.get_bitvector_in_hex())
    # Perform AddRoundKey step here...


################### S_BOX GENERATION AND ACESS #######################
sbox.genTables()

encryption_sbox = sbox.subBytesTable

#print(encryption_sbox)

#######################################################################'''

import sys
from BitVector import *

# Import your modules
import MI_algorithm as sbox
from key_expansion import get_round_keys
from shift_rows import shift_rows
from mix_columns import mix_columns

def add_round_key(state, round_key_matrix):
    """
    XORs the 4x4 state matrix with the 4x4 round key matrix.
    """
    for r in range(4):
        for c in range(4):
            state[r][c] ^= round_key_matrix[r][c]
    return state

def sub_bytes(state, sbox_table):
    """
    Substitutes every byte in the state matrix using the S-Box.
    """
    for r in range(4):
        for c in range(4):
            state[r][c] = sbox_table[state[r][c]]
    return state

def text_to_state_matrix(text):
    """
    Converts a 16-character string into a 4x4 column-major state matrix.
    Pads with null bytes if the text is shorter than 16 bytes.
    """
    # Ensure exactly 16 bytes
    text = text.ljust(16, '\0')[:16]
    bytes_list = [ord(c) for c in text]
    
    state = [[0]*4 for _ in range(4)]
    for c in range(4):
        for r in range(4):
            state[r][c] = bytes_list[c * 4 + r]
    return state

def bv_to_matrix(bv):
    """
    Converts a 128-bit BitVector (like a round key) into a 4x4 column-major matrix.
    """
    hex_str = bv.get_bitvector_in_hex()
    bytes_list = [int(hex_str[i:i+2], 16) for i in range(0, 32, 2)]
    
    matrix = [[0]*4 for _ in range(4)]
    for c in range(4):
        for r in range(4):
            matrix[r][c] = bytes_list[c * 4 + r]
    return matrix

def state_matrix_to_hex(state):
    """
    Converts the 4x4 column-major state matrix back to a hex string.
    """
    hex_str = ""
    for c in range(4):
        for r in range(4):
            hex_str += f"{state[r][c]:02x}"
    return hex_str

def aes_encrypt_block(plaintext, key_text, keysize=128):
    """
    Main AES Encryption Loop for a single 128-bit block.
    """
    # 1. Generate S-Box
    sbox.genTables()
    encryption_sbox = sbox.subBytesTable
    
    # 2. Key Expansion
    round_keys_bv = get_round_keys(keysize, key_text)
    num_rounds = len(round_keys_bv) - 1
    
    # 3. Initialize State
    state = text_to_state_matrix(plaintext)
    
    # 4. Initial AddRoundKey (Round 0)
    initial_key_matrix = bv_to_matrix(round_keys_bv[0])
    state = add_round_key(state, initial_key_matrix)
    
    # 5. Main Rounds (1 to num_rounds - 1)
    for round_num in range(1, num_rounds):
        state = sub_bytes(state, encryption_sbox)
        state = shift_rows(state)
        state = mix_columns(state)
        
        current_key_matrix = bv_to_matrix(round_keys_bv[round_num])
        state = add_round_key(state, current_key_matrix)
        
    # 6. Final Round (No MixColumns)
    state = sub_bytes(state, encryption_sbox)
    state = shift_rows(state)
    
    final_key_matrix = bv_to_matrix(round_keys_bv[num_rounds])
    state = add_round_key(state, final_key_matrix)
    
    # 7. Output Encrypted Block
    return state_matrix_to_hex(state)

if __name__ == "__main__":
    # Test Data
    keysize = 128
    #key_text = "mypassword12345"
    key_text = "2b7e151628aed2a6abf7158809cf4f3c"
    #plaintext = "Secret Message!!" # Exactly 16 characters
    plaintext = "3243f6a8885a308d313198a2e0370734"
    print("--------- AES-128 Encryption")
    print(f"Plaintext: {plaintext}")
    print(f"Key:       {key_text}")
    print("-" * 35)
    
    ciphertext_hex = aes_encrypt_block(plaintext, key_text, keysize)
    
    print(f"Ciphertext (Hex): {ciphertext_hex}")
    print(len(ciphertext_hex))
    







