`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.06.2026 11:57:30
// Design Name: 
// Module Name: atm_controller_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ============================================================
// ATM Machine Controller - Self-Checking Testbench
// ============================================================
// File        : atm_controller_tb.v
// Description : Comprehensive self-checking testbench for the
//               ATM FSM controller. Covers all scenarios:
//               - Cash Withdrawal (normal, cancel, error paths)
//               - New PIN Setup (fresh card)
//               - PIN Change/Reset (existing card)
//               - Balance Inquiry
//               - Mini Statement
//               - Wrong PIN / Card Block
//               - Hardware Error injection
//               - Cancel at every major stage
// ============================================================

`timescale 1ns/1ps

module atm_controller_tb;

    // --------------------------------------------------------
    // DUT Signal Declarations
    // --------------------------------------------------------
    reg        clk, rst_n;
    reg        card_inserted, card_has_pin, cancel;
    reg        pin_correct, otp_correct, acct_digits_ok;
    reg        sel_withdraw, sel_balance, sel_mini_stmt, sel_pin_change;
    reg        sel_savings;
    reg        amount_entered, balance_ok, denom_available;
    reg [2:0]  denom_selected;
    reg        cash_ok;
    reg        bin_100_avail, bin_500_avail, bin_2000_avail;
    reg        receipt_requested, new_pin_confirmed, hardware_error;

    wire       dispense_cash, print_receipt, eject_card;
    wire       update_balance, send_otp, store_new_pin, block_card;
    wire [4:0] state_out;
    wire       show_denom_100, show_denom_500, show_denom_2000;
    wire       msg_wrong_pin, msg_blocked, msg_insuff_bal, msg_no_denom;
    wire       msg_cancelled, msg_complete, msg_error;
    wire       msg_enter_pin, msg_enter_otp, msg_set_pin, msg_confirm_pin;

    // --------------------------------------------------------
    // State name constants (match RTL encoding)
    // --------------------------------------------------------
    localparam [4:0]
        IDLE               = 5'd0,
        CARD_INSERTED      = 5'd1,
        PIN_ENTRY          = 5'd2,
        ACCOUNT_VERIFY     = 5'd3,
        TRANSACTION_MENU   = 5'd4,
        WITHDRAW           = 5'd5,
        ACCOUNT_TYPE_SELECT= 5'd6,
        AMOUNT_ENTRY       = 5'd7,
        CHECK_BALANCE      = 5'd8,
        DENOMINATION_SELECT= 5'd9,
        DISPENSE_CASH      = 5'd10,
        RECEIPT_OPTION     = 5'd11,
        BALANCE_INQUIRY    = 5'd12,
        MINI_STATEMENT     = 5'd13,
        NEW_PIN_SETUP      = 5'd14,
        PIN_RESET          = 5'd15,
        OTP_VERIFY         = 5'd16,
        PIN_CONFIRM        = 5'd17,
        CARD_EJECT         = 5'd18,
        COMPLETE           = 5'd19,
        CANCELLED          = 5'd20,
        BLOCKED            = 5'd21,
        ERROR              = 5'd22;

    // --------------------------------------------------------
    // Test counters
    // --------------------------------------------------------
    integer test_pass_count;
    integer test_fail_count;

    // --------------------------------------------------------
    // DUT Instantiation
    // --------------------------------------------------------
    atm_controller dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .card_inserted    (card_inserted),
        .card_has_pin     (card_has_pin),
        .cancel           (cancel),
        .pin_correct      (pin_correct),
        .otp_correct      (otp_correct),
        .acct_digits_ok   (acct_digits_ok),
        .sel_withdraw     (sel_withdraw),
        .sel_balance      (sel_balance),
        .sel_mini_stmt    (sel_mini_stmt),
        .sel_pin_change   (sel_pin_change),
        .sel_savings      (sel_savings),
        .amount_entered   (amount_entered),
        .balance_ok       (balance_ok),
        .denom_available  (denom_available),
        .denom_selected   (denom_selected),
        .cash_ok          (cash_ok),
        .bin_100_avail    (bin_100_avail),
        .bin_500_avail    (bin_500_avail),
        .bin_2000_avail   (bin_2000_avail),
        .receipt_requested(receipt_requested),
        .new_pin_confirmed(new_pin_confirmed),
        .hardware_error   (hardware_error),
        .dispense_cash    (dispense_cash),
        .print_receipt    (print_receipt),
        .eject_card       (eject_card),
        .update_balance   (update_balance),
        .send_otp         (send_otp),
        .store_new_pin    (store_new_pin),
        .block_card       (block_card),
        .state_out        (state_out),
        .show_denom_100   (show_denom_100),
        .show_denom_500   (show_denom_500),
        .show_denom_2000  (show_denom_2000),
        .msg_wrong_pin    (msg_wrong_pin),
        .msg_blocked      (msg_blocked),
        .msg_insuff_bal   (msg_insuff_bal),
        .msg_no_denom     (msg_no_denom),
        .msg_cancelled    (msg_cancelled),
        .msg_complete     (msg_complete),
        .msg_error        (msg_error),
        .msg_enter_pin    (msg_enter_pin),
        .msg_enter_otp    (msg_enter_otp),
        .msg_set_pin      (msg_set_pin),
        .msg_confirm_pin  (msg_confirm_pin)
    );

    // --------------------------------------------------------
    // Clock Generation: 100 MHz (10 ns period)
    // --------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // --------------------------------------------------------
    // TASK: Reset all inputs to safe defaults
    // Prevents X-propagation between test cases
    // --------------------------------------------------------
    task reset_inputs;
    begin
        card_inserted    = 0; card_has_pin   = 0; cancel         = 0;
        pin_correct      = 0; otp_correct    = 0; acct_digits_ok = 0;
        sel_withdraw     = 0; sel_balance    = 0; sel_mini_stmt  = 0;
        sel_pin_change   = 0; sel_savings    = 0;
        amount_entered   = 0; balance_ok     = 0; denom_available= 0;
        denom_selected   = 3'b000; cash_ok   = 0;
        bin_100_avail    = 0; bin_500_avail  = 0; bin_2000_avail = 0;
        receipt_requested= 0; new_pin_confirmed = 0; hardware_error = 0;
    end
    endtask

    // --------------------------------------------------------
    // TASK: Apply synchronous reset
    // --------------------------------------------------------
    task apply_reset;
    begin
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end
    endtask

    // --------------------------------------------------------
    // TASK: Advance N clock cycles
    // --------------------------------------------------------
    task clk_step;
        input integer n;
        integer i;
    begin
        for (i = 0; i < n; i = i+1)
            @(posedge clk);
    end
    endtask

    // --------------------------------------------------------
    // TASK: Assert expected state with PASS/FAIL logging
    // --------------------------------------------------------
    task check_state;
        input [4:0]  expected;
        input [63:0] test_id;   // used as an integer tag
        input [255:0] test_name;
    begin
        @(negedge clk); // sample after clock edge settles
        if (state_out === expected) begin
            $display("[PASS] Test %0d (%s): State = %0d (expected %0d)",
                     test_id, test_name, state_out, expected);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d (%s): State = %0d (expected %0d) *** MISMATCH ***",
                     test_id, test_name, state_out, expected);
            test_fail_count = test_fail_count + 1;
        end
    end
    endtask

    // --------------------------------------------------------
    // TASK: Assert expected output signal
    // --------------------------------------------------------
    task check_output;
        input       actual;
        input       expected;
        input [63:0] test_id;
        input [255:0] sig_name;
    begin
        if (actual === expected) begin
            $display("[PASS] Test %0d (%s): Output = %0b (expected %0b)",
                     test_id, sig_name, actual, expected);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d (%s): Output = %0b (expected %0b) *** MISMATCH ***",
                     test_id, sig_name, actual, expected);
            test_fail_count = test_fail_count + 1;
        end
    end
    endtask

    // ========================================================
    // MAIN TEST SEQUENCE
    // ========================================================
    initial begin
        test_pass_count = 0;
        test_fail_count = 0;

        $display("============================================================");
        $display("   ATM Controller Testbench - Starting Simulation");
        $display("============================================================");

        reset_inputs;
        apply_reset;

        // ====================================================
        // TEST GROUP 1: RESET VERIFICATION
        // Objective: Confirm FSM starts in IDLE after reset
        // ====================================================
        $display("\n--- TEST GROUP 1: Reset Verification ---");
        check_state(IDLE, 1, "RESET_TO_IDLE");

        // ====================================================
        // TEST GROUP 2: SCENARIO 1 - Normal Cash Withdrawal
        // Objective: Full happy-path withdrawal with receipt
        // ====================================================
        $display("\n--- TEST GROUP 2: Normal Cash Withdrawal (Happy Path) ---");

        apply_reset; reset_inputs;

        // Step 1: Insert card (existing card with PIN)
        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1;
        check_state(CARD_INSERTED, 2, "CARD_INSERTED");

        card_inserted = 0;
        @(posedge clk); #1;
        check_state(PIN_ENTRY, 3, "PIN_ENTRY_AFTER_INSERT");

        // Step 2: Enter correct PIN
        pin_correct = 1;
        @(posedge clk); #1;
        check_state(TRANSACTION_MENU, 4, "MENU_AFTER_CORRECT_PIN");

        pin_correct = 0;

        // Step 3: Select Withdraw
        sel_withdraw = 1;
        @(posedge clk); #1;
        check_state(WITHDRAW, 5, "WITHDRAW_SELECTED");
        sel_withdraw = 0;

        // WITHDRAW is a one-cycle gateway; next clock → ACCOUNT_TYPE_SELECT
        @(posedge clk); #1;
        check_state(ACCOUNT_TYPE_SELECT, 6, "ACCOUNT_TYPE_SELECT");

        // Step 4: Select Savings account
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1;
        check_state(AMOUNT_ENTRY, 7, "AMOUNT_ENTRY");
        sel_savings = 0; amount_entered = 0;

        // Step 5: Enter amount
        amount_entered = 1;
        @(posedge clk); #1;
        check_state(CHECK_BALANCE, 8, "CHECK_BALANCE");
        amount_entered = 0;

        // Step 6: Both balance and denomination checks pass
        balance_ok = 1; denom_available = 1;
        bin_100_avail = 1; bin_500_avail = 1; bin_2000_avail = 1;
        @(posedge clk); #1;
        check_state(DENOMINATION_SELECT, 9, "DENOMINATION_SELECT");

        // Verify all three denominations are shown
        check_output(show_denom_100,  1, 10, "SHOW_DENOM_100");
        check_output(show_denom_500,  1, 11, "SHOW_DENOM_500");
        check_output(show_denom_2000, 1, 12, "SHOW_DENOM_2000");

        balance_ok = 0; denom_available = 0;

        // Step 7: Select Rs.500 denomination
        denom_selected = 3'b010; cash_ok = 1;
        @(posedge clk); #1;
        check_state(DISPENSE_CASH, 13, "DISPENSE_CASH");
        check_output(dispense_cash,  1, 14, "DISPENSE_CASH_PULSE");
        check_output(update_balance, 1, 15, "UPDATE_BALANCE_PULSE");
        denom_selected = 3'b000; cash_ok = 0;

        // Step 8: Move to receipt option
        @(posedge clk); #1;
        check_state(RECEIPT_OPTION, 16, "RECEIPT_OPTION");

        // Step 9: User wants receipt - set receipt_requested, then check output immediately.
        // check_state() already consumed a @negedge, so we are mid-cycle.
        // The combinational output responds instantly to the input assignment.
        receipt_requested = 1;
        #1; // let combinational settle
        check_output(print_receipt, 1, 17, "PRINT_RECEIPT");
        @(posedge clk); #1;
        check_state(CARD_EJECT, 18, "CARD_EJECT");
        check_output(eject_card, 1, 19, "EJECT_CARD_PULSE");
        receipt_requested = 0;

        @(posedge clk); #1;
        check_state(COMPLETE, 20, "COMPLETE");
        check_output(msg_complete, 1, 21, "MSG_COMPLETE");

        @(posedge clk); #1;
        check_state(IDLE, 22, "BACK_TO_IDLE");

        // ====================================================
        // TEST GROUP 3: Wrong PIN → Card Blocked
        // Objective: 3 consecutive wrong PINs must block card
        // ====================================================
        $display("\n--- TEST GROUP 3: Wrong PIN 3 Times → Card Blocked ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1;
        card_inserted = 0;
        @(posedge clk); #1; // Now in PIN_ENTRY

        // Wrong attempt 1
        pin_correct = 0;
        @(posedge clk); #1;
        check_state(PIN_ENTRY, 23, "STAY_PIN_ENTRY_WRONG1");
        check_output(msg_wrong_pin, 1, 24, "MSG_WRONG_PIN_1");

        // Wrong attempt 2
        @(posedge clk); #1;
        check_state(PIN_ENTRY, 25, "STAY_PIN_ENTRY_WRONG2");

        // Wrong attempt 3 → should go to BLOCKED
        @(posedge clk); #1;
        check_state(BLOCKED, 26, "BLOCKED_AFTER_3_WRONG");
        check_output(block_card,  1, 27, "BLOCK_CARD_PULSE");
        check_output(msg_blocked, 1, 28, "MSG_BLOCKED");

        @(posedge clk); #1;
        check_state(CARD_EJECT, 29, "EJECT_AFTER_BLOCK");
        @(posedge clk); #1;
        check_state(COMPLETE, 30, "COMPLETE_AFTER_BLOCK");
        @(posedge clk); #1;
        check_state(IDLE, 31, "IDLE_AFTER_BLOCK");

        // ====================================================
        // TEST GROUP 4: Insufficient Balance
        // Objective: Transaction must cancel if balance fails
        // ====================================================
        $display("\n--- TEST GROUP 4: Insufficient Balance ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
        @(posedge clk); #1; // ACCOUNT_TYPE_SELECT
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
        amount_entered = 1; @(posedge clk); #1; amount_entered = 0;
        // CHECK_BALANCE: balance fails
        balance_ok = 0; denom_available = 1;
        @(posedge clk); #1;
        check_state(CANCELLED, 32, "CANCELLED_INSUFF_BAL");
        // msg_insuff_bal is now also driven in CANCELLED state when balance_ok=0
        check_output(msg_insuff_bal, 1, 33, "MSG_INSUFF_BAL");
        @(posedge clk); #1;
        check_state(CARD_EJECT, 34, "EJECT_AFTER_INSUFF");

        // ====================================================
        // TEST GROUP 5: No Valid Denomination
        // Objective: If denom_available=0, transaction cancels
        // ====================================================
        $display("\n--- TEST GROUP 5: No Valid Denomination ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
        @(posedge clk); #1;
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
        amount_entered = 1; @(posedge clk); #1; amount_entered = 0;
        balance_ok = 1; denom_available = 0;
        @(posedge clk); #1;
        check_state(CANCELLED, 35, "CANCELLED_NO_DENOM");
        // denom_available still 0 so msg_no_denom fires in CANCELLED state
        check_output(msg_no_denom, 1, 36, "MSG_NO_DENOM");

        // ====================================================
        // TEST GROUP 6: Dynamic Denomination Display
        // Objective: Only available bins show as selectable
        // ====================================================
        $display("\n--- TEST GROUP 6: Dynamic Denomination Display ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
        @(posedge clk); #1;
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
        amount_entered = 1; @(posedge clk); #1; amount_entered = 0;
        // Only Rs.100 and Rs.2000 bins available (Rs.500 empty)
        balance_ok = 1; denom_available = 1;
        bin_100_avail = 1; bin_500_avail = 0; bin_2000_avail = 1;
        @(posedge clk); #1;
        check_state(DENOMINATION_SELECT, 37, "DENOM_SELECT_DYNAMIC");
        check_output(show_denom_100,  1, 38, "SHOW_100_AVAIL");
        check_output(show_denom_500,  0, 39, "HIDE_500_EMPTY");
        check_output(show_denom_2000, 1, 40, "SHOW_2000_AVAIL");

        // ====================================================
        // TEST GROUP 7: Cancel at Transaction Menu
        // Objective: Cancel at any stage returns to CARD_EJECT
        // ====================================================
        $display("\n--- TEST GROUP 7: Cancel at Transaction Menu ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        // Now in TRANSACTION_MENU - press cancel
        cancel = 1;
        @(posedge clk); #1; cancel = 0;
        check_state(CARD_EJECT, 41, "CANCEL_AT_MENU");
        check_output(msg_cancelled, 0, 42, "NO_CANCEL_MSG_AT_EJECT"); // msg shown in CANCELLED state
        @(posedge clk); #1;
        check_state(COMPLETE, 43, "COMPLETE_AFTER_CANCEL");

        // ====================================================
        // TEST GROUP 8: Cancel During Amount Entry
        // ====================================================
        $display("\n--- TEST GROUP 8: Cancel During Amount Entry ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
        @(posedge clk); #1;
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
        // In AMOUNT_ENTRY - press cancel
        cancel = 1;
        @(posedge clk); #1; cancel = 0;
        check_state(CANCELLED, 44, "CANCEL_AMOUNT_ENTRY");
        @(posedge clk); #1;
        check_state(CARD_EJECT, 45, "EJECT_AFTER_CANCEL_AMT");

        // ====================================================
        // TEST GROUP 9: Scenario 2 - New PIN Setup (Fresh Card)
        // Objective: Fresh card → account verify → OTP → set PIN
        // ====================================================
        $display("\n--- TEST GROUP 9: New PIN Setup (Fresh Card) ---");

        apply_reset; reset_inputs;

        // Fresh card: card_has_pin = 0
        card_inserted = 1; card_has_pin = 0;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1;
        check_state(ACCOUNT_VERIFY, 46, "ACCT_VERIFY_FRESH_CARD");

        // Enter correct last-4-digits of account
        acct_digits_ok = 1;
        @(posedge clk); #1; acct_digits_ok = 0;
        check_state(OTP_VERIFY, 47, "OTP_VERIFY_FRESH_CARD");
        check_output(send_otp,      1, 48, "SEND_OTP_PULSE");
        check_output(msg_enter_otp, 1, 49, "MSG_ENTER_OTP");

        // Enter correct OTP
        otp_correct = 1;
        @(posedge clk); #1; otp_correct = 0;
        check_state(NEW_PIN_SETUP, 50, "NEW_PIN_SETUP");
        check_output(msg_set_pin, 1, 51, "MSG_SET_PIN");

        // Move to PIN_CONFIRM
        @(posedge clk); #1;
        check_state(PIN_CONFIRM, 52, "PIN_CONFIRM");
        check_output(msg_confirm_pin, 1, 53, "MSG_CONFIRM_PIN");

        // Confirm new PIN - check store_new_pin immediately (combinational output)
        new_pin_confirmed = 1;
        #1; // combinational settle - check_state already consumed negedge
        check_output(store_new_pin, 1, 54, "STORE_NEW_PIN");
        @(posedge clk); #1; new_pin_confirmed = 0;
        check_state(CARD_EJECT, 55, "EJECT_AFTER_NEW_PIN");
        @(posedge clk); #1;
        check_state(COMPLETE, 56, "COMPLETE_NEW_PIN");

        // ====================================================
        // TEST GROUP 10: Scenario 3 - PIN Change (Existing Card)
        // Objective: Menu → PIN Reset → Acct verify → OTP → confirm
        // ====================================================
        $display("\n--- TEST GROUP 10: PIN Change/Reset (Existing Card) ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        // Select Change PIN from menu
        sel_pin_change = 1;
        @(posedge clk); #1; sel_pin_change = 0;
        check_state(PIN_RESET, 57, "PIN_RESET_FROM_MENU");

        // PIN_RESET → ACCOUNT_VERIFY
        @(posedge clk); #1;
        check_state(ACCOUNT_VERIFY, 58, "ACCT_VERIFY_PIN_RESET");

        acct_digits_ok = 1;
        @(posedge clk); #1; acct_digits_ok = 0;
        check_state(OTP_VERIFY, 59, "OTP_VERIFY_PIN_RESET");

        otp_correct = 1;
        @(posedge clk); #1; otp_correct = 0;
        // is_new_pin_flow = 0, so should go to PIN_CONFIRM directly
        check_state(PIN_CONFIRM, 60, "PIN_CONFIRM_PIN_RESET");

        new_pin_confirmed = 1;
        @(posedge clk); #1; new_pin_confirmed = 0;
        check_state(CARD_EJECT, 61, "EJECT_AFTER_PIN_RESET");

        // ====================================================
        // TEST GROUP 11: Balance Inquiry with Receipt
        // ====================================================
        $display("\n--- TEST GROUP 11: Balance Inquiry ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_balance = 1;
        @(posedge clk); #1; sel_balance = 0;
        check_state(BALANCE_INQUIRY, 62, "BALANCE_INQUIRY");

        // receipt_requested=1 in BALANCE_INQUIRY → check print_receipt combinationally
        receipt_requested = 1;
        #1; // combinational settle
        check_output(print_receipt, 1, 63, "PRINT_RECEIPT_BALANCE");
        @(posedge clk); #1;
        check_state(RECEIPT_OPTION, 64, "RECEIPT_OPTION_BAL");
        receipt_requested = 0;
        @(posedge clk); #1;
        check_state(CARD_EJECT, 65, "EJECT_AFTER_BAL_INQ");

        // ====================================================
        // TEST GROUP 12: Mini Statement
        // ====================================================
        $display("\n--- TEST GROUP 12: Mini Statement ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_mini_stmt = 1;
        @(posedge clk); #1; sel_mini_stmt = 0;
        check_state(MINI_STATEMENT, 66, "MINI_STATEMENT");
        check_output(print_receipt, 1, 67, "PRINT_MINI_STMT");

        @(posedge clk); #1;
        check_state(CARD_EJECT, 68, "EJECT_AFTER_MINI_STMT");

        // ====================================================
        // TEST GROUP 13: Hardware Error Injection
        // Objective: hardware_error must force FSM to ERROR state
        // ====================================================
        $display("\n--- TEST GROUP 13: Hardware Error Injection ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        // Inject hardware error while in TRANSACTION_MENU
        hardware_error = 1;
        @(posedge clk); #1; hardware_error = 0;
        check_state(ERROR, 69, "ERROR_STATE_HW_FAULT");
        check_output(msg_error, 1, 70, "MSG_ERROR");

        @(posedge clk); #1;
        check_state(CARD_EJECT, 71, "EJECT_AFTER_ERROR");
        @(posedge clk); #1;
        check_state(COMPLETE, 72, "COMPLETE_AFTER_ERROR");

        // ====================================================
        // TEST GROUP 14: Cancel at IDLE (insert then cancel)
        // ====================================================
        $display("\n--- TEST GROUP 14: Cancel Immediately After Insert ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        cancel = 1;
        @(posedge clk); #1; cancel = 0;
        check_state(CARD_EJECT, 73, "CANCEL_AT_CARD_INSERTED");

        // ====================================================
        // TEST GROUP 15: OTP Wrong → Retry → Correct
        // Objective: Wrong OTP keeps FSM in OTP_VERIFY
        // ====================================================
        $display("\n--- TEST GROUP 15: Wrong OTP then Correct OTP ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 0; // fresh card
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1;
        acct_digits_ok = 1;
        @(posedge clk); #1; acct_digits_ok = 0;
        // In OTP_VERIFY - enter wrong OTP
        otp_correct = 0;
        @(posedge clk); #1;
        check_state(OTP_VERIFY, 74, "STAY_OTP_VERIFY_WRONG_OTP");
        // Enter correct OTP
        otp_correct = 1;
        @(posedge clk); #1; otp_correct = 0;
        check_state(NEW_PIN_SETUP, 75, "NEW_PIN_SETUP_AFTER_CORRECT_OTP");

        // ====================================================
        // TEST GROUP 16: Denomination Selected But Bin Empty
        // Objective: If bin runs dry during selection → CANCELLED
        // ====================================================
        $display("\n--- TEST GROUP 16: Denomination Selected But Bin Empty ---");

        apply_reset; reset_inputs;

        card_inserted = 1; card_has_pin = 1;
        @(posedge clk); #1; card_inserted = 0;
        @(posedge clk); #1; pin_correct = 1;
        @(posedge clk); #1; pin_correct = 0;
        sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
        @(posedge clk); #1;
        sel_savings = 1; amount_entered = 1;
        @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
        amount_entered = 1; @(posedge clk); #1; amount_entered = 0;
        balance_ok = 1; denom_available = 1;
        bin_100_avail = 1; bin_500_avail = 1; bin_2000_avail = 0;
        @(posedge clk); #1;
        // Select Rs.500 but cash_ok = 0 (bin ran out)
        denom_selected = 3'b010; cash_ok = 0;
        @(posedge clk); #1;
        check_state(CANCELLED, 76, "CANCELLED_BIN_EMPTY");
        denom_selected = 3'b000;

        // ====================================================
        // TEST GROUP 17: Randomized Withdrawal Stress Test
        // Objective: Multiple random withdrawal sequences with
        //            random denomination selections
        // ====================================================
        $display("\n--- TEST GROUP 17: Randomized Withdrawal Stress Test ---");

        begin : RANDOM_TEST
            integer i;
            reg [7:0] rand_val;
            reg [2:0] rand_denom;
            for (i = 0; i < 5; i = i + 1) begin
                apply_reset; reset_inputs;

                // Use unsigned 8-bit mask to avoid signed $random giving 0
                rand_val  = ($random & 8'hFF) % 3;
                rand_denom = (rand_val == 0) ? 3'b001 :
                             (rand_val == 1) ? 3'b010 : 3'b100;

                card_inserted = 1; card_has_pin = 1;
                @(posedge clk); #1; card_inserted = 0;
                @(posedge clk); #1; pin_correct = 1;
                @(posedge clk); #1; pin_correct = 0;
                sel_withdraw = 1; @(posedge clk); #1; sel_withdraw = 0;
                @(posedge clk); #1;
                sel_savings = 1; amount_entered = 1;
                @(posedge clk); #1; sel_savings = 0; amount_entered = 0;
                amount_entered = 1; @(posedge clk); #1; amount_entered = 0;
                balance_ok = 1; denom_available = 1;
                bin_100_avail = 1; bin_500_avail = 1; bin_2000_avail = 1;
                @(posedge clk); #1;
                denom_selected = rand_denom; cash_ok = 1;
                @(posedge clk); #1;
                check_state(DISPENSE_CASH, 77+i, "RANDOM_DISPENSE");
                check_output(dispense_cash, 1, 82+i, "RANDOM_DISPENSE_PULSE");
                denom_selected = 0; cash_ok = 0; balance_ok = 0;
                @(posedge clk); #1; // RECEIPT_OPTION
                @(posedge clk); #1; // CARD_EJECT
                @(posedge clk); #1; // COMPLETE
                @(posedge clk); #1; // IDLE
            end
        end

        // ====================================================
        // FINAL SUMMARY
        // ====================================================
        $display("\n============================================================");
        $display("   SIMULATION COMPLETE");
        $display("   TOTAL PASS : %0d", test_pass_count);
        $display("   TOTAL FAIL : %0d", test_fail_count);
        if (test_fail_count == 0)
            $display("   RESULT     : *** ALL TESTS PASSED ***");
        else
            $display("   RESULT     : *** %0d TEST(S) FAILED - REVIEW ABOVE ***",
                     test_fail_count);
        $display("============================================================");

        $finish;
    end

    // --------------------------------------------------------
    // Timeout Watchdog: Prevent infinite simulation hang
    // --------------------------------------------------------
    initial begin
        #500000;
        $display("[TIMEOUT] Simulation exceeded 500us limit - forcing stop");
        $finish;
    end

    // --------------------------------------------------------
    // VCD Dump for waveform viewing in GTKWave / Vivado
    // --------------------------------------------------------
    initial begin
        $dumpfile("atm_controller_tb.vcd");
        $dumpvars(0, atm_controller_tb);
    end

endmodule

