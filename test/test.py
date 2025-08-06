# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def send_byte(dut, byte_val):
    """Send a byte serially (MSB first)"""
    dut._log.info(f"Sending byte: 0x{byte_val:02X}")
    for bit in range(8):
        bit_val = (byte_val >> (7-bit)) & 1
        dut.uio_in.value = 1 | (bit_val << 1)  # load_mode=1, serial_data=bit_val
        await ClockCycles(dut.clk, 1)

@cocotb.test()
async def test_iz_neuron_basic(dut):
    """Basic IZ neuron functionality test"""
    dut._log.info("Starting IZ Neuron Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0    # No stimulus
    dut.uio_in.value = 0   # load_mode=0, serial_data=0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    # Wait for system to stabilize
    await ClockCycles(dut.clk, 5)
    
    # Check that params_ready is high (default parameters loaded)
    params_ready = (dut.uio_out.value >> 2) & 1
    dut._log.info(f"Default params_ready: {params_ready}")
    
    # Test 1: Resting state (no stimulus)
    dut._log.info("Test 1: Resting state")
    dut.ui_in.value = 0  # No stimulus
    await ClockCycles(dut.clk, 20)
    
    v_mem = dut.uo_out.value & 0x7F  # Lower 7 bits
    spike = (dut.uo_out.value >> 7) & 1
    dut._log.info(f"Resting: V_mem={v_mem}, Spike={spike}")
    
    # Should be at rest, no spikes
    assert spike == 0, "Should not spike at rest"
    
    # Test 2: Low stimulus (subthreshold)
    dut._log.info("Test 2: Low stimulus")
    dut.ui_in.value = 3  # Low stimulus
    
    # Monitor for membrane potential buildup
    max_v_mem = 0
    for cycle in range(30):
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        max_v_mem = max(max_v_mem, v_mem)
        
        if spike == 1:
            dut._log.info(f"Unexpected spike at cycle {cycle} with low stimulus")
        elif cycle % 10 == 0:
            dut._log.info(f"Cycle {cycle}: V_mem={v_mem}")
    
    dut._log.info(f"Low stimulus max V_mem: {max_v_mem}")
    
    # Test 3: Medium stimulus (should generate spikes)
    dut._log.info("Test 3: Medium stimulus")
    dut.ui_in.value = 7  # Medium stimulus
    
    spike_count = 0
    for cycle in range(50):
        await ClockCycles(dut.clk, 1)
        v_mem = dut.uo_out.value & 0x7F
        spike = (dut.uo_out.value >> 7) & 1
        
        if spike == 1:
            spike_count += 1
            dut._log.info(f"SPIKE #{spike_count} at cycle {cycle}, V_mem={v_mem}")
        
        # Stop after getting a few spikes
        if spike_count >= 3:
            break
    
    dut._log.info(f"Medium stimulus generated {spike_count} spikes")
    assert spike_count > 0, "Medium stimulus should generate spikes"
    
    # Test 4: High stimulus (frequent spiking)
    dut._log.info("Test 4: High stimulus")
    dut.ui_in.value = 15  # High stimulus
    
    high_spike_count = 0
    for cycle in range(30):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            high_spike_count += 1
    
    dut._log.info(f"High stimulus generated {high_spike_count} spikes")
    assert high_spike_count >= spike_count, "High stimulus should generate more/equal spikes"
    
    # Test 5: Return to rest
    dut._log.info("Test 5: Return to rest")
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 20)
    
    final_spike = (dut.uo_out.value >> 7) & 1
    assert final_spike == 0, "Should return to rest without stimulus"
    
    dut._log.info("IZ Neuron basic functionality test completed successfully!")

@cocotb.test()
async def test_iz_parameter_loading(dut):
    """Test IZ neuron parameter loading functionality"""
    dut._log.info("Starting IZ Parameter Loading Test")

    # Set the clock period to 10 us (100 KHz) 
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Enter parameter loading mode
    dut._log.info("Entering parameter loading mode")
    dut.uio_in.value = 1  # load_mode = 1
    await ClockCycles(dut.clk, 2)
    
    # Check params_ready goes low
    params_ready = (dut.uio_out.value >> 2) & 1
    dut._log.info(f"Loading mode params_ready: {params_ready}")
    
    # Load new IZ parameters (Regular Spiking configuration)
    # a=0x05, b=0x33, c=0x41, d=0x08
    dut._log.info("Loading IZ parameters (Regular Spiking)")
    
    # Parameter A (recovery time constant)
    await send_byte(dut, 0x05)
    
    # Parameter B (recovery sensitivity) 
    await send_byte(dut, 0x33)
    
    # Parameter C (reset voltage)
    await send_byte(dut, 0x41)
    
    # Parameter D (recovery jump)
    await send_byte(dut, 0x08)
    
    # Exit loading mode
    dut.uio_in.value = 0  # load_mode = 0
    await ClockCycles(dut.clk, 5)
    
    # Wait for params_ready to go high
    for _ in range(20):
        await ClockCycles(dut.clk, 1)
        params_ready = (dut.uio_out.value >> 2) & 1
        if params_ready == 1:
            break
    
    dut._log.info(f"After loading params_ready: {params_ready}")
    assert params_ready == 1, "Parameters should be ready after loading"
    
    # Test new configuration with stimulus
    dut._log.info("Testing loaded parameters")
    dut.ui_in.value = 8  # Test stimulus
    
    # Monitor for different behavior with new parameters
    spike_count = 0
    for cycle in range(40):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            spike_count += 1
            dut._log.info(f"New config SPIKE #{spike_count} at cycle {cycle}")
            
        if spike_count >= 2:
            break
    
    dut._log.info(f"New configuration generated {spike_count} spikes")
    dut._log.info("IZ Parameter loading test completed!")

@cocotb.test()
async def test_iz_neuron_types(dut):
    """Test different IZ neuron type configurations"""
    dut._log.info("Starting IZ Neuron Types Test")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)
    
    # Test Fast Spiking neuron configuration
    dut._log.info("Loading Fast Spiking configuration")
    dut.uio_in.value = 1  # Enter loading mode
    await ClockCycles(dut.clk, 2)
    
    # Fast Spiking: a=0x19, b=0x33, c=0x41, d=0x08
    await send_byte(dut, 0x19)  # Higher 'a' for fast recovery
    await send_byte(dut, 0x33)
    await send_byte(dut, 0x41)
    await send_byte(dut, 0x08)
    
    dut.uio_in.value = 0  # Exit loading mode
    await ClockCycles(dut.clk, 10)
    
    # Test Fast Spiking behavior
    dut._log.info("Testing Fast Spiking behavior")
    dut.ui_in.value = 6  # Medium stimulus
    
    fs_spike_count = 0
    for cycle in range(30):
        await ClockCycles(dut.clk, 1)
        spike = (dut.uo_out.value >> 7) & 1
        if spike == 1:
            fs_spike_count += 1
            
        if fs_spike_count >= 2:
            break
    
    dut._log.info(f"Fast Spiking generated {fs_spike_count} spikes")
    
    # Return to rest
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 10)
    
    dut._log.info("IZ Neuron types test completed!")
