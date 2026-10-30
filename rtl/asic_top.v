module asic_top #(
    parameter MemMode = 1
) (
    input  wire       i_Clk,
    input  wire       i_Reset_n,

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
    output wire       o_Segment2_G,

    input  wire       i_SPI_SCLK,
    input  wire       i_SPI_MOSI,
    input  wire       i_SPI_CS_n,
    output wire       o_SPI_MISO
);

    pochoco_soc #(
        .MemMode(MemMode)
    ) u_soc (
        .i_Clk        (i_Clk),
        .i_Reset_n    (i_Reset_n),

        .o_LED        (o_LED),
        .i_Switch     (i_Switch),

        .o_Segment1_A (o_Segment1_A),
        .o_Segment1_B (o_Segment1_B),
        .o_Segment1_C (o_Segment1_C),
        .o_Segment1_D (o_Segment1_D),
        .o_Segment1_E (o_Segment1_E),
        .o_Segment1_F (o_Segment1_F),
        .o_Segment1_G (o_Segment1_G),

        .o_Segment2_A (o_Segment2_A),
        .o_Segment2_B (o_Segment2_B),
        .o_Segment2_C (o_Segment2_C),
        .o_Segment2_D (o_Segment2_D),
        .o_Segment2_E (o_Segment2_E),
        .o_Segment2_F (o_Segment2_F),
        .o_Segment2_G (o_Segment2_G),

        .i_SPI_SCLK   (i_SPI_SCLK),
        .i_SPI_MOSI   (i_SPI_MOSI),
        .i_SPI_CS_n   (i_SPI_CS_n),
        .o_SPI_MISO   (o_SPI_MISO)
    );

endmodule