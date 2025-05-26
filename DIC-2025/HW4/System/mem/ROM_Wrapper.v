`timescale 1ns/10ps
`include "./include/define.v"

module ROM_Wrapper(
    input                           bus_clk ,
    input                           bus_rst ,
    input      [`BUS_ADDR_BITS-1:0] ADDR_S  ,
    input      [`BUS_LEN_BITS -1:0] BLEN_S  ,
    input                           RVALID_S,
    output reg [`BUS_DATA_BITS-1:0] RDATA_S ,
    output reg                      RLAST_S ,
    output reg                      RREADY_S,
    output                          ROM_rd  ,
    output     [`BUS_ADDR_BITS-1:0] ROM_A   ,
    input      [`BUS_DATA_BITS-1:0] ROM_Q
);
    /////////////////////////////////
    // Please write your code here //
    /////////////////////////////////

localparam S_IDLE  = 2'd0,
           S_READY = 2'd1,
           S_READ  = 2'd2;

reg [1:0] state, next_state;
reg [`BUS_LEN_BITS -1:0] BLEN_S_r;
reg [`BUS_LEN_BITS-1:0] offset;
reg [`BUS_ADDR_BITS -1:0] ADDR_S_r;

//////////////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////////////

always @(*) begin
    case (state)
        S_IDLE:
            next_state = (RVALID_S) ? S_READY : S_IDLE;
        S_READY:
            next_state = (RVALID_S) ? S_READ : S_READY;
        S_READ:
            next_state = (offset == BLEN_S_r - 1) ? S_IDLE : S_READ;
        default:
            next_state = S_IDLE;
    endcase
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

// BLEN_S, ADDR_S
always @(posedge bus_clk) begin
    if (state == S_READY) begin
        BLEN_S_r <= BLEN_S;
        ADDR_S_r <= ADDR_S;
    end
end

// offset
always @(posedge bus_clk) begin
    if (state == S_READ) begin
        offset <= offset + 1;
    end else begin
        offset <= 0;
    end
end

// state
always @(posedge bus_clk or posedge rst) begin
    if (rst)
        state <= S_IDLE;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

// RREADY_S
always @(*) begin
    RREADY_S = (state == S_READY);
end

always @(*) begin
    if (state == S_READ) begin
        ROM_rd = 1'b1;
        ROM_A = ADDR_S_r + offset;
        R_DARA_S = ROM_Q;
        R_LAST_S = (offset == BLEN_S_r - 1) ? 1'b1 : 1'b0;
    end else begin
        ROM_rd = 1'b0;
        ROM_A = 0;
        R_DARA_S = 0;
        R_LAST_S = 1'b0;
    end
end

endmodule