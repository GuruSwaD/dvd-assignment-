// 4-bit x 4-bit unsigned array multiplier with registered inputs and output.
// Structure (Section 2 of the assignment guide):
//   row 0 : 4 AND gates only, p[0] = pp_0[0]
//   row 1-3: 4 AND gates + 4-bit ripple-carry adder (4 full adders) each
// Totals: 16 AND gates, 12 full adders, 16 flip-flops, latency = 2 cycles.
module mult_array (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [7:0] p
);

    // ---------------- input registers (8 flip-flops) ----------------
    reg [3:0] a_r, b_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'b0;
            b_r <= 4'b0;
        end else begin
            a_r <= a;
            b_r <= b;
        end
    end

    // ---------------- partial products (16 AND gates) ----------------
    // pp_i[j] = a[j] & b[i]
    wire [3:0] pp_0 = a_r & {4{b_r[0]}};
    wire [3:0] pp_1 = a_r & {4{b_r[1]}};
    wire [3:0] pp_2 = a_r & {4{b_r[2]}};
    wire [3:0] pp_3 = a_r & {4{b_r[3]}};

    // ---------------- row 0: no adders ----------------
    wire [3:0] r_0 = {1'b0, pp_0[3], pp_0[2], pp_0[1]};

    // ---------------- row 1: 4 full adders ----------------
    wire [3:0] s_1;
    wire [4:0] c_1;
    assign c_1[0] = 1'b0;

    full_adder fa1_0 (.a(pp_1[0]), .b(r_0[0]), .cin(c_1[0]), .sum(s_1[0]), .cout(c_1[1]));
    full_adder fa1_1 (.a(pp_1[1]), .b(r_0[1]), .cin(c_1[1]), .sum(s_1[1]), .cout(c_1[2]));
    full_adder fa1_2 (.a(pp_1[2]), .b(r_0[2]), .cin(c_1[2]), .sum(s_1[2]), .cout(c_1[3]));
    full_adder fa1_3 (.a(pp_1[3]), .b(r_0[3]), .cin(c_1[3]), .sum(s_1[3]), .cout(c_1[4]));

    wire [3:0] r_1 = {c_1[4], s_1[3], s_1[2], s_1[1]};

    // ---------------- row 2: 4 full adders ----------------
    wire [3:0] s_2;
    wire [4:0] c_2;
    assign c_2[0] = 1'b0;

    full_adder fa2_0 (.a(pp_2[0]), .b(r_1[0]), .cin(c_2[0]), .sum(s_2[0]), .cout(c_2[1]));
    full_adder fa2_1 (.a(pp_2[1]), .b(r_1[1]), .cin(c_2[1]), .sum(s_2[1]), .cout(c_2[2]));
    full_adder fa2_2 (.a(pp_2[2]), .b(r_1[2]), .cin(c_2[2]), .sum(s_2[2]), .cout(c_2[3]));
    full_adder fa2_3 (.a(pp_2[3]), .b(r_1[3]), .cin(c_2[3]), .sum(s_2[3]), .cout(c_2[4]));

    wire [3:0] r_2 = {c_2[4], s_2[3], s_2[2], s_2[1]};

    // ---------------- row 3: 4 full adders ----------------
    wire [3:0] s_3;
    wire [4:0] c_3;
    assign c_3[0] = 1'b0;

    full_adder fa3_0 (.a(pp_3[0]), .b(r_2[0]), .cin(c_3[0]), .sum(s_3[0]), .cout(c_3[1]));
    full_adder fa3_1 (.a(pp_3[1]), .b(r_2[1]), .cin(c_3[1]), .sum(s_3[1]), .cout(c_3[2]));
    full_adder fa3_2 (.a(pp_3[2]), .b(r_2[2]), .cin(c_3[2]), .sum(s_3[2]), .cout(c_3[3]));
    full_adder fa3_3 (.a(pp_3[3]), .b(r_2[3]), .cin(c_3[3]), .sum(s_3[3]), .cout(c_3[4]));

    // ---------------- combinational product ----------------
    wire [7:0] p_comb = {c_3[4], s_3[3], s_3[2], s_3[1], s_3[0], s_2[0], s_1[0], pp_0[0]};

    // ---------------- output register (8 flip-flops) ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            p <= 8'b0;
        else
            p <= p_comb;
    end

endmodule
