/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */
/////////////////////////////////////////////////////////////////////////
// I2C slave with one sub-address byte and
// address auto-increment on the application bus
/////////////////////////////////////////////////////////////////////////
module i2c_peripheral #(
  parameter SLAVE_ADDR = 7'b1110000 // 0x70 (0xE0 and 0xE1)
  )
  (
    input  logic clk,
    input  logic rst_n,
    input  logic ena,
    // i2c interface
    output logic sda_o,
    output logic sda_oe,
    input  logic sda_i,
    input  logic scl,
    // application interface
    output logic wr_rdn,
    output logic [7:0] addr,
    input  logic [7:0] rdata,
    output logic [7:0] wdata,
    output logic we,
    input  logic [7:0] status
  );

  logic pull_sda;
  logic [3:0] sda_d, scl_d; // sample registers for i2c line debouncing and edge detection
  logic scl_rise, scl_fall, sda_rise, sda_fall;

  // i2c event enums
  parameter scl_rise_event = 2'b00;
  parameter scl_fall_event = 2'b01;
  parameter sda_rise_event = 2'b10;
  parameter sda_fall_event = 2'b11;
  
  logic [1:0] last_event;
  logic bus_start, bus_stop;

  assign sda_o  = 1'b0;
  assign sda_oe = pull_sda;

  // Detect edges using a glitch/noise filter
  // Require three consecutive identical samples to identify a proper edge:
  always @(posedge clk) begin
    scl_d <= {scl_d[2:0], scl};
    sda_d <= {sda_d[2:0], sda_i};
  end

  assign scl_rise = (scl_d == 4'b0111);
  assign scl_fall = (scl_d == 4'b1000);
  assign sda_rise = (sda_d == 4'b0111);
  assign sda_fall = (sda_d == 4'b1000);

  // Remember previous events
  always @(posedge clk)
    if (scl_rise)
       last_event <= scl_rise_event;
    else if (scl_fall)
       last_event <= scl_fall_event;
    else if  (sda_rise)
       last_event <= sda_rise_event;
    else if (sda_fall)
       last_event <= sda_fall_event;

  // Detect start and stop events
  always @(posedge clk) begin
    bus_start <= (last_event == sda_fall_event) && scl_fall;
    bus_stop  <= (last_event == scl_rise_event) && sda_rise;
  end

  // FSM state enum
  parameter reset = 4'd0;
  parameter address_r = 4'd1;
  parameter address_f = 4'd2;
  parameter ack = 4'd3;
  parameter write_bytes = 4'd4;
  parameter write_bytes_f = 4'd5;
  parameter write_ack = 4'd6;
  parameter read_bytes_pre = 4'd7;
  parameter read_bytes_f = 4'd8;
  parameter read_ack = 4'd9;
    
  // This FSM tracks the bus transaction and executes the application R/W commands
  logic [7:0] dbyte;

  always @(posedge clk or negedge rst_n) begin
    reg [3:0] state;
    reg addr_ok;
    reg [3:0] counter;

    if (!rst_n) begin
      counter     <= 4'd0;
      dbyte       <= 8'd0;
      addr       <= 8'd0;
      wr_rdn     <= 1'b0;
      pull_sda    <= 1'b0;
      we         <= 1'b0;
      state        = reset;
      addr_ok     <= 1'b0;
    end else begin
      // default assignments
      we         <= 1'b0;

      // restart engine if start or stop was detected
      if (bus_start || bus_stop)
        state = reset;
      case (state)
        reset: begin
                   pull_sda <= 1'b0;
                   counter  <= 4'd0;
                   dbyte    <= 8'd0;
                   addr_ok  <= 1'b0;
                   if (bus_start)
                     state = address_r;
                   end

        address_r:  begin
                      pull_sda  <= 1'b0;
                      if (scl_rise) begin
                        dbyte <= {dbyte[6:0], sda_d[0]}; // shift in data bit
                        state = address_f;
                        counter <= counter + 1'b1;
                       end // scl_rise
                     end // state address_r

        address_f: begin
                     pull_sda <=1'b0;
                     if (scl_fall)
                       if (counter < 4'd8)
                         state = address_r; // need more bits
                       else
                        state = ack;
                    end //state address_f

        ack: begin
               counter <= 4'b0;
               if (!addr_ok) begin
                 // We haven't seen the slave address yet, so this must be it
                 if (dbyte[7:1] != SLAVE_ADDR)
                   state = reset; // not our message
                 else begin
                   // This is our I2C address
                   // Acknowledge it
                   pull_sda <= 1'b1;
                   if (scl_fall) begin
                     pull_sda <= 1'b0;
                     // remember that we've seen the address
                     addr_ok <= 1'b1;
                     if (!dbyte[0]) begin
                       wr_rdn <= 1'b1;
                       // and expect the subaddr byte next
                       state = address_r;
                     end else begin
                       // Remember that this is a read transaction
                       wr_rdn <= 1'b0;
                       // Grab data from application snd start the reply transaction
                       dbyte <= rdata;
                       state = read_bytes_pre;
                     end // dbyte[0] (read/write)
                   end // falling clock in slave address ack state
                 end // SLAVE_ADDR check
               end else begin // addr_ok
                 // We have seen the slave address previously,
                 // so this must be the sub-address byte.
                 // Acknowledge it, pass it to the application and prepare
                 // for write transactions after the next falling clock edge
                 pull_sda <= 1'b1;
                 if (scl_fall) begin
                   pull_sda <= 1'b0;
                   addr <= dbyte;
                   counter <= 0;
                   state = write_bytes;
                 end // falling clock in subaddr ack state
               end // addr_ok
             end // state ack

        write_bytes: begin
                       pull_sda  <= 1'b0;
                       if (scl_rise) begin
                         dbyte <= {dbyte[6:0] , sda_d[0]}; // shift in data bit
                         state = write_bytes_f;
                         counter <= counter + 1'b1;
                       end // scl_rise
                     end // state write_bytes

        write_bytes_f: begin
                         pull_sda  <= 1'b0;
                         if (scl_fall) begin
                           if (counter < 4'd8)
                             state = write_bytes; // get more bits
                           else begin
                             counter <= 4'd0;
                             we      <= 1'b1;
                             state  = write_ack;
                           end // counter
                         end // scl_fall
                       end // state write_bytes_f

        write_ack: begin
                     pull_sda <= 1'b1;
                     if (scl_fall) begin
                       pull_sda <= 1'b0;
                       addr <= addr + 1'b1;
                       state = write_bytes;
                     end // scl_fall
                   end // state write_ack

        read_bytes_pre: begin
                          counter <= 4'd0;
                          addr <= addr+1; // allow application to prepare for the next access
                          state = read_bytes_f;
                        end // state read_bytes_pre

        read_bytes_f: begin
                        pull_sda <= (dbyte[7] == 1'b0);
                        if (scl_rise)
                          counter <= counter + 1'd1;
                        if (scl_fall) begin
                          if (counter < 4'd8)
                            dbyte <= {dbyte[6:0], 1'b0};
                          else begin 
                            pull_sda <= 1'b0;
                            state = read_ack;
                          end
                        end // scl_fall in read_bytes_f
                      end //state read_bytes_f

        read_ack: begin
                    if (scl_rise)
                      if (sda_d[0])  // NAK
                        state = reset;
                    if (scl_fall) begin
                      // Capture rdata from app
                      dbyte <= rdata;
                      state = read_bytes_pre;
                    end // scl_fall in read_ack state
                  end // state read_acq

        default: state = reset;
      endcase // FSM state
    end // rst
  end

  assign wdata = dbyte;

  // List all unused inputs to prevent warnings
  logic _unused = &{status, ena, 1'b0};

endmodule
