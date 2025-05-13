module  FFT (
    input         clk      ,
    input         rst      ,
    input  [15:0] fir_d    ,
    input         fir_valid,
    output        fft_valid,
    output        done     ,
    output [15:0] fft_d1   ,
    output [15:0] fft_d2   ,
    output [15:0] fft_d3   ,
    output [15:0] fft_d4   ,
    output [15:0] fft_d5   ,
    output [15:0] fft_d6   ,
    output [15:0] fft_d7   ,
    output [15:0] fft_d8   ,
    output [15:0] fft_d9   ,
    output [15:0] fft_d10  ,
    output [15:0] fft_d11  ,
    output [15:0] fft_d12  ,
    output [15:0] fft_d13  ,
    output [15:0] fft_d14  ,
    output [15:0] fft_d15  ,
    output [15:0] fft_d0
);

/////////////////////////////////
// Please write your code here //
/////////////////////////////////

//////////////////////////////////////////////////////////////////////
// State
//////////////////////////////////////////////////////////////////////

localparam READ        = 4'd0, // Read first 16 input data
           STAGE1      = 4'd1,
           STAGE1_IDLE = 4'd2, // Wait for butterfly unit done
           STAGE2      = 4'd3,
           STAGE2_IDLE = 4'd4,
           STAGE3      = 4'd5,
           STAGE3_IDLE = 4'd6,
           STAGE4      = 4'd7,
           STAGE4_IDLE = 4'd8,
           IDLE        = 4'd9, // Wait for output
           DONE        = 4'd10;

//////////////////////////////////////////////////////////////////////
// FFT coefficient
//////////////////////////////////////////////////////////////////////

wire [31:0] wnk_real [0:7];
assign wnk_real[0] = 32'h00010000;
assign wnk_real[1] = 32'h0000EC83;
assign wnk_real[2] = 32'h0000B504;
assign wnk_real[3] = 32'h000061F7;
assign wnk_real[4] = 32'h00000000;
assign wnk_real[5] = 32'hFFFF9E09;
assign wnk_real[6] = 32'hFFFF4AFC;
assign wnk_real[7] = 32'hFFFF137D;

wire [31:0] wnk_imag [0:7];
assign wnk_imag[0] = 32'h00000000;
assign wnk_imag[1] = 32'hFFFF9E09;
assign wnk_imag[2] = 32'hFFFF4AFC;
assign wnk_imag[3] = 32'hFFFF137D;
assign wnk_imag[4] = 32'hFFFF0000;
assign wnk_imag[5] = 32'hFFFF137D;
assign wnk_imag[6] = 32'hFFFF4AFC;
assign wnk_imag[7] = 32'hFFFF9E09;

reg [3:0] state, next_state;

reg [15:0] fir_buf[0:15];
reg [3:0] fir_len;

// butterfly_unit input
reg [17:0] a [0:7];
reg [17:0] b [0:7];
reg [17:0] c [0:7];
reg [17:0] d [0:7];
reg [17:0] w_real [0:7];
reg [17:0] w_imag [0:7];

// butterfly_unit output
wire [17:0] p_real [0:7];
wire [17:0] p_imag [0:7];
wire [17:0] q_real [0:7];
wire [17:0] q_imag [0:7];

wire butterfly_en;
wire [7:0] butterfly_valid;

wire output_en;
wire output_done;

integer i;

generate
    genvar j;
    for (j = 0; j < 8; j = j + 1) begin : butterfly_gen
        Butterfly butterfly_unit (
            .clk   (clk),
            .rst   (rst),
            .en    (butterfly_en),
            .a     (a[j]),
            .b     (b[j]),
            .c     (c[j]),
            .d     (d[j]),
            .valid (butterfly_valid[j]),
            .w_real(w_real[j]),
            .w_imag(w_imag[j]),
            .p_real(p_real[j]),
            .p_imag(p_imag[j]),
            .q_real(q_real[j]),
            .q_imag(q_imag[j])
        );
    end
