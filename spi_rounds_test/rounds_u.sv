module rounds (
    input  logic         clk,
    input  logic         reset,
    input  logic         valid_in,
    input  logic [127:0] data_in,
    output logic         valid_out,
    output logic [127:0] STATE_OUT
);

    localparam logic [127:0] ROUND_KEYS [0:10] = '{
        128'h2B28AB09_7EAEF7CF_15D2154F_16A6883C,
        128'hA088232A_FA54A36C_FE2C3976_17B13905,
        128'hF27A5973_C2963559_95B980F6_F2437A7F,
        128'h3D471E6D_8016237A_47FE7E88_7D3E443B,
        128'hEFA8B6DB_4452710B_A55B25AD_417F3B00,
        128'hD47CCA11_D183F2F9_C69DB815_F887BCBC,
        128'h6D11DBCA_880BF900_A33E8693_7AFD41FD,
        128'h4E5F844E_545FA6A6_F7C94FDC_0EF3B24F,
        128'hEAB5317F_D28D2B8D_73BAF529_21D2602F,
        128'hAC192857_77FAD15C_66DC2900_F321416E,
        128'hD0C9E1B6_14EE3F63_F9250C0C_A889C8A6
    };

    logic [127:0] stage_reg  [0:10];
    logic [127:0] stage_next [1:10];
    logic [10:0]  valid_pipe;
    logic [127:0] mapped_input;

    function automatic logic [7:0] get_input_byte(
        input logic [127:0] data,
        input int unsigned  byte_index
    );
        get_input_byte = data[127 - (byte_index * 8) -: 8];
    endfunction

    function automatic logic [127:0] map_input_to_state(input logic [127:0] data);
        logic [127:0] mapped;
        logic [7:0]   bytes [0:15];
        begin
            for (int idx = 0; idx < 16; idx++) begin
                bytes[idx] = get_input_byte(data, idx);
            end

            mapped = {
                bytes[0],  bytes[4],  bytes[8],  bytes[12],
                bytes[1],  bytes[5],  bytes[9],  bytes[13],
                bytes[2],  bytes[6],  bytes[10], bytes[14],
                bytes[3],  bytes[7],  bytes[11], bytes[15]
            };

            map_input_to_state = mapped;
        end
    endfunction

    function automatic logic [127:0] map_state_to_output(input logic [127:0] state);
        logic [7:0] state_bytes [0:15];
        logic [7:0] output_bytes [0:15];
        begin
            for (int idx = 0; idx < 16; idx++) begin
                state_bytes[idx] = state[127 - (idx * 8) -: 8];
            end

            output_bytes[0]  = state_bytes[0];
            output_bytes[1]  = state_bytes[4];
            output_bytes[2]  = state_bytes[8];
            output_bytes[3]  = state_bytes[12];
            output_bytes[4]  = state_bytes[1];
            output_bytes[5]  = state_bytes[5];
            output_bytes[6]  = state_bytes[9];
            output_bytes[7]  = state_bytes[13];
            output_bytes[8]  = state_bytes[2];
            output_bytes[9]  = state_bytes[6];
            output_bytes[10] = state_bytes[10];
            output_bytes[11] = state_bytes[14];
            output_bytes[12] = state_bytes[3];
            output_bytes[13] = state_bytes[7];
            output_bytes[14] = state_bytes[11];
            output_bytes[15] = state_bytes[15];

            map_state_to_output = {
                output_bytes[0],  output_bytes[1],  output_bytes[2],  output_bytes[3],
                output_bytes[4],  output_bytes[5],  output_bytes[6],  output_bytes[7],
                output_bytes[8],  output_bytes[9],  output_bytes[10], output_bytes[11],
                output_bytes[12], output_bytes[13], output_bytes[14], output_bytes[15]
            };
        end
    endfunction

    assign mapped_input = map_input_to_state(data_in);

    genvar round_idx;
    generate
        for (round_idx = 1; round_idx <= 9; round_idx++) begin : gen_standard_rounds
            aes_round_stage #(
                .FINAL_ROUND(1'b0)
            ) round_stage_inst (
                .state_in(stage_reg[round_idx - 1]),
                .round_key(ROUND_KEYS[round_idx]),
                .state_out(stage_next[round_idx])
            );
        end
    endgenerate

    aes_round_stage #(
        .FINAL_ROUND(1'b1)
    ) final_round_inst (
        .state_in(stage_reg[9]),
        .round_key(ROUND_KEYS[10]),
        .state_out(stage_next[10])
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int idx = 0; idx <= 10; idx++) begin
                stage_reg[idx] <= '0;
            end
            valid_pipe <= '0;
        end else begin
            // Stage 0 performs the initial AddRoundKey. Remaining stages are the
            // 9 standard rounds plus the final round, giving a 10-cycle latency.
            stage_reg[0] <= mapped_input ^ ROUND_KEYS[0];
            for (int idx = 1; idx <= 10; idx++) begin
                stage_reg[idx] <= stage_next[idx];
            end

            valid_pipe[0] <= valid_in;
            for (int idx = 1; idx <= 10; idx++) begin
                valid_pipe[idx] <= valid_pipe[idx - 1];
            end
        end
    end

    assign valid_out = valid_pipe[10];
    assign STATE_OUT = map_state_to_output(stage_reg[10]);

endmodule
