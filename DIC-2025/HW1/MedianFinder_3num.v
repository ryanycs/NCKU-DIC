module MedianFinder_3num(
           input  [3:0]    num1    ,
           input  [3:0]    num2    ,
           input  [3:0]    num3    ,
           output [3:0]    median
       );

wire [3:0] min0, max0, min1;

Comparator2 u_Comparator2_0(
                .A(num1),
                .B(num2),
                .min(min0),
                .max(max0)
            );

Comparator2 u_Comparator2_1(
                .A(max0),
                .B(num3),
                .min(min1),
                .max()
            );

Comparator2 u_Comparator2_2(
                .A(min0),
                .B(min1),
                .min(),
                .max(median)
            );

endmodule
