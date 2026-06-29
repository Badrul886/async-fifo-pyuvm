# Asynchronous FIFO with PyUVM Verification Environment

## 📌 Overview

This repository contains the RTL implementation and a complete **PyUVM-based verification environment** for a parameterized **Asynchronous FIFO**.

The project demonstrates reliable data transfer between two independent asynchronous clock domains (**100 MHz Write Clock** and **33 MHz Read Clock**) using:

* 2-stage flip-flop synchronizers
* Gray code pointer synchronization
* Independent read/write clock domains
* Transaction-level verification with PyUVM

---

## 🏗️ Design Architecture

The RTL is modularized into five hardware blocks:

| Module       | Description                                                              |
| ------------ | ------------------------------------------------------------------------ |
| `fifomem`    | Dual-port SRAM storage array                                             |
| `sync2`      | Two-stage flip-flop synchronizer for clock-domain crossing               |
| `rptr_empty` | Read pointer logic, Binary-to-Gray conversion, and Empty flag generation |
| `wptr_full`  | Write pointer logic, Binary-to-Gray conversion, and Full flag generation |
| `async_fifo` | Top-level module integrating all FIFO components                         |

### Pointer Scheme

The FIFO uses the standard **N+1-bit pointer technique** to distinguish between:

* **Empty FIFO** → Read pointer equals Write pointer
* **Full FIFO** → Write pointer has wrapped around while Read pointer has not

Gray code pointers are synchronized across clock domains to minimize metastability during clock-domain crossing.

---

## 🔬 Verification Strategy (PyUVM)

The verification environment is implemented using:

* **Python**
* **Cocotb**
* **PyUVM**

instead of a traditional linear SystemVerilog testbench.

### Key Features

* Independent read and write agents operating at asynchronous clock frequencies
* Transaction-Level Modeling (TLM)
* Separate monitors for both clock domains
* Automated scoreboard for functional checking
* Fully object-oriented verification architecture

### Verification Flow

1. Write Driver generates randomized write transactions.
2. Read Driver independently performs read operations.
3. Monitors observe DUT interfaces without driving signals.
4. Analysis Ports broadcast transactions.
5. The Scoreboard compares expected and actual data to detect:

   * Data corruption
   * Data loss
   * Data duplication
   * Ordering violations

---

## 🐛 Development Bug Hunt (Authenticity Log)

During development, several subtle hardware verification issues were discovered and resolved.

### 1. Delta-Cycle Race Conditions

**Problem**

The initial verification environment suffered from driver/monitor race conditions at the picosecond (delta-cycle) level, resulting in inconsistent transaction capture.

**Solution**

The drivers were redesigned to emulate realistic hardware timing by:

* Driving signals on the `FallingEdge`
* Sampling on the following setup window before the active clock edge

This eliminated race conditions while modeling realistic setup/hold timing.

---

### 2. Combinational Read Data Trap

**Problem**

The read monitor occasionally missed the first valid data word because the FIFO uses a combinational read path:

```verilog
assign rdata = mem[raddr];
```

The output changed immediately after the read pointer incremented, causing the monitor to sample the updated value instead of the intended data.

**Solution**

The read monitor was modified to capture `rdata` immediately **before** the read clock edge, ensuring the correct data word was observed before the combinational output changed.

---

## 🚀 Getting Started

### Prerequisites

Install the following tools:

* Python 3
* Icarus Verilog (`iverilog`)
* Cocotb
* PyUVM

---

### Clone the Repository

```bash
git clone https://github.com/YourUsername/async-fifo-pyuvm.git
cd async-fifo-pyuvm
```

---

### Install Python Dependencies

```bash
pip install cocotb pyuvm
```

---

### Run the Simulation

```bash
cd sim
make WAVES=1
```

---

## 📂 Repository Structure

```text
async-fifo-pyuvm/
├── rtl/
│   └── async_fifo.sv       (Contains all 5 Verilog hardware modules)
├── tb/
│   └── test_async_fifo.py  (Contains the PyUVM Object-Oriented environment)
├── sim/
│   └── Makefile            (Contains compilation paths and wave options)
├── docs/
│   ├── terminal_pass.png   (Your clean terminal screenshot showing green PASS)
│   └── waveform.png        (Your GTKWave screenshot showing Gray code transition)
└── README.md               (The front page of your project)
```

---

## 🎯 Learning Objectives

This project demonstrates practical implementation of:

* Clock Domain Crossing (CDC)
* Asynchronous FIFO architecture
* Gray code pointer synchronization
* Two-stage synchronizers
* Cocotb verification
* PyUVM methodology
* Transaction-Level Modeling (TLM)
* Functional scoreboarding
* Object-oriented hardware verification
* Debugging real-world verification race conditions

---

## 📜 License

This project is intended for educational and learning purposes.


![Terminal Pass](docs/async_fifo%20terminal%20PASS.png)
![Terminal Pass](docs/async_fifo%20waveform.png)



