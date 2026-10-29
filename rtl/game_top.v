module game_top (
    input  wire       i_Clk,

    output wire [3:0] o_LED,
    input  wire [3:0] i_Switch,

    output wire       o_Segment1_A,
    output wire       o_Segment1_B,
    output wire       o_Segment1_C,
    output wire       o_Segment1_D,
    output wire       o_Segment1_E,
    output wire       o_Segment1_F,
    output wire       o_Segment1_G,

    output wire       o_Segment2_A,
    output wire       o_Segment2_B,
    output wire       o_Segment2_C,
    output wire       o_Segment2_D,
    output wire       o_Segment2_E,
    output wire       o_Segment2_F,
    output wire       o_Segment2_G
);

    // ----------------------------------------------------------
    // FPGA-specific power-on reset
    // ----------------------------------------------------------

    reg [15:0] por_cnt = 16'd0;
    reg        rst_q   = 1'b0;

    always @(posedge i_Clk) begin
        if (por_cnt != 16'hFFFF)
            por_cnt <= por_cnt + 16'd1;

        rst_q <= (por_cnt == 16'hFFFF);
    end


    // ----------------------------------------------------------
    // Internal logical 7-segment signals
    // ----------------------------------------------------------

    wire soc_Segment1_A;
    wire soc_Segment1_B;
    wire soc_Segment1_C;
    wire soc_Segment1_D;
    wire soc_Segment1_E;
    wire soc_Segment1_F;
    wire soc_Segment1_G;

    wire soc_Segment2_A;
    wire soc_Segment2_B;
    wire soc_Segment2_C;
    wire soc_Segment2_D;
    wire soc_Segment2_E;
    wire soc_Segment2_F;
    wire soc_Segment2_G;


    // SPI exists in the SoC but is not exposed by the FPGA wrapper.
    wire unused_spi_miso;


    // ----------------------------------------------------------
    // Pochoco SoC
    // ----------------------------------------------------------

    pochoco_soc #(
        .MemFile("sw/game.hex")
    ) u_soc (
        .i_Clk        (i_Clk),
        .i_Reset_n    (rst_q),

        // SPI disabled in FPGA implementation
        .i_SPI_SCLK   (1'b0),
        .i_SPI_MOSI   (1'b0),
        .i_SPI_CS_n   (1'b1),
        .o_SPI_MISO   (unused_spi_miso),

        .o_LED        (o_LED),
        .i_Switch     (i_Switch),

        .o_Segment1_A (soc_Segment1_A),
        .o_Segment1_B (soc_Segment1_B),
        .o_Segment1_C (soc_Segment1_C),
        .o_Segment1_D (soc_Segment1_D),
        .o_Segment1_E (soc_Segment1_E),
        .o_Segment1_F (soc_Segment1_F),
        .o_Segment1_G (soc_Segment1_G),

        .o_Segment2_A (soc_Segment2_A),
        .o_Segment2_B (soc_Segment2_B),
        .o_Segment2_C (soc_Segment2_C),
        .o_Segment2_D (soc_Segment2_D),
        .o_Segment2_E (soc_Segment2_E),
        .o_Segment2_F (soc_Segment2_F),
        .o_Segment2_G (soc_Segment2_G)
    );


    // ----------------------------------------------------------
    // Go Board displays are active-low.
    // This inversion belongs to the FPGA wrapper, not the SoC.
    // ----------------------------------------------------------

    assign o_Segment1_A = ~soc_Segment1_A;
    assign o_Segment1_B = ~soc_Segment1_B;
    assign o_Segment1_C = ~soc_Segment1_C;
    assign o_Segment1_D = ~soc_Segment1_D;
    assign o_Segment1_E = ~soc_Segment1_E;
    assign o_Segment1_F = ~soc_Segment1_F;
    assign o_Segment1_G = ~soc_Segment1_G;

    assign o_Segment2_A = ~soc_Segment2_A;
    assign o_Segment2_B = ~soc_Segment2_B;
    assign o_Segment2_C = ~soc_Segment2_C;
    assign o_Segment2_D = ~soc_Segment2_D;
    assign o_Segment2_E = ~soc_Segment2_E;
    assign o_Segment2_F = ~soc_Segment2_F;
    assign o_Segment2_G = ~soc_Segment2_G;

endmodule