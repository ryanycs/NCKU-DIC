`timescale 1ns/10ps
`include "./include/define.v"

module BUS(
    input                           bus_clk  ,
    input                           bus_rst  ,

    // MASTERS PORTS
    input      [`BUS_ID_BITS  -1:0] ID_M0    ,
    input      [`BUS_ADDR_BITS-1:0] ADDR_M0  ,
    input      [`BUS_DATA_BITS-1:0] WDATA_M0 ,
    input      [`BUS_LEN_BITS -1:0] BLEN_M0  ,
    input                           WLAST_M0 ,
    input                           WVALID_M0,
    input                           RVALID_M0,
    output reg [`BUS_DATA_BITS-1:0] RDATA_M0 ,
    output reg                      RLAST_M0 ,
    output reg                      WREADY_M0,
    output reg                      RREADY_M0,

    // SLAVE S0 PORTS (Image ROM)
    output reg [`BUS_ADDR_BITS-1:0] ADDR_S0  ,
    output reg [`BUS_LEN_BITS -1:0] BLEN_S0  ,
    output reg                      RVALID_S0,
    input      [`BUS_DATA_BITS-1:0] RDATA_S0 ,
    input                           RLAST_S0 ,
    input                           RREADY_S0,

    // SLAVE S1 PORTS (Layer0 SRAM)
    output reg [`BUS_ADDR_BITS-1:0] ADDR_S1  ,
    output reg [`BUS_DATA_BITS-1:0] WDATA_S1 ,
    output reg [`BUS_LEN_BITS -1:0] BLEN_S1  ,
    output reg                      WLAST_S1 ,
    output reg                      WVALID_S1,
    output reg                      RVALID_S1,
    input      [`BUS_DATA_BITS-1:0] RDATA_S1 ,
    input                           RLAST_S1 ,
    input                           WREADY_S1,
    input                           RREADY_S1,

    // SLAVE S2 PORTS (Layer1 SRAM)
    output reg [`BUS_ADDR_BITS-1:0] ADDR_S2  ,
    output reg [`BUS_DATA_BITS-1:0] WDATA_S2 ,
    output reg [`BUS_LEN_BITS -1:0] BLEN_S2  ,
    output reg                      WLAST_S2 ,
    output reg                      WVALID_S2,
    output reg                      RVALID_S2,
    input      [`BUS_DATA_BITS-1:0] RDATA_S2 ,
    input                           RLAST_S2 ,
    input                           WREADY_S2,
    input                           RREADY_S2
);
    /////////////////////////////////
    // Please write your code here //
    /////////////////////////////////

localparam SLAVE_0 = 0,
           SLAVE_1 = 1,
           SLAVE_2 = 2,
           DEFALUT_SLAVE = 3;

always @(*) begin
    // Default values
    // Master
    RDATA_M0 = 0;
    RLAST_M0 = 1'b0;
    WREADY_M0 = 1'b0;
    RREADY_M0 = 1'b0;

    // Slave 0
    ADDR_S0 = 0;
    BLEN_S0 = 0;
    RVALID_S0 = 1'b0;

    // Slave 1
    ADDR_S1 = 0;
    WDATA_S1 = 0;
    BLEN_S1 = 0;
    WLAST_S1 = 1'b0;
    WVALID_S1 = 1'b0;
    RVALID_S1 = 1'b0;

    // Slave 2
    ADDR_S2 = 0;
    WDATA_S2 = 0;
    BLEN_S2 = 0;
    WLAST_S2 = 1'b0;
    WVALID_S2 = 1'b0;
    RVALID_S2 = 1'b0;

    case (ID_M0)
        SLAVE_0: begin
            // Master
            RDATA_M0 = RDATA_S0;
            RLAST_M0 = RLAST_S0;
            WREADY_M0 = 1'b0;
            RREADY_M0 = RREADY_S0;
            // Slave
            ADDR_S0 = ADDR_M0;
            BLEN_S0 = BLEN_M0;
            RVALID_S0 = RVALID_M0;
        end
        SLAVE_1: begin
            // Master
            RDATA_M0 = RDATA_S1;
            RLAST_M0 = RLAST_S1;
            WREADY_M0 = WREADY_S1;
            RREADY_M0 = RREADY_S1;
            // Slave
            ADDR_S1 = ADDR_M0;
            WDATA_S1 = WDATA_M0;
            BLEN_S1 = BLEN_M0;
            WLAST_S1 = WLAST_M0;
            WVALID_S1 = WVALID_M0;
            RVALID_S1 = RVALID_M0;
        end
        SLAVE_2: begin
            // Master
            RDATA_M0 = RDATA_S2;
            RLAST_M0 = RLAST_S2;
            WREADY_M0 = WREADY_S2;
            RREADY_M0 = RREADY_S2;
            // Slave
            ADDR_S2 = ADDR_M0;
            WDATA_S2 = WDATA_M0;
            BLEN_S2 = BLEN_M0;
            WLAST_S2 = WLAST_M0;
            WVALID_S2 = WVALID_M0;
            RVALID_S2 = RVALID_M0;
        end
        default: begin
            // Master
            RDATA_M0 = 0;
            RLAST_M0 = 1'b0;
            WREADY_M0 = 1'b0;
            RREADY_M0 = 1'b0;
            // Slave
            ADDR_S0 = 0;
            BLEN_S0 = 0;
            RVALID_S0 = 1'b0;

            ADDR_S1 = 0;
            WDATA_S1 = 0;
            BLEN_S1 = 0;
            WLAST_S1 = 1'b0;
            WVALID_S1 = 1'b0;
            RVALID_S1 = 1'b0;

            ADDR_S2 = 0;
            WDATA_S2 = 0;
            BLEN_S2 = 0;
            WLAST_S2 = 1'b0;
            WVALID_S2 = 1'b0;
            RVALID_S2 = 1'b0;
        end
    endcase
end

endmodule
