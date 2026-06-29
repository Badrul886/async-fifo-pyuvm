\# Asynchronous FIFO with PyUVM Verification Environment



\## 📌 Overview

This repository contains the RTL design and a complete Universal Verification Methodology (UVM) testbench for a parameterized Asynchronous FIFO. The project demonstrates safe data transfer between two independent, asynchronous clock domains (100MHz Write / 33MHz Read) using 2-stage flip-flop synchronizers and Gray code pointer conversion.



\## 🏗️ Architecture

The design is strictly modularized into five distinct hardware blocks:

1\. \*\*`fifomem`\*\*: Dual-port SRAM array.

2\. \*\*`sync2`\*\*: 2-stage synchronizers to mitigate metastability.

3\. \*\*`rptr\_empty`\*\*: Read pointer logic (Binary to Gray conversion) and empty flag generation.

4\. \*\*`wptr\_full`\*\*: Write pointer logic (Binary to Gray conversion) and full flag generation.

5\. \*\*`async\_fifo`\*\*: Top-level wrapper.



\*Note: The N+1 bit pointer mathematical trick is utilized to differentiate between completely full and completely empty states.\*



\## 🔬 Verification Strategy (PyUVM)

The verification environment is built using Python, Cocotb, and PyUVM, moving away from linear SystemVerilog testbenches to an Object-Oriented, transaction-level architecture.



\* \*\*Independent Agents:\*\* Two autonomous threads drive the read and write interfaces at unaligned clock frequencies.

\* \*\*Transaction Level Modeling (TLM):\*\* Custom `uvm\_monitor` classes spy on the physical bus, bundle the data into Python objects, and broadcast them via Analysis Ports.

\* \*\*Automated Scoreboarding:\*\* A `uvm\_scoreboard` receives TLM broadcasts from both domains and mathematically verifies zero data corruption, dropping, or duplication across the clock boundaries.



\## 🐛 The Bug Hunt (Authenticity Log)

During development, the following microarchitectural edge cases were identified and resolved:

1\. \*\*Delta-Cycle Race Conditions:\*\* The initial testbench encountered driver/monitor race conditions at the picosecond level. \*\*Fix:\*\* Re-architected the testbench to simulate physical Setup/Hold times by driving data strictly on the `FallingEdge` and sampling on the subsequent setup window.

2\. \*\*Combinational Output Traps:\*\* The read monitor failed to capture the first byte of data because standard Async FIFOs utilize a continuous combinational read output (`assign rdata = mem\[raddr]`), which was overwritten instantly by the rising clock edge. \*\*Fix:\*\* Synchronized the read monitor to capture data prior to the clock edge boundary.



\## 🚀 How to Run

\*\*Prerequisites:\*\* Icarus Verilog (`iverilog`), Python 3, `cocotb`, and `pyuvm`.



```bash

git clone \[https://github.com/YourUsername/async-fifo-pyuvm.git](https://github.com/YourUsername/async-fifo-pyuvm.git)

cd async-fifo-pyuvm/sim

make WAVES=1

