def shift_rows(state):
    """
    Performs the ShiftRows transformation on a 4x4 state matrix.
    Each row 'i' is shifted left by 'i' positions.
    """
    shifted_state = [ [0]*4 for _ in range(4) ]
    
    # Row 0: No shift
    shifted_state[0] = state[0]
    # Row 1: Shift left by 1
    shifted_state[1] = state[1][1:] + state[1][:1]
    # Row 2: Shift left by 2
    shifted_state[2] = state[2][2:] + state[2][:2]
    # Row 3: Shift left by 3
    shifted_state[3] = state[3][3:] + state[3][:3]
    
    return shifted_state