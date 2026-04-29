module rounds(
    input  logic clk,
    input  logic reset,
    input  logic start,              // SPI Wrapper triggers this
    input  logic [127:0] data_in,    // Flat 128-bit plaintext from SPI
    output logic done,               // Pulses high when encryption is finished
    output logic [127:0] STATE_OUT   // Flat 128-bit ciphertext to SPI
);

// ==========================================
// 1. Data Structures & Hardcoded Tables
// ==========================================
logic [3:0][3:0][7:0] STATE_MATRIX;

// ---> PASTE YOUR EXACT 'sbox' ARRAY HERE <---
logic [0:15][0:15][7:0] sbox = {
    {8'h63, 8'h7C, 8'h77, 8'h7B, 8'hF2, 8'h6B, 8'h6F, 8'hC5, 8'h30, 8'h01, 8'h67, 8'h2B, 8'hFE, 8'hD7, 8'hAB, 8'h76}, // Row 0
    {8'hCA, 8'h82, 8'hC9, 8'h7D, 8'hFA, 8'h59, 8'h47, 8'hF0, 8'hAD, 8'hD4, 8'hA2, 8'hAF, 8'h9C, 8'hA4, 8'h72, 8'hC0}, // Row 1
    {8'hB7, 8'hFD, 8'h93, 8'h26, 8'h36, 8'h3F, 8'hF7, 8'hCC, 8'h34, 8'hA5, 8'hE5, 8'hF1, 8'h71, 8'hD8, 8'h31, 8'h15}, // Row 2
    {8'h04, 8'hC7, 8'h23, 8'hC3, 8'h18, 8'h96, 8'h05, 8'h9A, 8'h07, 8'h12, 8'h80, 8'hE2, 8'hEB, 8'h27, 8'hB2, 8'h75}, // Row 3
    {8'h09, 8'h83, 8'h2C, 8'h1A, 8'h1B, 8'h6E, 8'h5A, 8'hA0, 8'h52, 8'h3B, 8'hD6, 8'hB3, 8'h29, 8'hE3, 8'h2F, 8'h84}, // Row 4
    {8'h53, 8'hD1, 8'h00, 8'hED, 8'h20, 8'hFC, 8'hB1, 8'h5B, 8'h6A, 8'hCB, 8'hBE, 8'h39, 8'h4A, 8'h4C, 8'h58, 8'hCF}, // Row 5
    {8'hD0, 8'hEF, 8'hAA, 8'hFB, 8'h43, 8'h4D, 8'h33, 8'h85, 8'h45, 8'hF9, 8'h02, 8'h7F, 8'h50, 8'h3C, 8'h9F, 8'hA8}, // Row 6
    {8'h51, 8'hA3, 8'h40, 8'h8F, 8'h92, 8'h9D, 8'h38, 8'hF5, 8'hBC, 8'hB6, 8'hDA, 8'h21, 8'h10, 8'hFF, 8'hF3, 8'hD2}, // Row 7
    {8'hCD, 8'h0C, 8'h13, 8'hEC, 8'h5F, 8'h97, 8'h44, 8'h17, 8'hC4, 8'hA7, 8'h7E, 8'h3D, 8'h64, 8'h5D, 8'h19, 8'h73}, // Row 8
    {8'h60, 8'h81, 8'h4F, 8'hDC, 8'h22, 8'h2A, 8'h90, 8'h88, 8'h46, 8'hEE, 8'hB8, 8'h14, 8'hDE, 8'h5E, 8'h0B, 8'hDB}, // Row 9
    {8'hE0, 8'h32, 8'h3A, 8'h0A, 8'h49, 8'h06, 8'h24, 8'h5C, 8'hC2, 8'hD3, 8'hAC, 8'h62, 8'h91, 8'h95, 8'hE4, 8'h79}, // Row A
    {8'hE7, 8'hC8, 8'h37, 8'h6D, 8'h8D, 8'hD5, 8'h4E, 8'hA9, 8'h6C, 8'h56, 8'hF4, 8'hEA, 8'h65, 8'h7A, 8'hAE, 8'h08}, // Row B
    {8'hBA, 8'h78, 8'h25, 8'h2E, 8'h1C, 8'hA6, 8'hB4, 8'hC6, 8'hE8, 8'hDD, 8'h74, 8'h1F, 8'h4B, 8'hBD, 8'h8B, 8'h8A}, // Row C
    {8'h70, 8'h3E, 8'hB5, 8'h66, 8'h48, 8'h03, 8'hF6, 8'h0E, 8'h61, 8'h35, 8'h57, 8'hB9, 8'h86, 8'hC1, 8'h1D, 8'h9E}, // Row D
    {8'hE1, 8'hF8, 8'h98, 8'h11, 8'h69, 8'hD9, 8'h8E, 8'h94, 8'h9B, 8'h1E, 8'h87, 8'hE9, 8'hCE, 8'h55, 8'h28, 8'hDF}, // Row E
    {8'h8C, 8'hA1, 8'h89, 8'h0D, 8'hBF, 8'hE6, 8'h42, 8'h68, 8'h41, 8'h99, 8'h2D, 8'h0F, 8'hB0, 8'h54, 8'hBB, 8'h16}  // Row F
};

