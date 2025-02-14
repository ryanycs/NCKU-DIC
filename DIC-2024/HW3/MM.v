`timescale 1ns/10ps
module MM(in_data, col_end, row_end, is_legal, out_data, rst, clk , change_row,valid, busy);
input       clk;
input       rst;
input       col_end;
input       row_end;
input [7:0] in_data;

output reg signed [19:0] out_data; // Output the 20-bit matrix operation result
output reg is_legal;               // Output whether the two matrices can be multiplied
output reg change_row;             // When the output matrix completes the output of one row
output     valid;
output     busy;

// State
localparam READ_MAT0 = 3'd0;
localparam READ_MAT1 = 3'd1;
localparam VALIDATE = 3'd2;
localparam CALCULATE = 3'd3;
localparam RESULT = 3'd4;
localparam INIT = 3'd5;

reg [2:0] state, next_state;

reg signed [7:0] mat0 [0:3][0:3];
reg signed [7:0] mat1 [0:3][0:3];
reg [1:0] row, col, i;
reg [1:0] mat0_m, mat0_n, mat1_m, mat1_n; // m: # of row, n: # of col
reg signed [19:0] accumulator;

wire [1:0] row_plus_1 = row + 2'd1;
wire [1:0] col_plus_1 = col + 2'd1;

// Next state logic
always @(*) begin
    case (state)
        READ_MAT0:
            next_state = (mat0_m != 0) ? READ_MAT1 : READ_MAT0;

        READ_MAT1:
            next_state = (mat1_m != 0) ? VALIDATE : READ_MAT1;

        VALIDATE:
            next_state = (is_legal) ? CALCULATE : RESULT;

        CALCULATE:
            next_state = (i == mat0_n) ? RESULT : CALCULATE;

        RESULT:
            next_state = (row == mat0_m || !is_legal) ? INIT : CALCULATE;

        INIT:
            next_state = READ_MAT0;

        default:
            next_state = INIT;
    endcase
end

// State register
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= READ_MAT0;
    else
        state <= next_state;
end

// Output logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        row <= 0;
        col <= 0;
        i <= 0;

        mat0_m <= 0;
        mat0_n <= 0;
        mat1_m <= 0;
        mat1_n <= 0;
        accumulator <= 0;
    end
    else begin
        case (next_state)
            INIT: begin
                row <= 0;
                col <= 0;
                i <= 0;

                mat0_m <= 0;
                mat0_n <= 0;
                mat1_m <= 0;
                mat1_n <= 0;
                accumulator <= 0;
            end

            READ_MAT0: begin
                mat0[row][col] <= in_data;

                if (row_end) begin // End of the input of mat0
                    /* Update the matrix shape */
                    mat0_m <= row_plus_1;
                    mat0_n <= col_plus_1;

                    /* Init row & col */
                    row <= 0;
                    col <= 0;
                end
                else if (col_end) begin // End of the matrix input of a "row"
                    row <= row_plus_1;
                    col <= 0;
                end
                else begin
                    col <= col_plus_1;
                end
            end

            READ_MAT1: begin
                mat1[row][col] <= in_data;

                if (row_end) begin // End of the input of mat1
                    /* Update the matrix shape */
                    mat1_m <= row_plus_1;
                    mat1_n <= col_plus_1;

                    /* Init row & col */
                    row <= 0;
                    col <= 0;
                end
                else if (col_end) begin // End of the matrix input of a "row"
                    row <= row_plus_1;
                    col <= 0;
                end
                else begin
                    col <= col_plus_1;
                end
            end

            VALIDATE: begin
                is_legal <= (mat0_n == mat1_m);
            end

            CALCULATE: begin
                accumulator <= accumulator + (mat0[row][i] * mat1[i][col]);

                i <= i + 2'd1;
            end

            RESULT: begin
                change_row <= (col == mat1_n - 2'd1) ? 1'b1 : 1'b0; // Whether is end of a "row"
                out_data <= accumulator;

                accumulator <= 0; // Reset accumulator for next calculation

                i <= 0;
                if (col == mat1_n - 2'd1) begin // End of one row calculation
                    row <= row_plus_1;
                    col <= 0;
                end
                else begin
                    col <= col_plus_1;
                end
            end
        endcase
    end
end

assign busy = (state == VALIDATE || state == CALCULATE || state == RESULT);
assign valid = (state == RESULT);

endmodule
