`timescale 1ns / 1ps

module tb_spi_aes_wrapper;

    // ==========================================
    // Signals
    // ==========================================
    logic clk;
    logic reset;
    
    logic spi_cs_n;
    logic spi_sclk;
    logic spi_mosi;
    logic spi_miso;
    logic data_ready;

    // Test data arrays (16 bytes each)
    logic [7:0] plaintext [0:15];
    logic [7:0] ciphertext [0:15];
    logic [7:0] dummy_rx;

    // ==========================================
    // Clock Generation
    // ==========================================
    // 100 MHz System Clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // Device Under Test (DUT)
    // ==========================================
    spi_aes_wrapper dut (
        .clk(clk),
        .reset(reset),
        .spi_cs_n(spi_cs_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .data_ready(data_ready)
    );

    // ==========================================
    // SPI Master Emulation Task (Mode 0)
    // ==========================================
    // This task mimics the Raspberry Pi sending and receiving 1 byte
    task spi_transfer_byte(input logic [7:0] tx_data, output logic [7:0] rx_data);
        integer i;
        begin
            for (i = 7; i >= 0; i--) begin
                spi_mosi = tx_data[i];       // Master setup data on MOSI
                
                #50;                         // Half SPI clock period (10 MHz SPI = 100ns period)
                spi_sclk = 1'b1;             // Rising edge
                rx_data[i] = spi_miso;       // Master samples MISO
                
                #50;
                spi_sclk = 1'b0;             // Falling edge
            end
        end
    endtask

    // ==========================================
    // Main Stimulus Block
    // ==========================================
    initial begin
        // 1. Initialize Inputs
        reset    = 1;
        spi_cs_n = 1;
        spi_sclk = 0;
        spi_mosi = 0;

        // Initialize test plaintext (matches your Python example: 0x01, 0x02... 0x10)
        /*for (int i = 0; i < 16; i++) begin
            plaintext[i] = i + 1; 
        end*/
// 1. Initialize Inputs
        reset    = 1;
        spi_cs_n = 1;
        spi_sclk = 0;
        spi_mosi = 0;

        // FIPS 197 Appendix B Plaintext Test Vector
        plaintext[0]  = 8'h32;
        plaintext[1]  = 8'h43;
        plaintext[2]  = 8'hF6;
        plaintext[3]  = 8'hA8;
        plaintext[4]  = 8'h88;
        plaintext[5]  = 8'h5A;
        plaintext[6]  = 8'h30;
        plaintext[7]  = 8'h8D;
        plaintext[8]  = 8'h31;
        plaintext[9]  = 8'h31;
        plaintext[10] = 8'h98;
        plaintext[11] = 8'hA2;
        plaintext[12] = 8'hE0;
        plaintext[13] = 8'h37;
        plaintext[14] = 8'h07;
        plaintext[15] = 8'h34;

        // 2. Apply Reset
        #100;
        reset = 0;
        #100;

        $display("-----------------------------------------");
        $display("Starting AES SPI Simulation...");
        $display("-----------------------------------------");

        // 3. Send Plaintext (Pi -> FPGA)
        $display("1. Master asserting CS and sending 16 bytes of plaintext...");
        spi_cs_n = 0;
        #50; // Brief delay after CS drops
        
        for (int j = 0; j < 16; j++) begin
            spi_transfer_byte(plaintext[j], dummy_rx);
        end
        
        #50; 
        spi_cs_n = 1; // Master de-asserts CS
        $display("   Plaintext transmission complete.");

        // 4. Wait for FPGA to finish encrypting
        $display("2. Waiting for data_ready interrupt from FPGA...");
        wait(data_ready == 1'b1);
        $display("   Interrupt received! Data is ready.");
        #100;

        // 5. Read Ciphertext (FPGA -> Pi)
        $display("3. Master asserting CS to read ciphertext...");
        spi_cs_n = 0;
        #50;
        
        for (int k = 0; k < 16; k++) begin
            // Send dummy bytes (0x00) to clock out the ciphertext
            spi_transfer_byte(8'h00, ciphertext[k]);
        end
        
        #50;
        spi_cs_n = 1;

        // 6. Display Results
        $display("-----------------------------------------");
        $display("Encryption Complete.");
        $display("Ciphertext received by Master:");
        for (int m = 0; m < 16; m++) begin
            $write("%02X ", ciphertext[m]);
        end
        $display("\n-----------------------------------------");

        // Finish simulation
        #200;
        $finish;
    end

endmodule