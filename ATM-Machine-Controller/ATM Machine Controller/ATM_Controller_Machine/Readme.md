# ATM Machine Controller — Verilog FSM

A synthesizable ATM controller modeled as a finite state machine in Verilog-2001, written as part of a Digital Circuits course assignment. Covers the full transaction lifecycle including cash withdrawal, PIN management, balance inquiry, and mini statement, with clean handling of error and cancel paths throughout.

---

## What it does

The FSM models a real ATM interaction across five flows:

- **Cash Withdrawal** — card insert → PIN → account type → amount → denomination check → dispense → receipt → eject
- **New PIN Setup** — fresh card detected → last-4-digit account verification → OTP → set new PIN
- **PIN Change/Reset** — existing card → menu selection → account verification → OTP → confirm new PIN
- **Balance Inquiry** — post-authentication → display balance → optional receipt → eject
- **Mini Statement** — post-authentication → print last 5 transactions → eject

Every stage supports a cancel button that safely aborts and ejects the card. Hardware errors at any point drop the FSM into a safe error state before ejecting.

---

## States

The FSM uses 23 states:

`IDLE` → `CARD_INSERTED` → `PIN_ENTRY` → `TRANSACTION_MENU` → `WITHDRAW` → `ACCOUNT_TYPE_SELECT` → `AMOUNT_ENTRY` → `CHECK_BALANCE` → `DENOMINATION_SELECT` → `DISPENSE_CASH` → `RECEIPT_OPTION` → `CARD_EJECT` → `COMPLETE`

Plus: `ACCOUNT_VERIFY`, `OTP_VERIFY`, `NEW_PIN_SETUP`, `PIN_RESET`, `PIN_CONFIRM`, `BALANCE_INQUIRY`, `MINI_STATEMENT`, `CANCELLED`, `BLOCKED`, `ERROR`

---

## Files

| File | Description |
|------|-------------|
| `atm_controller.v` | RTL design — synthesizable Moore FSM |
| `atm_controller_tb.v` | Self-checking testbench |
| `atm_controller.xdc` | Synthesis-only constraints (100 MHz clock) |

---

## Simulation Results

Simulated in Xilinx Vivado. All tests pass with zero failures.

```
TOTAL PASS : 86
TOTAL FAIL : 0
RESULT     : *** ALL TESTS PASSED ***
```

Test coverage includes normal withdrawal, 3-strike PIN block, insufficient balance, empty cash bin, dynamic denomination display, fresh card PIN setup, existing card PIN reset, balance inquiry, mini statement, hardware error injection, cancel at every stage, wrong OTP retry, and randomized stress runs.

---

## Synthesis and Implementation Results (Xilinx Vivado, Zynq XC7Z020)

| Metric | Value |
|--------|-------|
| LUTs | 65 |
| Flip-Flops | 8 |
| BRAM | 0 |
| Total Power | 0.113 W |
| WNS | 5.744 ns |
| Fmax | ~235 MHz |

Clock constrained at 100 MHz. Positive WNS of 5.744 ns means the critical path delay is only 4.256 ns, giving a maximum operating frequency of around 235 MHz.

---

## How to simulate in Xilinx Vivado

1. Create a new project, set part to `xc7z020clg484-1`
2. Add `atm_controller.v` as design source and `atm_controller_tb.v` as simulation source
3. Add `atm_controller.xdc` as constraint
4. Open Simulation → Run Behavioral Simulation
5. Check the TCL console for PASS/FAIL results

## How to synthesize

1. Run Synthesis from the Flow Navigator
2. Run Implementation
3. Generate timing, power, and utilization reports from the Reports menu
