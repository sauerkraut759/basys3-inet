`timescale 1ns / 1ps

module inet_graph_engine #(
    parameter N_NODES = 32
)(
    input wire       clk,
    input wire       rst,
    input wire       start_demo,
    output reg [7:0] result_value,
    output reg [7:0] cycles_taken,
    output reg [7:0] total_reductions,
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
    
    /* el nodo 'i' forma un par activo con el nodo 'j' si port[i][MAIN] apunta a {j, P_MAIN}
     * y viceversa
     */
    reg [N_EDGES-1:0] is_active;
    reg [N_NODES-1:0] node_is_active;
    
    
    always @(*) begin : active_pair_detection
        integer i;
        reg [4:0] id_L, id_R;
        reg [1:0] p_L, p_R;
        
        node_is_active = {N_NODES{1'b0}}; // Inicializar antes para no borrar en el else
        
        for (i = 0; i < N_EDGES; i = i + 1) begin
            p_L = edges[i][13:12];
            id_L = edges[i][11:7];
            p_R = edges[i][6:5];
            id_R = edges[i][4:0];
            
            if (p_L == P_MAIN
            &&  p_R == P_MAIN
            &&  id_L != id_R
            &&  nodes[id_L][20:18] != T_EMPTY
            &&  nodes[id_R][20:18] != T_EMPTY) begin
                is_active[i] = 1'b1;
                node_is_active[id_L] = 1'b1;
                node_is_active[id_R] = 1'b1;
            end else begin
                is_active[i] = 1'b0;
            end
        end
    end
    
    reg [5:0] delta_reductions;
    reg [3:0] delta_result;
    
    always @(*) begin : compute_next_state
        integer i;
        reg [4:0] id_L, id_R, id_A, id_B, id_X;
        reg [2:0] type_L, type_R, type_A, type_B;
        reg [5:0] e_out, e_pred, e_aux1, e_next;
        reg [1:0] p_X;
        
        // Valores por defecto
        for (i = 0; i < N_EDGES; i = i + 1) begin
            next_edges[i] = edges[i];
        end
        for (i = 0; i < N_NODES; i = i + 1) begin
            next_nodes[i] = nodes[i];
        end
        
        delta_reductions = 6'd0;
        delta_result = 4'd0;
        
        id_L = 5'd0; id_R = 5'd0; id_A = 5'd0; id_B = 5'd0; id_X = 5'd0;
        type_L = 3'd0; type_R = 3'd0; type_A = 3'd0; type_B = 3'd0;
        e_out  = 6'd0; e_pred = 6'd0; e_aux1 = 6'd0; e_next = 6'd0;
        p_X    = 2'd0;
        
        // Evaluacion paralela sobre todas las aristas activas
        for (i = 0; i < N_EDGES; i = i + 1) begin
            if (is_active[i]) begin
                id_L = edges[i][11:7];
                id_R = edges[i][4:0];
                type_L = nodes[id_L][20:18];
                type_R = nodes[id_R][20:18];
                
                // Normalizar para que A siempre sea consumidor (ADD, IO) y B el dato (S, Z)
                if (type_L == T_ADD || type_L == T_IO) begin
                    id_A = id_L;
                    type_A = type_L;
                    id_B = id_R;
                    type_B = type_R;
                end else begin
                    id_A = id_R;
                    type_A = type_R;
                    id_B = id_L;
                    type_B = type_L;
                end
                
                // Regla 1: ADD >< S
                if (type_A == T_ADD && type_B == T_S) begin
                    e_out = nodes[id_A][5:0]; // A.AUX2 (arista resultado)
                    e_pred = nodes[id_B][11:6]; // B.AUX1 (arista antecesor)
                    
                    /* Al reescribir los bits de una arista la
                     * escritura debe hacerse exactamente en
                     * el extremo donde se encontraba el elemento a
                     * reemplazar para evitar errores cuando se
                     * reduzcan multiples pares activos conectados
                     */
                     
                    // B toma el lugar de A.AUX2 en e_out
                    if (edges[e_out][13:7] == {P_AUX2, id_A}) begin
                        next_edges[e_out][13:7] = {P_MAIN, id_B};
                    end else begin
                        next_edges[e_out][6:0] = {P_MAIN, id_B};
                    end
                    next_nodes[id_B][17:12] = e_out;
                    
                    // A toma el lugar de B.AUX1 en e_pred
                    if (edges[e_pred][13:7] == {P_AUX1, id_B}) begin
                        next_edges[e_pred][13:7] = {P_MAIN, id_A};
                    end else begin
                        next_edges[e_pred][6:0] = {P_MAIN, id_A};
                    end
                    next_nodes[id_A][17:12] = e_pred;
                    
                    // La arista i se reutiliza para el enlace interno A.AUX2 - B.AUX1
                    next_edges[i] = {P_AUX2, id_A, P_AUX1, id_B};
                    next_nodes[id_A][5:0] = i[5:0];
                    next_nodes[id_B][11:6] = i[5:0];
                    
                    delta_reductions = delta_reductions + 6'd1;
                end
                
                // Regla 2: ADD >< Z
                else if (type_A == T_ADD && type_B == T_Z) begin
                    e_aux1 = nodes[id_A][11:6]; // A.AUX1
                    e_out = nodes[id_A][5:0]; // A.AUX2
                    
                    // Extraer vecino X desde el extremo opuesto de e_aux1
                    if (edges[e_aux1][13:7] == {P_AUX1, id_A}) begin
                        p_X = edges[e_aux1][6:5];
                        id_X = edges[e_aux1][4:0];
                    end else begin
                        p_X = edges[e_aux1][13:12];
                        id_X = edges[e_aux1][11:7];
                    end
                    
                    /* 
                    * Para no disparar la complejidad, esta reduccion
                    * no puede suceder si el nodo X tambien está reduciendo
                    * para permitir que ambas reduzcan haria falta
                    * implementar una reescritura por fases capaz de
                    * detectar aristas "largas" y compactarlas en una
                    * sola. Se escapa del alcance de este proyecto básico
                    */
                    if (!node_is_active[id_X]) begin
                        // X reemplaza a A.AUX2 en e_out
                        if (edges[e_out][13:7] == {P_AUX2, id_A}) begin
                            next_edges[e_out][13:7] = {p_X, id_X};
                        end else begin
                            next_edges[e_out][6:0] = {p_X, id_X};
                        end
                    
                        // Actualizar en X solo el puerto p_X que apuntaba a e_aux1
                        case (p_X)
                            P_MAIN: next_nodes[id_X][17:12] = e_out;
                            P_AUX1: next_nodes[id_X][11:6] = e_out;
                            P_AUX2: next_nodes[id_X][5:0] = e_out;
                            default: ;
                        endcase
                    
                        // Limpiar nodos A, B y aristas i, e_aux1
                        next_edges[i] = 14'd0;
                        next_edges[e_aux1] = 14'd0;
                        next_nodes[id_A] = 21'd0;
                        next_nodes[id_B] = 21'd0;
                    
                        delta_reductions = delta_reductions + 6'd1;
                    end 
                end
                
                // Regla 3: IO >< S
                else if (type_A == T_IO && type_B == T_S) begin
                    e_next = nodes[id_B][11:6]; // B.AUX1
                    
                    // IO reemplaza a B.AUX1 en e_next
                    if (edges[e_next][13:7] == {P_AUX1, id_B}) begin
                        next_edges[e_next][13:7] = {P_MAIN, id_A};
                    end else begin
                        next_edges[e_next][6:0] = {P_MAIN, id_A};
                    end
                    
                    // Reemplaza P_MAIN en IO por e_next
                    next_nodes[id_A][17:12] = e_next;
                    // Limpiar arista i y nodo S
                    next_edges[i] = 14'd0;
                    next_nodes[id_B] = 21'd0;
                    
                    delta_result = delta_result + 4'd1;
                    delta_reductions = delta_reductions + 6'd1;
                end
                
                // Regla 4: IO >< Z (FIN)
                else if (type_A == T_IO && type_B == T_Z) begin
                    next_nodes[id_A][17:12] = 6'd0;
                    next_edges[i] = 14'd0;
                    next_nodes[id_B] = 21'd0;
                    
                    delta_reductions = delta_reductions + 6'd1;
                end
            end
        end
    end
    
    assign done = ~(|is_active); // listo cuando no hay pares activos
    
    // limpiar, cargar grafo y commit del estado t+1
    always @(posedge clk) begin: state_update
        integer i;
        
        if (rst) begin
            for (i = 0; i < N_EDGES; i = i + 1) begin
                edges[i] <= 14'd0;
            end
            for (i = 0; i < N_NODES; i = i + 1) begin
                nodes[i] <= 21'd0; 
            end
            
            total_reductions <= 8'd0;
            cycles_taken <= 8'd0;
            result_value <= 8'd0;
        end else if (!done) begin
            for (i = 0; i < N_EDGES; i = i + 1) begin
                edges[i] <= next_edges[i];
            end
            for (i = 0; i < N_NODES; i = i + 1) begin
                nodes[i] <= next_nodes[i];
            end
            
            total_reductions <= total_reductions + delta_reductions;
            result_value <= result_value + delta_result;
            cycles_taken <= cycles_taken + 8'd1;
        end
    end
        
endmodule