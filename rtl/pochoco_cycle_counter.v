// Contador de ciclos de reloj del Pochoco SoC.
//
// Cuenta cuántos flancos de subida de reloj han ocurrido desde el último reset.
// El programa lo lee por MMIO (0x8000_000C, vía pochoco_periph) para medir la
// espera de 3 s y el tiempo de reacción del jugador.
//
// Está en su propio módulo para que la síntesis y el layout lo puedan identificar
// (u_soc.u_periph.u_cycle_counter) y así medir su área por separado (Proyecto 3, 3.3).

module pochoco_cycle_counter (
  input  wire        clk_i,     // reloj del sistema
  input  wire        rst_ni,    // reset asíncrono, activo en bajo
  output reg  [31:0] count_o    // ciclos transcurridos desde el reset
);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      count_o <= 32'd0;              // reset: vuelve a cero
    else
      count_o <= count_o + 32'd1;    // cada ciclo: suma 1 (al llegar a 2^32-1 vuelve a 0)
  end

endmodule