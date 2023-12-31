module Top(
    input CLK,

// MDIO
    output MDC,
    inout MDIO,

// RMII
    input RMII_CLK,
    input [1:0] RMII_RX,
    output RMII_RST,

    output [3:0] LED,
    output UART_TX
);

    reg [31:0] rmii_cnt = 0;
    reg [3:0] reg_led = 1;
    reg [7:0] eth_in = 0;
    reg [15:0] preamble = 0;
    reg [8:0] preamble_cnt = 0;
    
    always @(posedge RMII_CLK) begin
        preamble <= preamble << 2;
        preamble[0:0] <= RMII_RX[0:0];
        preamble[1:1] <= RMII_RX[1:1];

        if (preamble == 16'hd555) begin
            reg_led = reg_led + 1;
        end
    end

    assign RMII_RST = 1;


    reg [7:0] uart_data;
    reg uart_start;
    wire uart_busy;

    UART uart(
        .clock(CLK),
        .data_in(uart_data),
        .start(uart_start),
        .tx_busy(uart_busy),
        .tx(UART_TX)
    );

    always @(posedge CLK) begin
        uart_data <= 8'b10000001;
        uart_start <= 1'b1;
    end

    reg [4:0] mdc_cnt = 0;
    wire mdclock;

    always @(posedge CLK)
        mdc_cnt <= mdclock ? 0 : mdc_cnt + 1;

    localparam S_IDLE = 0;
    localparam S_PREAMBLE = 1;
    localparam S_READ = 2;
    localparam S_WRITE = 3;
    localparam S_READ_PREAMBLE = 4;
    localparam S_WRITE_PREAMBLE = 5;
    localparam S_PHY = 6;
    localparam S_REG = 7;
    localparam S_TURN = 8;

    reg [3:0] state = S_IDLE;

    reg [31:0] cnt = 0;
    reg read_flag = 0;

    reg mdio_write = 0;
    reg mdio_out_en = 0;

    assign MDIO = mdio_out_en ? mdio_write : 1'bz;

    reg [3:0] read_preamble = 4'b0110;
    reg [3:0] write_preamble = 4'b0101;

    reg [4:0] reg_phy_address = 5'b00011;
    reg [4:0] reg_register_address = 5'b00101;

    reg [15:0] read = 16'b0000000000000000;
    reg [15:0] write = 16'b0000111111111010;

    reg [15:0] led_read = 0;

    // STATE MACHINE
    always @(posedge mdclock) begin
        case (state)
            S_IDLE: begin
                state <= S_PREAMBLE;
            end

            S_PREAMBLE: begin
                if (cnt == 31) begin
                    cnt = 0;
                    if (read_flag == 1'b1)
                        state <= S_READ_PREAMBLE;
                    else
                        state <= S_WRITE_PREAMBLE;
                end else begin
                    state <= S_PREAMBLE;
                    cnt <= cnt + 1;
                end
            end

            S_READ_PREAMBLE: begin
                if (cnt == 3) begin
                    state <= S_PHY;
                    cnt <= 0;
                end else begin
                    state <= S_READ_PREAMBLE;
                    cnt <= cnt + 1;
                end
            end

            S_WRITE_PREAMBLE: begin
                if (cnt == 3) begin
                    state <= S_PHY;
                    cnt <= 0;
                end else begin
                    state <= S_WRITE_PREAMBLE;
                    cnt <= cnt + 1;
                end
            end

            S_PHY: begin
                if (cnt == 4) begin
                    state <= S_REG;
                    cnt <= 0;
                end else begin
                    state <= S_PHY;
                    cnt <= cnt + 1;
                end
            end

            S_REG: begin
                if (cnt == 4) begin
                    state <= S_TURN;
                    cnt <= 0;
                end else begin
                    state <= S_REG;
                    cnt <= cnt + 1;
                end
            end

            S_TURN: begin
                if (cnt == 1) begin
                    cnt <= 0;
                    if (read_flag == 1)
                        state <= S_READ;
                    else
                        state <= S_WRITE;
                end else begin
                    state <= S_TURN;
                    cnt <= cnt + 1;
                end
            end

            S_READ: begin
                if (cnt == 15) begin
                    state <= S_IDLE;
                    cnt <= 0;
                end else begin
                    state <= S_READ;
                    cnt <= cnt + 1;
                end
            end

            S_WRITE: begin
                if (cnt == 15) begin
                    state <= S_IDLE;
                    cnt <= 0;
                end else begin
                    state <= S_WRITE;
                    cnt <= cnt + 1;
                end
            end
        endcase
    end

    // REG
    always @(posedge CLK) begin
        case (state)
            S_IDLE: begin
                mdio_out_en = 1;
                mdio_write = 0;
                led_read <= read;
            end

            S_PREAMBLE: begin
                mdio_out_en = 1;
                mdio_write = 1;
            end

            S_READ_PREAMBLE: begin
                mdio_out_en = 1;
                mdio_write = read_preamble[cnt];
            end

            S_WRITE_PREAMBLE: begin
                mdio_out_en = 1;
                mdio_write = write_preamble[cnt];
            end

            S_PHY: begin
                mdio_out_en = 1;
                mdio_write = reg_phy_address[4 - cnt];
            end

            S_REG: begin
                mdio_out_en = 1;
                mdio_write = reg_register_address[4 - cnt];
            end

            S_TURN: begin
                mdio_out_en = ~read_flag;
                mdio_write = 0;
            end

            S_READ: begin
                mdio_out_en = 0;
                read[15 - cnt] <= MDIO;
            end

            S_WRITE: begin
                mdio_out_en = 1;
                mdio_write <= write[15 - cnt];
                read_flag <= 0;
            end
        endcase
    end

    assign mdclock = mdc_cnt == 27;
    assign MDC = mdclock;

    assign LED = ~reg_led;


endmodule;
