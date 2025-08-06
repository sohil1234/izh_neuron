module iz_data_loader (
    // System signals
    input wire clk,
    input wire reset,
    input wire enable,
    
    // Serial data input (1 bit constraint as mentioned)
    input wire serial_data_in,
    input wire load_enable,        // Signal to start loading parameters
    
    // Outputs to IZ neuron
    output reg [15:0] param_a,     // Scaled parameter a
    output reg [15:0] param_b,     // Scaled parameter b  
    output reg [15:0] param_c,     // Scaled parameter c
    output reg [15:0] param_d,     // Scaled parameter d
    output reg params_ready,       // Signal that parameters are loaded
    
    // Debug outputs
    output wire [2:0] load_state
);

// State machine for parameter loading
parameter IDLE = 3'b000;
parameter LOAD_A = 3'b001;
parameter LOAD_B = 3'b010;
parameter LOAD_C = 3'b011;
parameter LOAD_D = 3'b100;
parameter READY = 3'b101;

// Internal registers for serial loading
reg [7:0] shift_reg;           // 8-bit shift register for serial input
reg [2:0] bit_count;           // Count bits received
reg [2:0] current_state;

// Edge detection for load_enable
reg load_enable_prev;
wire load_enable_rising;

// Scaling constants
parameter SCALE = 64;

// Default parameter values (Regular Spiking neuron)
parameter DEFAULT_A = 16'd1;        // a = 0.02 * SCALE ≈ 1
parameter DEFAULT_B = 16'd13;       // b = 0.2 * SCALE ≈ 13  
parameter DEFAULT_C = -65 * SCALE;  // c = -65mV
parameter DEFAULT_D = 2 * SCALE;    // d = 2mV

assign load_state = current_state;

// Edge detection for load_enable
assign load_enable_rising = load_enable & ~load_enable_prev;

always @(posedge clk) begin
    if (reset) begin
        load_enable_prev <= 1'b0;
    end else begin
        load_enable_prev <= load_enable;
    end
end

// State machine and serial loading logic
always @(posedge clk) begin
    if (reset) begin
        current_state <= IDLE;
        shift_reg <= 8'd0;
        bit_count <= 3'd0;
        param_a <= DEFAULT_A;
        param_b <= DEFAULT_B;
        param_c <= DEFAULT_C;
        param_d <= DEFAULT_D;
        params_ready <= 1'b1;  // Default params are ready
    end else if (enable) begin
        case (current_state)
            IDLE: begin
                if (load_enable_rising) begin  // Use edge detection
                    current_state <= LOAD_A;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;  // Not ready during loading
                end
            end
            
            LOAD_A: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        // Scale and store parameter 'a'
                        // Input range [0,255] -> a range [0.01, 0.1]
                        param_a <= (shift_reg >> 4) + 1;  // Maps to ~[1,17]
                        current_state <= LOAD_B;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_B: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        // Scale and store parameter 'b'
                        // Input range [0,255] -> b range [-0.5, 0.3]
                        if (shift_reg > 8'd127) begin
                            param_b <= (shift_reg - 8'd128) >> 2;  // Positive b
                        end else begin
                            param_b <= -(8'd128 - shift_reg) >> 2; // Negative b
                        end
                        current_state <= LOAD_C;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_C: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        // Scale and store parameter 'c'
                        // Input range [0,255] -> c range [-80, -40]
                        param_c <= -((shift_reg >> 2) + 40) * SCALE;
                        current_state <= LOAD_D;
                        bit_count <= 3'd0;
                        shift_reg <= 8'd0;
                    end
                end
            end
            
            LOAD_D: begin
                if (load_enable) begin
                    shift_reg <= {shift_reg[6:0], serial_data_in};
                    bit_count <= bit_count + 1;
                    if (bit_count == 3'd7) begin
                        // Scale and store parameter 'd'
                        // Input range [0,255] -> d range [0, 10]
                        param_d <= (shift_reg >> 4) * SCALE;
                        current_state <= READY;
                        params_ready <= 1'b1;
                    end
                end
            end
            
            READY: begin
                // Parameters loaded and ready - stay here until new rising edge
                if (load_enable_rising) begin  // Use edge detection
                    // Start new loading cycle
                    current_state <= LOAD_A;
                    bit_count <= 3'd0;
                    shift_reg <= 8'd0;
                    params_ready <= 1'b0;
                end else if (!load_enable) begin
                    // When load_enable goes low, return to IDLE
                    current_state <= IDLE;
                end
            end
            
            default: begin
                current_state <= IDLE;
            end
        endcase
    end
end

endmodule
