`timescale 1ns/10ps
module  ATCONV(
            input      clk,
            input      reset,           // Active-high asynchronous reset signal.
            output     busy,
            input      ready,

            output reg	  [11:0] iaddr, // Image memory address signal
            input  signed [12:0] idata, // Input pixel data of the grayscale image

            output reg cwr,             // Write enable signal
            output reg [11:0] caddr_wr, // Write address signal
            output reg [12:0] cdata_wr, // Write data signal

            output reg crd,             // Read enable signal
            output reg [11:0] caddr_rd, // Read address signal
            input      [12:0] cdata_rd, // Read data signal

            output reg csel             // Memory selection signal
        );

// Convolution kernel
wire signed [12:0] kernel [0:8];
assign kernel[0] = 13'h1fff; // -0.0625
assign kernel[1] = 13'h1ffe; // -0.125
assign kernel[2] = 13'h1fff; // -0.0625
assign kernel[3] = 13'h1ffc; // -0.25
assign kernel[4] = 13'h0010; // 1
assign kernel[5] = 13'h1ffc; // -0.25
assign kernel[6] = 13'h1fff; // -0.0625
assign kernel[7] = 13'h1ffe; // -0.125
assign kernel[8] = 13'h1fff; // -0.0625

// Bias
localparam BIAS = 26'h3ffff40; // -0.75

// State
localparam IDLE = 3'd0;
localparam LAYER0_MEM_ACCESS = 3'd1;
localparam ATROUS_CONVOLUTION = 3'd2;
localparam LAYER0_WRITE_BACK = 3'd3;
localparam LAYER1_MEM_ACCESS = 3'd4;
localparam MAX_POOLING = 3'd5;
localparam LAYER1_WRITE_BACK = 3'd6;

reg [2:0] state, next_state;

reg [11:0] img_index; // [11:6] is row, [5:0] is col
reg [3:0] kernel_index;
reg [1:0] pooling_index;
reg signed [25:0] accumulator;

wire signed [25:0] accumulator_plus_bias = accumulator + BIAS;
wire [12:0] cdata_rd_round_up = {cdata_rd[12:4] + |cdata_rd[3:0], 4'd0};

// State register
always @(posedge clk, posedge reset) begin
    if (reset)
        state <= IDLE;
    else
        state <= next_state;
end

// Next state logic
always @(*) begin
    case (state)
        IDLE:
            next_state = ready ? LAYER0_MEM_ACCESS : IDLE;

        LAYER0_MEM_ACCESS:
            next_state = ATROUS_CONVOLUTION;

        ATROUS_CONVOLUTION:
            next_state = (kernel_index == 0) ? LAYER0_WRITE_BACK : LAYER0_MEM_ACCESS;

        LAYER0_WRITE_BACK:
            next_state = (img_index == 0) ? LAYER1_MEM_ACCESS : LAYER0_MEM_ACCESS;

        LAYER1_MEM_ACCESS:
            next_state = MAX_POOLING;

        MAX_POOLING:
            next_state = (pooling_index == 0) ? LAYER1_WRITE_BACK : LAYER1_MEM_ACCESS;

        LAYER1_WRITE_BACK:
            next_state = (img_index == 0) ? IDLE : LAYER1_MEM_ACCESS;
    endcase
end

always @(posedge clk, posedge reset) begin
    if (reset) begin
        img_index <= 13'd0;
        kernel_index <= 4'd0;
        accumulator <= 25'd0;
        pooling_index <= 2'd0;
    end
    else begin
        case (next_state)
            LAYER0_MEM_ACCESS: begin
                // y axis
                case (kernel_index)
                    0, 1, 2:
                        iaddr[11:6] <= (img_index[11:6] == 6'd0 || img_index[11:6] == 6'd1) ? 6'd0 : img_index[11:6] - 6'd2;

                    3, 4, 5:
                        iaddr[11:6] <= img_index[11:6];

                    6, 7, 8:
                        iaddr[11:6] <= (img_index[11:6] == 6'd62 || img_index[11:6] == 6'd63) ? 6'd63 : img_index[11:6] + 6'd2;
                endcase

                // x axis
                case (kernel_index)
                    0, 3, 6:
                        iaddr[5:0] <= (img_index[5:0] == 6'd0 || img_index[5:0] == 6'd1) ? 6'd0 : img_index[5:0] - 6'd2;

                    1, 4, 7:
                        iaddr[5:0] <= img_index[5:0];

                    2, 5, 8:
                        iaddr[5:0] <= (img_index[5:0] == 6'd62 || img_index[5:0] == 6'd63) ? 6'd63 : img_index[5:0] + 6'd2;
                endcase
            end

            ATROUS_CONVOLUTION: begin
                accumulator <= accumulator + idata * kernel[kernel_index];

                kernel_index <= (kernel_index == 8) ? 0 : kernel_index + 1;
            end

            LAYER0_WRITE_BACK: begin
                csel <= 1'b0; // Select layer 0 memory
                cwr <= 1'b1;  // Write enable

                caddr_wr <= img_index;
                cdata_wr <= (accumulator_plus_bias > 0) ? accumulator_plus_bias[4 +: 13] : 13'd0; // ReLU Function

                accumulator <= 25'd0;
                img_index <= img_index + 12'd1;
            end

            LAYER1_MEM_ACCESS: begin
                csel <= 1'b0; // Select layer 0 memory
                cwr <= 1'b0;  // Write disable
                crd <= 1'b1;  // Read enable

                if (pooling_index == 0)
                    cdata_wr <= 13'd0;

                case (pooling_index)
                    0:
                        caddr_rd <= img_index;
                    1:
                        caddr_rd <= {img_index[11:6], img_index[5:0] + 6'd1};
                    2:
                        caddr_rd <= {img_index[11:6] + 6'd1, img_index[5:0]};
                    3:
                        caddr_rd <= {img_index[11:6] + 6'd1, img_index[5:0] + 6'd1};
                endcase
            end

            MAX_POOLING: begin
                cdata_wr <=  (cdata_rd > cdata_wr) ? cdata_rd_round_up : cdata_wr;
                pooling_index <= pooling_index + 1;
            end

            LAYER1_WRITE_BACK: begin
                csel <= 1'b1; // Select layer 1 memory
                cwr <= 1'b1;  // Write enable
                crd <= 1'b0;  // Read disable

                // Image index can be transform as: {(img_index[11:6] / 2) * 32, img_index[5:0] / 2}
                caddr_wr <= {2'b0, img_index[11:6], 4'b0} + {8'b0, img_index[5:1]};

                if (img_index[5:0] == 6'd62)
                    img_index <= {img_index[11:6] + 6'd2, 6'd0};
                else
                    img_index <= {img_index[11:6], img_index[5:0] + 6'd2};
            end
        endcase
    end
end

assign busy = (state != IDLE);

endmodule
