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
        P_NONE = 2'd0,
        P_MAIN = 2'd1,
        P_AUX1 = 2'd2,
        P_AUX2 = 2'd3;
        
    /* La representación se centrará en las aristas
     * [puerto_L (2b)] | nodo_L (5b) | puerto_R (2b) | nodo_R (5b)]
     * 14 bits en total
     *
     * La cantidad de aristas totales se calcula por
     * el lema del apreton de manos:
     * Aristas = Sum(deg(v)) / 2
     *
     * Los nodos guardan su tipo (3b) y el indice de sus puertos (6b c/u)
     * total: 21b
     */
    
    localparam integer N_EDGES = (N_NODES * 3) / 2;
    
    // Estado actual del grafo
    reg [13:0] edges [0:N_EDGES-1]; 
    reg [20:0] nodes [0:N_NODES-1];
    
    // Estado t+1 del grafo
    reg [13:0] next_edges [0:N_EDGES-1]; 
    reg [20:0] next_nodes [0:N_NODES-1];
    
    // funcion para empaquetar un nodo y un puerto en un puntero
    function [6:0] ptr(input [1:0] p, input [4:0] n);
        ptr = {p,n};
    endfunction
    
    // deteccion de pares activos:
    // el nodo 'i' forma un par activo con el nodo 'j' si port[i][MAIN] apunta a {j, P_MAIN}
    // y viceversa
    reg [N_EDGES-1:0] is_active;
    
    
    
    always @(*) begin : active_pair_detection
        integer i;
        reg [4:0] id_L, id_R;
        reg [1:0] p_L, p_R;
        for (i = 0; i < N_EDGES; i = i + 1) begin
            p_L = edges[i][13:12];
            p_R = edges[i][6:5];
            id_L = edges[i][11:7];
            id_R = edges[i][4:0];
            
            if (p_L == P_MAIN
            &&  p_R == P_MAIN
            &&  id_L != id_R
            &&  nodes[id_L][20:18] != T_EMPTY
            &&  nodes[id_R][20:18] != T_EMPTY) begin
                is_active[i] = 1'b1;
            end else begin
                is_active[i] = 1'b0;
            end
        end
    end
    
    always @(*) begin: compute_next_state
        integer i;
        reg [4:0] id_A, id_B;
        reg [2:0] type_L, type_R;
        reg [20:0] node_A, node_B;
        reg [5:0] aux1_A, aux2_A;
        // valores por defecto para evitar latches
        for (i = 0; i < N_EDGES; i = i + 1) begin
            next_edges[i] = edges[i];
        end
        for (i = 0; i < N_NODES; i = i + 1) begin
            next_nodes[i] = nodes[i];
        end
        
        for (i = 0; i < N_EDGES; i = i + 1) begin
            type_L = nodes[edges[i][11:7]][20:18];
            type_R = nodes[edges[i][4:0]][20:18];
            if (is_active[i]) begin
                id_A = (type_L == T_IO || type_L == T_ADD) ? edges[i][11:7] : edges[i][4:0];
                id_B = (type_L == T_IO || type_L == T_ADD) ? edges[i][4:0] : edges[i][11:7];
                node_A = nodes[id_A];
                node_B = nodes[id_B];
                
                aux1_A = node_A[11:6];
                aux2_A = node_A[5:0];
                
                if (node_A[20:18] == T_ADD && node_B[20:18] == T_Z) begin
                    if (is_active[aux1_A])
                end
                
            end else begin
                id_A = edges[i][11:7];
                id_B = edges[i][4:0];
                node_A = nodes[id_A];
                node_B = nodes[id_B];
                aux1_A = node_A[11:6];
                aux2_A = node_A[5:0];
            end
        end
    end
    
        
endmodule