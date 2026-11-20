`timescale 1ns / 1ps

module inet_graph_engine #(
    parameter N_NODES = 32
)(
    input wire       clk,
    input wire       rst,
    input wire       start_demo,
    output reg [7:0] result_value,
    output reg [7:0] cycles_taken,
    output reg [7:0] total_red,
    output wire      done
);

    // Tipos de nodos
    localparam [2:0]
        T_EMPTY = 3'd0,
        T_IO    = 3'd1, // Puerto de entrada / salida para el resultado
        T_Z     = 3'd2, // Cero
        T_S     = 3'd3, // Sucesor (+1)
        T_ADD   = 3'd4; // Sumador
        
    // Tipos de puerto
    localparam [1:0]
        P_MAIN = 2'd0,
        P_AUX1 = 2'd1,
        P_AUX2 = 2'd2,
        P_NONE = 2'd3;
    
    // Grafo
    reg [2:0] node_type [0:N_NODES-1];
    reg [6:0] port      [0:N_NODES-1][0:2]; // matriz de Nodos x Puertos (32x3) 
    
    // Registros para almacenar el estado del siguiente ciclo
    reg [2:0] next_type [0:N_NODES-1];
    reg [6:0] next_port [0:N_NODES-1][0:2];
    
    // funcion para empaquetar un nodo y un puerto en un puntero
    function [6:0] ptr(input [4:0] n, input [1:0] p);
        ptr = {n, p};
    endfunction
    
    // deteccion de pares activos:
    // el nodo 'i' forma un par activo con el nodo 'j' si port[i][MAIN] apunta a {j, P_MAIN}
    // y viceversa
    reg [N_NODES-1:0] is_active;
    integer i, j;
    reg [4:0] partner;
    reg [1:0] partner_p;
    
    always @(*) begin
        for (i = 0; i < N_NODES; i = i + 1) begin
            partner = port[i][P_MAIN][6:2];
            partner_p = port[i][P_MAIN][1:0];
            if (node_type[i] != T_EMPTY
            &&  partner_p == P_MAIN
            &&  partner != i[6:2]
            &&  node_type[partner] != T_EMPTY
            &&  port[partner][P_MAIN] == ptr(i[4:0], P_MAIN)) begin
                is_active[i] = 1'b1;
            end else begin
                is_active[i] = 1'b0;
            end
        end
    end
    
    reg [N_NODES-1:0] can_reduce; // Mascara para arbitraje para evitar corrupcion de punteros
    
    always @(*) begin
        
endmodule