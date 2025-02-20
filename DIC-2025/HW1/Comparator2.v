module Comparator2 (
           input   [3:0]   A  ,
           input   [3:0]   B  ,
           output  reg [3:0]   min,
           output  reg [3:0]   max
       );

always @(*) begin
    case (A < B)
        1'b0: begin
            min = B;
            max = A;
        end

        1'b1: begin
            min = A;
            max = B;
        end
    endcase
end

endmodule
