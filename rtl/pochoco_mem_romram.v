module pochoco_mem_romram (
    input  wire        clk_i,

    // Instruction port
    input  wire        a_req_i,
    input  wire [31:0] a_addr_i,
    output wire [31:0] a_rdata_o,

    // Data port
    input  wire        b_req_i,
    input  wire        b_we_i,
    input  wire [3:0]  b_be_i,
    input  wire [31:0] b_addr_i,
    input  wire [31:0] b_wdata_i,
    output reg  [31:0] b_rdata_o
);

    // ----------------------------------------------------------
    // Instruction ROM
    // ----------------------------------------------------------
    // The original FPGA memory had synchronous instruction reads.
    // We keep that one-cycle latency by registering the address,
    // while the actual ROM remains purely combinational.

    reg [31:0] instr_addr_q;

    always @(posedge clk_i) begin
        if (a_req_i)
            instr_addr_q <= a_addr_i;
    end

    game_rom u_rom (
        .addr_i  (instr_addr_q),
        .rdata_o (a_rdata_o)
    );


    // ----------------------------------------------------------
    // Minimal data RAM
    // ----------------------------------------------------------
    // game.s uses no ordinary data RAM; all loads/stores are MMIO.
    // One 32-bit word is retained to keep a valid data-memory
    // interface for the processor.

    reg [31:0] data_word;

    always @(posedge clk_i) begin
        if (b_req_i && b_we_i) begin
            if (b_be_i[0]) data_word[7:0]   <= b_wdata_i[7:0];
            if (b_be_i[1]) data_word[15:8]  <= b_wdata_i[15:8];
            if (b_be_i[2]) data_word[23:16] <= b_wdata_i[23:16];
            if (b_be_i[3]) data_word[31:24] <= b_wdata_i[31:24];
        end

        b_rdata_o <= data_word;
    end

    // The physical data RAM has one word, so its address is unused.
    wire _unused = &{1'b0, b_addr_i};

endmodule