module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;

/* States */
localparam IDLE = 0;
localparam READ = 1;
localparam IN_2_POST_1 = 2;
localparam IN_2_POST_2 = 3;
localparam EVAL = 4;
localparam RESULT = 5;

/* ASCII Table */
localparam CHAR_0 = 48;
localparam CHAR_1 = 49;
localparam CHAR_2 = 50;
localparam CHAR_3 = 51;
localparam CHAR_4 = 52;
localparam CHAR_5 = 53;
localparam CHAR_6 = 54;
localparam CHAR_7 = 55;
localparam CHAR_8 = 56;
localparam CHAR_9 = 57;
localparam CHAR_a = 97;
localparam CHAR_b = 98;
localparam CHAR_c = 99;
localparam CHAR_d = 100;
localparam CHAR_e = 101;
localparam CHAR_f = 102;
localparam CHAR_L_PARENTHESIS = 40;
localparam CHAR_R_PARENTHESIS = 41;
localparam CHAR_MUL = 42;
localparam CHAR_ADD = 43;
localparam CHAR_SUB = 45;
localparam CHAR_EQU = 61;

reg [3:0] state, next_state;

reg [6:0] str [0:15];
reg [3:0] len;
reg [3:0] index;

reg [3:0] top;
reg [6:0] stack [0:15];

reg [6:0] out_string [0:15];
reg [3:0] out_index;
reg [3:0] eval_index;

wire [3:0] last_index = len - 1;
wire [3:0] top_minus_one = top - 1;
wire [3:0] top_minus_two = top - 2;
wire [3:0] top_plus_one = top + 1;
wire [3:0] index_plus_one = index + 1;
wire [3:0] out_index_plus_one = out_index + 1;

always @(*) begin
    case (state)
        IDLE:
            next_state = ready ? READ : IDLE;

        READ:
            next_state = (str[last_index] == CHAR_EQU) ? IN_2_POST_1 : READ;

        IN_2_POST_1:
            next_state = (index == last_index) ? IN_2_POST_2: IN_2_POST_1;

        IN_2_POST_2:
            next_state = (top == 0) ? EVAL : IN_2_POST_2;

        EVAL:
            next_state = (eval_index == out_index) ? RESULT : EVAL;

        RESULT:
            next_state = IDLE;

        default:
            next_state = IDLE;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        len <= 0;
        index <= 0;
        top <= 0;
        out_index <= 0;
        eval_index <= 0;
    end
    else begin
        case (next_state)
            READ: begin // Read the character into string array;
                case (ascii_in)
                    CHAR_0, CHAR_1, CHAR_2, CHAR_3, CHAR_4,
                    CHAR_5, CHAR_6, CHAR_7, CHAR_8, CHAR_9:
                        str[len] <= ascii_in - 48;

                    CHAR_a, CHAR_b, CHAR_c, CHAR_d, CHAR_e,  CHAR_f:
                        str[len] <= ascii_in - 87;

                    default:
                        str[len] <= ascii_in;
                endcase

                len <= len + 1;
            end

            IN_2_POST_1: begin
                case (str[index])
                    CHAR_L_PARENTHESIS: begin
                        // Push left parenthesis to the stack
                        stack[top] <= str[index];
                        top <= top_plus_one;
                        index <= index_plus_one;
                    end

                    CHAR_R_PARENTHESIS: begin
                        if (stack[top_minus_one] != CHAR_L_PARENTHESIS) begin
                            // Pop stack until encounter left parenthesis
                            out_string[out_index] <= stack[top_minus_one];
                            out_index <= out_index_plus_one;
                        end
                        else begin
                            index <= index_plus_one;
                        end
                        top <= top_minus_one;
                    end

                    CHAR_MUL: begin
                        if (stack[top_minus_one] == CHAR_MUL) begin
                            out_string[out_index] <= stack[top_minus_one];
                            top <= top_minus_one;
                            out_index <= out_index_plus_one;
                        end
                        else begin
                            stack[top] <= str[index];
                            top <= top_plus_one;
                            index <= index_plus_one;
                        end
                    end

                    CHAR_ADD, CHAR_SUB: begin
                        if (stack[top_minus_one] == CHAR_MUL ||
                                stack[top_minus_one] == CHAR_ADD ||
                                stack[top_minus_one] == CHAR_SUB) begin
                            out_string[out_index] <= stack[top_minus_one];
                            top <= top_minus_one;
                            out_index <= out_index_plus_one;
                        end
                        else begin
                            stack[top] <= str[index];
                            top <= top_plus_one;
                            index <= index_plus_one;
                        end
                    end

                    default: begin
                        out_string[out_index] <= str[index];
                        out_index <= out_index_plus_one;
                        index <= index_plus_one;
                    end
                endcase
            end

            IN_2_POST_2: begin
                if (top > 0) begin
                    out_string[out_index] <= stack[top_minus_one];
                    top <= top_minus_one;
                    out_index <= out_index_plus_one;
                end
            end

            EVAL: begin
                case (out_string[eval_index])
                    CHAR_ADD: begin
                        stack[top_minus_two] <= stack[top_minus_one] + stack[top_minus_two];
                        top <= top_minus_one;
                    end

                    CHAR_SUB: begin
                        stack[top_minus_two] <= stack[top_minus_two] - stack[top_minus_one];
                        top <= top_minus_one;
                    end

                    CHAR_MUL: begin
                        stack[top_minus_two] <= stack[top_minus_one] * stack[top_minus_two];
                        top <= top_minus_one;
                    end

                    default: begin
                        stack[top] <= out_string[eval_index];
                        top <= top_plus_one;
                    end
                endcase

                eval_index <= eval_index + 1;
            end

            RESULT: begin
                result <= stack[top_minus_one];
                valid <= 1'b1;
            end

            IDLE: begin
                valid <= 1'b0;
                result <= 0;

                len <= 0;
                index <= 0;
                top <= 0;
                out_index <= 0;
                eval_index <= 0;
            end
        endcase
    end
end

endmodule
