(* multstyle = "logic" *) module MCH (
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
localparam NUM_COMPARATORS = NUM_VECTORS >> 1;

localparam READ       = 3'd0,
           SORT       = 3'd1, // Odd-Even sort
           GRAHM_SCAN = 3'd2,
           AREA       = 3'd3,
           DONE       = 3'd4;

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

// compare function for Odd-Even sort
reg cmp[NUM_COMPARATORS - 1:0];

reg [7:0] x0, y0, x1, y1, x2, y2;
wire signed [18:0] cross_product = cross_prod(x0, y0, x1, y1, x2, y2);

// point[top - 1] is inside the convex
wire is_inside = (top >= 2) && (cross_product <= 0);

wire is_odd = (idx & 1);

integer i;

//////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////

function [8:0] distance;
    input [7:0] y0, x0, y1, x1;
    begin
        distance = (y1 > y0 ? y1 - y0 : y0 - y1) + (x1 > x0 ? x1 - x0 : x0 - x1);
    end
endfunction

function signed [18:0] cross_prod;
    input [7:0] x0, y0, x1, y1, x2, y2;
    reg signed [8:0] dy1, dx1, dy2, dx2;
    begin
        dy1 = y1 - y0;
        dx1 = x1 - x0;
        dy2 = y2 - y0;
        dx2 = x2 - x0;
        cross_prod = (dx1 * dy2) - (dy1 * dx2);
    end
endfunction

function compare;
    input [7:0] x0, y0, x1, y1, x2, y2;
    reg signed [18:0] cross_product;
    reg [8:0] dis0, dis1;
    begin
        cross_product = cross_prod(x0, y0, x1, y1, x2, y2);
        dis0 = distance(y0, x0, y1, x1);
        dis1 = distance(y0, x0, y2, x2);

        // If the cross product is 0, compare the distances
        // The point with the larger distance is considered "greater"
        compare = (cross_product[18]) || (~|cross_product && dis0 > dis1);
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
            next_state = (idx == NUM_VECTORS) ? GRAHM_SCAN : SORT;
        end
        GRAHM_SCAN: begin
            next_state = (idx == NUM_POINTS && !is_inside) ? AREA : GRAHM_SCAN;
        end
        AREA: begin
            next_state = (idx == top - 2) ? DONE : AREA;
        end
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
            // TODO: Odd-Even sort
            // Swap points if the cross product is negative
            if (is_odd) begin
                // Odd phase
                for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
                    { x_r[i * 2 + 1], x_r[i * 2 + 2] } <= (
                        cmp[i] ?
                        { x_r[i * 2 + 2], x_r[i * 2 + 1] } :
                        { x_r[i * 2 + 1], x_r[i * 2 + 2] }
                    );

                    { y_r[i * 2 + 1], y_r[i * 2 + 2] } <= (
                        cmp[i] ?
                        { y_r[i * 2 + 2], y_r[i * 2 + 1] } :
                        { y_r[i * 2 + 1], y_r[i * 2 + 2] }
                    );
                end
            end else begin
                // Even phase
                for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
                    { x_r[i * 2 + 2], x_r[i * 2 + 3] } <= (
                        cmp[i] ?
                        { x_r[i * 2 + 3], x_r[i * 2 + 2] } :
                        { x_r[i * 2 + 2], x_r[i * 2 + 3] }
                    );

                    { y_r[i * 2 + 2], y_r[i * 2 + 3] } <= (
                        cmp[i] ?
                        { y_r[i * 2 + 3], y_r[i * 2 + 2] } :
                        { y_r[i * 2 + 2], y_r[i * 2 + 3] }
                    );
                end
            end
        end
    endcase
end

// convex hull
always @(posedge clk) begin
    convex_x[top] <= x_r[idx];
    convex_y[top] <= y_r[idx];
end

// area
always @(posedge clk or posedge reset) begin
    if (reset) begin
        area_r <= 0;
    end else if (state == AREA) begin
        area_r <= area_r + cross_product;
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
                idx <= (idx == NUM_VECTORS) ? 0 : idx + 1;
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

// compare function
reg [7:0] x_a[8:0], x_b[8:0];
reg [7:0] y_a[8:0], y_b[8:0];
always @(*) begin
    if (is_odd) begin
        for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
            x_a[i] = x_r[i * 2 + 1];
            y_a[i] = y_r[i * 2 + 1];
            x_b[i] = x_r[i * 2 + 2];
            y_b[i] = y_r[i * 2 + 2];
        end
    end else begin
        for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
            x_a[i] = x_r[i * 2 + 2];
            y_a[i] = y_r[i * 2 + 2];
            x_b[i] = x_r[i * 2 + 3];
            y_b[i] = y_r[i * 2 + 3];
        end
    end

    for (i = 0; i < NUM_COMPARATORS; i = i + 1) begin
        cmp[i] = compare(x_r[0], y_r[0], x_a[i], y_a[i], x_b[i], y_b[i]);
    end
end

// cross product input
always @(*) begin
    if (state == GRAHM_SCAN) begin
        x0 = convex_x[top - 2];
        y0 = convex_y[top - 2];
        x1 = convex_x[top - 1];
        y1 = convex_y[top - 1];
        x2 = x_r[idx];
        y2 = y_r[idx];
    end else begin
        x0 = x_r[0];
        y0 = y_r[0];
        x1 = convex_x[idx];
        y1 = convex_y[idx];
        x2 = convex_x[idx + 1];
        y2 = convex_y[idx + 1];
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

//////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////

assign Done = (state == DONE);
assign area = area_r;

endmodule
