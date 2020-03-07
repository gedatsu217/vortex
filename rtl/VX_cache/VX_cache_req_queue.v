`include "VX_cache_config.v"

module VX_cache_req_queue
	#(
	// Size of cache in bytes
	parameter CACHE_SIZE_BYTES              = 1024, 
	// Size of line inside a bank in bytes
	parameter BANK_LINE_SIZE_BYTES          = 16, 
	// Number of banks {1, 2, 4, 8,...}
	parameter NUMBER_BANKS                  = 8, 
	// Size of a word in bytes
	parameter WORD_SIZE_BYTES               = 4, 
	// Number of Word requests per cycle {1, 2, 4, 8, ...}
	parameter NUMBER_REQUESTS               = 2, 
	// Number of cycles to complete stage 1 (read from memory)
	parameter STAGE_1_CYCLES                = 2, 

// Queues feeding into banks Knobs {1, 2, 4, 8, ...}

	// Core Request Queue Size
	parameter REQQ_SIZE                     = 8, 
	// Miss Reserv Queue Knob
	parameter MRVQ_SIZE                     = 8, 
	// Dram Fill Rsp Queue Size
	parameter DFPQ_SIZE                     = 2, 
	// Snoop Req Queue
	parameter SNRQ_SIZE                     = 8, 

// Queues for writebacks Knobs {1, 2, 4, 8, ...}
	// Core Writeback Queue Size
	parameter CWBQ_SIZE                     = 8, 
	// Dram Writeback Queue Size
	parameter DWBQ_SIZE                     = 4, 
	// Dram Fill Req Queue Size
	parameter DFQQ_SIZE                     = 8, 
	// Lower Level Cache Hit Queue Size
	parameter LLVQ_SIZE                     = 16, 

 	// Fill Invalidator Size {Fill invalidator must be active}
 	parameter FILL_INVALIDAOR_SIZE          = 16, 

// Dram knobs
	parameter SIMULATED_DRAM_LATENCY_CYCLES = 10


	)
	(
	input  wire                             clk,
	input  wire                             reset,

	// Enqueue Data
	input  wire                             reqq_push,
 	input wire [NUMBER_REQUESTS-1:0]       bank_valids,
	input wire [NUMBER_REQUESTS-1:0][31:0] bank_addr,
	input wire [NUMBER_REQUESTS-1:0][31:0] bank_writedata,
	input wire [4:0]                        bank_rd,
	input wire [1:0]                        bank_wb,
	input wire [`NW_M1:0]                   bank_warp_num,
	input wire [2:0]                        bank_mem_read,  
	input wire [2:0]                        bank_mem_write,

	// Dequeue Data
	input  wire                                   reqq_pop,
    output wire                                   reqq_req_st0,
    output wire [`vx_clog2(NUMBER_REQUESTS)-1:0] reqq_req_tid_st0,
	output wire [31:0]                            reqq_req_addr_st0,
	output wire [31:0]                            reqq_req_writedata_st0,
	output wire [4:0]                             reqq_req_rd_st0,
	output wire [1:0]                             reqq_req_wb_st0,
	output wire [`NW_M1:0]                        reqq_req_warp_num_st0,
	output wire [2:0]                             reqq_req_mem_read_st0,  
	output wire [2:0]                             reqq_req_mem_write_st0,

	// State Data
	output wire                                   reqq_empty,
	output wire                                   reqq_full
);

 	wire [NUMBER_REQUESTS-1:0]       out_per_valids;
	wire [NUMBER_REQUESTS-1:0][31:0] out_per_addr;
	wire [NUMBER_REQUESTS-1:0][31:0] out_per_writedata;
	wire [4:0]                        out_per_rd;
	wire [1:0]                        out_per_wb;
	wire [`NW_M1:0]                   out_per_warp_num;
	wire [2:0]                        out_per_mem_read;  
	wire [2:0]                        out_per_mem_write;


 	reg [NUMBER_REQUESTS-1:0]       use_per_valids;
	reg [NUMBER_REQUESTS-1:0][31:0] use_per_addr;
	reg [NUMBER_REQUESTS-1:0][31:0] use_per_writedata;
	reg [4:0]                        use_per_rd;
	reg [1:0]                        use_per_wb;
	reg [`NW_M1:0]                   use_per_warp_num;
	reg [2:0]                        use_per_mem_read;  
	reg [2:0]                        use_per_mem_write;


 	wire [NUMBER_REQUESTS-1:0]       qual_valids;
	wire [NUMBER_REQUESTS-1:0][31:0] qual_addr;
	wire [NUMBER_REQUESTS-1:0][31:0] qual_writedata;
	wire [4:0]                        qual_rd;
	wire [1:0]                        qual_wb;
	wire [`NW_M1:0]                   qual_warp_num;
	wire [2:0]                        qual_mem_read;  
	wire [2:0]                        qual_mem_write;

    wire[NUMBER_REQUESTS-1:0]        updated_valids;

    wire o_empty;

	wire use_empty = !(|use_per_valids);
	wire out_empty = !(|out_per_valids) || o_empty;

	wire push_qual = reqq_push && !reqq_full;
	wire pop_qual  = reqq_pop  && use_empty && !out_empty;

	VX_generic_queue_ll #(.DATAW( (NUMBER_REQUESTS * (1+32+32)) + 5 + 2 + (`NW_M1+1) + 3 + 3 ), .SIZE(REQQ_SIZE)) reqq_queue(
		.clk     (clk),
		.reset   (reset),
		.push    (push_qual),
		.in_data ({bank_valids   , bank_addr   , bank_writedata   , bank_rd   , bank_wb   , bank_warp_num   , bank_mem_read   , bank_mem_write}),
		.pop     (pop_qual),
		.out_data({out_per_valids, out_per_addr, out_per_writedata, out_per_rd, out_per_wb, out_per_warp_num, out_per_mem_read, out_per_mem_write}),
		.empty   (o_empty),
		.full    (reqq_full)
		);


	wire[NUMBER_REQUESTS-1:0] real_out_per_valids = out_per_valids & {NUMBER_REQUESTS{~out_empty}};

	assign qual_valids     = use_empty ? real_out_per_valids : out_empty ? 0 : use_per_valids; 
	assign qual_addr       = use_empty ? out_per_addr        : use_per_addr;
	assign qual_writedata  = use_empty ? out_per_writedata   : use_per_writedata;
	assign qual_rd         = use_empty ? out_per_rd          : use_per_rd;
	assign qual_wb         = use_empty ? out_per_wb          : use_per_wb;
	assign qual_warp_num   = use_empty ? out_per_warp_num    : use_per_warp_num;
	assign qual_mem_read   = use_empty ? out_per_mem_read    : use_per_mem_read;
	assign qual_mem_write  = use_empty ? out_per_mem_write   : use_per_mem_write;

	wire[`vx_clog2(NUMBER_REQUESTS)-1:0] qual_request_index;
	wire                                  qual_has_request;
	VX_generic_priority_encoder #(.N(NUMBER_REQUESTS)) VX_sel_bank(
		.valids(qual_valids),
		.index (qual_request_index),
		.found (qual_has_request)
		);

	assign reqq_empty              = !qual_has_request;
	assign reqq_req_st0            = qual_has_request;
    assign reqq_req_tid_st0        = qual_request_index;
	assign reqq_req_addr_st0       = qual_addr     [qual_request_index];
	assign reqq_req_writedata_st0  = qual_writedata[qual_request_index];
	assign reqq_req_rd_st0         = qual_rd;
	assign reqq_req_wb_st0         = qual_wb;
	assign reqq_req_warp_num_st0   = qual_warp_num;
	assign reqq_req_mem_read_st0   = qual_mem_read;
	assign reqq_req_mem_write_st0  = qual_mem_write;

	assign updated_valids = qual_valids & (~(1 << qual_request_index));

	always @(posedge clk) begin
		if (reset) begin
 			use_per_valids    <= 0;
			use_per_addr      <= 0;
			use_per_writedata <= 0;
			use_per_rd        <= 0;
			use_per_wb        <= 0;
			use_per_warp_num  <= 0;
			use_per_mem_read  <= 0;  
			use_per_mem_write <= 0;
		end else begin
			if (reqq_pop && qual_has_request) begin
				use_per_valids    <= updated_valids;
				use_per_addr      <= qual_addr;
				use_per_writedata <= qual_writedata;
				use_per_rd        <= qual_rd;
				use_per_wb        <= qual_wb;
				use_per_warp_num  <= qual_warp_num;
				use_per_mem_read  <= qual_mem_read;  
				use_per_mem_write <= qual_mem_write;
			end 
			// else if (reqq_pop) begin
			// 	use_per_valids[qual_request_index] <= updated_valids;
			// end
		end
	end


endmodule