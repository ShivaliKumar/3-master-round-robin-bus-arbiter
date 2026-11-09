# 3-Master Round-Robin Bus Arbiter

A parameterized bus arbiter designed using **SystemVerilog**, supporting three bus masters with round-robin arbitration, burst transfers, locked transactions, and timeout recovery.

The project focuses on RTL design and functional verification using SystemVerilog assertions (SVA), a self-checking testbench, scoreboard checks, and functional coverage.

## Project Overview

A bus arbiter manages access to a shared bus when multiple masters request it simultaneously. This project implements a 3-master arbiter that provides controlled and fair access while handling different transfer conditions.

The arbiter uses a round-robin priority mechanism to prevent one master from continuously dominating bus access.

## Features

- **Round-Robin Arbitration:** Cyclic priority selection among three bus masters.
- **Burst Transfer Support:** Supports multi-beat transfers and releases the bus after burst completion.
- **Locked Transactions:** Allows a master to retain bus ownership across consecutive transactions when lock is requested.
- **Timeout Detection:** Detects prolonged stalled transfers and generates a timeout error.
- **Timeout Recovery:** Resets the timeout counter when a stalled transfer is withdrawn or a transfer is accepted.
- **Asynchronous Reset:** Clears arbiter state and recovers the system during reset.
- **Parameterized Design:** Supports configurable master count and counter widths.

## Architecture

The design consists of three main components:

1. **Arbiter Interface (`arbiter_if.sv`)**
   - Defines communication signals between the arbiter and testbench.
   - Includes request, grant, lock, burst, handshake, timeout, and status signals.

2. **Arbiter RTL (`round_robin_arbiter.sv`)**
   - Implements round-robin master selection.
   - Controls bus ownership and burst completion.
   - Handles locked transfers and timeout recovery.

3. **Verification Testbench (`arbiter_tb.sv`)**
   - Generates directed and randomized stimulus.
   - Checks expected behavior using a scoreboard.
   - Verifies protocol conditions using SVA.
   - Collects functional coverage.

## Verification Methodology

The design was verified using a SystemVerilog testbench with the following techniques:

- Directed testing for specific arbitration and transfer scenarios.
- Randomized stress testing to exercise different request and transfer conditions.
- Scoreboard-based checking of burst completion behavior.
- SystemVerilog Assertions (SVA) for protocol and control checks.
- Functional coverage to measure verification completeness.

### Test Scenarios

| Test | Description |
|---|---|
| Test 1 | Round-robin arbitration and priority pointer wrapping |
| Test 2 | Burst handling and bus release after the final beat |
| Test 3 | Lock verification for all three masters |
| Test 4 | Timeout detection and bus release |
| Test 5 | Timeout counter recovery |
| Test 6 | All eight request combinations |
| Test 7 | Lock combinations |
| Test 8 | Burst length combinations |
| Test 9 | Reset during active bus operation |
| Test 10 | Randomized stress testing |

## Simulation Results

<details>
</details>

The simulation completed successfully with the following results:

| Verification Metric | Result |
|---|---:|
| Directed tests passed | 44 |
| Directed tests failed | 0 |
| Assertion passes | 918 |
| Assertion failures | 0 |
| Scoreboard checks | 41 |
| Scoreboard failures | 0 |
| Overall functional coverage | **98.18%** |

### Functional Coverage

| Coverage Category | Coverage |
|---|---:|
| Request coverage | 100% |
| Grant coverage | 100% |
| Owner coverage | 100% |
| Handshake coverage | 100% |
| Lock coverage | 100% |
| Owner-lock coverage | 100% |
| Timeout coverage | 100% |
| Burst coverage | 100% |
| Request-grant cross coverage | 78.12% |
| Handshake-busy cross coverage | 100% |

**Final Simulation Status: VERIFICATION PASSED**

The request-grant cross coverage reached 78.12%, while the overall functional coverage was 98.18%.

## Tools and Technologies

- SystemVerilog
- RTL Design
- Functional Verification
- SystemVerilog Assertions (SVA)
- Functional Coverage
- Self-Checking Testbench
- Constrained/Randomized Testing

## Project Structure

```text
3-Master-Round-Robin-Bus-Arbiter/
│
├── rtl/
│   ├── arbiter_if.sv
│   └── round_robin_arbiter.sv
│
├── verification/
│   └── arbiter_tb.sv
│
└── README.md
```

## How to Run

1. Clone or download this repository.
2. Open the project in a SystemVerilog-compatible simulator.
3. Add the interface, RTL, and testbench files to the simulation project.
4. Compile the files in the following order:
   - `arbiter_if.sv`
   - `round_robin_arbiter.sv`
   - `arbiter_tb.sv`
5. Run the testbench.
6. Check the simulation transcript for the verification summary and final pass status.

**Note:** Use a simulator that supports the SystemVerilog features used in the testbench, including assertions and functional coverage.

## Key Learning Outcomes

- Understanding round-robin arbitration and bus ownership.
- Designing parameterized RTL modules using SystemVerilog.
- Handling burst transfers, locked transactions, and timeout conditions.
- Developing self-checking verification environments.
- Writing assertions and functional coverage models.
- Debugging RTL and verifying hardware control logic.

---

**Project Domain:** Digital VLSI Design and Functional Verification

**Languages:** SystemVerilog
