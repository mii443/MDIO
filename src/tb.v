module tb;

    parameter RATE = 1;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(3, tb);

        # (270000) $finish;
    end

    reg clk = 0;
    always #(RATE) clk = !clk;

    Top top(
        .CLK(clk)
    );

endmodule
