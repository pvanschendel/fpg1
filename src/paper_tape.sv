
module paper_tape
(
	//clk ports
	input         clk,
	input         reset,

	input         img_mounted,
	input         img_readonly,
	input  [31:0] img_size,

	input         reader_ready
	output  [7:0] reader_data,
	output reg    reader_valid = 0,

	//clk_sys ports
	input             clk_sys,

	input             sd_ack,
	input             sd_buff_wr,
	input      [13:0] sd_buff_addr, /// [8:0 ?
	input       [7:0] sd_buff_dout,
	output      [7:0] sd_buff_din,
	output reg [31:0] sd_lba,
	//output  [5:0] sd_blk_cnt, ///
	output reg        sd_rd,
	output reg        sd_wr,

);

reg [31:0] reader_position = 0;
reg        readonly = 0;     // no problem until we want to write
reg [23:0] ch_timeout; // TODO:
reg        position_valid = 0;

wire next_reader_postion = reader_position + 1;
wire next_buffer_ready = reader_position[13] != next_reader_postion[13];

always @(posedge clk) begin
	reader_valid <= position_valid && reader_ready;
	position_valid <= 0;

	reg old_mounted;
	old_mounted <= img_mounted;
	if (~old_mounted & img_mounted) begin
		readonly <= img_readonly;
		reader_position <= 0;
		buffer_ready    <= |img_size;
	end else if (reader_ready && reader_valid && next_reader_postion < img_size) begin
		if (next_buffer_ready) begin
			buffer_ready   <= 1;
		end else if (!buffer_ready && buffer_valid) begin
			buffer_ready   <= 0;
			position_valid <= 1;
		end else begin
			// TOOD: will never get here
			reader_position <= next_reader_postion;
			position_valid <= 1;
		end
	end
end

// TODO: buffer_ready/valid Handshake needs clock synchronizer

dpram #(8,13) buffer
(
	.clock_a(clk),
	.address_a(reader_position[12:0]),
	.data_a(0),
	.wren_a(0),
	.q_a(reader_data)

	.clock_b(clk_sys),
	.address_b(sd_buff_addr),
	.data_b(sd_buff_dout),
	.wren_b(sd_buff_wr),
	.q_b(sd_buff_din),
);

always @(posedge clk_sys) begin
	reg        old_ack;

	old_ack <= sd_ack;

	if (reset) begin
		sd_lba       <= 0;
		buffer_valid <= 0;
		sd_rd        <= 0;
		sd_wr        <= 0;
	end else if (buffer_ready) begin
		sd_rd        <= 1;
		if (buffer_valid) buffer_valid <= 0;
	end else if (old_ack && !sd_ack) begin
		sd_rd        <= 0;
		buffer_valid <= 1;
		sd_lba       <= sd_lba + 1; // only read forward
	end
end

endmodule


module dpram #(parameter DATAWIDTH, ADDRWIDTH, INITFILE=" ")
(
	input	                     clock_a,
	input	     [ADDRWIDTH-1:0] address_a,
	input	     [DATAWIDTH-1:0] data_a,
	input	                     wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input	                     clock_b,
	input	     [ADDRWIDTH-1:0] address_b,
	input	     [DATAWIDTH-1:0] data_b,
	input	                     wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

(* ram_init_file = INITFILE *) reg [DATAWIDTH-1:0] ram[1<<ADDRWIDTH];

reg                 wren_a_d;
reg [ADDRWIDTH-1:0] address_a_d;
always @(posedge clock_a) begin
	wren_a_d    <= wren_a;
	address_a_d <= address_a;
end

always @(posedge clock_a) begin
	if(wren_a_d) begin
		ram[address_a_d] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a_d];
	end
end

reg                 wren_b_d;
reg [ADDRWIDTH-1:0] address_b_d;
always @(posedge clock_b) begin
	wren_b_d    <= wren_b;
	address_b_d <= address_b;
end

always @(posedge clock_b) begin
	if(wren_b_d) begin
		ram[address_b_d] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b_d];
	end
end

endmodule
