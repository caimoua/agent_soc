`timescale 1ns/1ps

module rv32i_pipe_ctrl_tb;

  logic commit_redirect;
  logic ex_redirect;
  logic mem_stall;
  logic ex_muldiv_stall;
  logic load_use_stall;
  logic if_stall;
  logic if_discard;

  wire commit_flush;
  wire front_advance;
  wire if_discard_flush;
  wire if_redirect_flush;
  wire if_normal_load;
  wire id_ex_advance;
  wire id_ex_bubble;
  wire ex_mem_advance;
  wire ex_mem_bubble;
  wire perf_stall_event;
  wire perf_flush_event;

  task automatic clear_inputs;
    begin
      commit_redirect = 1'b0;
      ex_redirect = 1'b0;
      mem_stall = 1'b0;
      ex_muldiv_stall = 1'b0;
      load_use_stall = 1'b0;
      if_stall = 1'b0;
      if_discard = 1'b0;
    end
  endtask

  task automatic check_bit(
    input logic actual,
    input logic expected,
    input string name
  );
    begin
      #1ps;
      if (actual !== expected) begin
        $fatal(1, "%s mismatch: expected %0d, got %0d",
               name, expected, actual);
      end
    end
  endtask

  task automatic check_outputs(
    input bit exp_commit_flush,
    input bit exp_front_advance,
    input bit exp_if_discard_flush,
    input bit exp_if_redirect_flush,
    input bit exp_if_normal_load,
    input bit exp_id_ex_advance,
    input bit exp_id_ex_bubble,
    input bit exp_ex_mem_advance,
    input bit exp_ex_mem_bubble,
    input bit exp_perf_stall_event,
    input bit exp_perf_flush_event,
    input string case_name
  );
    begin
      check_bit(commit_flush, exp_commit_flush,
                {case_name, ".commit_flush"});
      check_bit(front_advance, exp_front_advance,
                {case_name, ".front_advance"});
      check_bit(if_discard_flush, exp_if_discard_flush,
                {case_name, ".if_discard_flush"});
      check_bit(if_redirect_flush, exp_if_redirect_flush,
                {case_name, ".if_redirect_flush"});
      check_bit(if_normal_load, exp_if_normal_load,
                {case_name, ".if_normal_load"});
      check_bit(id_ex_advance, exp_id_ex_advance,
                {case_name, ".id_ex_advance"});
      check_bit(id_ex_bubble, exp_id_ex_bubble,
                {case_name, ".id_ex_bubble"});
      check_bit(ex_mem_advance, exp_ex_mem_advance,
                {case_name, ".ex_mem_advance"});
      check_bit(ex_mem_bubble, exp_ex_mem_bubble,
                {case_name, ".ex_mem_bubble"});
      check_bit(perf_stall_event, exp_perf_stall_event,
                {case_name, ".perf_stall_event"});
      check_bit(perf_flush_event, exp_perf_flush_event,
                {case_name, ".perf_flush_event"});
    end
  endtask

  rv32i_pipe_ctrl u_pipe_ctrl (
    .commit_redirect  (commit_redirect),
    .ex_redirect      (ex_redirect),
    .mem_stall        (mem_stall),
    .ex_muldiv_stall  (ex_muldiv_stall),
    .load_use_stall   (load_use_stall),
    .if_stall         (if_stall),
    .if_discard       (if_discard),
    .commit_flush     (commit_flush),
    .front_advance    (front_advance),
    .if_discard_flush (if_discard_flush),
    .if_redirect_flush(if_redirect_flush),
    .if_normal_load   (if_normal_load),
    .id_ex_advance    (id_ex_advance),
    .id_ex_bubble     (id_ex_bubble),
    .ex_mem_advance   (ex_mem_advance),
    .ex_mem_bubble    (ex_mem_bubble),
    .perf_stall_event (perf_stall_event),
    .perf_flush_event (perf_flush_event)
  );

  initial begin
    clear_inputs();
    check_outputs(1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1,
                  1'b0, 1'b1, 1'b0, 1'b0, 1'b0, "normal");

    clear_inputs();
    load_use_stall = 1'b1;
    check_outputs(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                  1'b1, 1'b1, 1'b0, 1'b1, 1'b0, "load_use");

    clear_inputs();
    if_stall = 1'b1;
    check_outputs(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1,
                  1'b1, 1'b1, 1'b0, 1'b1, 1'b0, "if_stall");

    clear_inputs();
    if_discard = 1'b1;
    check_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1,
                  1'b1, 1'b1, 1'b0, 1'b1, 1'b0, "if_discard");

    clear_inputs();
    ex_redirect = 1'b1;
    check_outputs(1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1,
                  1'b1, 1'b1, 1'b0, 1'b0, 1'b1, "ex_redirect");

    clear_inputs();
    if_discard = 1'b1;
    ex_redirect = 1'b1;
    check_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1,
                  1'b1, 1'b1, 1'b0, 1'b1, 1'b1,
                  "discard_priority_over_ex_redirect");

    clear_inputs();
    mem_stall = 1'b1;
    ex_redirect = 1'b1;
    check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                  1'b0, 1'b0, 1'b0, 1'b1, 1'b0, "mem_stall");

    clear_inputs();
    ex_muldiv_stall = 1'b1;
    check_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                  1'b0, 1'b1, 1'b1, 1'b1, 1'b0, "muldiv_stall");

    clear_inputs();
    commit_redirect = 1'b1;
    ex_redirect = 1'b1;
    load_use_stall = 1'b1;
    check_outputs(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                  1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
                  "commit_redirect_priority");

    $display("[PASS] rv32i_pipe_ctrl_tb");
    $display("  pipeline control priority cases passed");
    $display("  commit redirect, mem stall, muldiv stall, load-use,");
    $display("  fetch discard and EX redirect controls matched core behavior");
    $finish;
  end

endmodule
