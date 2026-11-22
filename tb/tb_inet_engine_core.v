`timescale 1ns / 1ps

module tb_inet_engine;

    localparam [2:0] T_EMPTY = 3'd0;
    localparam [2:0] T_IO   = 3'd1;
    localparam [2:0] T_Z     = 3'd2;
    localparam [2:0] T_S     = 3'd3;
    localparam [2:0] T_ADD    = 3'd4;

    localparam [1:0] P_NONE = 2'd0;
    localparam [1:0] P_MAIN  = 2'd1;
    localparam [1:0] P_AUX1  = 2'd2;
    localparam [1:0] P_AUX2  = 2'd3;

    // Señales del DUT
    reg        clk;
    reg        rst;
    wire [3:0] result_value;
    wire [7:0] cycles_taken;
    wire [7:0] total_reductions;
    wire       done;

    // Instancia del motor (ajusta nombres de módulo/puertos si difieren)
    inet_graph_engine dut (
        .clk              (clk),
        .rst              (rst),
        .result_value     (result_value),
        .cycles_taken     (cycles_taken),
        .total_reductions (total_reductions),
        .done             (done)
    );

    // Reloj de 100 MHz (periodo 10 ns, igual que la Basys 3)
    always #5 clk = ~clk;

    // Tasks auxiliares para inyectar el grafo de forma legible
    task set_node;
        input [4:0] id;
        input [2:0] ntype;
        input [5:0] e_main;
        input [5:0] e_aux1;
        input [5:0] e_aux2;
        begin
            dut.nodes[id] = {ntype, e_main, e_aux1, e_aux2};
        end
    endtask

    task set_edge;
        input [5:0] eid;
        input [1:0] pL;
        input [4:0] idL;
        input [1:0] pR;
        input [4:0] idR;
        begin
            dut.edges[eid] = {pL, idL, pR, idR};
        end
    endtask

    integer timeout;

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        // 1. Mantener reset por 2 ciclos para limpiar tablas y contadores
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // =====================================================================
        // 2. Carga del grafo: (1 + 2) + (3 + 4) = 10
        //    ADD_left  (2): 1 + 2   |   ADD_right (3): 3 + 4
        //    ADD_root  (1): (1+2) + (3+4) -> IO (0)
        // =====================================================================

        // Nodos estructurales: set_node(id, type, e_main, e_aux1, e_aux2)
        set_node(5'd0,  T_IO,  6'd0,  6'd0,  6'd0); // IO
        set_node(5'd1,  T_ADD, 6'd1,  6'd2,  6'd0); // ADD_root
        set_node(5'd2,  T_ADD, 6'd3,  6'd5,  6'd1); // ADD_left  (1 + 2)
        set_node(5'd3,  T_ADD, 6'd8,  6'd12, 6'd2); // ADD_right (3 + 4)

        // Número 1 (S -> Z)
        set_node(5'd4,  T_S,   6'd3,  6'd4,  6'd0);
        set_node(5'd5,  T_Z,   6'd4,  6'd0,  6'd0);

        // Número 2 (S -> S -> Z)
        set_node(5'd6,  T_S,   6'd5,  6'd6,  6'd0);
        set_node(5'd7,  T_S,   6'd6,  6'd7,  6'd0);
        set_node(5'd8,  T_Z,   6'd7,  6'd0,  6'd0);

        // Número 3 (S -> S -> S -> Z)
        set_node(5'd9,  T_S,   6'd8,  6'd9,  6'd0);
        set_node(5'd10, T_S,   6'd9,  6'd10, 6'd0);
        set_node(5'd11, T_S,   6'd10, 6'd11, 6'd0);
        set_node(5'd12, T_Z,   6'd11, 6'd0,  6'd0);

        // Número 4 (S -> S -> S -> S -> Z)
        set_node(5'd13, T_S,   6'd12, 6'd13, 6'd0);
        set_node(5'd14, T_S,   6'd13, 6'd14, 6'd0);
        set_node(5'd15, T_S,   6'd14, 6'd15, 6'd0);
        set_node(5'd16, T_S,   6'd15, 6'd16, 6'd0);
        set_node(5'd17, T_Z,   6'd16, 6'd0,  6'd0);

        // Aristas: set_edge(eid, port_L, id_L, port_R, id_R)
        set_edge(6'd0,  P_MAIN, 5'd0,  P_AUX2, 5'd1);  // IO <-> ADD_root.out
        set_edge(6'd1,  P_MAIN, 5'd1,  P_AUX2, 5'd2);  // ADD_root.in1 <-> ADD_left.out
        set_edge(6'd2,  P_AUX1, 5'd1,  P_AUX2, 5'd3);  // ADD_root.in2 <-> ADD_right.out

        set_edge(6'd3,  P_MAIN, 5'd2,  P_MAIN, 5'd4);  // ADD_left.in1 <-> 1 [ACTIVO]
        set_edge(6'd4,  P_AUX1, 5'd4,  P_MAIN, 5'd5);
        set_edge(6'd5,  P_AUX1, 5'd2,  P_MAIN, 5'd6);  // ADD_left.in2 <-> 2
        set_edge(6'd6,  P_AUX1, 5'd6,  P_MAIN, 5'd7);
        set_edge(6'd7,  P_AUX1, 5'd7,  P_MAIN, 5'd8);

        set_edge(6'd8,  P_MAIN, 5'd3,  P_MAIN, 5'd9);  // ADD_right.in1 <-> 3 [ACTIVO]
        set_edge(6'd9,  P_AUX1, 5'd9,  P_MAIN, 5'd10);
        set_edge(6'd10, P_AUX1, 5'd10, P_MAIN, 5'd11);
        set_edge(6'd11, P_AUX1, 5'd11, P_MAIN, 5'd12);
        set_edge(6'd12, P_AUX1, 5'd3,  P_MAIN, 5'd13); // ADD_right.in2 <-> 4
        set_edge(6'd13, P_AUX1, 5'd13, P_MAIN, 5'd14);
        set_edge(6'd14, P_AUX1, 5'd14, P_MAIN, 5'd15);
        set_edge(6'd15, P_AUX1, 5'd15, P_MAIN, 5'd16);
        set_edge(6'd16, P_AUX1, 5'd16, P_MAIN, 5'd17);

        // Pequeño retardo para que el bloque combinacional propague is_active
        #1;
        $display("---------------------------------------------------------------");
        $display("Ciclo | Reduc/ciclo | Reduc Totales | Resultado | Done");
        $display("---------------------------------------------------------------");

        // 3. Monitoreo ciclo a ciclo con timeout de seguridad
        timeout = 0;
        while (!done && timeout < 50) begin
            $display("  %2d  |      %2d     |      %3d      |    %2d     |  %b",
                     cycles_taken, dut.delta_reductions, total_reductions, result_value, done);
            @(posedge clk);
            #1;
            timeout = timeout + 1;
        end

        // Estado final tras terminar
        $display("  %2d  |      %2d     |      %3d      |    %2d     |  %b",
                 cycles_taken, dut.delta_reductions, total_reductions, result_value, done);
        $display("---------------------------------------------------------------");

        if (done && result_value == 4'd10 && total_reductions == 8'd21) begin
            $display("PASS: (1+2)+(3+4) = %0d en %0d ciclos (%0d reducciones paralelas).",
                     result_value, cycles_taken, total_reductions);
        end else begin
            $display("FAIL: result=%0d (esperado 10), reduc=%0d (esperado 21), done=%b, timeout=%0d",
                     result_value, total_reductions, done, timeout);
        end

        $finish;
    end

endmodule
