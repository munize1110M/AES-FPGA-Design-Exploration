module spi_aes_wrapper (
    input  logic clk,
    input  logic reset,
    input  logic spi_cs_n,
    input  logic spi_sclk,
    input  logic spi_mosi,
    output logic spi_miso,
    output logic data_ready
);

    logic [2:0] sclk_sync;
    logic [1:0] cs_n_sync;
    logic [1:0] mosi_sync;

    logic [7:0]   bit_counter;
    logic [127:0] rx_buffer;
    logic [127:0] rx_shift_next;
    logic [127:0] aes_data_in;
    logic [127:0] tx_buffer;
    logic         valid_in;
    logic         valid_out;
    logic [127:0] aes_ciphertext;

    wire sclk_rising_edge  = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling_edge = (sclk_sync[2:1] == 2'b10);
    wire cs_active         = ~cs_n_sync[1];

    assign rx_shift_next = {rx_buffer[126:0], mosi_sync[1]};

    rounds aes_core (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .data_in(aes_data_in),
        .valid_out(valid_out),
        .STATE_OUT(aes_ciphertext)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            sclk_sync   <= '0;
            cs_n_sync   <= 2'b11;
            mosi_sync   <= '0;
            bit_counter <= '0;
            rx_buffer   <= '0;
            aes_data_in <= '0;
            tx_buffer   <= '0;
            valid_in    <= 1'b0;
            data_ready  <= 1'b0;
        end else begin
            sclk_sync <= {sclk_sync[1:0], spi_sclk};
            cs_n_sync <= {cs_n_sync[0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};

            valid_in <= 1'b0;

            if (cs_active) begin
                if (sclk_rising_edge) begin
                    rx_buffer <= rx_shift_next;

                    if (bit_counter == 8'd127) begin
                        // Launch exactly one AES block into the pipeline when the
                        // 128th bit arrives, then clear the receive buffer so the
                        // next SPI block can start immediately.
                        aes_data_in <= rx_shift_next;
                        valid_in    <= 1'b1;
                        rx_buffer   <= '0;
                        bit_counter <= '0;
                    end else begin
                        bit_counter <= bit_counter + 1'b1;
                    end

                    data_ready <= 1'b0;
                end

                if (sclk_falling_edge) begin
                    tx_buffer <= {tx_buffer[126:0], 1'b0};
                end
            end else begin
                bit_counter <= '0;
            end

            if (valid_out) begin
                // The AES pipeline runs independently of SPI bit timing. Latch the
                // newest ciphertext when the 10-stage valid pipeline says it is ready.
                tx_buffer  <= aes_ciphertext;
                data_ready <= 1'b1;
            end
        end
    end

    assign spi_miso = cs_active ? tx_buffer[127] : 1'bz;

endmodule
