module spi_aes_wrapper (
    input  logic clk,       // Your main high-speed system clock (e.g., 100MHz)
    input  logic reset,
    
    // SPI Interface (from Master/Arduino)
    input  logic spi_cs_n,  // Chip Select (Active Low)
    input  logic spi_sclk,  // SPI Clock
    input  logic spi_mosi,  // Master Out Slave In
    output logic spi_miso,  // Master In Slave Out
    
    // Optional Interrupt to Master
    output logic data_ready 
);

    // ==========================================
    // 1. Synchronizers (CDC mitigation)
    // ==========================================
    logic [2:0] sclk_sync;
    logic [1:0] cs_n_sync, mosi_sync;

    always_ff @(posedge clk) begin
        if (reset) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 2'b11; // Default high
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], spi_sclk};
            cs_n_sync <= {cs_n_sync[0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    // ==========================================
    // 2. Edge Detection
    // ==========================================
    // Assuming SPI Mode 0 (CPOL=0, CPHA=0): Sample on rising edge, Shift on falling edge
    wire sclk_rising_edge  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling_edge = (sclk_sync[2:1] == 2'b10);
    wire cs_active         = ~cs_n_sync[1];
    
    // --- ADDED: Edge detection for Chip Select ---
    logic prev_cs_active;
    wire cs_just_activated = cs_active & ~prev_cs_active;

    // ==========================================
    // 3. Data Collection & AES Instantiation
    // ==========================================
    logic [7:0]   bit_counter;
    logic [127:0] rx_buffer;    // Collects incoming plaintext
    logic [127:0] tx_buffer;    // Holds outgoing ciphertext
    
    logic aes_start;
    logic aes_done;
    logic [127:0] aes_ciphertext;

    // Instantiate your modified rounds module here
    rounds aes_core (
        .clk(clk),
        .reset(reset),
        .start(aes_start),
        .data_in(rx_buffer),
        .done(aes_done),
        .STATE_OUT(aes_ciphertext)
    );

    // ==========================================
    // 4. Main Control Logic
    // ==========================================
    always_ff @(posedge clk) begin
        // --- ADDED: Track the CS state ---
        prev_cs_active <= cs_active;

        if (reset) begin
            bit_counter    <= 0;
            aes_start      <= 0;
            data_ready     <= 0;
            prev_cs_active <= 0;
        end else begin
            aes_start <= 0; // Default off (pulse generation)
            
            if (cs_active) begin
                // --- Receiving Data (MOSI) ---
                if (sclk_rising_edge) begin
                    rx_buffer   <= {rx_buffer[126:0], mosi_sync[1]}; // Shift left
                    bit_counter <= bit_counter + 1;

                    // Once 128 bits (16 bytes) are collected, trigger AES
                    if (bit_counter == 127) begin
                        aes_start   <= 1'b1;
                        bit_counter <= 0; // Reset for next potential block
                    end
                end
                
                // --- Transmitting Data (MISO) ---
                if (sclk_falling_edge) begin
                    tx_buffer <= {tx_buffer[126:0], 1'b0}; // Shift left
                end
            end else begin
                // CS is high (inactive), reset bit counter
                bit_counter <= 0;
            end

            // --- CHANGED: Capture AES output flag when done ---
            if (aes_done) begin
                data_ready <= 1'b1; // Tell the Master it can read now
            end
            
            // --- ADDED: Load the buffer ONLY when the Master pulls CS low for a new transaction ---
            if (cs_just_activated) begin
                tx_buffer <= aes_ciphertext;
            end
            
            // Clear interrupt when Master starts reading
            if (cs_active && sclk_rising_edge) begin
                 data_ready <= 1'b0;
            end
        end
    end

    // Drive MISO with the highest bit of the tx_buffer
    // Use high-Z when CS is inactive to play nice on the SPI bus
    assign spi_miso = cs_active ? tx_buffer[127] : 1'bz;

endmodule