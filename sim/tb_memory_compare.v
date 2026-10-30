`timescale 1ns/1ps

module tb_memory_compare;

    reg clk = 0;
    reg rst_ni = 0;

    reg        a_req = 0;
    reg [31:0] a_addr = 0;

    wire [31:0] rom_data;
    wire [31:0] ff_data;

    integer i;
    integer errors = 0;

    always #5 clk = ~clk;

    // Strategy 1: combinational ROM + minimal data RAM
    pochoco_mem_romram mem_romram (
        .clk_i      (clk),

        .a_req_i    (a_req),
        .a_addr_i   (a_addr),
        .a_rdata_o  (rom_data),

        .b_req_i    (1'b0),
        .b_we_i     (1'b0),
        .b_be_i     (4'b0000),
        .b_addr_i   (32'b0),
        .b_wdata_i  (32'b0),
        .b_rdata_o  ()
    );

    // Strategy 2: unified flip-flop memory
    game_mem_ff mem_ff (
        .clk_i      (clk),
        .rst_ni     (rst_ni),

        .a_req_i    (a_req),
        .a_addr_i   (a_addr),
        .a_rdata_o  (ff_data),

        .b_req_i    (1'b0),
        .b_we_i     (1'b0),
        .b_be_i     (4'b0000),
        .b_addr_i   (32'b0),
        .b_wdata_i  (32'b0),
        .b_rdata_o  ()
    );

    initial begin
        // Reset FF memory so it loads the generated program
        repeat (2) @(posedge clk);

        @(negedge clk);
        rst_ni = 1'b1;
        a_req = 1'b1;

        // Compare all 97 program words
        for (i = 0; i < 97; i = i + 1) begin
            @(negedge clk);
            a_addr = i * 4;

            @(posedge clk);
            #1;

            if (rom_data !== ff_data) begin
                $display(
                    "ERROR word %0d addr=%08x ROM=%08x FF=%08x",
                    i, a_addr, rom_data, ff_data
                );
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("PASS: las 97 instrucciones coinciden.");
        else
            $display("FAIL: %0d diferencias encontradas.", errors);

        $finish;
    end

endmodule