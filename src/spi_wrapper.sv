/*
 * Copyright (c) 2024 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module spi_wrapper #(parameter int NUM_CFG = 8, parameter int NUM_STATUS = 8, parameter int REG_WIDTH = 8) (rstb, clk, ena, mode, spi_cs_n, spi_clk, spi_mosi, spi_miso, config_regs, status_regs);

  input logic rstb;
  input logic clk;
  input logic ena;

  input logic [1:0] mode;
  input logic spi_cs_n;
  input logic spi_clk;
  input logic spi_mosi;
  output logic spi_miso;

  output logic [NUM_CFG*REG_WIDTH-1:0] config_regs;
  input logic [NUM_STATUS*REG_WIDTH-1:0] status_regs;

  // Address width for register bank
  localparam int NUM_REGS = NUM_CFG+NUM_STATUS;
  localparam int ADDR_WIDTH = $clog2(NUM_REGS);

  // Auxiliar variables for spi peripheral
  logic spi_wr_rdn;
  logic [ADDR_WIDTH-1:0] spi_addr;
  logic [REG_WIDTH-1:0] spi_rdata, spi_wdata;
  logic spi_we;
  
  logic [REG_WIDTH-1:0] config_mem [NUM_CFG];
  logic [REG_WIDTH-1:0] status_int [NUM_STATUS];

  logic i2c_wr_rdn;
  logic [7:0] i2c_addr;  // TODO
  logic [REG_WIDTH-1:0] i2c_rdata, i2c_wdata;
  logic i2c_we;
  
  // Serial interface
  spi_peripheral #(
    .ADDR_W(ADDR_WIDTH),
    .REG_W(REG_WIDTH)
  ) spi_peripheral_i (
    .clk(clk),
    .rstb(rstb),
    .ena(ena),
    .mode(mode),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_clk(spi_clk),
    .spi_cs_n(spi_cs_n),
    .wr_rdn(spi_wr_rdn),
    .addr(spi_addr),
    .rdata(spi_rdata),
    .wdata(spi_wdata),
    .we(spi_we),
    .status('0)
  );

  i2c_peripheral #(
    .SLAVE_ADDR (7'b1110000)
  ) i2c_peripheral_i (
    .clk(clk),
    .rst_n(rstb),
    //.ena(ena),
    .sda_o(),
    .sda_oe(),
    .sda_i(1'b0),
    .scl(1'b0),
    .wr_rdn(),
    .addr(i2c_addr),
    .rdata(i2c_rdata),
    .wdata(i2c_wdata),
    .we(i2c_we),
    .status('0)
  );
  
  // Mux to select CFG or Status Register read access
  // This imposes a limitation that NUM_CFG and NUM_STATUS have to have the same VALUE!
  assign spi_rdata = (spi_addr[ADDR_WIDTH-1] == 1'b0) ? config_mem[spi_addr[ADDR_WIDTH-2:0]] : status_int[spi_addr[ADDR_WIDTH-2:0]];

  assign i2c_rdata = '0; // TODO

  // Index for reset register array
  int i;

  // Register write
  always_ff @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      for (i = 0; i < NUM_CFG; i++) begin
        config_mem[i] <= '0;
      end
    end else begin
      if (ena) begin
        if (spi_we) begin
          config_mem[spi_addr[ADDR_WIDTH-2:0]] <= spi_wdata;
        end
      end
    end
  end

  // Generate variable
  genvar x, y;
  // Convert to unpacked array
  generate for (x = 0; x < NUM_STATUS; x = x + 1) begin
    assign status_int[x] = status_regs[((x+1)*REG_WIDTH-1) : x*REG_WIDTH];
  end endgenerate
  // Convert to 1 dimension packed array
  generate for (y = 0; y < NUM_CFG; y = y + 1) begin
    assign config_regs[((y+1)*REG_WIDTH-1) : y*REG_WIDTH] = config_mem[y];
  end endgenerate

  // Get rid off lint warning
  wire _unused = spi_wr_rdn;

endmodule
