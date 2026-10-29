// Copyright 2026 Universidad de los Andes.
// Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: SHL-0.51
//
// Course: Arquitectura de Computadores (2026)
// 
// Authors:
// - Nicolás Villegas <navillegas@miuandes.cl>

module espino_register_file (
  input  wire        clk_i,
  input  wire        rst_ni,

  input  wire [3:0]  raddr_a_i,
  output reg  [31:0] rdata_a_o,

  input  wire [3:0]  raddr_b_i,
  output reg  [31:0] rdata_b_o,

  input  wire [3:0]  waddr_i,
  input  wire [31:0] wdata_i,
  input  wire        we_i
);

  // RV32E: 16 registers of 32 bits.
  // x0 is hardwired to zero.
  reg [31:0] regs [0:15];

  integer i;

  wire wr;
  assign wr = we_i & (waddr_i != 4'd0);

  // Standard-cell friendly register file.
  // Reads remain synchronous to preserve the timing expected
  // by espino_id_stage.
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin

      for (i = 0; i < 16; i = i + 1)
        regs[i] <= 32'b0;

      rdata_a_o <= 32'b0;
      rdata_b_o <= 32'b0;

    end else begin

      if (wr)
        regs[waddr_i] <= wdata_i;

      if (raddr_a_i == 4'd0)
        rdata_a_o <= 32'b0;
      else
        rdata_a_o <= regs[raddr_a_i];

      if (raddr_b_i == 4'd0)
        rdata_b_o <= 32'b0;
      else
        rdata_b_o <= regs[raddr_b_i];

    end
  end

endmodule