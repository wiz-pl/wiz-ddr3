// D3c: the memory test's core (the controller, the PHY's 7-series cells, the test and
// its UART) against Micron's DDR3 model, in Icarus Verilog. Local use only: Micron's
// model may not be redistributed (micron/, git-ignored); the cells are Xilinx's unisims
// (Apache-2.0), fetched by `ddr3 vsim`.
//
// The clocks a PLL would make: 100 MHz, 400 MHz, 400 MHz at 90°, 200 MHz, edges aligned.
// The UART's bytes are printed as they arrive; the run stops after `PASSES` pass reports.
`timescale 1ps / 1ps
module tb;
  reg clk = 0, sys4x = 0, sys4xDqs = 0, ref200 = 0;
  always #5000 clk = ~clk;
  always #1250 sys4x = ~sys4x;
  initial begin #625; forever #1250 sys4xDqs = ~sys4xDqs; end
  always #2500 ref200 = ~ref200;
  reg locked = 0;
  initial #200000 locked = 1;

  wire ck_p, ck_n, reset_n, cs_n, cke, odt, ras_n, cas_n, we_n;
  wire [2:0] ba;
  wire [13:0] a;
  wire [1:0] dm;
  wire [15:0] dq;
  wire [1:0] dqs_p, dqs_n;
  wire uart_tx;
  wire [3:0] led;

  memtest dut (.clk(clk), .sys4x(sys4x), .sys4xDqs(sys4xDqs), .ref200(ref200), .locked(locked), .uart_rx(1'b1),
    .ddr3_ck_p(ck_p), .ddr3_ck_n(ck_n), .ddr3_reset_n(reset_n), .ddr3_cs_n(cs_n), .ddr3_cke(cke), .ddr3_odt(odt),
    .ddr3_ras_n(ras_n), .ddr3_cas_n(cas_n), .ddr3_we_n(we_n),
    .ddr3_ba_0(ba[0]), .ddr3_ba_1(ba[1]), .ddr3_ba_2(ba[2]),
    .ddr3_a_0(a[0]), .ddr3_a_1(a[1]), .ddr3_a_2(a[2]), .ddr3_a_3(a[3]), .ddr3_a_4(a[4]), .ddr3_a_5(a[5]), .ddr3_a_6(a[6]),
    .ddr3_a_7(a[7]), .ddr3_a_8(a[8]), .ddr3_a_9(a[9]), .ddr3_a_10(a[10]), .ddr3_a_11(a[11]), .ddr3_a_12(a[12]), .ddr3_a_13(a[13]),
    .ddr3_dm_0(dm[0]), .ddr3_dm_1(dm[1]),
    .ddr3_dq_0(dq[0]), .ddr3_dq_1(dq[1]), .ddr3_dq_2(dq[2]), .ddr3_dq_3(dq[3]), .ddr3_dq_4(dq[4]), .ddr3_dq_5(dq[5]),
    .ddr3_dq_6(dq[6]), .ddr3_dq_7(dq[7]), .ddr3_dq_8(dq[8]), .ddr3_dq_9(dq[9]), .ddr3_dq_10(dq[10]), .ddr3_dq_11(dq[11]),
    .ddr3_dq_12(dq[12]), .ddr3_dq_13(dq[13]), .ddr3_dq_14(dq[14]), .ddr3_dq_15(dq[15]),
    .ddr3_dqs_p0(dqs_p[0]), .ddr3_dqs_n0(dqs_n[0]), .ddr3_dqs_p1(dqs_p[1]), .ddr3_dqs_n1(dqs_n[1]),
    .uart_tx(uart_tx), .led(led));

  ddr3 mem (.rst_n(reset_n), .ck(ck_p), .ck_n(ck_n), .cke(cke), .cs_n(cs_n), .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
    .dm_tdqs(dm), .ba(ba), .addr(a), .dq(dq), .dqs(dqs_p), .dqs_n(dqs_n), .tdqs_n(), .odt(odt));

  // the UART, `BIT` clock cycles per bit
  parameter BIT = 16;
  parameter PASSES = 3;
  integer i, lines = 0;
  reg [7:0] c;
  initial begin
    forever begin
      @(negedge uart_tx);
      repeat (BIT / 2) @(posedge clk);
      c = 0;
      for (i = 0; i < 8; i = i + 1) begin
        repeat (BIT) @(posedge clk);
        c[i] = uart_tx;
      end
      repeat (BIT) @(posedge clk);
      $write("%c", c);
      if (c == 8'h50) lines = lines + 1;    // 'P': a pass report
      if (c == 8'h0a && lines == PASSES) $finish;
    end
  end
  initial begin #400000000000; $display("TIMEOUT"); $finish; end
endmodule
