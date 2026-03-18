`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,   // Steuerung: P1/P2 Tasten
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // VGA Signale
  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;
  wire [1:0] R, G, B;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  localparam H = 480;
  localparam W = 640;
  localparam PADDLE_H = 40;
  localparam PADDLE_W = 8;
  localparam BALL_SIZE = 4;

  reg [9:0] paddle1_y = H/2 - PADDLE_H/2;
  reg [9:0] paddle2_y = H/2 - PADDLE_H/2;
  reg [9:0] ball_x = W/2;
  reg [9:0] ball_y = H/2;
  reg signed [9:0] ball_dx = 2;
  reg signed [9:0] ball_dy = 1;

  reg [9:0] new_ball_x;
  reg [9:0] new_ball_y;

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      paddle1_y <= H/2 - PADDLE_H/2;
      paddle2_y <= H/2 - PADDLE_H/2;
      ball_x <= W/2;
      ball_y <= H/2;
      ball_dx <= 2;
      ball_dy <= 1;
    end else begin
      // Paddle Bewegung
      if (ui_in[0] && paddle1_y>0)          paddle1_y <= paddle1_y - 4;
      if (ui_in[1] && paddle1_y<H-PADDLE_H) paddle1_y <= paddle1_y + 4;
      if (ui_in[2] && paddle2_y>0)          paddle2_y <= paddle2_y - 4;
      if (ui_in[3] && paddle2_y<H-PADDLE_H) paddle2_y <= paddle2_y + 4;

      // Ballbewegung
      new_ball_x = ball_x + ball_dx;
      new_ball_y = ball_y + ball_dy;

      // Kollision top/bottom
      if (new_ball_y <= 0) begin
        new_ball_y = 0;
        ball_dy <= -ball_dy;
      end
      if (new_ball_y >= H-BALL_SIZE) begin
        new_ball_y = H-BALL_SIZE;
        ball_dy <= -ball_dy;
      end

      // Kollision Paddle1
      if (new_ball_x <= PADDLE_W && new_ball_y+BALL_SIZE >= paddle1_y && new_ball_y <= paddle1_y+PADDLE_H) begin
        new_ball_x = PADDLE_W;
        ball_dx <= -ball_dx;
      end

      // Kollision Paddle2
      if (new_ball_x >= W-PADDLE_W-BALL_SIZE && new_ball_y+BALL_SIZE >= paddle2_y && new_ball_y <= paddle2_y+PADDLE_H) begin
        new_ball_x = W-PADDLE_W-BALL_SIZE;
        ball_dx <= -ball_dx;
      end

      // Ball Reset falls out of bounds
      if (new_ball_x <= 0 || new_ball_x >= W-BALL_SIZE) begin
        new_ball_x = W/2;
        new_ball_y = H/2;
        ball_dx <= 2;
        ball_dy <= 1;
      end

      ball_x <= new_ball_x;
      ball_y <= new_ball_y;
    end
  end

  // Active Pixels
  wire paddle1_active = video_active && (pix_x < PADDLE_W) && (pix_y >= paddle1_y) && (pix_y < paddle1_y+PADDLE_H);
  wire paddle2_active = video_active && (pix_x >= W-PADDLE_W) && (pix_y >= paddle2_y) && (pix_y < paddle2_y+PADDLE_H);
  wire ball_active    = video_active && (pix_x >= ball_x) && (pix_x < ball_x+BALL_SIZE) && (pix_y >= ball_y) && (pix_y < ball_y+BALL_SIZE);

  // Farben: Hintergrund schwarz, Paddle & Ball weiß
  assign R = video_active ? {ball_active|paddle1_active|paddle2_active, 1'b1} : 2'b00;
  assign G = video_active ? {ball_active|paddle1_active|paddle2_active, 1'b1} : 2'b00;
  assign B = video_active ? {ball_active|paddle1_active|paddle2_active, 1'b1} : 2'b00;

  // HVSYNC Generator
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

endmodule
