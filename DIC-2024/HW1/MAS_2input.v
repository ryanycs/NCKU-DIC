//
// Designer: <student ID>
//
module MAS_2input(
           input signed [4:0]Din1,
           input signed [4:0]Din2,
           input [1:0]Sel,
           input signed[4:0]Q,
           output [1:0]Tcmp,
           output signed [4:0]TDout,
           output signed [3:0]Dout
       );

wire signed [4:0] tmp;

ALU1 u_ALU1(
         .Din1(Din1),
         .Din2(Din2),
         .Sel(Sel),
         .result(tmp)
     );

Q_comparator u_Q_comparator(
                 .Din(tmp),
                 .Q(Q),
                 .Tcmp(Tcmp)
             );

ALU2 u_ALU2(
         .Din(tmp),
         .Q(Q),
         .Tcmp(Tcmp),
         .result(TDout)
     );

assign Dout = TDout[3:0];

endmodule

    module ALU1(
        input signed [4:0] Din1,
        input signed [4:0] Din2,
        input [1:0] Sel,
        output reg signed [4:0] result
    );

always @( *) begin
    case (Sel)
        2'b00:
            result = Din1 + Din2;
        2'b11:
            result = Din1 - Din2;
        default:
            result = Din1;
    endcase
end

endmodule

    module Q_comparator(
        input signed [4:0] Din,
        input signed [4:0] Q,
        output [1:0] Tcmp
    );

wire LSB, MSB;

assign LSB = (Din >= 0);
assign MSB = (Din >= Q);
assign Tcmp = {MSB, LSB};

endmodule

    module ALU2(
        input signed [4:0] Din,
        input signed [4:0] Q,
        input [1:0] Tcmp,
        output reg signed [4:0] result
    );

always @( *) begin
    case (Tcmp)
        2'b00: // Din < 0
            result = Din + Q;
        2'b01: // Q > Din >= 0
            result = Din;
        2'b11: // Din >= Q >= 0
            result = Din - Q;
        default:
            result = Din;
    endcase
end

endmodule
