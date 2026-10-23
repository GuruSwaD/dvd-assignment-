// Exhaustive, self-checking testbench for mult_array.
// - 10 ns clock, rst_n held low for the first 2 cycles
// - applies all 256 (a, b) combinations
// - waits for the 2-cycle latency, then compares p with a * b
// - prints every mismatch and one PASS/FAIL summary line
// - dumps waveforms to mult.vcd
`timescale 1ns / 1ps

module tb_mult;

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    integer i, j;
    integer vectors;
    integer errors;
    reg [7:0] expected;

    mult_array dut (
        .clk  (clk),
        .rst_n(rst_n),
        .a    (a),
        .b    (b),
        .p    (p)
    );

    // 10 ns period clock: rising edges at 5, 15, 25, ... ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
        $timeformat(-9, 0, " ns", 0);

        rst_n   = 1'b0;
        a       = 4'd0;
        b       = 4'd0;
        vectors = 0;
        errors  = 0;

        // hold reset low for the first 2 clock cycles
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // inputs change on a falling edge, away from the sampling edge
                a = i[3:0];
                b = j[3:0];
                expected = i * j;

                @(posedge clk);   // edge 1: a, b captured into input registers
                @(posedge clk);   // edge 2: product captured into p
                @(negedge clk);   // check in the middle of the cycle

                vectors = vectors + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH at %0t: a=%0d b=%0d p=%0d expected=%0d",
                             $time, a, b, p, expected);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", vectors, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", vectors, errors);

        $finish;
    end

endmodule
