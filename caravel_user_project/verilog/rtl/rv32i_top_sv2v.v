module alu (
	operand_a,
	operand_b,
	alu_op,
	result,
	zero_flag
);
	input wire [31:0] operand_a;
	input wire [31:0] operand_b;
	input wire [3:0] alu_op;
	output reg [31:0] result;
	output wire zero_flag;
	always @(*) begin
		result = 32'b00000000000000000000000000000000;
		case (alu_op)
			4'd0: result = operand_a + operand_b;
			4'd1: result = operand_a - operand_b;
			4'd2: result = operand_a & operand_b;
			4'd3: result = operand_a | operand_b;
			4'd4: result = operand_a ^ operand_b;
			4'd5: result = operand_a << operand_b[4:0];
			4'd6: result = operand_a >> operand_b[4:0];
			4'd7: result = $signed(operand_a) >>> operand_b[4:0];
			4'd8: result = {31'b0000000000000000000000000000000, $signed(operand_a) < $signed(operand_b)};
			4'd9: result = {31'b0000000000000000000000000000000, operand_a < operand_b};
			4'd10: result = operand_b;
			4'd11: result = operand_a;
			default: result = 32'b00000000000000000000000000000000;
		endcase
	end
	assign zero_flag = result == 32'b00000000000000000000000000000000;
