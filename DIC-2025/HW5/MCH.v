module MCH (
    input               clk,
    input               reset,
    input       [ 7:0]  X,
    input       [ 7:0]  Y,
    output              Done,
    output      [16:0]  area
);

/////////////////////////////////
// Please write your code here //
/////////////////////////////////

localparam NUM_POINTS = 20;
localparam NUM_VECTORS = NUM_POINTS - 1;

localparam READ       = 3'd0,
           SORT       = 3'd1,
           GRAHM_SCAN = 3'd2,
           AREA       = 3'd3,
        //    IDLE       = 3'd4, // Wait for area calculation
           DONE       = 3'd7;

reg [2:0] state, next_state;

// Input points
reg [7:0] x_r [NUM_POINTS:0]; // Total NUM_POINTS + 1 points
reg [7:0] y_r [NUM_POINTS:0];

// convex hull points
reg [7:0] convex_x [NUM_POINTS:0];
reg [7:0] convex_y [NUM_POINTS:0];

reg [4:0] idx;

// For finding buttom left point
reg [7:0] x_min, y_min;
reg [4:0] min_idx;

// stack pointer
reg [4:0] top;

reg [16:0] area_r;

// vector

wire signed [35:0] cross_product;
wire signed [35:0] cross_product2 = cross_prod (
                                        convex_x[top - 2], convex_y[top - 2],
                                        convex_x[top - 1], convex_y[top - 1],
                                        x_r[idx], y_r[idx]
                                    );
wire [38:0] dis0, dis1; // Manhattan distance
wire cmp;
wire is_inside;

integer i;

//////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////

function [38:0] distance;
    input [7:0] y0, x0, y1, x1;
    begin
        distance = (y1 > y0 ? y1 - y0 : y0 - y1) + (x1 > x0 ? x1 - x0 : x0 - x1);
    end
endfunction

function signed [35:0] cross_prod;
    input [7:0] x0, y0, x1, y1, x2, y2;
    reg signed [8:0] dy1, dx1, dy2, dx2;
    begin
        dy1 = y1 - y0;
        dx1 = x1 - x0;
        dy2 = y2 - y0;
        dx2 = x2 - x0;
        cross_prod = dx1 * dy2 - dy1 * dx2;
    end
endfunction

//////////////////////////////////////////////////////////////////////
// FSM
//////////////////////////////////////////////////////////////////////

always @(*) begin
    case (state)
        READ: begin
            next_state = (idx == NUM_POINTS - 1) ? SORT : READ;
        end
        SORT: begin
            next_state = ( (idx == NUM_VECTORS - 2) && (!cmp) ) ? GRAHM_SCAN : SORT;
        end
        GRAHM_SCAN: begin
            next_state = (idx == NUM_POINTS && !is_inside) ? AREA : GRAHM_SCAN;
        end
        AREA: begin
            next_state = (idx == top - 2) ? DONE : AREA;
        end
        // IDLE: begin
        //     next_state = DONE;
        // end
        DONE: begin
            next_state = READ;
        end
        default: begin
            next_state = READ;
        end
    endcase
end

//////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////

// x, y
always @(posedge clk) begin
    case (state)
        READ: begin
            x_r[idx] <= X;
            y_r[idx] <= Y;

            // Swap the first point with the minimum point
            if (next_state == SORT) begin
                { x_r[0], x_r[min_idx] } <= { x_r[min_idx], x_r[0] };
                { y_r[0], y_r[min_idx] } <= { y_r[min_idx], y_r[0] };

                // The next point of the last point is the first point
                x_r[NUM_POINTS] <= x_r[min_idx];
                y_r[NUM_POINTS] <= y_r[min_idx];
            end
        end
        SORT: begin

            // Swap points if the cross product is negative
            if (cmp) begin
                { x_r[idx + 1], x_r[idx + 2] } <= { x_r[idx + 2], x_r[idx + 1] };
                { y_r[idx + 1], y_r[idx + 2] } <= { y_r[idx + 2], y_r[idx + 1] };
            end
        end
    endcase
end

// convex hull
always @(posedge clk) begin
    convex_x[top] <= x_r[idx];
    convex_y[top] <= y_r[idx];
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        area_r <= 0;
    end else if (state == AREA) begin
        area_r <= area_r + (
            (convex_x[idx] * convex_y[idx + 1]) -
            (convex_x[idx + 1] * convex_y[idx])
        );
    end else if (state == DONE) begin
        area_r <= 0;
    end
