module MedianFinder_5num(
           input  [3:0] 	num1  ,
           input  [3:0] 	num2  ,
           input  [3:0] 	num3  ,
           input  [3:0] 	num4  ,
           input  [3:0] 	num5  ,
           output [3:0] 	median
       );

wire [3:0] min0, max0, min1, max1, max2, min3;

Comparator2 u_Comparator2_0(
                .A(num1),
                .B(num2),
                .min(min0),
                .max(max0)
            );

Comparator2 u_Comparator2_1(
                .A(num3),
                .B(num4),
                .min(min1),
                .max(max1)
            );

Comparator2 u_Comparator2_2(
                .A(min0),
                .B(min1),
                .min(),
                .max(max2)
            );

Comparator2 u_Comparator2_3(
                .A(max0),
                .B(max1),
                .min(min3),
                .max()
            );

MedianFinder_3num u_MedianFinder_3num(
                      .num1(max2),
                      .num2(min3),
                      .num3(num5),
                      .median(median)
                  );

endmodule
