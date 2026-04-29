def hex_to_4x4_hex_matrix(hex_string):
    # Remove '0x' if present to standardize the string length
    clean_hex = hex_string[2:] if hex_string.startswith('0x') else hex_string
    
    # Slice the string into 2-character segments (bytes)
    # We keep them as strings formatted with '0x'
    hex_bytes = [clean_hex[i:i+2] for i in range(0, len(clean_hex), 2)]
    
    # Reshape the list of 16 hex strings into a 4x4 matrix
    matrix = [hex_bytes[i:i+4] for i in range(0, 16, 4)]
    
    return matrix

# Input
hex_input = "0xe4f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5"
matrix = hex_to_4x4_hex_matrix(hex_input)

# Display
print("4x4 Hex Matrix:")
for row in matrix:
    print(row)