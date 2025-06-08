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
    input  logic 	            we
    output logic              ack,
    output logic              err
);
