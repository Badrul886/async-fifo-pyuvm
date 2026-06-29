import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly, FallingEdge
import pyuvm
from pyuvm import *

# ============================================================================
# 1. The Transaction Item
# ============================================================================
class FifoItem(uvm_sequence_item):
    def __init__(self, name, data=0):
        super().__init__(name)
        self.data = data

    def __eq__(self, other):
        return self.data == other.data

    def __str__(self):
        return f"DATA: {hex(self.data)}"

# ============================================================================
# 2. The Monitors (Spies on the hardware)
# ============================================================================
class WriteMonitor(uvm_monitor):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        while True:
            # FIX: Sample the data during the setup window (Falling Edge)
            await FallingEdge(cocotb.top.wclk)
            await ReadOnly()
            
            if cocotb.top.write_en.value == 1 and cocotb.top.full.value == 0:
                item = FifoItem("write_item", cocotb.top.write_data.value.to_unsigned())
                self.ap.write(item)

class ReadMonitor(uvm_monitor):
    def build_phase(self):
        self.ap = uvm_analysis_port("ap", self)

    async def run_phase(self):
        while True:
            # FIX: Sample the live combinational wire BEFORE the clock changes it
            await FallingEdge(cocotb.top.rclk)
            await ReadOnly()
            
            if cocotb.top.read_en.value == 1 and cocotb.top.empty.value == 0:
                item = FifoItem("read_item", cocotb.top.read_data.value.to_unsigned())
                self.ap.write(item)

# ============================================================================
# 3. The Scoreboard (The Source of Truth)
# ============================================================================
class FifoScoreboard(uvm_scoreboard):
    def build_phase(self):
        # We only need the TLM FIFOs. We don't need intermediate exports.
        self.write_fifo = uvm_tlm_analysis_fifo("write_fifo", self)
        self.read_fifo  = uvm_tlm_analysis_fifo("read_fifo", self)

    async def run_phase(self):
        self.passed_count = 0
        while True:
            write_item = await self.write_fifo.get()
            read_item  = await self.read_fifo.get()
            
            if write_item == read_item:
                self.passed_count += 1
                cocotb.log.info(f"SCOREBOARD MATCH: Written {write_item} == Read {read_item}")
            else:
                self.logger.error(f"DATA CORRUPTION! Written {write_item} != Read {read_item}")
                assert False, "Simulation Failed due to Data Mismatch."

    def extract_phase(self):
        if self.passed_count == 0:
            self.logger.error("No data passed through the FIFO!")
            assert False

# ============================================================================
# 4. The Environment
# ============================================================================
class FifoEnv(uvm_env):
    def build_phase(self):
        self.write_mon = WriteMonitor("write_mon", self)
        self.read_mon  = ReadMonitor("read_mon", self)
        self.scoreboard = FifoScoreboard("scoreboard", self)

    def connect_phase(self):
        # Connect the monitor port directly to the scoreboard's FIFO export
        self.write_mon.ap.connect(self.scoreboard.write_fifo.analysis_export)
        self.read_mon.ap.connect(self.scoreboard.read_fifo.analysis_export)

# ============================================================================
# 5. The Test (The Entry Point)
# ============================================================================
@pyuvm.test()
class FifoTest(uvm_test):
    def build_phase(self):
        self.env = FifoEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        dut = cocotb.top
        
        # 1. Start Independent Asynchronous Clocks!
        cocotb.start_soon(Clock(dut.wclk, 10, unit="ns").start()) # 100 MHz
        cocotb.start_soon(Clock(dut.rclk, 30, unit="ns").start()) # 33 MHz

        # 2. Initialize and Reset
        dut.write_en.value = 0
        dut.read_en.value = 0
        dut.write_data.value = 0
        dut.wrst_n.value = 0
        dut.rrst_n.value = 0
        
        await Timer(50, unit="ns")
        dut.wrst_n.value = 1
        dut.rrst_n.value = 1
        await Timer(50, unit="ns")

        # 3. Burst Write Sequence (Drive on the FALLING edge to simulate setup time)
        write_values = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
        for val in write_values:
            await FallingEdge(dut.wclk)
            dut.write_en.value = 1
            dut.write_data.value = val
        
        await FallingEdge(dut.wclk)
        dut.write_en.value = 0 # Stop writing
        
        # Give the Gray Code pointers time to travel through the 2-stage synchronizers!
        await Timer(100, unit="ns")
        
        # 4. Read Sequence (Drain the FIFO)
        for _ in range(8):
            await FallingEdge(dut.rclk)
            dut.read_en.value = 1
            
        await FallingEdge(dut.rclk)
        dut.read_en.value = 0 # Stop reading
        
        # Wait for Scoreboard to finish processing the final data
        await Timer(200, unit="ns")
        self.drop_objection()