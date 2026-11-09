
interface arbiter_if #(
    parameter int N = 3,
    parameter int LEN_W = 4,
    parameter int TIMEOUT_W = 8,
    parameter int OWNER_W = (N > 1) ? $clog2(N) : 1
)(
    input logic clk
);

    logic rst;

    logic [N-1:0] req;
    logic [N-1:0] lock_req;

    logic [N*LEN_W-1:0] burst_len_flat;

    logic transfer_valid;
    logic transfer_ready;

    logic [TIMEOUT_W-1:0] timeout_limit;

    logic [N-1:0] gnt;

    logic busy;

    logic [OWNER_W-1:0] owner;

    logic [LEN_W-1:0] beat_count;

    logic done;
    logic timeout_error;

    modport dut (
        input clk,
        input rst,
        input req,
        input lock_req,
        input burst_len_flat,
        input transfer_valid,
        input transfer_ready,
        input timeout_limit,

        output gnt,
        output busy,
        output owner,
        output beat_count,
        output done,
        output timeout_error
    );

endinterface
