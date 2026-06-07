## ============================================================
## ATM Machine Controller - Synthesis-Only XDC
## ============================================================
## Purpose : Provide the minimum constraints required for
##           Vivado to run synthesis and generate:
##             - Timing report  (report_timing_summary)
##             - Power report   (report_power)
##             - Utilization    (report_utilization)
##
## NO physical I/O pin assignments are included because this
## design is NOT being implemented on an FPGA board.
## The clock constraint below is all Vivado needs to
## perform static timing analysis after synthesis.
##
## Target device : Zynq XC7Z020-CLG484-1 (ZedBoard)
## Tool          : Vivado 2023.x
## ============================================================

## ------------------------------------------------------------
## Primary Clock Constraint (100 MHz)
## Attach to the top-level clk port so the timing engine
## knows the operating frequency for setup/hold analysis.
## ------------------------------------------------------------
create_clock -period 10.000 \
             -name   sys_clk_100mhz \
             -waveform {0.000 5.000} \
             [get_ports clk]

## ------------------------------------------------------------
## Input false paths for all control inputs.
## These are driven by testbench / behavioural models, not real
## flip-flops, so we tell the timing engine not to waste time
## computing input-to-register paths for these signals.
## ------------------------------------------------------------
#set_false_path -from [get_ports rst_n]
#set_false_path -from [get_ports card_inserted]
#set_false_path -from [get_ports card_has_pin]
#set_false_path -from [get_ports cancel]
#set_false_path -from [get_ports pin_correct]
#set_false_path -from [get_ports otp_correct]
#set_false_path -from [get_ports acct_digits_ok]
#set_false_path -from [get_ports sel_withdraw]
#set_false_path -from [get_ports sel_balance]
#set_false_path -from [get_ports sel_mini_stmt]
#set_false_path -from [get_ports sel_pin_change]
#set_false_path -from [get_ports sel_savings]
#set_false_path -from [get_ports amount_entered]
#set_false_path -from [get_ports balance_ok]
#set_false_path -from [get_ports denom_available]
#set_false_path -from [get_ports {denom_selected[*]}]
#set_false_path -from [get_ports cash_ok]
#set_false_path -from [get_ports bin_100_avail]
#set_false_path -from [get_ports bin_500_avail]
#set_false_path -from [get_ports bin_2000_avail]
#set_false_path -from [get_ports receipt_requested]
#set_false_path -from [get_ports new_pin_confirmed]
#set_false_path -from [get_ports hardware_error]

### ------------------------------------------------------------
### Output false paths for all output ports.
### Outputs go to LEDs / display logic with no timing closure
### requirement, so exclude them from timing analysis.
### ------------------------------------------------------------
#set_false_path -to [get_ports dispense_cash]
#set_false_path -to [get_ports print_receipt]
#set_false_path -to [get_ports eject_card]
#set_false_path -to [get_ports update_balance]
#set_false_path -to [get_ports send_otp]
#set_false_path -to [get_ports store_new_pin]
#set_false_path -to [get_ports block_card]
#set_false_path -to [get_ports {state_out[*]}]
#set_false_path -to [get_ports show_denom_100]
#set_false_path -to [get_ports show_denom_500]
#set_false_path -to [get_ports show_denom_2000]
#set_false_path -to [get_ports msg_wrong_pin]
#set_false_path -to [get_ports msg_blocked]
#set_false_path -to [get_ports msg_insuff_bal]
#set_false_path -to [get_ports msg_no_denom]
#set_false_path -to [get_ports msg_cancelled]
#set_false_path -to [get_ports msg_complete]
#set_false_path -to [get_ports msg_error]
#set_false_path -to [get_ports msg_enter_pin]
#set_false_path -to [get_ports msg_enter_otp]
#set_false_path -to [get_ports msg_set_pin]
#set_false_path -to [get_ports msg_confirm_pin]
