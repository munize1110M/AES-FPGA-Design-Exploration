module aes_round_stage #(
    parameter bit FINAL_ROUND = 1'b0
) (
    input  logic [127:0] state_in,
    input  logic [127:0] round_key,
    output logic [127:0] state_out
);

    logic [7:0] state_bytes     [0:15];
    logic [7:0] sub_bytes       [0:15];
    logic [7:0] shifted_bytes   [0:15];
    logic [7:0] mixed_bytes     [0:15];
    logic [127:0] round_core_out;

    genvar byte_idx;
    generate
        for (byte_idx = 0; byte_idx < 16; byte_idx++) begin : gen_stage_sboxes
            assign state_bytes[byte_idx] = state_in[127 - (byte_idx * 8) -: 8];
            sbox_lut sbox_inst (
                .byte_in(state_bytes[byte_idx]),
                .byte_out(sub_bytes[byte_idx])
            );
        end
    endgenerate

    always_comb begin
        shifted_bytes[0]  = sub_bytes[0];
        shifted_bytes[1]  = sub_bytes[1];
        shifted_bytes[2]  = sub_bytes[2];
        shifted_bytes[3]  = sub_bytes[3];

        shifted_bytes[4]  = sub_bytes[5];
        shifted_bytes[5]  = sub_bytes[6];
        shifted_bytes[6]  = sub_bytes[7];
        shifted_bytes[7]  = sub_bytes[4];

        shifted_bytes[8]  = sub_bytes[10];
        shifted_bytes[9]  = sub_bytes[11];
        shifted_bytes[10] = sub_bytes[8];
        shifted_bytes[11] = sub_bytes[9];

        shifted_bytes[12] = sub_bytes[15];
        shifted_bytes[13] = sub_bytes[12];
        shifted_bytes[14] = sub_bytes[13];
        shifted_bytes[15] = sub_bytes[14];
    end

    function automatic logic [7:0] xtime(input logic [7:0] value);
        xtime = value[7] ? ((value << 1) ^ 8'h1B) : (value << 1);
    endfunction

    always_comb begin
        logic [7:0] s0;
        logic [7:0] s1;
        logic [7:0] s2;
        logic [7:0] s3;

        for (int idx = 0; idx < 16; idx++) begin
            mixed_bytes[idx] = shifted_bytes[idx];
        end

        if (!FINAL_ROUND) begin
            for (int column = 0; column < 4; column++) begin
                s0 = shifted_bytes[column];
                s1 = shifted_bytes[4 + column];
                s2 = shifted_bytes[8 + column];
                s3 = shifted_bytes[12 + column];

                mixed_bytes[column]      = xtime(s0) ^ (xtime(s1) ^ s1) ^ s2 ^ s3;
                mixed_bytes[4 + column]  = s0 ^ xtime(s1) ^ (xtime(s2) ^ s2) ^ s3;
                mixed_bytes[8 + column]  = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3) ^ s3);
                mixed_bytes[12 + column] = (xtime(s0) ^ s0) ^ s1 ^ s2 ^ xtime(s3);
            end
        end

        for (int idx = 0; idx < 16; idx++) begin
            round_core_out[127 - (idx * 8) -: 8] = mixed_bytes[idx];
        end
    end

    assign state_out = round_core_out ^ round_key;

endmodule
