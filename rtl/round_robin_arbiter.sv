`include "interface.sv"

module round_robin_arbiter #(
    parameter int N = 3,
    parameter int LEN_W = 4,
    parameter int TIMEOUT_W = 8,
    parameter int OWNER_W = (N > 1) ? $clog2(N) : 1
)(
    arbiter_if.dut bus
);

    logic [OWNER_W-1:0] priority_ptr;

    integer selected;

    logic [LEN_W-1:0] remaining_beats;

    logic [TIMEOUT_W-1:0] timeout_count;

    function automatic integer select_master(
        input logic [N-1:0] requests,
        input integer start_priority
    );

        integer candidate;

        begin

            select_master = -1;

            for (integer i = 0; i < N; i++) begin

                candidate = (start_priority + i) % N;

                if (
                    select_master == -1 &&
                    requests[candidate]
                ) begin

                    select_master = candidate;

                end

            end

        end

    endfunction

    function automatic logic [LEN_W-1:0] get_burst_len(
        input logic [N*LEN_W-1:0] packed_len,
        input integer master_idx
    );

        begin

            get_burst_len =
                packed_len[master_idx*LEN_W +: LEN_W];

        end

    endfunction

    initial begin

        if (N < 1)
            $fatal(1, "N must be at least 1");

        if (LEN_W < 1)
            $fatal(1, "LEN_W must be positive");

        if (TIMEOUT_W < 1)
            $fatal(1, "TIMEOUT_W must be positive");

    end

    // Arbitration selection

    always_comb begin

        selected = -1;

        selected = select_master(
            bus.req,
            priority_ptr
        );

    end

    // Grant generation

    always_comb begin

        bus.gnt = '0;

        if (bus.busy) begin

            if (bus.owner < N)
                bus.gnt[bus.owner] = 1'b1;

        end

        else if (selected != -1) begin

            bus.gnt[selected] = 1'b1;

        end

    end

    // Sequential arbitration and transfer control

    always_ff @(posedge bus.clk or posedge bus.rst) begin

        if (bus.rst) begin

            priority_ptr <= '0;

            bus.owner <= '0;

            bus.busy <= 1'b0;

            remaining_beats <= '0;

            bus.beat_count <= '0;

            timeout_count <= '0;

            bus.done <= 1'b0;

            bus.timeout_error <= 1'b0;

        end

        else begin

            bus.done <= 1'b0;

            bus.timeout_error <= 1'b0;

            if (!bus.busy) begin

                timeout_count <= '0;

                if (selected != -1) begin

                    bus.busy <= 1'b1;

                    bus.owner <= selected;

                    if (selected == N-1)
                        priority_ptr <= '0;
                    else
                        priority_ptr <= selected + 1;

                    if (
                        get_burst_len(
                            bus.burst_len_flat,
                            selected
                        ) == 0
                    )
                        remaining_beats <= 1;

                    else
                        remaining_beats <= get_burst_len(
                            bus.burst_len_flat,
                            selected
                        );

                    bus.beat_count <= '0;

                end

            end

            else begin

                if (
                    bus.transfer_valid &&
                    bus.transfer_ready
                ) begin

                    timeout_count <= '0;

                    if (remaining_beats > 1) begin

                        remaining_beats <=
                            remaining_beats - 1'b1;

                        bus.beat_count <=
                            bus.beat_count + 1'b1;

                    end

                    else begin

                        bus.done <= 1'b1;

                        bus.beat_count <= '0;

                        if (bus.lock_req[bus.owner]) begin

                            if (
                                get_burst_len(
                                    bus.burst_len_flat,
                                    bus.owner
                                ) == 0
                            )
                                remaining_beats <= 1;

                            else
                                remaining_beats <= get_burst_len(
                                    bus.burst_len_flat,
                                    bus.owner
                                );

                        end

                        else begin

                            bus.busy <= 1'b0;

                            remaining_beats <= '0;

                        end

                    end

                end

                else if (
                    bus.transfer_valid &&
                    !bus.transfer_ready
                ) begin

                    if (
                        (bus.timeout_limit == 0) ||
                        (
                            timeout_count >=
                            bus.timeout_limit - 1'b1
                        )
                    ) begin

                        bus.busy <= 1'b0;

                        remaining_beats <= '0;

                        timeout_count <= '0;

                        bus.timeout_error <= 1'b1;

                        bus.beat_count <= '0;

                    end

                    else begin

                        timeout_count <=
                            timeout_count + 1'b1;

                    end

                end

                else begin

                    timeout_count <= '0;

                end

            end

        end

    end

endmodule
