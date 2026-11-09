
`timescale 1ns/1ps

module arbiter_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam int N = 3;
    localparam int LEN_W = 4;
    localparam int TIMEOUT_W = 8;
    localparam int OWNER_W = 2;

    logic clk = 0;

    always #5 clk = ~clk;

    arbiter_if #(
        .N(N),
        .LEN_W(LEN_W),
        .TIMEOUT_W(TIMEOUT_W),
        .OWNER_W(OWNER_W)
    ) bus(clk);

    round_robin_arbiter #(
        .N(N),
        .LEN_W(LEN_W),
        .TIMEOUT_W(TIMEOUT_W),
        .OWNER_W(OWNER_W)
    ) dut(bus);

    initial begin
        $dumpfile("arbiter.vcd");
        $dumpvars(0, arbiter_tb);
    end

    int assertion_passes = 0;
    int assertion_failures = 0;

    int scoreboard_checks = 0;
    int scoreboard_failures = 0;

    int directed_passes = 0;
    int directed_failures = 0;

    // SVA properties

    property p_onehot_grant;
        @(posedge clk)
        disable iff (bus.rst)
        $onehot0(bus.gnt);
    endproperty

    a_onehot_grant:
    assert property (p_onehot_grant)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Multiple grants detected");
    end

    property p_grant_has_request;
        @(posedge clk)
        disable iff (bus.rst)
        !bus.busy |-> ((bus.gnt & ~bus.req) == '0);
    endproperty

    a_grant_has_request:
    assert property (p_grant_has_request)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Grant without request");
    end

    property p_owner_has_grant;
        @(posedge clk)
        disable iff (bus.rst)
        bus.busy |-> (
            (bus.owner < N) && bus.gnt[bus.owner]
        );
    endproperty

    a_owner_has_grant:
    assert property (p_owner_has_grant)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Owner does not have grant");
    end

    property p_timeout_release;
        @(posedge clk)
        disable iff (bus.rst)
        bus.timeout_error |-> !bus.busy;
    endproperty

    a_timeout_release:
    assert property (p_timeout_release)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Timeout failed to release bus");
    end

    property p_done_after_handshake;
        @(posedge clk)
        disable iff (bus.rst)
        bus.done |-> $past(
            bus.busy &&
            bus.transfer_valid &&
            bus.transfer_ready
        );
    endproperty

    a_done_after_handshake:
    assert property (p_done_after_handshake)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Invalid completion pulse");
    end

    property p_owner_stable_during_wait;
        @(posedge clk)
        disable iff (bus.rst)
        (
            bus.busy &&
            bus.transfer_valid &&
            !bus.transfer_ready
        )
        |=>
        (
            bus.timeout_error ||
            (
                bus.busy &&
                $stable(bus.owner)
            )
        );
    endproperty

    a_owner_stable_during_wait:
    assert property (p_owner_stable_during_wait)
    begin
        assertion_passes++;
    end
    else begin
        assertion_failures++;
        $error("Owner changed during wait state");
    end

    // Functional coverage

    covergroup arb_cg;

        option.per_instance = 1;
        option.goal = 100;

        cp_req: coverpoint bus.req {

            bins no_request = {3'b000};
            bins master0 = {3'b001};
            bins master1 = {3'b010};
            bins master2 = {3'b100};

            bins pair01 = {3'b011};
            bins pair02 = {3'b101};
            bins pair12 = {3'b110};

            bins all_masters = {3'b111};

        }

        cp_gnt: coverpoint bus.gnt {

            bins no_grant = {3'b000};
            bins grant0 = {3'b001};
            bins grant1 = {3'b010};
            bins grant2 = {3'b100};

        }

        cp_busy: coverpoint bus.busy {

            bins idle = {0};
            bins active = {1};

        }

        cp_owner: coverpoint bus.owner {

            bins master0 = {0};
            bins master1 = {1};
            bins master2 = {2};

            ignore_bins invalid_owner = {3};

        }

        cp_handshake: coverpoint {
            bus.transfer_valid,
            bus.transfer_ready
        } {

            bins idle = {2'b00};
            bins valid_wait = {2'b10};
            bins accepted = {2'b11};
            bins ready_only = {2'b01};

        }

        cp_lock: coverpoint bus.lock_req {

            bins unlocked = {3'b000};
            bins lock0 = {3'b001};
            bins lock1 = {3'b010};
            bins lock2 = {3'b100};

            bins multiple_locks[] = {
                3'b011,
                3'b101,
                3'b110,
                3'b111
            };

        }

        cp_owner_lock: coverpoint {
            bus.owner,
            bus.lock_req[bus.owner]
        } {

            bins m0_unlocked = {3'b000};
            bins m0_locked = {3'b001};

            bins m1_unlocked = {3'b010};
            bins m1_locked = {3'b011};

            bins m2_unlocked = {3'b100};
            bins m2_locked = {3'b101};

        }

        cp_done: coverpoint bus.done {

            bins completed = {1};
            bins incomplete = {0};

        }

        cp_timeout: coverpoint bus.timeout_error {

            bins timeout = {1};
            bins normal = {0};

        }

        cp_burst0: coverpoint bus.burst_len_flat[3:0] {

            bins zero_length = {0};
            bins single_beat = {1};
            bins short_burst = {[2:3]};
            bins medium_burst = {[4:7]};
            bins long_burst = {[8:15]};

        }

        cp_request_grant: cross cp_req, cp_gnt;

        cp_handshake_busy: cross cp_handshake, cp_busy;

    endgroup

    arb_cg coverage = new();

    // Sample after registered outputs settle

    always @(negedge clk) begin

        #1;

        if (!bus.rst)
            coverage.sample();

    end

    // Burst completion scoreboard

    integer accepted_beats = 0;
    integer expected_len = 0;

    bit expected_done = 0;

    always @(posedge clk) begin

        if (bus.rst) begin

            accepted_beats = 0;
            expected_len = 0;
            expected_done = 0;

        end

        else begin

            // Check completion from the previous cycle

            if (expected_done) begin

                scoreboard_checks++;

                if (bus.done !== 1'b1) begin

                    scoreboard_failures++;

                    $error("Scoreboard: Expected done pulse");

                end

            end

            // Check unexpected completion

            if (bus.done && !expected_done) begin

                scoreboard_failures++;

                $error("Scoreboard: Unexpected done pulse");

            end

            expected_done = 0;

            // Timeout cancels incomplete burst

            if (bus.timeout_error) begin

                accepted_beats = 0;
                expected_len = 0;

            end

            else if (
                bus.busy &&
                bus.transfer_valid &&
                bus.transfer_ready
            ) begin

                if (accepted_beats == 0) begin

                    expected_len = bus.burst_len_flat[
                        bus.owner*LEN_W +: LEN_W
                    ];

                    if (expected_len == 0)
                        expected_len = 1;

                end

                accepted_beats++;

                if (accepted_beats >= expected_len) begin

                    accepted_beats = 0;
                    expected_done = 1;

                end

            end

        end

    end

    // Helper tasks

    task automatic set_burst(
        input integer master,
        input logic [LEN_W-1:0] length
    );

        bus.burst_len_flat[
            master*LEN_W +: LEN_W
        ] = length;

    endtask

    task automatic check_result(
        input bit condition,
        input string test_name
    );

        if (condition) begin

            directed_passes++;

            $display("PASS: %s", test_name);

        end

        else begin

            directed_failures++;

            $error("FAIL: %s", test_name);

        end

    endtask

    task automatic reset_dut;

        @(negedge clk);

        bus.rst = 1'b1;

        bus.req = '0;
        bus.lock_req = '0;

        bus.transfer_valid = 0;
        bus.transfer_ready = 0;

        repeat(2) @(posedge clk);

        #1;

        check_result(
            !bus.busy && bus.gnt == '0,
            "Reset recovery"
        );

        @(negedge clk);

        bus.rst = 1'b0;

    endtask

    task automatic wait_for_owner(
        input integer master,
        input integer max_cycles
    );

        integer elapsed;

        begin

            elapsed = 0;

            while (
                !(bus.busy && bus.owner == master) &&
                elapsed < max_cycles
            ) begin

                @(posedge clk);

                #1;

                elapsed++;

            end

            if (!(bus.busy && bus.owner == master))
                $fatal(1, "Master %0d was not granted", master);

        end

    endtask

    task automatic send_beats(
        input integer count
    );

        begin

            for (integer i = 0; i < count; i++) begin

                @(negedge clk);

                bus.transfer_valid = 1'b1;
                bus.transfer_ready = 1'b1;

                @(posedge clk);

                #1;

            end

            @(negedge clk);

            bus.transfer_valid = 1'b0;

        end

    endtask

    task automatic wait_cycles(
        input integer count
    );

        repeat(count) begin

            @(posedge clk);

            #1;

        end

    endtask

    // Main test sequence

    initial begin

        bus.rst = 1'b1;

        bus.req = '0;
        bus.lock_req = '0;

        bus.burst_len_flat = '0;

        bus.transfer_valid = 0;
        bus.transfer_ready = 0;

        bus.timeout_limit = 8'd3;

        set_burst(0, 4'd1);
        set_burst(1, 4'd1);
        set_burst(2, 4'd1);

        reset_dut();

        // Test 1: Round-robin arbitration

        $display("TEST 1: Round-robin arbitration");

        @(negedge clk);

        bus.req = 3'b111;

        wait_for_owner(0, 10);

        check_result(
            bus.gnt == 3'b001,
            "Master 0 grant"
        );

        send_beats(1);

        wait_for_owner(1, 10);

        check_result(
            bus.gnt == 3'b010,
            "Master 1 grant"
        );

        send_beats(1);

        wait_for_owner(2, 10);

        check_result(
            bus.gnt == 3'b100,
            "Master 2 grant"
        );

        send_beats(1);

        wait_for_owner(0, 10);

        check_result(
            bus.owner == 0,
            "Round-robin pointer wraps"
        );

        send_beats(1);

        @(negedge clk);

        bus.req = 0;

        // Test 2: Burst retention

        $display("TEST 2: Burst handling");

        reset_dut();

        set_burst(1, 4'd3);

        @(negedge clk);

        bus.req = 3'b010;

        wait_for_owner(1, 10);

        send_beats(2);

        check_result(
            bus.busy && !bus.done,
            "Bus retained before final burst beat"
        );

        send_beats(1);

        check_result(
            !bus.busy && bus.done,
            "Burst completion releases bus"
        );

        @(negedge clk);

        bus.req = 0;

        // Test 3: Lock handling

        $display("TEST 3: Lock verification");

        for (integer m = 0; m < N; m++) begin

            reset_dut();

            set_burst(m, 4'd1);

            @(negedge clk);

            bus.req = 3'b001 << m;

            wait_for_owner(m, 10);

            @(negedge clk);

            bus.lock_req = 3'b001 << m;

            send_beats(1);

            check_result(
                bus.busy && bus.owner == m && bus.done,
                $sformatf(
                    "Master %0d retains locked bus",
                    m
                )
            );

            bus.lock_req = 0;

            send_beats(1);

            check_result(
                !bus.busy,
                $sformatf(
                    "Master %0d releases unlocked bus",
                    m
                )
            );

            @(negedge clk);

            bus.req = 0;

        end

        // Test 4: Timeout protection

        $display("TEST 4: Timeout handling");

        reset_dut();

        set_burst(0, 4'd3);

        @(negedge clk);

        bus.req = 3'b001;

        wait_for_owner(0, 10);

        @(negedge clk);

        bus.req = 0;

        bus.transfer_valid = 1;
        bus.transfer_ready = 0;

        wait_cycles(3);

        check_result(
            bus.timeout_error,
            "Timeout error generated"
        );

        check_result(
            !bus.busy && bus.gnt == 0,
            "Bus released after timeout"
        );

        @(negedge clk);

        bus.transfer_valid = 0;
        bus.transfer_ready = 1;

        // Test 5: Timeout counter reset on valid withdrawal

        $display("TEST 5: Timeout counter recovery");

        reset_dut();

        @(negedge clk);

        bus.req = 3'b001;

        wait_for_owner(0, 10);

        @(negedge clk);

        bus.req = 0;
        bus.transfer_valid = 1;
        bus.transfer_ready = 0;

        wait_cycles(1);

        @(negedge clk);

        bus.transfer_valid = 0;

        wait_cycles(1);

        @(negedge clk);

        bus.transfer_valid = 1;

        wait_cycles(2);

        check_result(
            bus.busy && !bus.timeout_error,
            "Timeout counter resets after valid withdrawal"
        );

        wait_cycles(1);

        check_result(
            bus.timeout_error && !bus.busy,
            "Timeout after consecutive stalled cycles"
        );

        @(negedge clk);

        bus.transfer_valid = 0;
        bus.transfer_ready = 1;

        // Test 6: All request combinations

        $display("TEST 6: Request combinations");

        for (integer r = 0; r < 8; r++) begin

            reset_dut();

            @(negedge clk);

            bus.req = r;

            #1;

            check_result(
                $onehot0(bus.gnt) &&
                ((bus.gnt & ~bus.req) == 0),
                $sformatf(
                    "Request combination %b",
                    r[2:0]
                )
            );

        end

        // Test 7: Lock vector coverage

        $display("TEST 7: Lock combinations");

        reset_dut();

        @(negedge clk);

        bus.req = 3'b001;

        wait_for_owner(0, 10);

        for (integer r = 0; r < 8; r++) begin

            @(negedge clk);

            bus.lock_req = r;

        end

        @(negedge clk);

        bus.lock_req = 0;
        bus.req = 0;

        // Test 8: Burst length coverage

        $display("TEST 8: Burst length combinations");

        reset_dut();

        for (integer b = 0; b < 5; b++) begin

            @(negedge clk);

            case (b)

                0: set_burst(0, 4'd0);
                1: set_burst(0, 4'd1);
                2: set_burst(0, 4'd2);
                3: set_burst(0, 4'd4);
                4: set_burst(0, 4'd8);

            endcase

        end

        // Test 9: Reset during active transfer

        $display("TEST 9: Reset during activity");

        reset_dut();

        set_burst(2, 4'd4);

        @(negedge clk);

        bus.req = 3'b100;

        wait_for_owner(2, 10);

        @(negedge clk);

        bus.transfer_valid = 1;
        bus.transfer_ready = 1;

        wait_cycles(1);

        @(negedge clk);

        bus.rst = 1;
        bus.req = 0;

        #1;

        check_result(
            !bus.busy &&
            bus.gnt == 0 &&
            !bus.timeout_error,
            "Asynchronous reset clears arbiter state"
        );

        repeat(2) @(posedge clk);

        @(negedge clk);

        bus.rst = 0;
        bus.transfer_valid = 0;
        bus.transfer_ready = 1;

        // Test 10: Randomized stress testing

        $display("TEST 10: Randomized stress testing");

        reset_dut();

        set_burst(0, 4'd1);
        set_burst(1, 4'd2);
        set_burst(2, 4'd3);

        for (integer i = 0; i < 300; i++) begin

            @(negedge clk);

            bus.req = $urandom_range(0, 7);

            bus.transfer_valid =
                $urandom_range(0, 1);

            bus.transfer_ready =
                $urandom_range(0, 1);

            bus.lock_req = 0;

            @(posedge clk);

            #1;

        end

        @(negedge clk);

        bus.req = 0;
        bus.lock_req = 0;

        bus.transfer_valid = 0;
        bus.transfer_ready = 1;

        wait_cycles(5);

        // Final verification report

        $display("VERIFICATION SUMMARY");

        $display(
            "Directed tests passed = %0d",
            directed_passes
        );

        $display(
            "Directed tests failed = %0d",
            directed_failures
        );

        $display(
            "Assertion passes = %0d",
            assertion_passes
        );

        $display(
            "Assertion failures = %0d",
            assertion_failures
        );

        $display(
            "Scoreboard checks = %0d",
            scoreboard_checks
        );

        $display(
            "Scoreboard failures = %0d",
            scoreboard_failures
        );

        $display(
            "Overall coverage = %0.2f%%",
            coverage.get_coverage()
        );

        $display(
            "Request coverage = %0.2f%%",
            coverage.cp_req.get_coverage()
        );

        $display(
            "Grant coverage = %0.2f%%",
            coverage.cp_gnt.get_coverage()
        );

        $display(
            "Owner coverage = %0.2f%%",
            coverage.cp_owner.get_coverage()
        );

        $display(
            "Handshake coverage = %0.2f%%",
            coverage.cp_handshake.get_coverage()
        );

        $display(
            "Lock coverage = %0.2f%%",
            coverage.cp_lock.get_coverage()
        );

        $display(
            "Owner-lock coverage = %0.2f%%",
            coverage.cp_owner_lock.get_coverage()
        );

        $display(
            "Timeout coverage = %0.2f%%",
            coverage.cp_timeout.get_coverage()
        );

        $display(
            "Burst coverage = %0.2f%%",
            coverage.cp_burst0.get_coverage()
        );

        $display(
            "Request-grant cross = %0.2f%%",
            coverage.cp_request_grant.get_coverage()
        );

        $display(
            "Handshake-busy cross = %0.2f%%",
            coverage.cp_handshake_busy.get_coverage()
        );

        if (
            directed_failures == 0 &&
            assertion_failures == 0 &&
            scoreboard_failures == 0
        )
            $display("VERIFICATION PASSED");

        else
            $display("VERIFICATION FAILED");

        $finish;

    end

endmodule
