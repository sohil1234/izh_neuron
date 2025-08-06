`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Replace tt_um_example with your IZ neuron module name:
  tt_um_iz_neuron user_project (
      .ui_in  (ui_in),    // Dedicated inputs - 8-bit stimulus input
      .uo_out (uo_out),   // Dedicated outputs - Membrane potential[6:0], Spike[7]
      .uio_in (uio_in),   // IOs: Input path - load_mode[0], serial_data[1]
      .uio_out(uio_out),  // IOs: Output path - params_ready[2], spike_monitor[3], etc.
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

endmodule
