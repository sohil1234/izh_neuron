/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_iz_neuron (
    input  wire [7:0] ui_in,    // Dedicated inputs - stimulus/configuration data
    output wire [7:0] uo_out,   // Dedicated outputs - neuron output + status
    input  wire [7:0] uio_in,   // IOs: Input path - control signals
    output wire [7:0] uio_out,  // IOs: Output path - debug/status outputs
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// Internal signals
wire reset;
wire enable;
wire load_mode;
wire serial_data;
wire [7:0] stimulus_input;
wire [7:0] neuron_output;
wire params_ready;

// Convert active-low reset to active-high for internal use
assign reset = ~rst_n;
assign enable = ena;  // Use ena as enable signal

// Input mapping
assign stimulus_input = ui_in[7:0];     // 8-bit stimulus from dedicated inputs
assign load_mode = uio_in[0];           // Load mode control from bidirectional pins
assign serial_data = uio_in[1];         // Serial parameter data from bidirectional pins

// Output mapping
assign uo_out[7:0] = neuron_output[7:0];  // Main neuron output (membrane potential + spike)

// Bidirectional IO configuration
assign uio_oe[7:0] = 8'b11111100;       // Bits [7:2] = output, bits [1:0] = input
assign uio_out[0] = 1'b0;               // Input pin - don't drive
assign uio_out[1] = 1'b0;               // Input pin - don't drive  
assign uio_out[2] = params_ready;       // Parameter loading status
assign uio_out[3] = neuron_output[7];   // Duplicate spike output for monitoring
assign uio_out[4] = |neuron_output[6:0]; // Membrane potential activity indicator
assign uio_out[5] = load_mode;          // Echo load mode for verification
assign uio_out[6] = serial_data;        // Echo serial data for verification
assign uio_out[7] = enable;             // Echo enable status

// Instantiate the IZ neuron system
iz_neuron_system iz_core (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .input_bus(stimulus_input),
    .load_mode(load_mode),
    .serial_data(serial_data),
    .output_bus(neuron_output),
    .params_ready(params_ready)
);

// Handle unused inputs to prevent warnings
wire _unused = &{uio_in[7:2], 1'b0};  // Explicitly mark unused bits

endmodule