endgenerate

OutputController output_controller (
    .clk      (clk),
    .rst      (rst),
    .en       (output_en),
    .p_real0  (p_real[0][17:2]), .p_real1(p_real[1][17:2]), .p_real2(p_real[2][17:2]), .p_real3(p_real[3][17:2]),
    .p_real4  (p_real[4][17:2]), .p_real5(p_real[5][17:2]), .p_real6(p_real[6][17:2]), .p_real7(p_real[7][17:2]),
    .p_imag0  (p_imag[0][17:2]), .p_imag1(p_imag[1][17:2]), .p_imag2(p_imag[2][17:2]), .p_imag3(p_imag[3][17:2]),
    .p_imag4  (p_imag[4][17:2]), .p_imag5(p_imag[5][17:2]), .p_imag6(p_imag[6][17:2]), .p_imag7(p_imag[7][17:2]),
    .q_real0  (q_real[0][17:2]), .q_real1(q_real[1][17:2]), .q_real2(q_real[2][17:2]), .q_real3(q_real[3][17:2]),
    .q_real4  (q_real[4][17:2]), .q_real5(q_real[5][17:2]), .q_real6(q_real[6][17:2]), .q_real7(q_real[7][17:2]),
    .q_imag0  (q_imag[0][17:2]), .q_imag1(q_imag[1][17:2]), .q_imag2(q_imag[2][17:2]), .q_imag3(q_imag[3][17:2]),
    .q_imag4  (q_imag[4][17:2]), .q_imag5(q_imag[5][17:2]), .q_imag6(q_imag[6][17:2]), .q_imag7(q_imag[7][17:2]),
    .done     (output_done),
    .fft_valid(fft_valid),
    .fft_d0   (fft_d0),  .fft_d1   (fft_d1),  .fft_d2   (fft_d2),  .fft_d3   (fft_d3),
    .fft_d4   (fft_d4),  .fft_d5   (fft_d5),  .fft_d6   (fft_d6),  .fft_d7   (fft_d7),
    .fft_d8   (fft_d8),  .fft_d9   (fft_d9),  .fft_d10  (fft_d10), .fft_d11  (fft_d11),
    .fft_d12  (fft_d12), .fft_d13  (fft_d13), .fft_d14  (fft_d14), .fft_d15  (fft_d15)
);

//////////////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////////////

always @(*) begin
    case (state)
        READ:
            next_state = (fir_valid && fir_len == 15) ? STAGE1 :
                         (!fir_valid && output_done) ? DONE : READ;
        STAGE1:
            next_state = STAGE1_IDLE;
        STAGE1_IDLE:
            next_state = butterfly_valid[0] ? STAGE2 : STAGE1_IDLE;
        STAGE2:
            next_state = STAGE2_IDLE;
        STAGE2_IDLE:
            next_state = butterfly_valid[0] ? STAGE3 : STAGE2_IDLE;
        STAGE3:
            next_state = STAGE3_IDLE;
        STAGE3_IDLE:
            next_state = butterfly_valid[0] ? STAGE4 : STAGE3_IDLE;
        STAGE4:
            next_state = STAGE4_IDLE;
        STAGE4_IDLE:
            next_state = butterfly_valid[0] ?
            (!fir_valid ? IDLE : STAGE1) :
            STAGE4_IDLE;
        IDLE:
            next_state = output_done ? DONE : IDLE;
        DONE:
            next_state = DONE;
        default:
            next_state = READ;
    endcase
end

//////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////

// fir_buf
always @(posedge clk) begin
    case (state)
        READ, STAGE1, STAGE2, STAGE3, STAGE4,
        STAGE1_IDLE, STAGE2_IDLE, STAGE3_IDLE, STAGE4_IDLE:
            fir_buf[fir_len] <= fir_valid ? fir_d : fir_buf[fir_len];
    endcase
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