// ---> PASTE YOUR EXACT 'round_keys' ARRAY HERE <---
logic [3:0][3:0][7:0] round_keys [0:10] = '{
    // Round 0 (Initial Key)
    {
        {8'h2B, 8'h28, 8'hAB, 8'h09}, // Row 0
        {8'h7E, 8'hAE, 8'hF7, 8'hCF}, // Row 1
        {8'h15, 8'hD2, 8'h15, 8'h4F}, // Row 2
        {8'h16, 8'hA6, 8'h88, 8'h3C}  // Row 3
    },
    // Round 1
    {
        {8'hA0, 8'h88, 8'h23, 8'h2A},
        {8'hFA, 8'h54, 8'hA3, 8'h6C},
        {8'hFE, 8'h2C, 8'h39, 8'h76},
        {8'h17, 8'hB1, 8'h39, 8'h05}
    },
    // Round 2
    {
        {8'hF2, 8'h7A, 8'h59, 8'h73},
        {8'hC2, 8'h96, 8'h35, 8'h59},
        {8'h95, 8'hB9, 8'h80, 8'hF6},
        {8'hF2, 8'h43, 8'h7A, 8'h7F}
    },
    // Round 3
    {
        {8'h3D, 8'h47, 8'h1E, 8'h6D},
        {8'h80, 8'h16, 8'h23, 8'h7A},
        {8'h47, 8'hFE, 8'h7E, 8'h88},
        {8'h7D, 8'h3E, 8'h44, 8'h3B}
    },
    // Round 4
    {
        {8'hEF, 8'hA8, 8'hB6, 8'hDB},
        {8'h44, 8'h52, 8'h71, 8'h0B},
        {8'hA5, 8'h5B, 8'h25, 8'hAD},
        {8'h41, 8'h7F, 8'h3B, 8'h00}
    },
    // Round 5
    {
        {8'hD4, 8'h7C, 8'hCA, 8'h11},
        {8'hD1, 8'h83, 8'hF2, 8'hF9},
        {8'hC6, 8'h9D, 8'hB8, 8'h15},
        {8'hF8, 8'h87, 8'hBC, 8'hBC}
    },
    // Round 6
    {
        {8'h6D, 8'h11, 8'hDB, 8'hCA},
        {8'h88, 8'h0B, 8'hF9, 8'h00},
        {8'hA3, 8'h3E, 8'h86, 8'h93},
        {8'h7A, 8'hFD, 8'h41, 8'hFD}
    },
    // Round 7
    {
        {8'h4E, 8'h5F, 8'h84, 8'h4E},
        {8'h54, 8'h5F, 8'hA6, 8'hA6},
        {8'hF7, 8'hC9, 8'h4F, 8'hDC},
        {8'h0E, 8'hF3, 8'hB2, 8'h4F}
    },
    // Round 8
    {
        {8'hEA, 8'hB5, 8'h31, 8'h7F},
        {8'hD2, 8'h8D, 8'h2B, 8'h8D},
        {8'h73, 8'hBA, 8'hF5, 8'h29},
        {8'h21, 8'hD2, 8'h60, 8'h2F}
    },
    // Round 9
    {
        {8'hAC, 8'h19, 8'h28, 8'h57},
        {8'h77, 8'hFA, 8'hD1, 8'h5C},
        {8'h66, 8'hDC, 8'h29, 8'h00},
        {8'hF3, 8'h21, 8'h41, 8'h6E}
    },
    // Round 10 (Final Round)
    {
        {8'hD0, 8'hC9, 8'hE1, 8'hB6},
        {8'h14, 8'hEE, 8'h3F, 8'h63},
        {8'hF9, 8'h25, 8'h0C, 8'h0C},
        {8'hA8, 8'h89, 8'hC8, 8'hA6}
    }
};

// ==========================================
// 2. Data Flattening & Matrix Mapping
// ==========================================
logic [7:0] in_bytes [0:15];
logic [127:0] transposed_data_in;

genvar i;
generate
    // Extract bytes from flat input (MSB is byte 0)
    for (i = 0; i < 16; i++) begin : gen_in_bytes
        assign in_bytes[i] = data_in[127 - (i*8) -: 8];
    end
