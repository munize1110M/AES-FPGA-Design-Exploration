`timescale 1ns / 1ps

module tb_aes_pipelined;

    localparam int NUM_BLOCKS = 3;
    localparam logic [127:0] FIPS_PLAINTEXT  = 128'h3243F6A8_885A308D_313198A2_E0370734;
    localparam logic [127:0] FIPS_CIPHERTEXT = 128'h3925841D_02DC09FB_DC118597_196A0B32;

    logic clk;
    logic reset;
    logic valid_in;
    logic valid_out;
    logic [127:0] data_in;
    logic [127:0] state_out;

    integer cycle_count;
    integer launch_count;
    integer complete_count;
    integer launch_cycles [0:NUM_BLOCKS-1];

    rounds dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .STATE_OUT(state_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (reset) begin
            cycle_count    <= 0;
            launch_count   <= 0;
            complete_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            #1;

            if (dut.valid_pipe[0] && (launch_count < NUM_BLOCKS)) begin
                launch_cycles[launch_count] <= cycle_count;
                $display("[%0t] AES launch %0d at cycle %0d, plaintext = %032h",
                         $time, launch_count, cycle_count, dut.stage_reg[0] ^ dut.ROUND_KEYS[0]);
                launch_count <= launch_count + 1;
            end

            if (valid_out && (complete_count < NUM_BLOCKS)) begin
                $display("[%0t] AES result %0d at cycle %0d, latency = %0d cycles, ciphertext = %032h",
                         $time, complete_count, cycle_count,
                         cycle_count - launch_cycles[complete_count], state_out);

                if (state_out !== FIPS_CIPHERTEXT) begin
                    $error("Ciphertext mismatch for block %0d. Expected %032h, got %032h",
                           complete_count, FIPS_CIPHERTEXT, state_out);
                end

                if ((cycle_count - launch_cycles[complete_count]) != 10) begin
                    $error("Pipeline latency mismatch for block %0d. Expected 10 cycles, got %0d",
                           complete_count, cycle_count - launch_cycles[complete_count]);
                end

                complete_count <= complete_count + 1;
            end
        end
    end

    task automatic drive_block(input logic [127:0] block_data);
        begin
            @(negedge clk);
            data_in   <= block_data;
            valid_in  <= 1'b1;

            //@(negedge clk);
            //valid_in  <= 1'b0;
            //data_in   <= '0;
        end
    endtask

    initial begin
        reset    = 1'b1;
        valid_in = 1'b0;
        data_in  = '0;

        #40;
        @(negedge clk);
        reset <= 1'b0;

        $display("------------------------------------------------------------");
        $display("Driving %0d AES-128 plaintext blocks directly into the core", NUM_BLOCKS);
        $display("Expected FIPS-197 Appendix B ciphertext: %032h", FIPS_CIPHERTEXT);
        $display("Pipeline target: 1 block/cycle after 10-cycle latency");
        $display("------------------------------------------------------------");

        for (int block_idx = 0; block_idx < NUM_BLOCKS; block_idx++) begin
            $display("[%0t] Scheduling plaintext block %0d = %032h",
                     $time, block_idx, FIPS_PLAINTEXT);
            drive_block(FIPS_PLAINTEXT);
        end

        wait (complete_count == NUM_BLOCKS);

        $display("All direct AES pipeline checks completed.");
        #40;
        $finish;
    end

endmodule