// fir_len
always @(posedge clk or posedge rst) begin
    if (rst)
        fir_len <= 0;
    else
    case (state)
        READ, STAGE1, STAGE2, STAGE3, STAGE4,
        STAGE1_IDLE, STAGE2_IDLE, STAGE3_IDLE, STAGE4_IDLE:
            fir_len <= fir_valid ? fir_len + 1 : fir_len;
    endcase
end

// butterfly inputs
always @(posedge clk) begin
    case (next_state)
        STAGE1: begin
            for (i = 0; i < 8; i = i + 1) begin
                a[i]      <= { fir_buf[i], 2'b0 };
                b[i]      <= 18'b0;
                c[i]      <= i == 7 ? { fir_d, 2'b0 } :
                                      { fir_buf[i + 8], 2'b0 };
                d[i]      <= 18'b0;
                w_real[i] <= wnk_real[i][23:6];
                w_imag[i] <= wnk_imag[i][23:6];
            end
        end
        STAGE2: begin
            for (i = 0; i < 4; i = i + 1) begin
                a[i]      <= p_real[i];
                b[i]      <= p_imag[i];
                c[i]      <= p_real[i + 4];
                d[i]      <= p_imag[i + 4];
                w_real[i] <= wnk_real[i << 1][23:6];
                w_imag[i] <= wnk_imag[i << 1][23:6];
            end
            for (i = 4; i < 8; i = i + 1) begin
                a[i]      <= q_real[i - 4];
                b[i]      <= q_imag[i - 4];
                c[i]      <= q_real[i];
                d[i]      <= q_imag[i];
                w_real[i] <= wnk_real[(i - 4) << 1][23:6];
                w_imag[i] <= wnk_imag[(i - 4) << 1][23:6];
            end
        end
        STAGE3: begin
            for (i = 0; i < 2; i = i + 1) begin
                a[i]      <= p_real[i];
                b[i]      <= p_imag[i];
                c[i]      <= p_real[i + 2];
                d[i]      <= p_imag[i + 2];
                w_real[i] <= wnk_real[i << 2][23:6];
                w_imag[i] <= wnk_imag[i << 2][23:6];
            end
            for (i = 2; i < 4; i = i + 1) begin
                a[i]      <= q_real[i - 2];
                b[i]      <= q_imag[i - 2];
                c[i]      <= q_real[i];
                d[i]      <= q_imag[i];
                w_real[i] <= wnk_real[(i - 2) << 2][23:6];
                w_imag[i] <= wnk_imag[(i - 2) << 2][23:6];
            end
            for (i = 4; i < 6; i = i + 1) begin
                a[i]      <= p_real[i];
                b[i]      <= p_imag[i];
                c[i]      <= p_real[i + 2];
                d[i]      <= p_imag[i + 2];
                w_real[i] <= wnk_real[(i - 4) << 2][23:6];
                w_imag[i] <= wnk_imag[(i - 4) << 2][23:6];
            end
            for (i = 6; i < 8; i = i + 1) begin
                a[i]      <= q_real[i - 2];
                b[i]      <= q_imag[i - 2];
                c[i]      <= q_real[i];
                d[i]      <= q_imag[i];
                w_real[i] <= wnk_real[(i - 6) << 2][23:6];
                w_imag[i] <= wnk_imag[(i - 6) << 2][23:6];
            end
        end
        STAGE4: begin
            a[0] <= p_real[0];
            a[1] <= q_real[0];
            a[2] <= p_real[2];
            a[3] <= q_real[2];
            a[4] <= p_real[4];
            a[5] <= q_real[4];
            a[6] <= p_real[6];
            a[7] <= q_real[6];

            b[0] <= p_imag[0];
            b[1] <= q_imag[0];
            b[2] <= p_imag[2];
            b[3] <= q_imag[2];
            b[4] <= p_imag[4];
            b[5] <= q_imag[4];
            b[6] <= p_imag[6];
            b[7] <= q_imag[6];

            c[0] <= p_real[1];
            c[1] <= q_real[1];
            c[2] <= p_real[3];
            c[3] <= q_real[3];
            c[4] <= p_real[5];
            c[5] <= q_real[5];
            c[6] <= p_real[7];
            c[7] <= q_real[7];

            d[0] <= p_imag[1];
            d[1] <= q_imag[1];
            d[2] <= p_imag[3];
            d[3] <= q_imag[3];
            d[4] <= p_imag[5];
            d[5] <= q_imag[5];
            d[6] <= p_imag[7];
            d[7] <= q_imag[7];

            for (i = 0; i < 8; i = i + 1) begin
                w_real[i] <= wnk_real[0][23:6];
                w_imag[i] <= wnk_imag[0][23:6];
            end
        end
        default: begin
            for (i = 0; i < 8; i = i + 1) begin
                a[i]      <= a[i];
                b[i]      <= b[i];
                c[i]      <= c[i];
                d[i]      <= d[i];
                w_real[i] <= w_real[i];
                w_imag[i] <= w_imag[i];
            end
        end
    endcase
end

assign butterfly_en = (state == STAGE1 || state == STAGE2 ||
                       state == STAGE3 ||state == STAGE4);
assign output_en = (state == STAGE4_IDLE &&
                    butterfly_valid[0]);

// state
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= READ;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

assign done = (state == DONE);

endmodule

module Butterfly (
    input         clk,
    input         rst,
    input         en,
    input  [17:0] a,
    input  [17:0] b,
    input  [17:0] c,
    input  [17:0] d,
    input  [17:0] w_real,
    input  [17:0] w_imag,
    output        valid,
    output [17:0] p_real,
    output [17:0] p_imag,
    output [17:0] q_real,
    output [17:0] q_imag
);

reg [1:0] counter;

reg signed [17:0] x0, x1, x2, x3, w0, w1;
reg signed [17:0] x2_tmp, x3_tmp;
reg signed [35:0] prod0, prod1, prod2, prod3;
reg signed [17:0] sum0, sum1;

//////////////////////////////////////////////////////////////////////
// Data & Control
//////////////////////////////////////////////////////////////////////

// pipeline
always @(posedge clk) begin
    x0 <= a - c;
    x1 <= d - b;
    x2 <= a + c;
    x3 <= b + d;
    w0 <= w_real;
    w1 <= w_imag;
end

always @(posedge clk) begin
    x2_tmp <= x2;
    x3_tmp <= x3;
    prod0 <= x0 * w0; // (a - c) * w_real
    prod1 <= x1 * w1; // (d - b) * w_imag
    prod2 <= x0 * w1; // (a - c) * w_imag
    prod3 <= x1 * w0; // (d - b) * w_real
end

always @(posedge clk) begin
    sum0 <= prod0[10 +: 18] + prod1[10 +: 18];
    sum1 <= prod2[10 +: 18] - prod3[10 +: 18];
end

always @(posedge clk) begin
    if (en)
        counter <= 2'd0;
    else
        counter <= (counter == 2'd2) ? 2'd0 : counter + 2'd1;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

assign valid = (counter == 2'd2);
assign p_real = x2_tmp;
assign p_imag = x3_tmp;
assign q_real = sum0;
assign q_imag = sum1;

endmodule

module OutputController (
    input             clk,
    input             rst,
    input             en,
    input      [15:0] p_real0  ,
    input      [15:0] p_real1  ,
    input      [15:0] p_real2  ,
    input      [15:0] p_real3  ,
    input      [15:0] p_real4  ,
    input      [15:0] p_real5  ,
    input      [15:0] p_real6  ,
    input      [15:0] p_real7  ,
    input      [15:0] p_imag0  ,
    input      [15:0] p_imag1  ,
    input      [15:0] p_imag2  ,
    input      [15:0] p_imag3  ,
    input      [15:0] p_imag4  ,
    input      [15:0] p_imag5  ,
    input      [15:0] p_imag6  ,
    input      [15:0] p_imag7  ,
    input      [15:0] q_real0  ,
    input      [15:0] q_real1  ,
    input      [15:0] q_real2  ,
    input      [15:0] q_real3  ,
    input      [15:0] q_real4  ,
    input      [15:0] q_real5  ,
    input      [15:0] q_real6  ,
    input      [15:0] q_real7  ,
    input      [15:0] q_imag0  ,
    input      [15:0] q_imag1  ,
    input      [15:0] q_imag2  ,
    input      [15:0] q_imag3  ,
    input      [15:0] q_imag4  ,
    input      [15:0] q_imag5  ,
    input      [15:0] q_imag6  ,
    input      [15:0] q_imag7  ,
    output            done,
    output            fft_valid,
    output reg [15:0] fft_d1   ,
    output reg [15:0] fft_d2   ,
    output reg [15:0] fft_d3   ,
    output reg [15:0] fft_d4   ,
    output reg [15:0] fft_d5   ,
    output reg [15:0] fft_d6   ,
    output reg [15:0] fft_d7   ,
    output reg [15:0] fft_d8   ,
    output reg [15:0] fft_d9   ,
    output reg [15:0] fft_d10  ,
    output reg [15:0] fft_d11  ,
    output reg [15:0] fft_d12  ,
    output reg [15:0] fft_d13  ,
    output reg [15:0] fft_d14  ,
    output reg [15:0] fft_d15  ,
    output reg [15:0] fft_d0
);

localparam IDLE        = 2'd0,
           OUTPUT_REAL = 2'd1,
           OUTPUT_IMAG = 2'd2;

reg [1:0] state, next_state;

always @(*) begin
    case (state)
        IDLE:
            next_state = en ? OUTPUT_REAL : IDLE;
        OUTPUT_REAL:
            next_state = OUTPUT_IMAG;
        OUTPUT_IMAG:
            next_state = IDLE;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

always @(*) begin
    if (state == OUTPUT_REAL) begin
        fft_d0 = p_real0;
        fft_d1 = p_real4;
        fft_d2 = p_real2;
        fft_d3 = p_real6;
        fft_d4 = p_real1;
        fft_d5 = p_real5;
        fft_d6 = p_real3;
        fft_d7 = p_real7;

        fft_d8  = q_real0;
        fft_d9  = q_real4;
        fft_d10 = q_real2;
        fft_d11 = q_real6;
        fft_d12 = q_real1;
        fft_d13 = q_real5;
        fft_d14 = q_real3;
        fft_d15 = q_real7;
    end else if (state == OUTPUT_IMAG) begin
        fft_d0 = p_imag0;
        fft_d1 = p_imag4;
        fft_d2 = p_imag2;
        fft_d3 = p_imag6;
        fft_d4 = p_imag1;
        fft_d5 = p_imag5;
        fft_d6 = p_imag3;
        fft_d7 = p_imag7;

        fft_d8  = q_imag0;
        fft_d9  = q_imag4;
        fft_d10 = q_imag2;
        fft_d11 = q_imag6;
        fft_d12 = q_imag1;
        fft_d13 = q_imag5;
        fft_d14 = q_imag3;
        fft_d15 = q_imag7;
    end else begin
        fft_d0  = 0;
        fft_d1  = 0;
        fft_d2  = 0;
        fft_d3  = 0;
        fft_d4  = 0;
        fft_d5  = 0;
        fft_d6  = 0;
        fft_d7  = 0;
        fft_d8  = 0;
        fft_d9  = 0;
        fft_d10 = 0;
        fft_d11 = 0;
        fft_d12 = 0;
        fft_d13 = 0;
        fft_d14 = 0;
        fft_d15 = 0;
    end
end

assign fft_valid = (state == OUTPUT_REAL || state == OUTPUT_IMAG);
assign done = (state == OUTPUT_IMAG);

endmodule