endgenerate

// Transpose the input array into column-major order (flat 128-bit vector)
// This perfectly mimics the layout of your original 'initial_state' block
assign transposed_data_in = {
    in_bytes[0], in_bytes[4], in_bytes[8],  in_bytes[12], // Row 0
    in_bytes[1], in_bytes[5], in_bytes[9],  in_bytes[13], // Row 1
    in_bytes[2], in_bytes[6], in_bytes[10], in_bytes[14], // Row 2
    in_bytes[3], in_bytes[7], in_bytes[11], in_bytes[15]  // Row 3
};

// ==========================================
// 3. Internal Registers & Signals
// ==========================================
logic [0:3][0:3][7:0] reg_bank0;
logic [0:3][0:3][7:0] reg_bank1;
logic [0:3][0:3][7:0] reg_bank2;
logic [0:3][0:3][7:0] reg_bank3;
logic [0:3][0:3][7:0] reg_bank4;

logic [0:3][0:3][7:0] sub_bytes;
logic [0:3][0:3][7:0] mix_col;

logic [$clog2(10):0] main_counter;
logic [$clog2(2):0]  sub_counter;

typedef enum logic [1:0]{
    IDLE,
    ACTIVE
} states;

states state;
states next_state;

// ==========================================
// 4. Control Logic (State Machine & Counters)
// ==========================================
always_comb begin
    next_state = state;
    case(state)
        IDLE: begin
            if (start) next_state = ACTIVE;
        end
        ACTIVE: begin
            if (main_counter == 10 && sub_counter == 2) 
                next_state = IDLE;
        end
    endcase
end

always_ff @ (posedge clk) begin
    if (reset) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Counters only run when ACTIVE
always_ff @ (posedge clk) begin
    if (reset || state == IDLE) begin
        sub_counter  <= 0;
        main_counter <= 1;
    end else if (state == ACTIVE) begin
        sub_counter <= (sub_counter == 2) ? 0 : sub_counter + 1;
        main_counter <= (main_counter == 10 && sub_counter == 2) ? 0 : 
                        (sub_counter == 2 ? main_counter + 1 : main_counter);
    end
end

// ==========================================
// 5. Main Pipeline Logic
// ==========================================
always_ff @ (posedge clk) begin
    if (reset) begin
        reg_bank0 <= 0;
        reg_bank1 <= 0;
        reg_bank2 <= 0;
        reg_bank3 <= 0;
        reg_bank4 <= 0;
    end 
    else if (state == IDLE && start) begin
        // ONLY capture input and apply initial round key when 'start' is pulsed
        reg_bank0 = transposed_data_in ^ round_keys[0];
    end
    else if (state == ACTIVE) begin
        if (main_counter == 10) begin
            reg_bank2 <= sub_bytes;
            
            // shift_rows (Final Round - No Mix Columns)
            reg_bank4[0][0] <= reg_bank2[0][0]; reg_bank4[0][1] <= reg_bank2[0][1]; reg_bank4[0][2] <= reg_bank2[0][2]; reg_bank4[0][3] <= reg_bank2[0][3];
            reg_bank4[1][0] <= reg_bank2[1][1]; reg_bank4[1][1] <= reg_bank2[1][2]; reg_bank4[1][2] <= reg_bank2[1][3]; reg_bank4[1][3] <= reg_bank2[1][0];
            reg_bank4[2][0] <= reg_bank2[2][2]; reg_bank4[2][1] <= reg_bank2[2][3]; reg_bank4[2][2] <= reg_bank2[2][0]; reg_bank4[2][3] <= reg_bank2[2][1];
            reg_bank4[3][0] <= reg_bank2[3][3]; reg_bank4[3][1] <= reg_bank2[3][0]; reg_bank4[3][2] <= reg_bank2[3][1]; reg_bank4[3][3] <= reg_bank2[3][2];    
        end
        else begin
            reg_bank2 <= sub_bytes;
            
            // shift_rows (Standard Rounds)
            reg_bank3[0][0] <= reg_bank2[0][0]; reg_bank3[0][1] <= reg_bank2[0][1]; reg_bank3[0][2] <= reg_bank2[0][2]; reg_bank3[0][3] <= reg_bank2[0][3];
            reg_bank3[1][0] <= reg_bank2[1][1]; reg_bank3[1][1] <= reg_bank2[1][2]; reg_bank3[1][2] <= reg_bank2[1][3]; reg_bank3[1][3] <= reg_bank2[1][0];
            reg_bank3[2][0] <= reg_bank2[2][2]; reg_bank3[2][1] <= reg_bank2[2][3]; reg_bank3[2][2] <= reg_bank2[2][0]; reg_bank3[2][3] <= reg_bank2[2][1];
            reg_bank3[3][0] <= reg_bank2[3][3]; reg_bank3[3][1] <= reg_bank2[3][0]; reg_bank3[3][2] <= reg_bank2[3][1]; reg_bank3[3][3] <= reg_bank2[3][2];

            reg_bank1 <= mix_col ^ round_keys[main_counter];
        end
    end
