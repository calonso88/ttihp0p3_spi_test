/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_calonso88_spi_test (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Number of CFG Regs and Status Regs
  // Limitation: NUM_CFG must be equal to NUM_STATUS
  localparam int NUM_CFG = 8;
  localparam int NUM_STATUS = NUM_CFG;
  // Size of Regs
  localparam int REG_WIDTH = 8;

  // Config Regs and Status Regs
  wire [NUM_CFG*REG_WIDTH-1:0] rw_regs;
  wire [NUM_STATUS*REG_WIDTH-1:0] ro_regs;

  // i2c Auxiliars
  wire i2c_sda_i;
  wire i2c_sda_o;
  wire i2c_sda_oe;
  wire i2c_scl;

  // SPI Auxiliars
  wire cpol;
  wire cpha;
  wire spi_cs_n;
  wire spi_clk;
  wire spi_miso;
  wire spi_mosi;

  // Sync'ed
  wire cpol_sync;
  wire cpha_sync;
  wire spi_cs_n_sync;
  wire spi_clk_sync;
  wire spi_mosi_sync;

  // Peripheral selector
  // 1'b0 - SPI can access reg bank
  // 1'b1 - i2c can access reg bank
  wire sel;

  // Input ports - SPI modes
  assign cpol = ui_in[0];
  assign cpha = ui_in[1];

  // Input ports - peripheral selector
  assign sel = ui_in[7];

  // Output ports (drive 7seg display) - Config Reg Address 0
  assign uo_out[7:0] = rw_regs[7:0];

  // Bi direction IOs [6:4] (cs_n, sclk, mosi) always as inputs
  assign uio_oe[6:4] = 3'b000;

  // Bi direction IOs [3] - (miso) is controlled by spi_cs_n_sync
  // input port when spi_cs_n_sync = 1'b1
  // output port when spi_cs_n_sync = 1'b0
  assign uio_oe[3] = spi_cs_n_sync ? 1'b0 : 1'b1;

  // Bi direction IOs [1] - Control of i2c SDA
  // Bi direction IOs [2] - i2c SCL, always input
  assign uio_oe[1] = i2c_sda_oe;
  assign uio_oe[2] = 1'b0;

  // Bi direction IOs [7] and [0] unused - set always as inputs
  assign uio_oe[7] = 1'b0;
  assign uio_oe[0] = 1'b0;

  // Bi-directional Input ports i2c
  assign i2c_sda_i = uio_in[1];
  assign i2c_scl   = uio_in[2];

  // Bi-directional Input ports SPI
  assign spi_cs_n  = uio_in[4];
  assign spi_clk   = uio_in[5];
  assign spi_mosi  = uio_in[6];

  // Bi-directional Output ports i2c
  assign uio_out[1] = i2c_sda_o;
  // Bi-directional Output ports SPI
  assign uio_out[3] = spi_miso;

  // Bi-directional ouputs unused needs to be assigned to 0.
  assign uio_out[0] = 1'b0;
  assign uio_out[2] = 1'b0;
  assign uio_out[7:4] = 4'b0000;

  // List all unused inputs to prevent warnings
  wire _unused = &{ui_in[6:2], uio_in[7], uio_in[3], uio_in[0], rw_regs[NUM_CFG*REG_WIDTH-1:8], 1'b0};

  // Number of stages in each synchronizer
  localparam int SYNC_STAGES = 2;
  localparam int SYNC_WIDTH = 1;

  // Synchronizers
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH)) synchronizer_spi_mode_cpol (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(cpol),     .data_out(cpol_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH)) synchronizer_spi_mode_cpha (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(cpha),     .data_out(cpha_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH)) synchronizer_spi_cs_n_inst (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_cs_n), .data_out(spi_cs_n_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH)) synchronizer_spi_clk_inst  (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_clk),  .data_out(spi_clk_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH)) synchronizer_spi_mosi_inst (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_mosi), .data_out(spi_mosi_sync));

  // Assign status
  assign ro_regs[7:0]   = 8'hCA;
  assign ro_regs[15:8]  = 8'h10;
  assign ro_regs[23:16] = 8'hAA;
  assign ro_regs[31:24] = 8'h55;
  assign ro_regs[39:32] = 8'hFF;
  assign ro_regs[47:40] = 8'h00;
  assign ro_regs[55:48] = 8'hA5;
  assign ro_regs[63:56] = 8'h5A;
  //assign ro_regs[NUM_STATUS*REG_WIDTH-1:64] = '0;

  // top wrapper
  top_wrapper #(
    .NUM_CFG(NUM_CFG),
    .NUM_STATUS(NUM_STATUS),
    .REG_WIDTH(REG_WIDTH)
  ) top_wrapper_i (
    .rstb(rst_n),
    .clk(clk),
    .ena(ena),
    .mode({cpol_sync, cpha_sync}),
    .spi_cs_n(spi_cs_n_sync),
    .spi_clk(spi_clk_sync),
    .spi_mosi(spi_mosi_sync),
    .spi_miso(spi_miso),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_oe(i2c_sda_oe),
    .i2c_sda_i(i2c_sda_i),
    .i2c_scl(i2c_scl),
    .sel(sel),
    .rw_regs(rw_regs),
    .ro_regs(ro_regs)
  );

endmodule
