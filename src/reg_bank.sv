/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module reg_bank #(
    parameter int ADDR_W = 8,
    parameter int REG_W = 8
) (
    input  logic 	      clk,
    input  logic 	      rstb,
    input  logic 	      ena,
    // application interface
    input  logic              wr_rdn,
    input  logic [ADDR_W-1:0] addr,
    output logic [REG_W-1:0]  rdata,
    input  logic [REG_W-1:0]  wdata,
    input  logic              we,
    output logic              ack,
    output logic              err
);

  // rw registers
  logic [REG_W-1:0] config [ADDR_W-1:0];

  assign ack = 1'b1;
  assign err = '0;
  assign rdata = config[addr];

  // Register write
  always_ff @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      for (i = 0; i < 8; i++) begin
        config[i] <= '0;
      end
    end else begin
      if (ena) begin
        if (we) begin
          config[addr] <= wdata;
        end
      end
    end
  end

endmodule
