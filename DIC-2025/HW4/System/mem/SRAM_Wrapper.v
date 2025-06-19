`timescale 1ns/10ps
`include "./include/define.v"

module SRAM_Wrapper(
    input                           bus_clk ,
    input                           bus_rst ,
    input      [`BUS_ADDR_BITS-1:0] ADDR_S  ,
    input      [`BUS_DATA_BITS-1:0] WDATA_S ,
    input      [`BUS_LEN_BITS -1:0] BLEN_S  ,
    input                           WLAST_S ,
    input                           WVALID_S,
    input                           RVALID_S,
    output     [`BUS_DATA_BITS-1:0] RDATA_S ,
    output reg                      RLAST_S ,
    output reg                      WREADY_S,
    output reg                      RREADY_S,
    output reg [`BUS_DATA_BITS-1:0] SRAM_D  ,
    output reg [`BUS_ADDR_BITS-1:0] SRAM_A  ,
    input      [`BUS_DATA_BITS-1:0] SRAM_Q  ,
    output reg                      SRAM_ceb,
    output reg                      SRAM_web
);
    /////////////////////////////////
    // Please write your code here //
    /////////////////////////////////

localparam S_IDLE   = 3'd0,
           S_WREADY = 3'd1,
           S_RREADY = 3'd2,
           S_WRITE  = 3'd3,
           S_READ   = 3'd4;

reg [2:0] state, next_state;
reg [`BUS_LEN_BITS -1:0] BLEN_S_r;
reg [`BUS_ADDR_BITS -1:0] ADDR_S_r;
reg [`BUS_LEN_BITS-1:0] offset;

//////////////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////////////

always @(*) begin
    case (state)
        S_IDLE:
            if (WVALID_S) begin
                next_state = S_WREADY;
            end else if (RVALID_S) begin
                next_state = S_RREADY;
            end else begin
                next_state = S_IDLE;
            end
        S_WREADY:
            next_state = (WREADY_S) ? S_WRITE : S_WREADY;
        S_RREADY:
            next_state = (RREADY_S) ? S_READ : S_RREADY;
        S_WRITE:
            next_state = (WLAST_S) ? S_IDLE : S_WRITE;
        S_READ:
            next_state = (offset == BLEN_S_r - 1) ? S_IDLE : S_READ;
        default:
            next_state = S_IDLE;
    endcase
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

// BLEN_S
always @(posedge bus_clk) begin
    if (state == S_WREADY || state == S_RREADY) begin
        BLEN_S_r <= BLEN_S;
        ADDR_S_r <= ADDR_S;
    end
end

// offset
always @(posedge bus_clk) begin
    if (state == S_READ || state == S_WRITE) begin
        offset <= offset + 1;
    end else begin
        offset <= 0;
    end
end

// state
always @(posedge bus_clk or posedge bus_rst) begin
    if (bus_rst)
        state <= S_IDLE;
    else
        state <= next_state;
end

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

// RREADY_S, WREADY_S
always @(*) begin
    WREADY_S = (state == S_WREADY);
    RREADY_S = (state == S_RREADY);
end

always @(*) begin
    case (state)
        S_WRITE: begin
            SRAM_ceb = 1'b1;
            SRAM_web = 1'b0;
            SRAM_A = ADDR_S_r + offset;
            SRAM_D = WDATA_S;
            RLAST_S = 0;
        end
        S_READ: begin
            SRAM_ceb = 1'b1;
            SRAM_web = 1'b1;
            SRAM_A = ADDR_S_r + offset;
            SRAM_D = 0;
            RLAST_S = (offset == BLEN_S_r - 1);
        end
        default: begin
            SRAM_ceb = 1'b0;
            SRAM_web = 1'b1;
            SRAM_A = 0;
            SRAM_D = 0;
            RLAST_S = 0;
        end
    endcase
end

assign RDATA_S = SRAM_Q;

endmodule