end

//////////////////////////////////////////////////////////////////////
// Control
//////////////////////////////////////////////////////////////////////

// idx
always @(posedge clk or posedge reset) begin
    if (reset) begin
        idx <= 0;
    end else begin
        case (state)
            READ: begin
                idx <= (idx == NUM_POINTS - 1) ? 0 : idx + 1;
            end

            SORT: begin
                if (cmp) begin
                    idx <= (idx == 0) ? 0 : idx - 1;
                end else begin
                    idx <= (idx == NUM_VECTORS - 2) ? 0 : idx + 1;
                end
            end

            GRAHM_SCAN: begin
                if (is_inside) begin
                    top <= top;
                end else begin
                    idx <= (idx == NUM_POINTS) ? 0 : idx + 1;
                end
            end

            AREA: begin
                idx <= (idx == top - 2) ? 0 : idx + 1;
            end
        endcase
    end
end

// top
always @(posedge clk or posedge reset) begin
    if (reset) begin
        top <= 0;
    end else if (state == GRAHM_SCAN) begin
        if (is_inside) begin
            top <= top - 1;
        end else begin
            top <= top + 1;
        end
    end else if (state == DONE) begin
        top <= 0;
    end
end

// x_min, y_min, min_idx
always @(posedge clk or posedge reset) begin
    if (reset) begin
        x_min <= 8'hFF;
        y_min <= 8'hFF;
        min_idx <= 0;
    end else if (state == READ) begin
        if ( (Y < y_min) || (Y == y_min && X < x_min) ) begin
            x_min <= X;
            y_min <= Y;
            min_idx <= idx;
        end
    end else begin
        x_min <= 8'hFF;
        y_min <= 8'hFF;
        min_idx <= 0;
    end
end

// state
always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= READ;
    end else begin
        state <= next_state;
    end
end

// assign cross_product = (vx[idx] * vy[idx + 1]) - (vx[idx + 1] * vy[idx]);
assign cross_product = cross_prod(
    x_r[0], y_r[0],
    x_r[idx + 1], y_r[idx + 1],
    x_r[idx + 2], y_r[idx + 2]
);

// Manhattan distance
assign dis0 = distance(y_r[0], x_r[0], y_r[idx + 1], x_r[idx + 1]);
assign dis1 = distance(y_r[0], x_r[0], y_r[idx + 2], x_r[idx + 2]);

// compare function
assign cmp = (cross_product < 0) || (cross_product == 0 && dis0 > dis1);

// point[top - 1] is inside the convex
assign is_inside = (top >= 2) && (cross_product2 <= 0);

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

assign Done = (state == DONE);
assign area = area_r;

//////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////

// integer cp;
// always @(posedge clk) begin
//     if (state == SORT) begin
//         for (i = 0; i < 20; i = i + 1) begin
//             $display(
//                 "p[%02d] = (%03d, %03d) (0x%02x, 0x%02x)",
//                 i, x_r[i], y_r[i], x_r[i], y_r[i]
//             );
//         end
//         // for (i = 0; i < 19; i = i + 1) begin
//         //     cp = vx[i] * vy[i + 1] - vx[i + 1] * vy[i];
//         //     $display(
//         //         "v[%02d] = (%4d, %4d) %s, cross product = %d",
//         //         i, vx[i], vy[i], (i == idx) ? "<--" : "", cp
//         //     );
//         // end
//         // $display("cross_product = %d", cross_product);
//         // if (cross_product < 0) begin
//         //     $display(
//         //         "p[0]->p[%02d] x p[0]->p[%02d] cross product is %d, swapping points.",
//         //         idx + 1, idx + 2, cross_product
//         //     );
//         // end
//         // $display("dis0 = %d, dis1 = %d", dis0, dis1);

//         $display();
//     end else if (state == GRAHM_SCAN) begin
//         for (i = 0; i < top; i = i + 1) begin
//             $display(
//                 "convex[%02d] = (%03d, %03d) (0x%02x, 0x%02x)",
//                 i, convex_x[i], convex_y[i], convex_x[i], convex_y[i]
//             );
//         end
//         if (!is_inside) begin
//             $display(
//                 "convex[%02d] = (%03d, %03d) (0x%02x, 0x%02x) <--",
//                 top, x_r[idx], y_r[idx], x_r[idx], y_r[idx]
//             );
//         end
//         $display();
//     end
// end

endmodule
