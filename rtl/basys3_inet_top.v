`timescale 1ns / 1ps

module basys3_inet_top (
    input  wire        clk,   // W5 (100 MHz)
    input  wire        rst,  // U18 (Reset)
    input  wire [1:0]  sw,    // V17, V16 (Selector de métrica en LEDs)
    output reg  [15:0] led    // U16..L1
);

    wire [7:0] result_value;
    wire [7:0] cycles_taken;
    wire [7:0] total_reductions;
    wire       done;

    inet_graph_engine #(
        .N_NODES(20)
    ) u_engine (
        .clk              (clk),
        .rst              (rst),
        .result_value     (result_value),
        .cycles_taken     (cycles_taken),
        .total_reductions (total_reductions),
        .done             (done)
    );

    always @(*) begin
        led[15]   = done;
        led[14:8] = 7'd0;
        case (sw)
            2'b00:   led[7:0] = result_value;
            2'b01:   led[7:0] = cycles_taken;
            2'b10:   led[7:0] = total_reductions;
            default: led[7:0] = result_value;
        endcase
    end

endmodule