module MedianFinder_7num(
           input  	[3:0]  	num1  ,
           input  	[3:0]  	num2  ,
           input  	[3:0]  	num3  ,
           input  	[3:0]  	num4  ,
           input  	[3:0]  	num5  ,
           input  	[3:0]  	num6  ,
           input  	[3:0]  	num7  ,
           output 	[3:0] 	median
       );

wire [3:0] min0, max0, min1, max1, min2, max2, min3, max3, max4, min5, max5, min6;

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
                .A(num5),
                .B(num6),
                .min(min2),
                .max(max2)
            );

Comparator2 u_Comparator2_3(
                .A(min0),
                .B(min1),
                .min(min3),
                .max(max3) // to be connected to MedianFinder_5num
            );

Comparator2 u_Comparator2_4(
                .A(min2),
                .B(min3),
                .min(),
                .max(max4) // to be connected to MedianFinder_5num
            );

Comparator2 u_Comparator2_5(
                .A(max0),
                .B(max1),
                .min(min5), // to be connected to MedianFinder_5num
                .max(max5)
            );

Comparator2 u_Comparator2_6(
                .A(max2),
                .B(max5),
                .min(min6), // to be connected to MedianFinder_5num
                .max()
            );

MedianFinder_5num u_MedianFinder_5num(
                      .num1(max3),
                      .num2(max4),
                      .num3(min5),
                      .num4(min6),
                      .num5(num7),
                      .median(median)
                  );

endmodule
