module iz_neuron_with_loader (
    // System signals (excluded from pin count)
    input wire clk,
    input wire reset,
    input wire enable,
    
    // 8-bit input bus (now dedicated to stimulus only)
    input wire [7:0] stimulus_input,
    
    // Parameter inputs from data loader
    input wire [15:0] param_a,
    input wire [15:0] param_b,
    input wire [15:0] param_c,
    input wire [15:0] param_d,
    input wire params_ready,
    
    // 8-bit output bus (constraint: 8 pins total)  
    output reg [7:0] output_bus
);

// Internal state variables (scaled by 64 for fixed-point)
reg signed [15:0] v;         // Membrane potential (scaled)
reg signed [15:0] u;         // Recovery variable (scaled)

// Computation variables
reg signed [31:0] v_squared; // v² computation (needs 32 bits)
reg signed [31:0] dv_calc;   // dv calculation
reg signed [31:0] du_calc;   // du calculation
wire spike_detect;

// Constants (properly scaled)
parameter SCALE = 64;                    // Scaling factor
parameter V_THRESH = 30 * SCALE;         // 30mV threshold
parameter V_REST = -70 * SCALE;          // -70mV resting
parameter CONST_140 = 140 * SCALE;       // Constant 140

// Spike detection
assign spike_detect = (v >= V_THRESH);

// Izhikevich computation with correct constants
always @(*) begin
    // Calculate v² term: 0.04 * v²
    // 0.04 * SCALE = 2.56 ≈ 3 (approximation for hardware efficiency)
    v_squared = (v * v) >>> 10;  // Scale down v² appropriately
    
    // IZ equation: dv = 0.04v² + 5v + 140 - u + I
    dv_calc = (v_squared * 3) +              // 0.04v² term (≈ 3 * v²/1024)
              (v * 5) +                      // 5v term  
              CONST_140 -                    // 140 constant
              u +                            // recovery variable
              (stimulus_input * SCALE);      // input current (8-bit precision)
    
    // Recovery equation: du = a(bv - u)  
    du_calc = (param_a * ((param_b * v - (u << 6)) >>> 6)) >>> 6;
end

// State update with proper IZ dynamics
always @(posedge clk) begin
    if (reset) begin
        v <= V_REST;           // Initialize to resting potential
        u <= 16'd0;           // Initialize recovery to 0
        output_bus <= 8'd0;
    end else if (enable && params_ready) begin  // Only operate when params ready
        if (spike_detect) begin
            // IZ reset conditions
            v <= param_c;                    // Reset voltage to 'c'
            u <= u + param_d;               // Increment recovery by 'd'
            output_bus[7] <= 1'b1;           // Spike output
        end else begin
            // Integrate equations
            v <= v + (dv_calc >>> 8);        // Update membrane potential
            u <= u + (du_calc >>> 6);       // Update recovery variable
            output_bus[7] <= 1'b0;           // No spike
        end
        
        // Output membrane potential (map to 0-127 range)
        if (v > V_THRESH) begin
            output_bus[6:0] <= 7'd127;       // Clamp to max during spike
        end else begin
            // Map v from [-70*64, 30*64] to [0, 127]
            output_bus[6:0] <= ((v - V_REST) >>> 6) & 7'b1111111;
        end
    end else if (!params_ready) begin
        // Hold outputs during parameter loading
        output_bus[7] <= 1'b0;  // No spike during loading
        // Keep membrane potential output
    end
end

endmodule
