`timescale 1ns / 1ps

module tb_sim;
    reg clk;
    reg rst_n;
    reg [3:0] i_Switch;
    
    wire [3:0] o_LED;
    wire o_Segment1_A, o_Segment1_B, o_Segment1_C, o_Segment1_D, o_Segment1_E, o_Segment1_F, o_Segment1_G;
    wire o_Segment2_A, o_Segment2_B, o_Segment2_C, o_Segment2_D, o_Segment2_E, o_Segment2_F, o_Segment2_G;

    // Bus virtual para monitorear el display en GTKWave
    wire [13:0] o_Segment_Bus = {
        o_Segment2_G, o_Segment2_F, o_Segment2_E, o_Segment2_D, o_Segment2_C, o_Segment2_B, o_Segment2_A,
        o_Segment1_G, o_Segment1_F, o_Segment1_E, o_Segment1_D, o_Segment1_C, o_Segment1_B, o_Segment1_A
    };

    asic_top uut (
        .i_Clk(clk),
        .i_Reset_n(rst_n),
        .i_Switch(i_Switch),
        .o_LED(o_LED),
        
        .o_Segment1_A(o_Segment1_A), .o_Segment1_B(o_Segment1_B), .o_Segment1_C(o_Segment1_C),
        .o_Segment1_D(o_Segment1_D), .o_Segment1_E(o_Segment1_E), .o_Segment1_F(o_Segment1_F), .o_Segment1_G(o_Segment1_G),
        
        .o_Segment2_A(o_Segment2_A), .o_Segment2_B(o_Segment2_B), .o_Segment2_C(o_Segment2_C),
        .o_Segment2_D(o_Segment2_D), .o_Segment2_E(o_Segment2_E), .o_Segment2_F(o_Segment2_F), .o_Segment2_G(o_Segment2_G),
        
        .i_SPI_SCLK(1'b0), .i_SPI_MOSI(1'b0), .i_SPI_CS_n(1'b1), .o_SPI_MISO()
    );

    always #50 clk = ~clk;

    initial begin
        $dumpfile("ondas.vcd");
        $dumpvars(0, tb_sim);

        clk = 0; rst_n = 0; i_Switch = 4'b0000;
        #500; rst_n = 1; 

        // 1. ESPERA DE INICIO
        wait (o_LED == 4'b1001); 
        #500;
        i_Switch = 4'b0001; 
        #2000; // Mantenemos presionado 20 ciclos para asegurar lectura
        i_Switch = 4'b0000; 
        
        // =========================================================
        // PRUEBA 1: PULSACIÓN INCORRECTA
        // =========================================================
        wait (o_LED == 4'b1111); // Comienza ronda
        wait (o_LED != 4'b1111 && o_LED != 4'b0000 && o_LED != 4'b1001); // Muestra LED objetivo
        
        #2000; // Espera simulando tiempo de reacción
        i_Switch = (o_LED == 4'b0001) ? 4'b0010 : 4'b0001; // Pulsación errónea
        
        wait (o_LED == 4'b0000); // Esperamos a que la etiqueta "wrong" apague los LEDs
        #500; 
        i_Switch = 4'b0000; // Ahora sí soltamos el botón
        
        // =========================================================
        // PRUEBA 2: RONDA CORRECTA
        // =========================================================
        wait (o_LED == 4'b1111); // El error anterior reinicia la ronda
        wait (o_LED != 4'b1111 && o_LED != 4'b0000 && o_LED != 4'b1001); 
        
        #3500;  
        i_Switch = o_LED; // Pulsación correcta
        
        wait (o_LED == 4'b0000); // Esperamos a que la etiqueta "correct" apague los LEDs
        #500;
        i_Switch = 4'b0000; 
        
        #10000; // Esperamos los cálculos matemáticos para que se actualice el display
        
        $finish;
    end
endmodule