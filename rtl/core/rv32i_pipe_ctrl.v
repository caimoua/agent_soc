module rv32i_pipe_ctrl (
  input  wire commit_redirect,
  input  wire ex_redirect,
  input  wire mem_stall,
  input  wire ex_muldiv_stall,
  input  wire load_use_stall,
  input  wire if_stall,
  input  wire if_discard,

  output wire commit_flush,
  output wire front_advance,
  output wire if_discard_flush,
  output wire if_redirect_flush,
  output wire if_normal_load,
  output wire id_ex_advance,
  output wire id_ex_bubble,
  output wire ex_mem_advance,
  output wire ex_mem_bubble,
  output wire perf_stall_event,
  output wire perf_flush_event
);

  assign commit_flush = commit_redirect;

  assign front_advance = !commit_redirect &&
                         !mem_stall &&
                         !ex_muldiv_stall;
  assign if_discard_flush = front_advance &&
                            if_discard;
  assign if_redirect_flush = front_advance &&
                             !if_discard &&
                             ex_redirect;
  assign if_normal_load = front_advance &&
                          !if_discard &&
                          !ex_redirect &&
                          !load_use_stall &&
                          !if_stall;

  assign id_ex_advance = front_advance;
  assign id_ex_bubble = id_ex_advance &&
                        (ex_redirect ||
                         load_use_stall ||
                         if_stall ||
                         if_discard);

  assign ex_mem_advance = !commit_redirect &&
                          !mem_stall;
  assign ex_mem_bubble = ex_mem_advance &&
                         ex_muldiv_stall;

  assign perf_stall_event = load_use_stall ||
                            mem_stall ||
                            ex_muldiv_stall ||
                            if_stall ||
                            if_discard;
  assign perf_flush_event = ex_redirect &&
                            !mem_stall &&
                            !commit_redirect;

endmodule
