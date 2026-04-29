`timescale 1ns / 1ps

module tb_spi_aes_wrapper;

    localparam int NUM_BLOCKS = 3;
    localparam logic [127:0] FIPS_PLAINTEXT  = 128'h3243F6A8_885A308D_313198A2_E0370734;
    localparam logic [127:0] FIPS_CIPHERTEXT = 128'h3925841D_02DC09FB_DC118597_196A0B32;

    logic clk;
    logic reset;
    logic spi_cs_n;
    logic spi_sclk;
    logic spi_mosi;
    logic spi_miso;
    logic data_ready;

    logic [127:0] block_rx;
    integer       cycle_count;
    integer       launch_cycles [0:NUM_BLOCKS-1];
    integer       launch_count;
    integer       complete_count;

    spi_aes_wrapper dut (
        .clk(clk),
        .reset(reset),
        .spi_cs_n(spi_cs_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .data_ready(data_ready)
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

            // Measure latency from the point where the AES core itself accepts
            // the block into stage 0, not from the wrapper's pre-core pulse.
            if (dut.aes_core.valid_pipe[0] && (launch_count < NUM_BLOCKS)) begin
                launch_cycles[launch_count] <= cycle_count;
                $display("[%0t] AES launch %0d at cycle %0d, block = %032h",
                         $time, launch_count, cycle_count, dut.aes_data_in);
                launch_count <= launch_count + 1;
            end

            if (dut.aes_core.valid_out && (complete_count < NUM_BLOCKS)) begin
                $display("[%0t] AES result %0d at cycle %0d, latency = %0d cycles, ciphertext = %032h",
                         $time, complete_count, cycle_count,
                         cycle_count - launch_cycles[complete_count],
                         dut.aes_ciphertext);

                if (dut.aes_ciphertext !== FIPS_CIPHERTEXT) begin
                    $error("Ciphertext mismatch for block %0d. Expected %032h, got %032h",
                           complete_count, FIPS_CIPHERTEXT, dut.aes_ciphertext);
                end

                if ((cycle_count - launch_cycles[complete_count]) != 10) begin
                    $error("Pipeline latency mismatch for block %0d. Expected 10 cycles, got %0d",
                           complete_count, cycle_count - launch_cycles[complete_count]);
                end

                complete_count <= complete_count + 1;
            end
        end
    end

    task automatic spi_transfer_byte(
        input  logic [7:0] tx_data,
        output logic [7:0] rx_data
    );
        for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
            spi_mosi = tx_data[bit_idx];
            #20;
            spi_sclk = 1'b1;
            #20;
            rx_data[bit_idx] = spi_miso;
            spi_sclk = 1'b0;
            #20;
        end
    endtask

    task automatic spi_send_block(input logic [127:0] block_data);
        logic [7:0] dummy_rx;
        logic [7:0] byte_value;
        begin
            for (int idx = 0; idx < 16; idx++) begin
                byte_value = block_data[127 - (idx * 8) -: 8];
                spi_transfer_byte(byte_value, dummy_rx);
            end
        end
    endtask

    task automatic spi_read_block(output logic [127:0] block_data);
        logic [7:0] rx_byte;
        begin
            for (int idx = 0; idx < 16; idx++) begin
                spi_transfer_byte(8'h00, rx_byte);
                block_data[127 - (idx * 8) -: 8] = rx_byte;
            end
        end
    endtask

    initial begin
        reset    = 1'b1;
        spi_cs_n = 1'b1;
        spi_sclk = 1'b0;
        spi_mosi = 1'b0;
        block_rx = '0;

        #100;
        reset = 1'b0;
        #40;

        $display("------------------------------------------------------------");
        $display("Streaming %0d AES-128 plaintext blocks over SPI with CS held low", NUM_BLOCKS);
        $display("Expected FIPS-197 Appendix B ciphertext: %032h", FIPS_CIPHERTEXT);
        $display("------------------------------------------------------------");

        spi_cs_n = 1'b0;
        for (int block_idx = 0; block_idx < NUM_BLOCKS; block_idx++) begin
            $display("[%0t] Sending plaintext block %0d = %032h",
                     $time, block_idx, FIPS_PLAINTEXT);
            spi_send_block(FIPS_PLAINTEXT);
        end
        spi_cs_n = 1'b1;

        wait (complete_count == NUM_BLOCKS);

        if (!data_ready) begin
            wait (data_ready == 1'b1);
        end

        #40;
        spi_cs_n = 1'b0;
        spi_read_block(block_rx);
        spi_cs_n = 1'b1;

        $display("Latest ciphertext shifted back over MISO = %032h", block_rx);
        if (block_rx !== FIPS_CIPHERTEXT) begin
            $error("SPI readback mismatch. Expected %032h, got %032h", FIPS_CIPHERTEXT, block_rx);
        end

        $display("All AES pipeline and SPI wrapper checks completed.");
        #100;
        $finish;
    end

endmodule
