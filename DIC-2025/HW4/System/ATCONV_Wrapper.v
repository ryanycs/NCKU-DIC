`timescale 1ns/10ps
`include "./include/define.v"

module ATCONV_Wrapper(
    input                               bus_clk  ,
    input                               bus_rst  ,
    input         [`BUS_DATA_BITS-1:0]  RDATA_M  ,
    input                               RLAST_M  ,
    input                               WREADY_M ,
    input                               RREADY_M ,
    output reg    [`BUS_ID_BITS  -1:0]  ID_M     ,
    output reg    [`BUS_ADDR_BITS-1:0]  ADDR_M   ,
    output reg    [`BUS_DATA_BITS-1:0]  WDATA_M  ,
    output reg    [`BUS_LEN_BITS -1:0]  BLEN_M   ,
    output                              WLAST_M  ,
    output                              WVALID_M ,
    output                              RVALID_M ,
    output                              done
);

    /////////////////////////////////
    // Please write your code here //
    /////////////////////////////////

localparam SLAVE_0       = 2'd0,
           SLAVE_1       = 2'd1,
           SLAVE_2       = 2'd2,
           DEFALUT_SLAVE = 2'd3;

localparam S_WAIT  = 2'd0, // Wait for slave's ready signal
           S_WRITE = 2'd1,
           S_READ  = 2'd2;

reg [1:0] state, next_state;

// ROM
wire ROM_rd;
wire [11:0] iaddr;
wire  [15:0] idata;

// layer0 SRAM
wire layer0_ceb;
wire layer0_web;
wire [11:0] layer0_A;
wire [15:0] layer0_D;
wire  [15:0] layer0_Q;

// layer1 SRAM
wire layer1_ceb;
wire layer1_web;
wire [11:0] layer1_A;
wire [15:0] layer1_D;
wire  [15:0] layer1_Q;

ATCONV u_ATCONV(
    .clk       (bus_clk   ),
    .rst       (bus_rst   ),
    .RREADY_M  (RREADY_M  ),
    .WREADY_M  (WREADY_M ),
    .ROM_rd    (ROM_rd    ),
    .iaddr     (iaddr     ),
    .idata     (idata     ),
    .layer0_ceb(layer0_ceb),
    .layer0_web(layer0_web),
    .layer0_A  (layer0_A  ),
    .layer0_D  (layer0_D  ),
    .layer0_Q  (layer0_Q  ),
    .layer1_ceb(layer1_ceb),
    .layer1_web(layer1_web),
    .layer1_A  (layer1_A  ),
    .layer1_D  (layer1_D  ),
    .layer1_Q  (layer1_Q  ),
    .done      (done      )
);

//////////////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////////////

always @(*) begin
    case (state)
        S_WAIT:
            case ({WREADY_M, RREADY_M})
                2'b10:
                    next_state = S_WRITE;
                2'b01:
                    next_state = S_READ;
                default:
                    next_state = S_WAIT;
            endcase
        S_WRITE:
            next_state = S_WAIT;
        S_READ:
            next_state = (RLAST_M) ? S_WAIT : S_READ; // Wait for RLAST
    endcase
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

always @(posedge bus_clk or posedge bus_rst) begin
    if (bus_rst)
        state <= S_WAIT;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

// ID_M
always @(*) begin
    case ({ROM_rd, layer0_ceb, layer1_ceb})
        3'b100:  ID_M = SLAVE_0; // ROM
        3'b010:  ID_M = SLAVE_1; // layer0 SRAM
        3'b001:  ID_M = SLAVE_2; // layer1 SRAM
        default: ID_M = DEFALUT_SLAVE;
    endcase
end

// ADDR_M, BLEN_M, WDATA_M
always @(*) begin
    case (ID_M)
        SLAVE_0: begin
            ADDR_M = iaddr;
            BLEN_M = 1;
            WDATA_M = 0;
        end
        SLAVE_1: begin
            ADDR_M = layer0_A;
            BLEN_M = 1;
            WDATA_M = layer0_D;
        end
        SLAVE_2: begin
            ADDR_M = layer1_A;
            BLEN_M = 1;
            WDATA_M = layer1_D;
        end
        default: begin
            ADDR_M = 0;
            BLEN_M = 0;
            WDATA_M = 0;
        end
    endcase
end

assign RVALID_M = (
    ROM_rd ||
    (layer0_ceb && layer0_web) ||
    (layer1_ceb && layer1_web)
);
assign WVALID_M = (
    (layer0_ceb && !layer0_web) ||
    (layer1_ceb && !layer1_web)
);

assign idata = RDATA_M;
assign layer0_Q = RDATA_M;
assign layer1_Q = RDATA_M;

assign WLAST_M = (state == S_WRITE);

endmodule

module  ATCONV(
    input                  clk       ,
    input                  rst       ,
    input                  RREADY_M  ,
    input                  WREADY_M  ,
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

localparam S_IDLE         = 4'd0,
           S_IMAGE_READ   = 4'd1,
           S_CONV         = 4'd2,
           S_LAYER0_WAIT  = 4'd3, // Wait for layer0 SRAM ready signal
           S_LAYER0_WRITE = 4'd4,
           S_LAYER0_READ  = 4'd5,
           S_MAXPOOL      = 4'd6,
           S_LAYER1_WAIT  = 4'd7, // Wait for layer1 SRAM ready signal
           S_LAYER1_WRITE = 4'd8,
           S_DONE         = 4'd9;

reg [3:0] state, next_state;
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
            next_state = (RREADY_M) ? S_CONV : S_IMAGE_READ;
        S_CONV:
            next_state = (index == 4'd8) ? S_LAYER0_WAIT : S_IMAGE_READ;
        S_LAYER0_WAIT:
            next_state = (WREADY_M) ? S_LAYER0_WRITE : S_LAYER0_WAIT;
        S_LAYER0_WRITE:
            next_state = (y == 6'd63 && x == 6'd63) ? S_LAYER0_READ : S_IMAGE_READ;
        S_LAYER0_READ:
            next_state = (RREADY_M) ? S_MAXPOOL : S_LAYER0_READ;
        S_MAXPOOL:
            next_state = (index == 4'd3) ? S_LAYER1_WAIT : S_LAYER0_READ;
        S_LAYER1_WAIT:
            next_state = (WREADY_M) ? S_LAYER1_WRITE : S_LAYER1_WAIT;
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

// y, x
always @(posedge clk or posedge rst) begin
    if (rst) begin
        y <= 6'd0;
        x <= 6'd0;
    end else if (state == S_LAYER0_WRITE) begin
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
    else if (state == S_CONV) begin
        index <= (index == 4'd8) ? 4'd0 : index + 4'd1;
    end else if (state == S_MAXPOOL) begin
        index <= (index == 4'd3) ? 4'd0 : index + 4'd1;
    end
end

// iaddr_reg
always @(posedge clk or posedge rst) begin
    if (rst)
        iaddr_reg <= 12'd0;
    else if (next_state == S_IMAGE_READ) begin
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
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sum <= BIAS;
    end else if (state == S_CONV) begin
        sum <= sum + (idata * kernal[index]);
    end else if (state == S_LAYER0_WRITE) begin
        sum <= BIAS;
    end
end

// data
always @(posedge clk or posedge rst) begin
    if (rst)
        data <= 16'd0;
    else if (state == S_MAXPOOL)
        data <= (layer0_Q > data) ? layer0_Q : data;
    else if (state == S_LAYER1_WRITE)
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
    if (next_state == S_LAYER0_WAIT) begin
        layer0_A <= {y, x};
    end else if (state == S_LAYER0_READ) begin
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
    if (next_state == S_LAYER1_WAIT) begin
        layer1_A <= {2'b0, y[5:1], x[5:1]};
    end
end

// layer1_D
always @(*) begin
    if (state == S_LAYER1_WRITE) begin
        layer1_D = data[3:0] ? {data[15:4] + 12'd1, 4'b0} : {data[15:4], 4'b0};
    end else begin
        layer1_D = 16'd0;
    end
end

assign ROM_rd = (state == S_IMAGE_READ || state == S_CONV);
assign layer0_ceb = (state == S_LAYER0_WAIT || state == S_LAYER0_WRITE || state == S_LAYER0_READ || state == S_MAXPOOL);
assign layer0_web = (state == S_LAYER0_WAIT || state == S_LAYER0_WRITE) ? 1'b0 : 1'b1;
assign layer1_ceb = (state == S_LAYER1_WAIT || state == S_LAYER1_WRITE);
assign layer1_web = (state == S_LAYER1_WAIT || state == S_LAYER1_WRITE) ? 1'b0 : 1'b1;

assign iaddr = iaddr_reg;
assign done = (state == S_DONE);

endmodule