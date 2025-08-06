module iz_neuron_system (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // 8-bit input bus (constraint: 8 pins total)
    input wire [7:0] input_bus,
    
    // Control signals (can be part of input_bus or separate)
    input wire load_mode,          // 0=normal operation, 1=parameter loading
    input wire serial_data,        // Serial data for parameter loading
    
    // 8-bit output bus (constraint: 8 pins total)
    output wire [7:0] output_bus,
    
    // Status output
    output wire params_ready
);

// Internal signals
wire [15:0] param_a, param_b, param_c, param_d;
wire loader_params_ready;

// Data loader instance
iz_data_loader loader (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .serial_data_in(serial_data),
    .load_enable(load_mode),
    .param_a(param_a),
    .param_b(param_b),
    .param_c(param_c),
    .param_d(param_d),
    .params_ready(loader_params_ready),
    .load_state()  // Can be used for debugging
);

// IZ neuron instance
iz_neuron_with_loader neuron (
    .clk(clk),
    .reset(reset),
    .enable(enable),
    .stimulus_input(input_bus),     // Full 8-bit for stimulus
    .param_a(param_a),
    .param_b(param_b),
    .param_c(param_c),
    .param_d(param_d),
    .params_ready(loader_params_ready),
    .output_bus(output_bus)
);

assign params_ready = loader_params_ready;

endmodule
