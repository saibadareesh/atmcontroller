`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.06.2026 11:56:59
// Design Name: 
// Module Name: atm_controller
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
// ATM Machine Controller - Verilog FSM
// ============================================================
// File        : atm_controller.v
// Description : Complete ATM controller modeled as a Moore FSM.
//               Handles cash withdrawal, new PIN setup, PIN reset,
//               balance inquiry, mini statement, and all error/cancel
//               paths as specified in the assignment.
//

// ============================================================

module atm_controller (
    // -----------------------------------------------------------
    // Clock and Reset
    // -----------------------------------------------------------
    input  wire        clk,          // 100 MHz system clock (ZedBoard)
    input  wire        rst_n,        // Active-low synchronous reset

    // -----------------------------------------------------------
    // Card Interface
    // -----------------------------------------------------------
    input  wire        card_inserted,    // HIGH when card is physically inserted
    input  wire        card_has_pin,     // HIGH if card already has a PIN configured
    input  wire        cancel,           // Cancel button - aborts transaction at any stage

    // -----------------------------------------------------------
    // PIN / OTP / Account Verification
    // -----------------------------------------------------------
    input  wire        pin_correct,      // HIGH when entered PIN matches stored PIN
    input  wire        otp_correct,      // HIGH when entered OTP matches sent OTP
    input  wire        acct_digits_ok,   // HIGH when last-4-digits of account match

    // -----------------------------------------------------------
    // Transaction Menu Selection
    // -----------------------------------------------------------
    input  wire        sel_withdraw,     // User selected Withdraw from menu
    input  wire        sel_balance,      // User selected Balance Inquiry
    input  wire        sel_mini_stmt,    // User selected Mini Statement
    input  wire        sel_pin_change,   // User selected Change/Reset PIN
    input  wire        sel_savings,      // User selected Savings account type
    // sel_current is implied by NOT sel_savings when in ACCOUNT_TYPE_SELECT

    // -----------------------------------------------------------
    // Amount and Denomination
    // -----------------------------------------------------------
    input  wire        amount_entered,   // HIGH when user finishes entering amount
    input  wire        balance_ok,       // HIGH when account balance >= withdrawal amount
    input  wire        denom_available,  // HIGH when at least one valid denomination exists
    //   for the entered amount and non-empty bins
    input  wire [2:0]  denom_selected,   // Which denomination user picked:
    //   bit2=Rs.2000, bit1=Rs.500, bit0=Rs.100
    input  wire        cash_ok,          // HIGH when ATM bin has enough notes for selection

    // -----------------------------------------------------------
    // Cash Bin Status (for dynamic denomination display)
    // -----------------------------------------------------------
    input  wire        bin_100_avail,    // Rs.100 bin is non-empty
    input  wire        bin_500_avail,    // Rs.500 bin is non-empty
    input  wire        bin_2000_avail,   // Rs.2000 bin is non-empty

    // -----------------------------------------------------------
    // Receipt
    // -----------------------------------------------------------
    input  wire        receipt_requested,// HIGH if user wants a receipt
    input  wire        new_pin_confirmed,// HIGH when new PIN re-entry matches first entry
    input  wire        hardware_error,   // HIGH when any hardware fault is detected

    // -----------------------------------------------------------
    // Outputs - ATM Actions
    // -----------------------------------------------------------
    output reg         dispense_cash,    // Pulse to dispense cash to user
    output reg         print_receipt,    // Pulse to print receipt
    output reg         eject_card,       // Pulse to eject card
    output reg         update_balance,   // Pulse to update account balance in backend
    output reg         send_otp,         // Pulse to send OTP to registered mobile
    output reg         store_new_pin,    // Pulse to commit new PIN to storage
    output reg         block_card,       // Pulse to permanently block card

    // -----------------------------------------------------------
    // Outputs - Display / Status Signals (for LEDs / display logic)
    // -----------------------------------------------------------
    output reg [4:0]   state_out,        // Current FSM state (for debug/display)
    output reg         show_denom_100,   // Show Rs.100 as selectable denomination
    output reg         show_denom_500,   // Show Rs.500 as selectable denomination
    output reg         show_denom_2000,  // Show Rs.2000 as selectable denomination
    output reg         msg_wrong_pin,    // Display "Wrong PIN" message
    output reg         msg_blocked,      // Display "Card Blocked" message
    output reg         msg_insuff_bal,   // Display "Insufficient Balance" message
    output reg         msg_no_denom,     // Display "No Valid Denomination" message
    output reg         msg_cancelled,    // Display "Transaction Cancelled" message
    output reg         msg_complete,     // Display "Transaction Complete" message
    output reg         msg_error,        // Display "Hardware Error" message
    output reg         msg_enter_pin,    // Prompt: Enter PIN
    output reg         msg_enter_otp,    // Prompt: Enter OTP
    output reg         msg_set_pin,      // Prompt: Set New PIN
    output reg         msg_confirm_pin   // Prompt: Confirm New PIN
);

    // ===========================================================
    // STATE ENCODING
    // ===========================================================
    // One-hot encoding is NOT used here to keep code readable.
    // Binary encoding keeps the state register compact.
    // State names match specification exactly for viva clarity.
    // ===========================================================
    localparam [4:0]
        IDLE               = 5'd0,
        CARD_INSERTED      = 5'd1,
        PIN_ENTRY          = 5'd2,
        ACCOUNT_VERIFY     = 5'd3,   // Verify last-4-digits for new/reset PIN flow
        TRANSACTION_MENU   = 5'd4,
        WITHDRAW           = 5'd5,   // User confirmed withdraw - gateway state
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

    // ===========================================================
    // INTERNAL REGISTERS
    // ===========================================================
    reg [4:0]  current_state, next_state;   // FSM state registers
    reg [1:0]  pin_attempt_cnt;             // Counts wrong PIN tries (max 3)
    reg        is_new_pin_flow;             // Distinguishes new-PIN vs PIN-reset path
    //   so OTP_VERIFY knows where to return

    // ===========================================================
    // SEQUENTIAL BLOCK - State Register Update
    // ===========================================================
    // All flip-flops are clocked here. On reset, go to IDLE.
    // pin_attempt_cnt is also reset here.
    // ===========================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            current_state   <= IDLE;
            pin_attempt_cnt <= 2'd0;
            is_new_pin_flow <= 1'b0;
        end else begin
            current_state <= next_state;

            // -------------------------------------------------------
            // PIN attempt counter logic:
            // Increment on each wrong PIN; reset to 0 on correct PIN
            // or when FSM leaves PIN_ENTRY for a non-BLOCKED state.
            // -------------------------------------------------------
            if (current_state == PIN_ENTRY) begin
                if (pin_correct)
                    pin_attempt_cnt <= 2'd0;           // correct PIN, clear counter
                else if (!pin_correct && !cancel)
                    pin_attempt_cnt <= pin_attempt_cnt + 1'b1; // count wrong attempt
            end else if (current_state == IDLE) begin
                pin_attempt_cnt <= 2'd0;               // fresh card, fresh count
            end

            // -------------------------------------------------------
            // Track which PIN-management flow we are in so that
            // after OTP verification we go to the right place.
            // -------------------------------------------------------
            if (current_state == CARD_INSERTED && !card_has_pin)
                is_new_pin_flow <= 1'b1;   // fresh card → new PIN setup
            else if (current_state == TRANSACTION_MENU && sel_pin_change)
                is_new_pin_flow <= 1'b0;   // existing card PIN change
            else if (current_state == IDLE)
                is_new_pin_flow <= 1'b0;
        end
    end

    // ===========================================================
    // COMBINATIONAL BLOCK - Next State Logic
    // ===========================================================
    // Pure combinational: determines next_state from current_state
    // and all input signals. No registers updated here.
    // ===========================================================
    always @(*) begin
        // Default: stay in current state (safe fallback)
        next_state = current_state;

        case (current_state)

            // ---------------------------------------------------
            // IDLE: ATM is waiting for a card to be inserted.
            // ---------------------------------------------------
            IDLE: begin
                if (card_inserted)
                    next_state = CARD_INSERTED;
                // If hardware error even at idle, flag it
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // CARD_INSERTED: Detect whether card has a PIN.
            // Fresh card → go directly to account verification
            // for new PIN setup (Scenario 2).
            // Existing card → go to PIN entry (Scenario 1/3).
            // ---------------------------------------------------
            CARD_INSERTED: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (!card_has_pin)
                    next_state = ACCOUNT_VERIFY;   // fresh card: verify account first
                else
                    next_state = PIN_ENTRY;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // PIN_ENTRY: User types their PIN.
            // 3 wrong attempts → BLOCKED.
            // Correct PIN → TRANSACTION_MENU.
            // Cancel → CARD_EJECT.
            // ---------------------------------------------------
            PIN_ENTRY: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (pin_correct)
                    next_state = TRANSACTION_MENU;
                else if (pin_attempt_cnt == 2'd2 && !pin_correct)
                    // Third failed attempt (cnt was 2 before this clock)
                    next_state = BLOCKED;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // ACCOUNT_VERIFY: User enters last-4-digits of account.
            // Used in both Scenario 2 (new PIN) and Scenario 3
            // (PIN reset). After correct digits → send OTP.
            // ---------------------------------------------------
            ACCOUNT_VERIFY: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (acct_digits_ok) begin
                    next_state = OTP_VERIFY;   // send OTP and wait for entry
                end
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // TRANSACTION_MENU: User selects what to do.
            // ---------------------------------------------------
            TRANSACTION_MENU: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (sel_withdraw)
                    next_state = WITHDRAW;
                else if (sel_balance)
                    next_state = BALANCE_INQUIRY;
                else if (sel_mini_stmt)
                    next_state = MINI_STATEMENT;
                else if (sel_pin_change)
                    next_state = PIN_RESET;    // existing card PIN change flow
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // WITHDRAW: Gateway state confirming withdraw selected.
            // Immediately proceeds to account type selection.
            // Kept separate to match specification state list.
            // ---------------------------------------------------
            WITHDRAW: begin
                if (cancel)
                    next_state = CANCELLED;
                else
                    next_state = ACCOUNT_TYPE_SELECT;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // ACCOUNT_TYPE_SELECT: Savings or Current account.
            // ---------------------------------------------------
            ACCOUNT_TYPE_SELECT: begin
                if (cancel)
                    next_state = CANCELLED;
                else if (sel_savings || (!sel_savings && amount_entered))
                    // Any account type selection moves to amount entry
                    next_state = AMOUNT_ENTRY;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // AMOUNT_ENTRY: User enters withdrawal amount.
            // ---------------------------------------------------
            AMOUNT_ENTRY: begin
                if (cancel)
                    next_state = CANCELLED;
                else if (amount_entered)
                    next_state = CHECK_BALANCE;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // CHECK_BALANCE: ATM verifies:
            //  (a) account has sufficient balance, AND
            //  (b) ATM bins can satisfy the amount with available
            //      denominations.
            // If both OK → DENOMINATION_SELECT.
            // If balance fails → CANCELLED (with insuff_bal msg).
            // If no denomination possible → CANCELLED (no_denom).
            // ---------------------------------------------------
            CHECK_BALANCE: begin
                if (cancel)
                    next_state = CANCELLED;
                else if (balance_ok && denom_available)
                    next_state = DENOMINATION_SELECT;
                else
                    next_state = CANCELLED;   // Fail handled via output signals
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // DENOMINATION_SELECT: Show only valid denominations.
            // User picks one; ATM then verifies bin has enough notes.
            // ---------------------------------------------------
            DENOMINATION_SELECT: begin
                if (cancel)
                    next_state = CANCELLED;
                else if (|denom_selected && cash_ok)
                    next_state = DISPENSE_CASH;
                else if (|denom_selected && !cash_ok)
                    next_state = CANCELLED;   // selected denom but bin ran out
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // DISPENSE_CASH: ATM physically releases cash.
            // After dispensing → RECEIPT_OPTION.
            // ---------------------------------------------------
            DISPENSE_CASH: begin
                if (hardware_error)
                    next_state = ERROR;
                else
                    next_state = RECEIPT_OPTION;
            end

            // ---------------------------------------------------
            // RECEIPT_OPTION: Ask user if they want a receipt.
            // Either way → CARD_EJECT → COMPLETE.
            // ---------------------------------------------------
            RECEIPT_OPTION: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (receipt_requested)
                    next_state = CARD_EJECT;   // print is done via output pulse
                else
                    next_state = CARD_EJECT;
            end

            // ---------------------------------------------------
            // BALANCE_INQUIRY: Display balance, optional receipt.
            // ---------------------------------------------------
            BALANCE_INQUIRY: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else
                    next_state = RECEIPT_OPTION;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // MINI_STATEMENT: Print last 5 transactions.
            // ---------------------------------------------------
            MINI_STATEMENT: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else
                    next_state = CARD_EJECT;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // NEW_PIN_SETUP: Fresh card. OTP verified. Set new PIN.
            // After OTP_VERIFY returns here, prompt for new PIN.
            // ---------------------------------------------------
            NEW_PIN_SETUP: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else
                    next_state = PIN_CONFIRM;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // PIN_RESET: Existing card PIN change. Asks for last-4
            // account digits, then OTP. Reuses ACCOUNT_VERIFY and
            // OTP_VERIFY states.
            // ---------------------------------------------------
            PIN_RESET: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else
                    next_state = ACCOUNT_VERIFY;
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // OTP_VERIFY: Wait for user to enter OTP.
            // On correct OTP: go to NEW_PIN_SETUP (fresh card) or
            // PIN_CONFIRM (existing card reset), determined by
            // is_new_pin_flow register.
            // On wrong OTP: stay (user re-enters) or cancel.
            // ---------------------------------------------------
            OTP_VERIFY: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (otp_correct) begin
                    if (is_new_pin_flow)
                        next_state = NEW_PIN_SETUP;
                    else
                        next_state = PIN_CONFIRM;
                end
                // Wrong OTP: stay in OTP_VERIFY for retry
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // PIN_CONFIRM: User re-enters new PIN to confirm.
            // On match → save PIN → CARD_EJECT.
            // On mismatch → stay for re-entry.
            // ---------------------------------------------------
            PIN_CONFIRM: begin
                if (cancel)
                    next_state = CARD_EJECT;
                else if (new_pin_confirmed)
                    next_state = CARD_EJECT;
                // Mismatch: stay in PIN_CONFIRM
                if (hardware_error)
                    next_state = ERROR;
            end

            // ---------------------------------------------------
            // CARD_EJECT: Physically eject card, then COMPLETE.
            // ---------------------------------------------------
            CARD_EJECT: begin
                next_state = COMPLETE;
            end

            // ---------------------------------------------------
            // COMPLETE: Transaction done. Wait briefly, then IDLE.
            // (In real design, a timer would hold here one cycle.)
            // ---------------------------------------------------
            COMPLETE: begin
                next_state = IDLE;
            end

            // ---------------------------------------------------
            // CANCELLED: Safe abort. Eject card, show message.
            // ---------------------------------------------------
            CANCELLED: begin
                next_state = CARD_EJECT;
            end

            // ---------------------------------------------------
            // BLOCKED: Card permanently blocked after 3 wrong PINs.
            // Card is ejected (blocked, not swallowed in this model).
            // ---------------------------------------------------
            BLOCKED: begin
                next_state = CARD_EJECT;
            end

            // ---------------------------------------------------
            // ERROR: Hardware error detected. Safe state.
            // Eject card and return to IDLE after one cycle.
            // ---------------------------------------------------
            ERROR: begin
                next_state = CARD_EJECT;
            end

            // ---------------------------------------------------
            // Default: catch any undefined state → IDLE (safe)
            // ---------------------------------------------------
            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // ===========================================================
    // COMBINATIONAL BLOCK - Output Logic (Moore outputs)
    // ===========================================================
    // All outputs are derived purely from current_state.
    // This is a Moore FSM: outputs depend only on state.
    // All outputs have safe defaults (0) at the top of the block
    // to prevent latch inference.
    // ===========================================================
    always @(*) begin
        // ---------------------------------------------------------
        // SAFE DEFAULTS: every output = 0 unless explicitly driven.
        // This is mandatory to avoid latch inference in synthesis.
        // ---------------------------------------------------------
        dispense_cash    = 1'b0;
        print_receipt    = 1'b0;
        eject_card       = 1'b0;
        update_balance   = 1'b0;
        send_otp         = 1'b0;
        store_new_pin    = 1'b0;
        block_card       = 1'b0;

        show_denom_100   = 1'b0;
        show_denom_500   = 1'b0;
        show_denom_2000  = 1'b0;

        msg_wrong_pin    = 1'b0;
        msg_blocked      = 1'b0;
        msg_insuff_bal   = 1'b0;
        msg_no_denom     = 1'b0;
        msg_cancelled    = 1'b0;
        msg_complete     = 1'b0;
        msg_error        = 1'b0;
        msg_enter_pin    = 1'b0;
        msg_enter_otp    = 1'b0;
        msg_set_pin      = 1'b0;
        msg_confirm_pin  = 1'b0;

        state_out        = current_state;

        case (current_state)

            IDLE: begin
                // Nothing active; waiting for card insertion
            end

            CARD_INSERTED: begin
                // Card detected; ATM decides next flow (handled in next-state logic)
            end

            PIN_ENTRY: begin
                msg_enter_pin = 1'b1;   // Prompt user to enter PIN
                // Show wrong PIN message if last attempt was wrong
                // (pin_attempt_cnt > 0 means at least one wrong attempt)
                if (pin_attempt_cnt > 2'd0)
                    msg_wrong_pin = 1'b1;
            end

            ACCOUNT_VERIFY: begin
                // Prompt user to enter last 4 digits of account number
                // (display message handled by external display controller)
            end

            TRANSACTION_MENU: begin
                // Display transaction options; no output pulses needed here
            end

            WITHDRAW: begin
                // Brief gateway state; no physical action yet
            end

            ACCOUNT_TYPE_SELECT: begin
                // Prompt: Savings or Current?
            end

            AMOUNT_ENTRY: begin
                // Prompt: Enter amount
            end

            CHECK_BALANCE: begin
                // Show insufficient balance or no denomination messages
                // depending on what caused failure (visible next clock)
                if (!balance_ok)
                    msg_insuff_bal = 1'b1;
                else if (!denom_available)
                    msg_no_denom = 1'b1;
            end

            DENOMINATION_SELECT: begin
                // Dynamically display only available and usable denominations.
                // This implements requirement 7 from Scenario 1.
                show_denom_100  = bin_100_avail;
                show_denom_500  = bin_500_avail;
                show_denom_2000 = bin_2000_avail;
            end

            DISPENSE_CASH: begin
                // Trigger the mechanical cash dispenser
                dispense_cash  = 1'b1;
                // Update account balance in backend simultaneously
                update_balance = 1'b1;
            end

            RECEIPT_OPTION: begin
                // Print receipt only if user requested it
                if (receipt_requested)
                    print_receipt = 1'b1;
            end

            BALANCE_INQUIRY: begin
                // Balance is displayed; receipt if requested
                if (receipt_requested)
                    print_receipt = 1'b1;
            end

            MINI_STATEMENT: begin
                // Trigger printing of last 5 transactions
                print_receipt = 1'b1;
            end

            NEW_PIN_SETUP: begin
                msg_set_pin = 1'b1;   // Prompt: Enter new PIN
            end

            PIN_RESET: begin
                // Gateway state for existing-card PIN change
            end

            OTP_VERIFY: begin
                // Send OTP to registered mobile as soon as we enter this state
                send_otp      = 1'b1;
                msg_enter_otp = 1'b1;  // Prompt: Enter OTP
            end

            PIN_CONFIRM: begin
                msg_confirm_pin = 1'b1;  // Prompt: Confirm new PIN
                // Commit new PIN when user confirms successfully
                if (new_pin_confirmed)
                    store_new_pin = 1'b1;
            end

            CARD_EJECT: begin
                eject_card = 1'b1;  // Physically eject card
            end

            COMPLETE: begin
                msg_complete = 1'b1;  // Show success message
            end

            CANCELLED: begin
                msg_cancelled = 1'b1;  // Inform user of cancellation
                // Preserve the specific failure reason so the display controller
                // can show the correct message while in CANCELLED state.
                // These mirror what CHECK_BALANCE set on the previous clock.
                if (!balance_ok)
                    msg_insuff_bal = 1'b1;
                else if (!denom_available)
                    msg_no_denom = 1'b1;
            end

            BLOCKED: begin
                // Block card permanently and inform user
                block_card  = 1'b1;
                msg_blocked = 1'b1;
            end

            ERROR: begin
                msg_error = 1'b1;  // Hardware error message
            end

            default: begin
                // Should never reach here; all outputs remain 0 (safe)
            end

        endcase
    end

endmodule

