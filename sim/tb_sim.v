`timescale 1ns / 1ps

module tb_sim;

    reg clk;
    reg rst_n;
    reg [3:0] i_Switch;

    wire [3:0] o_LED;

    wire o_Segment1_A, o_Segment1_B, o_Segment1_C, o_Segment1_D;
    wire o_Segment1_E, o_Segment1_F, o_Segment1_G;

    wire o_Segment2_A, o_Segment2_B, o_Segment2_C, o_Segment2_D;
    wire o_Segment2_E, o_Segment2_F, o_Segment2_G;

    // Bus virtual para monitorear el display en GTKWave
    wire [13:0] o_Segment_Bus = {
        o_Segment2_G, o_Segment2_F, o_Segment2_E, o_Segment2_D,
        o_Segment2_C, o_Segment2_B, o_Segment2_A,
        o_Segment1_G, o_Segment1_F, o_Segment1_E, o_Segment1_D,
        o_Segment1_C, o_Segment1_B, o_Segment1_A
    };

    // DUT
    asic_top uut (
        .i_Clk(clk),
        .i_Reset_n(rst_n),
        .i_Switch(i_Switch),
        .o_LED(o_LED),

        .o_Segment1_A(o_Segment1_A),
        .o_Segment1_B(o_Segment1_B),
        .o_Segment1_C(o_Segment1_C),
        .o_Segment1_D(o_Segment1_D),
        .o_Segment1_E(o_Segment1_E),
        .o_Segment1_F(o_Segment1_F),
        .o_Segment1_G(o_Segment1_G),

        .o_Segment2_A(o_Segment2_A),
        .o_Segment2_B(o_Segment2_B),
        .o_Segment2_C(o_Segment2_C),
        .o_Segment2_D(o_Segment2_D),
        .o_Segment2_E(o_Segment2_E),
        .o_Segment2_F(o_Segment2_F),
        .o_Segment2_G(o_Segment2_G),

        .i_SPI_SCLK(1'b0),
        .i_SPI_MOSI(1'b0),
        .i_SPI_CS_n(1'b1),
        .o_SPI_MISO()
    );

    // Reloj: periodo de 100 ns
    always #50 clk = ~clk;

    // Contador de ciclos del testbench
    integer tb_cycle = 0;

    always @(posedge clk) begin
        if (!rst_n)
            tb_cycle <= 0;
        else
            tb_cycle <= tb_cycle + 1;
    end

    initial begin

        // Registro de ondas
        $dumpfile("ondas.vcd");
        $dumpvars(0, clk, rst_n, i_Switch, o_LED, o_Segment_Bus);

        // Inicialización
        clk = 0;
        rst_n = 0;
        i_Switch = 4'b0000;

        repeat (5) @(negedge clk);
        rst_n = 1;

        // =========================================================
        // 1. ESPERA DE INICIO
        // =========================================================

        wait (o_LED == 4'b1001);

        repeat (5) @(negedge clk);

        // Pulsación para iniciar el juego
        i_Switch = 4'b0001;

        repeat (20) @(negedge clk);

        // Soltar botón
        i_Switch = 4'b0000;

        // =========================================================
        // 2. PRUEBA DE PULSACIÓN INCORRECTA
        // =========================================================

        // Esperar comienzo de ronda
        wait (o_LED == 4'b1111);

        // Esperar que aparezca el LED objetivo
        wait (o_LED != 4'b1111 &&
              o_LED != 4'b0000 &&
              o_LED != 4'b1001);

        // Tiempo de reacción: 20 ciclos
        repeat (20) @(negedge clk);

        // Pulsar un botón incorrecto
        i_Switch = (o_LED == 4'b0001) ? 4'b0010 : 4'b0001;

        // Esperar que el juego apague los LED por error
        wait (o_LED == 4'b0000);

        $display(
            "WRONG: ciclo=%0d | medido=%0d | inicio_objetivo=%0d",
            tb_cycle,
            uut.u_soc.u_core.u_rf.regs[15],
            uut.u_soc.u_core.u_rf.regs[13]
        );

        repeat (5) @(negedge clk);

        // Soltar botón
        i_Switch = 4'b0000;

        // =========================================================
        // 3. PRUEBA DE RONDA CORRECTA
        // =========================================================

        // Esperar reinicio de la ronda
        wait (o_LED == 4'b1111);

        $display(
            "REINICIO_RONDA: ciclo=%0d | LED=%b",
            tb_cycle, o_LED
        );

        // Esperar que aparezca el nuevo LED objetivo
        wait (o_LED != 4'b1111 &&
              o_LED != 4'b0000 &&
              o_LED != 4'b1001);

        // Tiempo de reacción: 35 ciclos
        repeat (35) @(negedge clk);

        // Pulsar el botón correcto
        i_Switch = o_LED;

        // Esperar que el juego apague los LED al aceptar la respuesta
        wait (o_LED == 4'b0000);

        $display(
            "CORRECT: ciclo=%0d | medido=%0d | inicio_objetivo=%0d",
            tb_cycle,
            uut.u_soc.u_core.u_rf.regs[15],
            uut.u_soc.u_core.u_rf.regs[13]
        );

        repeat (5) @(negedge clk);

        // Soltar botón
        i_Switch = 4'b0000;

        // Esperar cálculos y actualización del display
        repeat (100) @(negedge clk);

        $display("SIMULACION RTL FINALIZADA");
        $finish;
    end

    // Monitor de cambios en los LED
    always @(o_LED) begin
        $display(
            "t=%0t | ciclo=%0d | LED=%b | Switch=%b",
            $time, tb_cycle, o_LED, i_Switch
        );
    end

    // Watchdog para evitar simulaciones infinitas
    initial begin
        #1000000;

        $display(
            "TIMEOUT: LED=%b SW=%b ciclos=%0d PC=%h x6=%h x7=%h x9=%h x10=%h",
            o_LED,
            i_Switch,
            uut.u_soc.u_periph.u_cycle_counter.count_o,
            uut.u_soc.u_core.pc_id,
            uut.u_soc.u_core.u_rf.regs[6],
            uut.u_soc.u_core.u_rf.regs[7],
            uut.u_soc.u_core.u_rf.regs[9],
            uut.u_soc.u_core.u_rf.regs[10]
        );

        $finish;
    end

endmodule