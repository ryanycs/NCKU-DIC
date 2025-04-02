module LCD_CTRL(
    input            clk      ,
    input            rst      ,
    input      [3:0] cmd      ,
    input            cmd_valid,
    input      [7:0] IROM_Q   ,
    output reg       IROM_rd  ,
    output reg [5:0] IROM_A   ,
    output reg       IRAM_ceb ,
    output reg       IRAM_web ,
    output reg [7:0] IRAM_D   ,
    output reg [5:0] IRAM_A   ,
    input      [7:0] IRAM_Q   ,
    output reg       busy     ,
    output reg       done
);

/////////////////////////////////
// Please write your code here //
/////////////////////////////////

localparam CMD_WRITE = 4'b0000,
           CMD_UP    = 4'b0001,
           CMD_DOWN  = 4'b0010,
           CMD_LEFT  = 4'b0011,
           CMD_RIGHT = 4'b0100,
           CMD_MAX   = 4'b0101,
           CMD_MIN   = 4'b0110,
           CMD_AVG   = 4'b0111;

localparam S_READ_IMG = 3'd0,
           S_INPUT    = 3'd1,
           S_MAX      = 3'd2,
           S_MIN      = 3'd3,
           S_SUM      = 3'd4,
           S_AVG      = 3'd5,
           S_WRITE    = 3'd6,
           S_DONE     = 3'd7;

reg [2:0] state, next_state;

reg [2:0] y, x;
reg [5:0] counter;
reg [7:0] img [0:63];
reg [11:0] sum;

wire [5:0] index = {y + counter[3:2], x + counter[1:0]};
wire [7:0] max [1:31];
wire [7:0] min [1:31];

genvar i, j;
generate
    for (i = 1; i < 16; i = i + 1) begin: max_gen
        assign max[i] = (max[i << 1] > max[i << 1 | 1]) ? max[i << 1] : max[i << 1 | 1];
    end
    for (i = 0; i < 16; i = i + 1) begin: max_gen1
        assign max[i + 16] = img[{y + i[3:2], x + i[1:0]}];
    end

    for (i = 1; i < 16; i = i + 1) begin: min_gen
        assign min[i] = (min[i << 1] < min[i << 1 | 1]) ? min[i << 1] : min[i << 1 | 1];
    end
    for (i = 0; i < 16; i = i + 1) begin: min_gen1
        assign min[i + 16] = img[{y + i[3:2], x + i[1:0]}];
    end
endgenerate

// ===================================================================
//  FSM
// ===================================================================

always @(*) begin
    case (state)
        S_READ_IMG:
            next_state = (IROM_A == 6'd63) ? S_INPUT : S_READ_IMG;
        S_INPUT:
            if (cmd_valid)
                case (cmd)
                    CMD_WRITE: next_state = S_WRITE;
                    CMD_UP   : next_state = S_INPUT;
                    CMD_DOWN : next_state = S_INPUT;
                    CMD_LEFT : next_state = S_INPUT;
                    CMD_RIGHT: next_state = S_INPUT;
                    CMD_MAX  : next_state = S_MAX;
                    CMD_MIN  : next_state = S_MIN;
                    CMD_AVG  : next_state = S_SUM;
                    default  : next_state = S_INPUT;
                endcase
            else
                next_state = S_INPUT;
        S_MAX:
            next_state = (counter == 4'd15) ? S_INPUT : S_MAX;
        S_MIN:
            next_state = (counter == 4'd15) ? S_INPUT : S_MIN;
        S_SUM:
            next_state = (counter == 4'd15) ? S_AVG : S_SUM;
        S_AVG:
            next_state = (counter == 4'd15) ? S_INPUT : S_AVG;
        S_WRITE:
            next_state = (IRAM_A == 6'd63) ? S_DONE : S_WRITE;
        S_DONE:
            next_state = S_DONE;
    endcase
end

// ===================================================================
//  Data
// ===================================================================

// img
always @(posedge clk) begin
    case (state)
        S_READ_IMG:
            img[IROM_A] <= IROM_Q;
        S_MAX:
            img[index] <= max[1];
        S_MIN:
            img[index] <= min[1];
        S_AVG:
            img[index] <= sum >> 4;
    endcase
end

// sum
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sum <= 12'd0;
    end
    else
    case (state)
        S_SUM:
            sum <= sum + img[index];
        S_AVG:
            sum <= sum;
        default:
            sum <= 12'd0;
    endcase
end

// ===================================================================
//  Control
// ===================================================================

// y, x
always @(posedge clk or posedge rst) begin
    if (rst) begin
        y <= 3'd2;
        x <= 3'd2;
    end
    else
    case (state)
        S_INPUT:
            case (cmd)
                CMD_UP   : y <= (y == 3'd0) ? 3'd0 : y - 3'd1;
                CMD_DOWN : y <= (y == 3'd4) ? 3'd4 : y + 3'd1;
                CMD_LEFT : x <= (x == 3'd0) ? 3'd0 : x - 3'd1;
                CMD_RIGHT: x <= (x == 3'd4) ? 3'd4 : x + 3'd1;
            endcase
    endcase
end

//counter
always @(posedge clk or posedge rst) begin
    if (rst)
        counter <= 6'd0;
    else
    case (state)
        S_MAX, S_MIN, S_SUM, S_AVG, S_WRITE:
            counter <= counter + 6'd1;
        default:
            counter <= 6'd0;
    endcase
end

// State register
always @(posedge clk or posedge rst) begin
    if (rst)
        state <= S_READ_IMG;
    else
        state <= next_state;
end

// ===================================================================
//  Output
// ===================================================================

// IROM_A
always @(posedge clk or posedge rst) begin
    if (rst) begin
        IROM_A <= 6'd0;
    end
    else
    case (state)
        S_READ_IMG:
            IROM_A <= IROM_A + 6'd1;
    endcase
end

// IRAM_A, IRAM_D
always @(posedge clk or posedge rst) begin
    if (rst) begin
        IRAM_A <= 6'd0;
    end
    else
    case (state)
        S_WRITE: begin
            IRAM_D <= img[counter];
            IRAM_A <= counter;
        end
    endcase
end

// IRAM_ceb, IRAM_web
always @(posedge clk or posedge rst) begin
    if (rst) begin
        IRAM_ceb <= 1'b0;
        IRAM_web <= 1'b0;
    end
    case (state)
        S_WRITE: begin
            IRAM_ceb <= 1'b1;
            IRAM_web <= 1'b0;
        end

        default:
            IRAM_ceb <= 1'b0;
    endcase
end

always @(*) begin
    IROM_rd = (state == S_READ_IMG);
    done = (state == S_DONE);
    busy = (state != S_INPUT && state != S_DONE);
end

endmodule