endmodule
module if_stage (
	clk,
	rst_n,
	stall_if,
	flush_if,
	branch_taken,
	branch_target,
	imem_en,
	imem_addr,
	imem_rdata,
	if_id_out
);
	input wire clk;
	input wire rst_n;
	input wire stall_if;
	input wire flush_if;
	input wire branch_taken;
	input wire [31:0] branch_target;
	output wire imem_en;
	output wire [31:0] imem_addr;
	input wire [31:0] imem_rdata;
	output reg [96:0] if_id_out;
	reg [31:0] pc_q;
	reg [31:0] pc_q_prev;
	wire [31:0] pc_d;
	assign pc_d = (branch_taken ? branch_target : (stall_if ? pc_q : pc_q + 32'd4));
	always @(posedge clk)
		if (!rst_n) begin
			pc_q <= 32'b00000000000000000000000000000000;
			pc_q_prev <= 32'b00000000000000000000000000000000;
		end
		else if (!stall_if) begin
			pc_q <= pc_d;
			if (branch_taken)
				pc_q_prev <= branch_target;
			else
				pc_q_prev <= pc_q;
		end
	assign imem_en = ~stall_if;
	assign imem_addr = pc_q;
	always @(posedge clk)
		if (!rst_n)
			if_id_out <= 1'sb0;
		else if (flush_if)
			if_id_out <= 1'sb0;
		else if (!stall_if) begin
			if_id_out[96] <= 1'b1;
			if_id_out[95-:32] <= pc_q_prev;
			if_id_out[63-:32] <= pc_q_prev + 32'd4;
			if_id_out[31-:32] <= imem_rdata;
		end
endmodule
module id_stage (
	clk,
	rst_n,
	stall_id,
	flush_id,
	if_id_in,
	rs1_addr,
	rs2_addr,
	rs1_data,
	rs2_data,
	id_ex_out
);
	input wire clk;
	input wire rst_n;
	input wire stall_id;
	input wire flush_id;
	input wire [96:0] if_id_in;
	output wire [4:0] rs1_addr;
	output wire [4:0] rs2_addr;
	input wire [31:0] rs1_data;
	input wire [31:0] rs2_data;
	output reg [194:0] id_ex_out;
	wire [6:0] opcode;
	wire [2:0] funct3;
	wire [6:0] funct7;
	wire [4:0] rd;
	assign opcode = if_id_in[6:0];
	assign funct3 = if_id_in[14:12];
	assign funct7 = if_id_in[31:25];
	assign rd = if_id_in[11:7];
	assign rs1_addr = if_id_in[19:15];
	assign rs2_addr = if_id_in[24:20];
	wire [31:0] imm_i;
	wire [31:0] imm_s;
	wire [31:0] imm_b;
	wire [31:0] imm_u;
	wire [31:0] imm_j;
	assign imm_i = {{20 {if_id_in[31]}}, if_id_in[31:20]};
	assign imm_s = {{20 {if_id_in[31]}}, if_id_in[31:25], if_id_in[11:7]};
	assign imm_b = {{20 {if_id_in[31]}}, if_id_in[7], if_id_in[30:25], if_id_in[11:8], 1'b0};
	assign imm_u = {if_id_in[31:12], 12'b000000000000};
	assign imm_j = {{12 {if_id_in[31]}}, if_id_in[19:12], if_id_in[20], if_id_in[30:21], 1'b0};
	reg [31:0] imm;
	reg [194:0] id_ex_next;
	localparam [2:0] riscv_pkg_F3_ADD_SUB = 3'b000;
	localparam [2:0] riscv_pkg_F3_AND = 3'b111;
	localparam [2:0] riscv_pkg_F3_BEQ = 3'b000;
	localparam [2:0] riscv_pkg_F3_BGE = 3'b101;
	localparam [2:0] riscv_pkg_F3_BGEU = 3'b111;
	localparam [2:0] riscv_pkg_F3_BLT = 3'b100;
	localparam [2:0] riscv_pkg_F3_BLTU = 3'b110;
	localparam [2:0] riscv_pkg_F3_BNE = 3'b001;
	localparam [2:0] riscv_pkg_F3_OR = 3'b110;
	localparam [2:0] riscv_pkg_F3_SLL = 3'b001;
	localparam [2:0] riscv_pkg_F3_SLT = 3'b010;
	localparam [2:0] riscv_pkg_F3_SLTU = 3'b011;
	localparam [2:0] riscv_pkg_F3_SRL_SRA = 3'b101;
	localparam [2:0] riscv_pkg_F3_XOR = 3'b100;
	localparam [6:0] riscv_pkg_F7_ALT = 7'b0100000;
	localparam [6:0] riscv_pkg_OPC_AUIPC = 7'b0010111;
	localparam [6:0] riscv_pkg_OPC_BRANCH = 7'b1100011;
	localparam [6:0] riscv_pkg_OPC_JAL = 7'b1101111;
	localparam [6:0] riscv_pkg_OPC_JALR = 7'b1100111;
	localparam [6:0] riscv_pkg_OPC_LOAD = 7'b0000011;
	localparam [6:0] riscv_pkg_OPC_LUI = 7'b0110111;
	localparam [6:0] riscv_pkg_OPC_OP = 7'b0110011;
	localparam [6:0] riscv_pkg_OPC_OP_IMM = 7'b0010011;
	localparam [6:0] riscv_pkg_OPC_STORE = 7'b0100011;
	always @(*) begin
		id_ex_next = 1'sb0;
		id_ex_next[193-:32] = if_id_in[95-:32];
		id_ex_next[161-:32] = if_id_in[63-:32];
		id_ex_next[129-:32] = rs1_data;
		id_ex_next[97-:32] = rs2_data;
		id_ex_next[33-:5] = rs1_addr;
		id_ex_next[28-:5] = rs2_addr;
		id_ex_next[23-:5] = rd;
		imm = 32'b00000000000000000000000000000000;
		if (if_id_in[96]) begin
			id_ex_next[194] = 1'b1;
			case (opcode)
				riscv_pkg_OPC_LUI: begin
					imm = imm_u;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd3;
				end
				riscv_pkg_OPC_AUIPC: begin
					imm = imm_u;
					id_ex_next[18-:4] = 4'd0;
					id_ex_next[14] = 1'b1;
					id_ex_next[13] = 1'b1;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd0;
				end
				riscv_pkg_OPC_JAL: begin
					imm = imm_j;
					id_ex_next[9] = 1'b1;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd2;
				end
				riscv_pkg_OPC_JALR: begin
					imm = imm_i;
					id_ex_next[9] = 1'b1;
					id_ex_next[8] = 1'b1;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd2;
				end
				riscv_pkg_OPC_BRANCH: begin
					imm = imm_b;
					case (funct3)
						riscv_pkg_F3_BEQ: id_ex_next[12-:3] = 3'd1;
						riscv_pkg_F3_BNE: id_ex_next[12-:3] = 3'd2;
						riscv_pkg_F3_BLT: id_ex_next[12-:3] = 3'd3;
						riscv_pkg_F3_BGE: id_ex_next[12-:3] = 3'd4;
						riscv_pkg_F3_BLTU: id_ex_next[12-:3] = 3'd5;
						riscv_pkg_F3_BGEU: id_ex_next[12-:3] = 3'd6;
						default: id_ex_next[12-:3] = 3'd0;
					endcase
				end
				riscv_pkg_OPC_LOAD: begin
					imm = imm_i;
					id_ex_next[18-:4] = 4'd0;
					id_ex_next[13] = 1'b1;
					id_ex_next[7] = 1'b1;
					id_ex_next[5-:3] = funct3;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd1;
				end
				riscv_pkg_OPC_STORE: begin
					imm = imm_s;
					id_ex_next[18-:4] = 4'd0;
					id_ex_next[13] = 1'b1;
					id_ex_next[6] = 1'b1;
					id_ex_next[5-:3] = funct3;
				end
				riscv_pkg_OPC_OP_IMM: begin
					imm = imm_i;
					id_ex_next[13] = 1'b1;
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd0;
					case (funct3)
						riscv_pkg_F3_ADD_SUB: id_ex_next[18-:4] = 4'd0;
						riscv_pkg_F3_SLT: id_ex_next[18-:4] = 4'd8;
						riscv_pkg_F3_SLTU: id_ex_next[18-:4] = 4'd9;
						riscv_pkg_F3_XOR: id_ex_next[18-:4] = 4'd4;
						riscv_pkg_F3_OR: id_ex_next[18-:4] = 4'd3;
						riscv_pkg_F3_AND: id_ex_next[18-:4] = 4'd2;
						riscv_pkg_F3_SLL: id_ex_next[18-:4] = 4'd5;
						riscv_pkg_F3_SRL_SRA:
							if (funct7 == riscv_pkg_F7_ALT)
								id_ex_next[18-:4] = 4'd7;
							else
								id_ex_next[18-:4] = 4'd6;
						default: id_ex_next[18-:4] = 4'd0;
					endcase
				end
				riscv_pkg_OPC_OP: begin
					id_ex_next[2] = 1'b1;
					id_ex_next[1-:2] = 2'd0;
					case (funct3)
						riscv_pkg_F3_ADD_SUB:
							if (funct7 == riscv_pkg_F7_ALT)
								id_ex_next[18-:4] = 4'd1;
							else
								id_ex_next[18-:4] = 4'd0;
						riscv_pkg_F3_SLL: id_ex_next[18-:4] = 4'd5;
						riscv_pkg_F3_SLT: id_ex_next[18-:4] = 4'd8;
						riscv_pkg_F3_SLTU: id_ex_next[18-:4] = 4'd9;
						riscv_pkg_F3_XOR: id_ex_next[18-:4] = 4'd4;
						riscv_pkg_F3_SRL_SRA:
							if (funct7 == riscv_pkg_F7_ALT)
								id_ex_next[18-:4] = 4'd7;
							else
								id_ex_next[18-:4] = 4'd6;
						riscv_pkg_F3_OR: id_ex_next[18-:4] = 4'd3;
						riscv_pkg_F3_AND: id_ex_next[18-:4] = 4'd2;
						default: id_ex_next[18-:4] = 4'd0;
					endcase
				end
				default: id_ex_next = 1'sb0;
			endcase
			id_ex_next[65-:32] = imm;
		end
	end
	always @(posedge clk)
		if (!rst_n)
			id_ex_out <= 1'sb0;
		else if (flush_id)
			id_ex_out <= 1'sb0;
		else if (!stall_id)
			id_ex_out <= id_ex_next;
endmodule
module ex_stage (
	clk,
	rst_n,
	stall_ex,
	flush_ex,
	id_ex_in,
	forward_a,
	forward_b,
	forward_ex_mem,
	forward_mem_wb,
	branch_taken,
	branch_target,
	ex_mem_out
);
	input wire clk;
	input wire rst_n;
	input wire stall_ex;
	input wire flush_ex;
	input wire [194:0] id_ex_in;
	input wire [1:0] forward_a;
	input wire [1:0] forward_b;
	input wire [31:0] forward_ex_mem;
	input wire [31:0] forward_mem_wb;
	output wire branch_taken;
	output wire [31:0] branch_target;
	output reg [141:0] ex_mem_out;
	reg [31:0] op_a_fwd;
	reg [31:0] op_b_fwd;
	always @(*) begin
		case (forward_a)
			2'b01: op_a_fwd = forward_ex_mem;
			2'b10: op_a_fwd = forward_mem_wb;
			default: op_a_fwd = id_ex_in[129-:32];
		endcase
		case (forward_b)
			2'b01: op_b_fwd = forward_ex_mem;
			2'b10: op_b_fwd = forward_mem_wb;
			default: op_b_fwd = id_ex_in[97-:32];
		endcase
	end
	wire [31:0] alu_in_a;
	wire [31:0] alu_in_b;
	assign alu_in_a = (id_ex_in[14] ? id_ex_in[193-:32] : op_a_fwd);
	assign alu_in_b = (id_ex_in[13] ? id_ex_in[65-:32] : op_b_fwd);
	wire [31:0] alu_result;
	wire zero_flag;
	alu alu_inst(
		.operand_a(alu_in_a),
		.operand_b(alu_in_b),
		.alu_op(id_ex_in[18-:4]),
		.result(alu_result),
		.zero_flag(zero_flag)
	);
	reg branch_cond_met;
	always @(*)
		case (id_ex_in[12-:3])
			3'd1: branch_cond_met = op_a_fwd == op_b_fwd;
			3'd2: branch_cond_met = op_a_fwd != op_b_fwd;
			3'd3: branch_cond_met = $signed(op_a_fwd) < $signed(op_b_fwd);
			3'd4: branch_cond_met = $signed(op_a_fwd) >= $signed(op_b_fwd);
			3'd5: branch_cond_met = op_a_fwd < op_b_fwd;
			3'd6: branch_cond_met = op_a_fwd >= op_b_fwd;
			default: branch_cond_met = 1'b0;
		endcase
	assign branch_taken = id_ex_in[194] && (id_ex_in[9] || ((id_ex_in[12-:3] != 3'd0) && branch_cond_met));
	wire [31:0] target_base;
	assign target_base = (id_ex_in[8] ? op_a_fwd : id_ex_in[193-:32]);
	assign branch_target = {target_base + id_ex_in[65-:32]} & 32'hfffffffe;
	reg [141:0] ex_mem_next;
	always @(*) begin
		ex_mem_next = 1'sb0;
		if (id_ex_in[194]) begin
			ex_mem_next[141] = 1'b1;
			ex_mem_next[140-:32] = alu_result;
			ex_mem_next[108-:32] = op_b_fwd;
			ex_mem_next[76-:32] = id_ex_in[161-:32];
			ex_mem_next[44-:32] = id_ex_in[65-:32];
			ex_mem_next[12-:5] = id_ex_in[23-:5];
			ex_mem_next[7] = id_ex_in[7];
			ex_mem_next[6] = id_ex_in[6];
			ex_mem_next[5-:3] = id_ex_in[5-:3];
			ex_mem_next[2] = id_ex_in[2];
			ex_mem_next[1-:2] = id_ex_in[1-:2];
		end
	end
	always @(posedge clk)
		if (!rst_n)
			ex_mem_out <= 1'sb0;
		else if (flush_ex)
			ex_mem_out <= 1'sb0;
		else if (!stall_ex)
			ex_mem_out <= ex_mem_next;
endmodule
module mem_stage (
	clk,
	rst_n,
	stall_mem,
	flush_mem,
	ex_mem_in,
	dmem_en,
	dmem_addr,
	dmem_wdata,
	dmem_wmask,
	dmem_we,
	mem_wb_out
);
	input wire clk;
	input wire rst_n;
	input wire stall_mem;
	input wire flush_mem;
	input wire [141:0] ex_mem_in;
	output wire dmem_en;
	output wire [31:0] dmem_addr;
	output wire [31:0] dmem_wdata;
	output wire [3:0] dmem_wmask;
	output wire dmem_we;
	output reg [107:0] mem_wb_out;
	assign dmem_en = (ex_mem_in[141] && (ex_mem_in[7] || ex_mem_in[6])) && !stall_mem;
	assign dmem_addr = ex_mem_in[140-:32];
	assign dmem_we = ex_mem_in[6];
	wire [1:0] byte_offset;
	assign byte_offset = ex_mem_in[110:109];
	reg [31:0] store_data;
	reg [3:0] store_mask;
	always @(*) begin
		store_data = 32'b00000000000000000000000000000000;
		store_mask = 4'b0000;
		if (ex_mem_in[141] && ex_mem_in[6])
			case (ex_mem_in[5-:3])
				3'b000:
					case (byte_offset)
						2'b00: begin
							store_data = {24'b000000000000000000000000, ex_mem_in[84:77]};
							store_mask = 4'b0001;
						end
						2'b01: begin
							store_data = {16'b0000000000000000, ex_mem_in[84:77], 8'b00000000};
							store_mask = 4'b0010;
						end
						2'b10: begin
							store_data = {8'b00000000, ex_mem_in[84:77], 16'b0000000000000000};
							store_mask = 4'b0100;
						end
						2'b11: begin
							store_data = {ex_mem_in[84:77], 24'b000000000000000000000000};
							store_mask = 4'b1000;
						end
					endcase
				3'b001:
					case (byte_offset[1])
						1'b0: begin
							store_data = {16'b0000000000000000, ex_mem_in[92:77]};
							store_mask = 4'b0011;
						end
						1'b1: begin
							store_data = {ex_mem_in[92:77], 16'b0000000000000000};
							store_mask = 4'b1100;
						end
					endcase
				3'b010: begin
					store_data = ex_mem_in[108-:32];
					store_mask = 4'b1111;
				end
				default: begin
					store_data = 32'b00000000000000000000000000000000;
					store_mask = 4'b0000;
				end
			endcase
	end
	assign dmem_wdata = store_data;
	assign dmem_wmask = store_mask;
	reg [107:0] mem_wb_next;
	always @(*) begin
		mem_wb_next = 1'sb0;
		if (ex_mem_in[141]) begin
			mem_wb_next[107] = 1'b1;
			mem_wb_next[106-:32] = ex_mem_in[140-:32];
			mem_wb_next[74-:3] = ex_mem_in[5-:3];
			mem_wb_next[71-:32] = ex_mem_in[76-:32];
			mem_wb_next[39-:32] = ex_mem_in[44-:32];
			mem_wb_next[7-:5] = ex_mem_in[12-:5];
			mem_wb_next[2] = ex_mem_in[2];
			mem_wb_next[1-:2] = ex_mem_in[1-:2];
		end
	end
	always @(posedge clk)
		if (!rst_n)
			mem_wb_out <= 1'sb0;
		else if (flush_mem)
			mem_wb_out <= 1'sb0;
		else if (!stall_mem)
			mem_wb_out <= mem_wb_next;
endmodule
module wb_stage (
	mem_wb_in,
	dmem_rdata,
	rd_addr,
	rd_data,
	rd_write_en
);
	input wire [107:0] mem_wb_in;
	input wire [31:0] dmem_rdata;
	output wire [4:0] rd_addr;
	output wire [31:0] rd_data;
	output wire rd_write_en;
	wire [1:0] byte_offset;
	reg [31:0] load_data;
	assign byte_offset = mem_wb_in[76:75];
	always @(*) begin
		load_data = dmem_rdata;
		case (mem_wb_in[74-:3])
			3'b000:
				case (byte_offset)
					2'b00: load_data = {{24 {dmem_rdata[7]}}, dmem_rdata[7:0]};
					2'b01: load_data = {{24 {dmem_rdata[15]}}, dmem_rdata[15:8]};
					2'b10: load_data = {{24 {dmem_rdata[23]}}, dmem_rdata[23:16]};
					2'b11: load_data = {{24 {dmem_rdata[31]}}, dmem_rdata[31:24]};
				endcase
			3'b001:
				case (byte_offset[1])
					1'b0: load_data = {{16 {dmem_rdata[15]}}, dmem_rdata[15:0]};
					1'b1: load_data = {{16 {dmem_rdata[31]}}, dmem_rdata[31:16]};
				endcase
			3'b010: load_data = dmem_rdata;
			3'b100:
				case (byte_offset)
					2'b00: load_data = {24'b000000000000000000000000, dmem_rdata[7:0]};
					2'b01: load_data = {24'b000000000000000000000000, dmem_rdata[15:8]};
					2'b10: load_data = {24'b000000000000000000000000, dmem_rdata[23:16]};
					2'b11: load_data = {24'b000000000000000000000000, dmem_rdata[31:24]};
				endcase
			3'b101:
				case (byte_offset[1])
					1'b0: load_data = {16'b0000000000000000, dmem_rdata[15:0]};
					1'b1: load_data = {16'b0000000000000000, dmem_rdata[31:16]};
				endcase
			default: load_data = dmem_rdata;
		endcase
	end
	reg [31:0] wb_data;
	always @(*)
		case (mem_wb_in[1-:2])
			2'd0: wb_data = mem_wb_in[106-:32];
			2'd1: wb_data = load_data;
			2'd2: wb_data = mem_wb_in[71-:32];
			2'd3: wb_data = mem_wb_in[39-:32];
			default: wb_data = mem_wb_in[106-:32];
		endcase
	assign rd_addr = mem_wb_in[7-:5];
	assign rd_data = wb_data;
	assign rd_write_en = (mem_wb_in[107] && mem_wb_in[2]) && (mem_wb_in[7-:5] != 5'b00000);
endmodule
module forwarding_unit (
	id_ex_rs1_addr,
	id_ex_rs2_addr,
	ex_mem_reg_write,
	ex_mem_rd_addr,
	mem_wb_reg_write,
	mem_wb_rd_addr,
	forward_a,
	forward_b
);
	input wire [4:0] id_ex_rs1_addr;
	input wire [4:0] id_ex_rs2_addr;
	input wire ex_mem_reg_write;
	input wire [4:0] ex_mem_rd_addr;
	input wire mem_wb_reg_write;
	input wire [4:0] mem_wb_rd_addr;
	output reg [1:0] forward_a;
	output reg [1:0] forward_b;
	always @(*)
		if ((ex_mem_reg_write && (ex_mem_rd_addr != 5'b00000)) && (ex_mem_rd_addr == id_ex_rs1_addr))
			forward_a = 2'b01;
		else if ((mem_wb_reg_write && (mem_wb_rd_addr != 5'b00000)) && (mem_wb_rd_addr == id_ex_rs1_addr))
			forward_a = 2'b10;
		else
			forward_a = 2'b00;
	always @(*)
		if ((ex_mem_reg_write && (ex_mem_rd_addr != 5'b00000)) && (ex_mem_rd_addr == id_ex_rs2_addr))
			forward_b = 2'b01;
		else if ((mem_wb_reg_write && (mem_wb_rd_addr != 5'b00000)) && (mem_wb_rd_addr == id_ex_rs2_addr))
			forward_b = 2'b10;
		else
			forward_b = 2'b00;
endmodule
module hazard_unit (
	id_ex_mem_read,
	id_ex_rd_addr,
	if_id_rs1_addr,
	if_id_rs2_addr,
	branch_taken,
	stall_if,
	stall_id,
	flush_if,
	flush_id,
	flush_ex
);
	input wire id_ex_mem_read;
	input wire [4:0] id_ex_rd_addr;
	input wire [4:0] if_id_rs1_addr;
	input wire [4:0] if_id_rs2_addr;
	input wire branch_taken;
	output reg stall_if;
	output reg stall_id;
	output reg flush_if;
	output reg flush_id;
	output reg flush_ex;
	reg load_use_hazard;
	always @(*)
		if ((id_ex_mem_read && (id_ex_rd_addr != 5'b00000)) && ((id_ex_rd_addr == if_id_rs1_addr) || (id_ex_rd_addr == if_id_rs2_addr)))
			load_use_hazard = 1'b1;
		else
			load_use_hazard = 1'b0;
	always @(*) begin
		stall_if = 1'b0;
		stall_id = 1'b0;
		flush_if = 1'b0;
		flush_id = 1'b0;
		flush_ex = 1'b0;
		if (branch_taken) begin
			flush_if = 1'b1;
			flush_id = 1'b1;
		end
		else if (load_use_hazard) begin
			stall_if = 1'b1;
			stall_id = 1'b1;
			flush_ex = 1'b1;
		end
	end
endmodule
module reg_file (
	clk,
	rst_n,
	rs1_addr,
	rs1_data,
	rs2_addr,
	rs2_data,
	rd_addr,
	rd_data,
	rd_write_en,
	dbg_addr,
	dbg_wdata,
	dbg_we,
	dbg_rdata
);
	input wire clk;
	input wire rst_n;
	input wire [4:0] rs1_addr;
	output wire [31:0] rs1_data;
	input wire [4:0] rs2_addr;
	output wire [31:0] rs2_data;
	input wire [4:0] rd_addr;
	input wire [31:0] rd_data;
	input wire rd_write_en;
	input wire [4:0] dbg_addr;
	input wire [31:0] dbg_wdata;
	input wire dbg_we;
	output wire [31:0] dbg_rdata;
	reg [31:0] regs [1:31];
	assign rs1_data = (rs1_addr == 5'b00000 ? 32'b00000000000000000000000000000000 : regs[rs1_addr]);
	assign rs2_data = (rs2_addr == 5'b00000 ? 32'b00000000000000000000000000000000 : regs[rs2_addr]);
	assign dbg_rdata = (dbg_addr == 5'b00000 ? 32'b00000000000000000000000000000000 : regs[dbg_addr]);
	integer i;
	always @(posedge clk)
		if (!rst_n)
			for (i = 1; i < 32; i = i + 1)
				regs[i] <= 32'b00000000000000000000000000000000;
		else if (dbg_we && (dbg_addr != 5'b00000))
			regs[dbg_addr] <= dbg_wdata;
		else if (rd_write_en && (rd_addr != 5'b00000))
			regs[rd_addr] <= rd_data;
endmodule
module rv32_core (
	clk,
	rst_n,
	imem_en,
	imem_addr,
	imem_rdata,
	dmem_en,
	dmem_addr,
	dmem_wdata,
	dmem_wmask,
	dmem_we,
	dmem_rdata,
	dbg_halt,
	dbg_write_en,
	dbg_reg_addr,
	dbg_write_data,
	dbg_read_data
);
	input wire clk;
	input wire rst_n;
	output wire imem_en;
	output wire [31:0] imem_addr;
	input wire [31:0] imem_rdata;
	output wire dmem_en;
	output wire [31:0] dmem_addr;
	output wire [31:0] dmem_wdata;
	output wire [3:0] dmem_wmask;
	output wire dmem_we;
	input wire [31:0] dmem_rdata;
	input wire dbg_halt;
	input wire dbg_write_en;
	input wire [4:0] dbg_reg_addr;
	input wire [31:0] dbg_write_data;
	output wire [31:0] dbg_read_data;
	wire [96:0] if_id_reg;
	wire [194:0] id_ex_reg;
	wire [141:0] ex_mem_reg;
	wire [107:0] mem_wb_reg;
	wire branch_taken;
	wire [31:0] branch_target;
	wire stall_if;
	wire stall_id;
	wire stall_ex;
	wire stall_mem;
	wire flush_if;
	wire flush_id;
	wire flush_ex;
	wire flush_mem;
	wire [4:0] rs1_addr;
	wire [4:0] rs2_addr;
	wire [31:0] rs1_data;
	wire [31:0] rs2_data;
	wire [4:0] rd_addr;
	wire [31:0] rd_data;
	wire rd_write_en;
	wire [1:0] forward_a;
	wire [1:0] forward_b;
	wire [31:0] forward_ex_mem_data;
	wire [31:0] forward_mem_wb_data;
	hazard_unit u_hazard_unit(
		.id_ex_mem_read(id_ex_reg[7]),
		.id_ex_rd_addr(id_ex_reg[23-:5]),
		.if_id_rs1_addr(if_id_reg[19:15]),
		.if_id_rs2_addr(if_id_reg[24:20]),
		.branch_taken(branch_taken),
		.stall_if(stall_if),
		.stall_id(stall_id),
		.flush_if(flush_if),
		.flush_id(flush_id),
		.flush_ex(flush_ex)
	);
	assign stall_ex = dbg_halt;
	assign stall_mem = dbg_halt;
	assign flush_mem = 1'b0;
	wire real_stall_if;
	wire real_stall_id;
	assign real_stall_if = stall_if | dbg_halt;
	assign real_stall_id = stall_id | dbg_halt;
	assign forward_ex_mem_data = ex_mem_reg[140-:32];
	assign forward_mem_wb_data = rd_data;
	forwarding_unit u_forwarding_unit(
		.id_ex_rs1_addr(id_ex_reg[33-:5]),
		.id_ex_rs2_addr(id_ex_reg[28-:5]),
		.ex_mem_reg_write(ex_mem_reg[2]),
		.ex_mem_rd_addr(ex_mem_reg[12-:5]),
		.mem_wb_reg_write(mem_wb_reg[2]),
		.mem_wb_rd_addr(mem_wb_reg[7-:5]),
		.forward_a(forward_a),
		.forward_b(forward_b)
	);
	reg_file u_reg_file(
		.clk(clk),
		.rst_n(rst_n),
		.rs1_addr(rs1_addr),
		.rs1_data(rs1_data),
		.rs2_addr(rs2_addr),
		.rs2_data(rs2_data),
		.rd_addr(rd_addr),
		.rd_data(rd_data),
		.rd_write_en(rd_write_en),
		.dbg_addr(dbg_reg_addr),
		.dbg_wdata(dbg_write_data),
		.dbg_we(dbg_write_en),
		.dbg_rdata(dbg_read_data)
	);
	if_stage u_if_stage(
		.clk(clk),
		.rst_n(rst_n),
		.stall_if(real_stall_if),
		.flush_if(flush_if),
		.branch_taken(branch_taken),
		.branch_target(branch_target),
		.imem_en(imem_en),
		.imem_addr(imem_addr),
		.imem_rdata(imem_rdata),
		.if_id_out(if_id_reg)
	);
	id_stage u_id_stage(
		.clk(clk),
		.rst_n(rst_n),
		.stall_id(real_stall_id),
		.flush_id(flush_id),
		.if_id_in(if_id_reg),
		.rs1_addr(rs1_addr),
		.rs2_addr(rs2_addr),
		.rs1_data(rs1_data),
		.rs2_data(rs2_data),
		.id_ex_out(id_ex_reg)
	);
	ex_stage u_ex_stage(
		.clk(clk),
		.rst_n(rst_n),
		.stall_ex(stall_ex),
		.flush_ex(flush_ex),
		.id_ex_in(id_ex_reg),
		.forward_a(forward_a),
		.forward_b(forward_b),
		.forward_ex_mem(forward_ex_mem_data),
		.forward_mem_wb(forward_mem_wb_data),
		.branch_taken(branch_taken),
		.branch_target(branch_target),
		.ex_mem_out(ex_mem_reg)
	);
	mem_stage u_mem_stage(
		.clk(clk),
		.rst_n(rst_n),
		.stall_mem(stall_mem),
		.flush_mem(flush_mem),
		.ex_mem_in(ex_mem_reg),
		.dmem_en(dmem_en),
		.dmem_addr(dmem_addr),
		.dmem_wdata(dmem_wdata),
		.dmem_wmask(dmem_wmask),
		.dmem_we(dmem_we),
		.mem_wb_out(mem_wb_reg)
	);
	wb_stage u_wb_stage(
		.mem_wb_in(mem_wb_reg),
		.dmem_rdata(dmem_rdata),
		.rd_addr(rd_addr),
		.rd_data(rd_data),
		.rd_write_en(rd_write_en)
	);
endmodule
module rv32i_top (
	clk,
	rst_n,
	wb_clk_i,
	wb_rst_i,
	wbs_cyc_i,
	wbs_stb_i,
	wbs_we_i,
	wbs_sel_i,
	wbs_adr_i,
	wbs_dat_i,
	wbs_ack_o,
	wbs_dat_o,
	irq,
	jtag_tck,
	jtag_tms,
	jtag_tdi,
	jtag_tdo,
	jtag_trst_n,
	bist_mode_ext,
	bist_done_ext,
	bist_pass_ext,
	io_out,
	io_oeb,
	la_data_out
);
	input wire clk;
	input wire rst_n;
	input wire wb_clk_i;
	input wire wb_rst_i;
	input wire wbs_cyc_i;
	input wire wbs_stb_i;
	input wire wbs_we_i;
	input wire [3:0] wbs_sel_i;
	input wire [31:0] wbs_adr_i;
	input wire [31:0] wbs_dat_i;
	output reg wbs_ack_o;
	output reg [31:0] wbs_dat_o;
	output wire [2:0] irq;
	input wire jtag_tck;
	input wire jtag_tms;
	input wire jtag_tdi;
	output wire jtag_tdo;
	input wire jtag_trst_n;
	input wire bist_mode_ext;
	output wire bist_done_ext;
	output wire bist_pass_ext;
	output wire [37:0] io_out;
	output wire [37:0] io_oeb;
	output wire [127:0] la_data_out;
	assign irq = 3'b000;
	assign jtag_tdo = 1'b0;
	assign bist_done_ext = 1'b1;
	assign bist_pass_ext = 1'b1;
	assign io_out = 38'b00000000000000000000000000000000000000;
	assign io_oeb = 38'h3fffffffff;
	assign la_data_out = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
	localparam [31:0] IMEM_BASE = 32'h30000000;
	localparam [31:0] IMEM_MASK = 32'h00001fff;
	localparam [31:0] DMEM_BASE = 32'h30002000;
	localparam [31:0] DMEM_MASK = 32'h00001fff;
	localparam [31:0] CTRL_BASE = 32'h30004000;
	wire core_imem_en;
	wire [31:0] core_imem_addr;
	wire [31:0] core_imem_rdata;
	wire core_dmem_en;
	wire [31:0] core_dmem_addr;
	wire [31:0] core_dmem_wdata;
	wire [3:0] core_dmem_wmask;
	wire core_dmem_we;
	wire [31:0] core_dmem_rdata;
	wire [31:0] wb_imem_rdata;
	wire [31:0] wb_dmem_rdata;
	wire cpu_reset_n;
	reg [31:0] ctrl_reg;
	reg [1:0] wb_state;
	reg [1:0] wb_state_next;
	wire wb_req_valid;
	reg wb_req_is_imem;
	reg wb_req_is_dmem;
	reg wb_req_is_ctrl;
	reg [31:0] wb_req_addr;
	reg wb_req_we;
	reg [3:0] wb_req_sel;
	reg [31:0] wb_req_dat;
	assign wb_req_valid = wbs_cyc_i & wbs_stb_i;
	always @(posedge wb_clk_i or posedge wb_rst_i)
		if (wb_rst_i) begin
			wb_state <= 2'd0;
			wb_req_is_imem <= 1'b0;
			wb_req_is_dmem <= 1'b0;
			wb_req_is_ctrl <= 1'b0;
			wb_req_addr <= 32'b00000000000000000000000000000000;
			wb_req_we <= 1'b0;
			wb_req_sel <= 4'b0000;
			wb_req_dat <= 32'b00000000000000000000000000000000;
			wbs_ack_o <= 1'b0;
			wbs_dat_o <= 32'b00000000000000000000000000000000;
			ctrl_reg <= 32'h00000000;
		end
		else begin
			wb_state <= wb_state_next;
			case (wb_state)
				2'd0: begin
					wbs_ack_o <= 1'b0;
					if (wb_req_valid) begin
						wb_req_addr <= wbs_adr_i;
						wb_req_we <= wbs_we_i;
						wb_req_sel <= wbs_sel_i;
						wb_req_dat <= wbs_dat_i;
						wb_req_is_imem <= (wbs_adr_i & ~IMEM_MASK) == IMEM_BASE;
						wb_req_is_dmem <= (wbs_adr_i & ~DMEM_MASK) == DMEM_BASE;
						wb_req_is_ctrl <= wbs_adr_i == CTRL_BASE;
					end
				end
				2'd2:
					if (wb_req_is_ctrl && wb_req_we)
						ctrl_reg <= wb_req_dat;
				2'd3: begin
					wbs_ack_o <= 1'b1;
					if (wb_req_is_imem)
						wbs_dat_o <= wb_imem_rdata;
					else if (wb_req_is_dmem)
						wbs_dat_o <= wb_dmem_rdata;
					else if (wb_req_is_ctrl)
						wbs_dat_o <= ctrl_reg;
					else
						wbs_dat_o <= 32'hdeadbeef;
				end
				default: wbs_ack_o <= 1'b0;
			endcase
		end
	always @(*) begin
		wb_state_next = wb_state;
		case (wb_state)
			2'd0:
				if (wb_req_valid)
					wb_state_next = 2'd1;
			2'd1: wb_state_next = 2'd2;
			2'd2: wb_state_next = 2'd3;
			2'd3: wb_state_next = 2'd0;
			default: wb_state_next = 2'd0;
		endcase
	end
	assign cpu_reset_n = ctrl_reg[0] & ~wb_rst_i;
	wire wb_active;
	assign wb_active = wb_state == 2'd2;
	wire imem_csb0;
	wire imem_csb1;
	wire imem_web0;
	wire [3:0] imem_wmask0;
	wire [8:0] imem_addr0;
	wire [8:0] imem_addr1;
	wire [31:0] imem_din0;
	wire [31:0] imem_dout0;
	wire [31:0] imem_dout1;
	assign imem_csb0 = ~(wb_active & wb_req_is_imem);
	assign imem_web0 = ~wb_req_we;
	assign imem_wmask0 = wb_req_sel;
	assign imem_addr0 = wb_req_addr[10:2];
	assign imem_din0 = wb_req_dat;
	assign wb_imem_rdata = imem_dout0;
	assign imem_csb1 = ~core_imem_en;
	assign imem_addr1 = core_imem_addr[10:2];
	assign core_imem_rdata = imem_dout1;
	wire dmem_csb0;
	wire dmem_csb1;
	wire dmem_web0;
	wire [3:0] dmem_wmask0;
	wire [8:0] dmem_addr0;
	wire [8:0] dmem_addr1;
	wire [31:0] dmem_din0;
	wire [31:0] dmem_dout0;
	wire [31:0] dmem_dout1;
	assign dmem_csb0 = (wb_active & wb_req_is_dmem ? 1'b0 : ~core_dmem_en);
	assign dmem_web0 = (wb_active & wb_req_is_dmem ? ~wb_req_we : ~core_dmem_we);
	assign dmem_wmask0 = (wb_active & wb_req_is_dmem ? wb_req_sel : core_dmem_wmask);
	assign dmem_addr0 = (wb_active & wb_req_is_dmem ? wb_req_addr[10:2] : core_dmem_addr[10:2]);
	assign dmem_din0 = (wb_active & wb_req_is_dmem ? wb_req_dat : core_dmem_wdata);
	assign core_dmem_rdata = dmem_dout0;
	assign wb_dmem_rdata = dmem_dout0;
	assign dmem_csb1 = 1'b1;
	assign dmem_addr1 = 9'b000000000;
	rv32_core u_rv32_core(
		.clk(clk),
		.rst_n(cpu_reset_n),
		.imem_en(core_imem_en),
		.imem_addr(core_imem_addr),
		.imem_rdata(core_imem_rdata),
		.dmem_en(core_dmem_en),
		.dmem_addr(core_dmem_addr),
		.dmem_wdata(core_dmem_wdata),
		.dmem_wmask(core_dmem_wmask),
		.dmem_we(core_dmem_we),
		.dmem_rdata(core_dmem_rdata),
		.dbg_halt(1'b0),
		.dbg_write_en(1'b0),
		.dbg_reg_addr(5'b00000),
		.dbg_write_data(32'b00000000000000000000000000000000),
		.dbg_read_data()
	);
	sky130_sram_2kbyte_1rw1r_32x512_8 u_imem_sram(
		.clk0(clk),
		.csb0(imem_csb0),
		.web0(imem_web0),
		.wmask0(imem_wmask0),
		.addr0(imem_addr0),
		.din0(imem_din0),
		.dout0(imem_dout0),
		.clk1(clk),
		.csb1(imem_csb1),
		.addr1(imem_addr1),
		.dout1(imem_dout1)
	);
	sky130_sram_2kbyte_1rw1r_32x512_8 u_dmem_sram(
		.clk0(clk),
		.csb0(dmem_csb0),
		.web0(dmem_web0),
		.wmask0(dmem_wmask0),
		.addr0(dmem_addr0),
		.din0(dmem_din0),
		.dout0(dmem_dout0),
		.clk1(clk),
		.csb1(dmem_csb1),
		.addr1(dmem_addr1),
		.dout1(dmem_dout1)
	);
endmodule
