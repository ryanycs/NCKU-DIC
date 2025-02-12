`include "MMS_4num.v"

module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
input  [7:0] number4;
input  [7:0] number5;
input  [7:0] number6;
input  [7:0] number7;
output reg [7:0] result;

/*
    Write Your Design Here ~
*/
wire [7:0] tmp1, tmp2;

MMS_4num u_MMS_4num1(
             .select(select),
             .number0(number0),
             .number1(number1),
             .number2(number2),
             .number3(number3),
             .result(tmp1)
         );

MMS_4num u_MMS_4num2(
             .select(select),
             .number0(number4),
             .number1(number5),
             .number2(number6),
             .number3(number7),
             .result(tmp2)
         );

always @(tmp1 or tmp2) begin
    case ({select, tmp1 < tmp2})
        2'b00:
            result = tmp1;
        2'b01:
            result = tmp2;
        2'b10:
            result = tmp2;
        2'b11:
            result = tmp1;
    endcase
end

endmodule
