module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg   valid;
output reg   result;

parameter NUM_IN = 3'd0,
          DATA_IN = 3'd1,
          STACK_POP = 3'd3,
          STACK_PUSH = 3'd4,
          FINISH = 3'd5,
          IDLE = 3'd6;

reg [2:0] state, next_state;
reg [3:0] num;
reg [3:0] arr [0:9];
reg [3:0] idx;
reg [3:0] train_id;

reg [3:0] stack [0:9];
reg [3:0] top;

/* Next state logic */
always @(*) begin
    case(state)
        NUM_IN:
            next_state = DATA_IN;
        DATA_IN: begin
            if (idx == num - 1)
                next_state = STACK_POP;
            else
                next_state = DATA_IN;
        end
        STACK_POP: begin
            if (top > 4'b0 && arr[idx] == stack[top-1])
                next_state = STACK_POP;
            else
                next_state = STACK_PUSH;
        end
        STACK_PUSH: begin
            if (train_id == num + 1)
                next_state = FINISH;
            else
                next_state = STACK_POP;
        end
        FINISH:
            next_state = IDLE;
        default:
            next_state = NUM_IN;
    endcase
end

/* State register */
always @(posedge clk or posedge reset) begin
    if (reset)
        state <= NUM_IN;
    else
        state <= next_state;
end

/* Output locic */
always @(posedge clk or posedge reset) begin
    if (reset) begin
        idx = 1'b0;
        top = 1'b0;
        train_id = 1'b1;
    end
    else
    case (state)
        NUM_IN: begin
            num <= data;
        end
        DATA_IN: begin
            arr[idx] <= data;
            if (idx == num - 1)
                idx <= 1'b0;
            else
                idx <= idx + 1;
        end
        STACK_POP: begin
            if (top > 4'b0 && arr[idx] == stack[top-1]) begin
                top <= top - 1;
                idx <= idx + 1;
            end
        end
        STACK_PUSH: begin
            stack[top] <= train_id;
            top <= top + 1;
            train_id <= train_id + 1;
        end
        FINISH: begin
            valid <= 1'b1;
            result <= idx == num;
        end
        IDLE: begin
            for (integer i = 0; i < 10; i++)
                stack[i] <= 4'hf;
            valid <= 1'b0;
            result <= 1'b0;
            idx <= 1'b0;
            top <= 1'b0;
            train_id = 4'd1;
        end
    endcase
end

endmodule