end

// ==========================================
// 6. SubBytes Logic
// ==========================================
always_comb begin
    sub_bytes = 0;
    if (state == ACTIVE) begin // Changed to only run when ACTIVE
        if (main_counter == 1) begin
            for(int k = 0; k < 4; k++) begin
                for (int w = 0; w< 4; w++) begin
                    sub_bytes[k][w] = sbox[reg_bank0[k][w][7:4]][reg_bank0[k][w][3:0]];
                end
            end 
        end
        else begin
            for(int k = 0; k < 4; k++) begin
                for (int w = 0; w< 4; w++) begin
                    sub_bytes[k][w] = sbox[reg_bank1[k][w][7:4]][reg_bank1[k][w][3:0]];
                end
            end 
        end
    end
end

// ==========================================
// 7. MixColumns Logic
// ==========================================
function automatic [7:0] xtime(input [7:0] b);
    return (b[7] == 1'b1) ? ((b << 1) ^ 8'h1b) : (b << 1);
endfunction

always_comb begin
    mix_col = 0; 
    if (state == ACTIVE) begin
        for (int j = 0; j < 4; j++) begin
            logic [7:0] s0, s1, s2, s3;
            s0 = reg_bank3[0][j]; s1 = reg_bank3[1][j]; s2 = reg_bank3[2][j]; s3 = reg_bank3[3][j];
            
            mix_col[0][j] = xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3;
            mix_col[1][j] = s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3;
            mix_col[2][j] = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3);
            mix_col[3][j] = (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3);
        end
    end
end

// ==========================================
// 8. Final Output Formatting
// ==========================================
logic [127:0] raw_ciphertext;
logic [7:0]   out_bytes [0:15];

// Pulse done signal exactly when the final state is reached
assign done = (state == ACTIVE && main_counter == 10 && sub_counter == 2);

// Perform final AddRoundKey (vector XOR operates correctly on flat arrays)
assign raw_ciphertext = reg_bank4 ^ round_keys[10];

// Un-transpose the column-major ciphertext back into standard byte order
assign out_bytes[0]  = raw_ciphertext[127 - 0*8 -: 8];  // Row 0, Col 0
assign out_bytes[4]  = raw_ciphertext[127 - 1*8 -: 8];  // Row 0, Col 1
assign out_bytes[8]  = raw_ciphertext[127 - 2*8 -: 8];  // Row 0, Col 2
assign out_bytes[12] = raw_ciphertext[127 - 3*8 -: 8];  // Row 0, Col 3

assign out_bytes[1]  = raw_ciphertext[127 - 4*8 -: 8];  // Row 1, Col 0
assign out_bytes[5]  = raw_ciphertext[127 - 5*8 -: 8];  // Row 1, Col 1
assign out_bytes[9]  = raw_ciphertext[127 - 6*8 -: 8];  // Row 1, Col 2
assign out_bytes[13] = raw_ciphertext[127 - 7*8 -: 8];  // Row 1, Col 3

assign out_bytes[2]  = raw_ciphertext[127 - 8*8 -: 8];  // Row 2, Col 0
assign out_bytes[6]  = raw_ciphertext[127 - 9*8 -: 8];  // Row 2, Col 1
assign out_bytes[10] = raw_ciphertext[127 - 10*8 -: 8]; // Row 2, Col 2
assign out_bytes[14] = raw_ciphertext[127 - 11*8 -: 8]; // Row 2, Col 3

assign out_bytes[3]  = raw_ciphertext[127 - 12*8 -: 8]; // Row 3, Col 0
assign out_bytes[7]  = raw_ciphertext[127 - 13*8 -: 8]; // Row 3, Col 1
assign out_bytes[11] = raw_ciphertext[127 - 14*8 -: 8]; // Row 3, Col 2
assign out_bytes[15] = raw_ciphertext[127 - 15*8 -: 8]; // Row 3, Col 3

// Pack it back into the flat 128-bit output vector 
assign STATE_OUT = {
    out_bytes[0], out_bytes[1], out_bytes[2],  out_bytes[3],
    out_bytes[4], out_bytes[5], out_bytes[6],  out_bytes[7],
    out_bytes[8], out_bytes[9], out_bytes[10], out_bytes[11],
    out_bytes[12], out_bytes[13], out_bytes[14], out_bytes[15]
};

endmodule