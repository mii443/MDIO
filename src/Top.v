module Top(
    input CLK,
    output MDC,
    inout MDIO,
    output [3:0] LED
);

    reg [4:0] mdc_cnt = 0;
    reg mdc_cnt_half = 0;
    reg mdc_cnt_half_flag = 1;
    wire mdclock;
    wire [15:0] mdc_cnt_max;
    reg [15:0] reg_mdc_cnt_max = 30;

    always @(posedge CLK) begin
        mdc_cnt <= mdclock ? 0 : mdc_cnt + 1;
    end

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
    reg read_flag = 1;

    reg mdio_write = 0;
    reg mdio_out_en = 0;

    assign MDIO = mdio_out_en ? mdio_write : 1'bz;

    reg [3:0] read_preamble = 4'b0110;
    reg [3:0] write_preamble = 4'b0101;

    reg [4:0] reg_phy_address = 5'b00001;
    reg [4:0] reg_register_address = 5'b00000;

    reg [15:0] read = 16'b0;
    reg [15:0] write = 16'b0000111111111010;

    reg [15:0] led_read = 0;

    // STATE MACHINE
    always @(posedge mdclock) begin
        case (state)
            S_IDLE: begin
                state <= S_PREAMBLE;
                mdc_cnt_half <= 0;
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
                read_flag <= 1;
            end
        endcase
    end

    assign mdc_cnt_max = reg_mdc_cnt_max;
    assign mdclock = mdc_cnt == mdc_cnt_max;
    assign MDC = mdclock;

    assign LED = ~read[9:6];

endmodule;
