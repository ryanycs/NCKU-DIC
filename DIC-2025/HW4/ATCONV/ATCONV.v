`timescale 1ns/10ps

module  ATCONV(
    input                  clk       ,
    input                  rst       ,
    output                 ROM_rd    ,
    output        [11:0]   iaddr     ,
    input  signed [15:0]   idata     ,
    output                 layer0_ceb,
    output                 layer0_web,
    output reg    [11:0]   layer0_A  ,
    output reg    [15:0]   layer0_D  ,
    input         [15:0]   layer0_Q  ,
    output                 layer1_ceb,
    output                 layer1_web,
    output reg    [11:0]   layer1_A  ,
    output reg    [15:0]   layer1_D  ,
    input         [15:0]   layer1_Q  ,
    output                 done
);

/////////////////////////////////
// Please write your code here //
/////////////////////////////////

//////////////////////////////////////////////////////////////////////
// Kernal Weight
//////////////////////////////////////////////////////////////////////

wire signed [15:0] kernal [8:0];
assign kernal[0] = 16'hFFFF;
assign kernal[1] = 16'hFFFE;
assign kernal[2] = 16'hFFFF;
assign kernal[3] = 16'hFFFC;
assign kernal[4] = 16'h0010;
assign kernal[5] = 16'hFFFC;
assign kernal[6] = 16'hFFFF;
assign kernal[7] = 16'hFFFE;
assign kernal[8] = 16'hFFFF;

localparam BIAS = 32'hFFFFFF40;

localparam S_IDLE         = 3'd0,
           S_IMAGE_READ   = 3'd1,
           S_CONV         = 3'd2,
           S_LAYER0_WRITE = 3'd3,
           S_LAYER0_READ  = 3'd4,
           S_LAYER1_WRITE = 3'd5,
           S_DONE         = 3'd6;

reg [2:0] state, next_state;
reg [11:0] iaddr_reg;

reg [5:0] y, x;
reg [3:0] index;
reg signed [31:0] sum;
reg [15:0] data;

always @(*) begin
    case (state)
        S_IDLE:
            next_state = S_IMAGE_READ;
        S_IMAGE_READ:
            next_state = S_CONV;
        S_CONV:
            next_state = (index == 4'd9) ? S_LAYER0_WRITE : S_CONV;
        S_LAYER0_WRITE:
            next_state = (y == 6'd0 && x == 6'd0) ? S_LAYER0_READ : S_IMAGE_READ;
        S_LAYER0_READ:
            next_state = (index == 4'd0) ? S_LAYER1_WRITE : S_LAYER0_READ;
        S_LAYER1_WRITE:
            next_state = (y == 6'd0 && x == 6'd0) ? S_DONE : S_LAYER0_READ;
        S_DONE:
            next_state = S_DONE;
        default:
            next_state = S_IDLE;
    endcase
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst) begin
        y <= 6'd0;
        x <= 6'd0;
    end else if (next_state == S_LAYER0_WRITE) begin
        y <= (x == 6'd63) ? y + 6'd1 : y;
        x <= (x == 6'd63) ? 6'd0 : x + 6'd1;
    end else if (state == S_LAYER0_WRITE && next_state == S_LAYER0_READ) begin
        y <= 0;
        x <= 0;
    end else if (next_state == S_LAYER1_WRITE) begin
        y <= (x == 6'd62) ? y + 6'd2: y;
        x <= (x == 6'd62) ? 6'd0 : x + 6'd2;
    end
end

// index
always @(posedge clk or posedge rst) begin
    if (rst)
        index <= 4'd0;
    else if (next_state == S_IMAGE_READ || next_state == S_CONV) begin
        index <= (index == 4'd9) ? 4'd0 : index + 4'd1;
    end else if (next_state == S_LAYER0_READ) begin
        index <= (index == 4'd3) ? 4'd0 : index + 4'd1;
    end else begin
        index <= 4'd0;
    end
end

// iaddr_reg
always @(posedge clk or posedge rst) begin
    if (rst)
        iaddr_reg <= 12'd0;
    else if (next_state == S_IMAGE_READ || next_state == S_CONV) begin
        // y
        case (index)
            0, 1, 2: begin
                iaddr_reg[11:6] <= (y == 6'd0 || y == 6'd1) ? 6'd0 : y - 6'd2;
            end
            3, 4, 5: begin
                iaddr_reg[11:6] <= y;
            end
            6, 7, 8: begin
                iaddr_reg[11:6] <= (y == 6'd62 || y == 6'd63) ? 6'd63 : y + 6'd2;
            end
        endcase

        // x
        case (index)
            0, 3, 6: begin
                iaddr_reg[5:0] <= (x == 6'd0 || x == 6'd1) ? 6'd0 : x - 6'd2;
            end
            1, 4, 7: begin
                iaddr_reg[5:0] <= x;
            end
            2, 5, 8: begin
                iaddr_reg[5:0] <= (x == 6'd62 || x == 6'd63) ? 6'd63 : x + 6'd2;
            end
        endcase
    end
end

// sum
always @(posedge clk) begin
    if (next_state == S_CONV || next_state == S_LAYER0_WRITE) begin
        sum <= sum + (idata * kernal[index-1]);
    end else if (next_state == S_LAYER0_WRITE) begin
        sum <= sum;
    end else begin
        sum <= BIAS;
    end
end

// data
always @(posedge clk) begin
    if (state == S_LAYER0_READ)
        data <= (layer0_Q > data) ? layer0_Q : data;
    else
        data <= 16'd0;
end

// layer0_A_reg
always @(posedge clk) begin
end

// state
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= S_IDLE;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

// layer0_A
always @(posedge clk) begin
    if (next_state == S_LAYER0_WRITE) begin
        layer0_A <= {y, x};
    end else if (next_state == S_LAYER0_READ) begin
        // y
        case (index)
            0, 1: layer0_A[11:6] <= y;
            2, 3: layer0_A[11:6] <= y + 6'd1;
        endcase

        // x
        case (index)
            0, 2: layer0_A[5:0] <= x;
            1, 3: layer0_A[5:0] <= x + 6'd1;
        endcase
    end
end

// layer0_D
always @(*) begin
    if (state == S_LAYER0_WRITE) begin
        layer0_D = sum[31] ? 16'd0 : sum[19:4]; // ReLU
    end else begin
        layer0_D = 16'd0;
    end
end

// layer1_A
always @(posedge clk) begin
    if (next_state == S_LAYER1_WRITE) begin
        layer1_A <= {2'b0, y[5:1], x[5:1]};
    end
end

// layer1_D
always @(*) begin
    if (state == S_LAYER1_WRITE) begin
        layer1_D = data[3:0] ? {data[15:4] + 1, 4'b0} : {data[15:4], 4'b0};
    end else begin
        layer1_D = 16'd0;
    end
end

assign ROM_rd = (state == S_IMAGE_READ || state == S_CONV);
assign layer0_ceb = (state == S_LAYER0_WRITE || state == S_LAYER0_READ);
assign layer0_web = (state == S_LAYER0_WRITE) ? 1'b0 : 1'b1;
assign layer1_ceb = (state == S_LAYER1_WRITE);
assign layer1_web = (state == S_LAYER1_WRITE) ? 1'b0 : 1'b1;

assign iaddr = iaddr_reg;
assign done = (state == S_DONE);

endmodule
