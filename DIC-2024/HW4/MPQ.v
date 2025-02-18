module MPQ(
           input clk,
           input rst,
           input data_valid,
           input [7:0] data,
           input cmd_valid,
           input [2:0] cmd,
           input [7:0] index,
           input [7:0] value,
           output busy,
           output reg RAM_valid,
           output reg[7:0]RAM_A,
           output reg [7:0]RAM_D,
           output done
       );

// ==== State ====
localparam INPUT               = 4'd0;
localparam IDLE                = 4'd1;
localparam FETCH               = 4'd2;
localparam BUILD               = 4'd3;
localparam EXTRACT_MAX         = 4'd4;
localparam INCREASE_VALUE      = 4'd5;
localparam INCREASE_VALUE_SWAP = 4'd6;
localparam INSERT_DATA         = 4'd7;
localparam WRITE               = 4'd8;
localparam HEAPIFY             = 4'd9;
localparam DONE                = 4'd10;

// ==== Command ====
localparam CMD_BUILD          = 3'b000;
localparam CMD_EXTRACT_MAX    = 3'b001;
localparam CMD_INCREASE_VALUE = 3'b010;
localparam CMD_INSERT_DATA    = 3'b011;
localparam CMD_WRITE          = 3'b100;

reg [3:0] state, next_state;
reg [7:0] n;                 // size of the heap
reg [7:0] i, j;              // general purpose registers
reg [7:0] A [1:255];         // heap array

reg [2:0] IR;                // instruction register

reg [7:0] tmp, max_idx;      // wire, used to find the max index in heapify step

wire [7:0] n_plus_1 = n + 8'd1;
wire [7:0] i_plus_1 = i + 8'd1;
wire [7:0] i_minus_1 = i - 8'd1;
wire [7:0] left_child = i << 1;
wire [7:0] right_child = i << 1 | 8'd1;
wire [7:0] parent = i >> 1;

wire greater_than_parent = (i > 1 && A[parent] < A[i]);
wire value_less_than_target = j < A[i]; // value < A[index]
wire max_idx_is_not_i = (max_idx != i);

// Next state logic
always @(*) begin
    next_state = INPUT;

    case (state)
        INPUT:
            next_state = data_valid ? INPUT : IDLE;

        IDLE:
            next_state = cmd_valid ? FETCH : IDLE;

        FETCH:
        case (IR)
            CMD_BUILD:
                next_state = BUILD;
            CMD_EXTRACT_MAX:
                next_state = EXTRACT_MAX;
            CMD_INCREASE_VALUE:
                next_state = INCREASE_VALUE;
            CMD_INSERT_DATA:
                next_state = INSERT_DATA;
            CMD_WRITE:
                next_state = WRITE;
            default:
                next_state = IDLE;
        endcase

        BUILD:
            next_state = (i == 0) ? IDLE : HEAPIFY;

        HEAPIFY:
            if (max_idx_is_not_i) begin
                next_state = HEAPIFY;
            end
            else begin
                case (IR)
                    CMD_BUILD:
                        next_state = BUILD;
                    CMD_EXTRACT_MAX:
                        next_state = IDLE;
                    CMD_INCREASE_VALUE:
                        next_state = value_less_than_target ? IDLE : INCREASE_VALUE;
                    default:
                        next_state = IDLE;
                endcase
            end

        EXTRACT_MAX:
            next_state = HEAPIFY;

        INCREASE_VALUE:
            next_state = greater_than_parent ? INCREASE_VALUE_SWAP : IDLE;

        INCREASE_VALUE_SWAP:
            next_state = greater_than_parent ? INCREASE_VALUE_SWAP : IDLE;

        INSERT_DATA:
            next_state = INCREASE_VALUE;

        WRITE:
            next_state = (i == n_plus_1) ? DONE : WRITE;

        DONE:
            next_state = DONE;

        default:
            next_state = IDLE;
    endcase
end

// FSM
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= INPUT;
    else
        state <= next_state;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        n <= 8'd0;
    end
    else begin
        case (next_state)
            INPUT: begin
                n <= n_plus_1;
            end

            FETCH: begin
                case (cmd)
                    CMD_BUILD:
                        j <= n >> 1;
                    CMD_WRITE:
                        i <= 8'd1;
                    CMD_INCREASE_VALUE: begin
                        i <= index + 8'd1; // our index starts from 1
                        j <= value; // value buffer
                    end
                    CMD_INSERT_DATA:
                        j <= value;
                endcase
                IR <= cmd;
            end

            BUILD: begin
                i <= j;
                j <= j - 8'd1;
            end

            HEAPIFY: begin // heapify(i)
                if (i != max_idx) begin
                    i <= max_idx;
                end
            end

            EXTRACT_MAX: begin
                n <= n - 8'd1;
                i <= 8'd1; // heapify(1)
            end

            INCREASE_VALUE_SWAP: begin
                i <= parent;
            end

            INSERT_DATA: begin
                n <= n_plus_1;
                i <= n_plus_1;
            end

            WRITE: begin
                i <= i_plus_1;
            end

        endcase
    end
end

// Find the index with largest value in heapify step
always @(*) begin
    tmp = (left_child <= n) ? ((A[left_child] > A[i]) ? left_child : i) : i;
    max_idx = (right_child <= n) ? ((A[right_child] > A[tmp]) ? right_child : tmp) : tmp;
end

// A array (heap) logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
    end
    else begin
        case (next_state)
            INPUT:
                A[n_plus_1] <= data;

            HEAPIFY:
                if (max_idx_is_not_i) begin
                    A[i] <= A[max_idx];
                    A[max_idx] <= A[i];
                end

            EXTRACT_MAX:
                A[1] <= A[n];

            INCREASE_VALUE:
                A[i] <= j;

            INCREASE_VALUE_SWAP: begin
                A[i] <= A[parent];
                A[parent] <= A[i];
            end

            INSERT_DATA:
                A[n_plus_1] <= 8'd0;
        endcase
    end
end

// === Output ===

// RAM_valid
always @(posedge clk or posedge rst) begin
    if (rst)
        RAM_valid <= 0;
    else
    case (next_state)
        WRITE:
            RAM_valid <= 1;
        default:
            RAM_valid <= 0;
    endcase
end

// RAM_A
always @(posedge clk or posedge rst) begin
    if (rst)
        RAM_A <= 8'd0;
    else
    case (next_state)
        WRITE:
            RAM_A <= i_minus_1;
        default:
            RAM_A <= 8'd0;
    endcase
end

// RAM_D
always @(posedge clk or posedge rst) begin
    if (rst)
        RAM_D <= 8'd0;
    else
    case (next_state)
        WRITE:
            RAM_D <= A[i];
        default:
            RAM_D <= 8'd0;
    endcase
end

assign busy = (state != IDLE);
assign done = (state == DONE);

endmodule
