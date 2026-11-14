-- Board top: Tang Nano 20K (GW2AR-18C)
--
-- clk_calc (~40.5 MHz): UART → commands → mandelbrot_core write path
-- pclk (25.2 MHz): video readout → palette → HDMI 640x480@60
-- Frame buffer is 320x240 BSRAM; video repeats pixels/lines 2x

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY main IS
	PORT(
		clk_27		: IN  STD_LOGIC;
		uart_rx		: IN  STD_LOGIC;
		led			: OUT STD_LOGIC_VECTOR(5 DOWNTO 0);  -- active low
		tmds_clk_p	: OUT STD_LOGIC;
		tmds_clk_n	: OUT STD_LOGIC;
		tmds_d_p	: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
		tmds_d_n	: OUT STD_LOGIC_VECTOR(2 DOWNTO 0)
	);
END main;

ARCHITECTURE structural OF main IS
	-- clk_calc = 27*(FBDIV+1)/(IDIV+1) = 40.5 MHz (VCO = 40.5*16 = 648 MHz)
	-- iterator has combo 36x36 muls; @54 MHz Fmax was only 54.016 (no silicon margin).
	CONSTANT CALC_IDIV		: INTEGER := 1;
	CONSTANT CALC_FBDIV		: INTEGER := 2;
	CONSTANT CALC_ODIV		: INTEGER := 16;
	CONSTANT CLK_CALC_HZ	: NATURAL := 40_500_000;

	CONSTANT K			: NATURAL := 36;
	CONSTANT RES_H		: NATURAL := 320;
	CONSTANT RES_V		: NATURAL := 240;
	CONSTANT MAX_ITER	: NATURAL := 255;
	CONSTANT ZOOM_MAX	: NATURAL := 31;
	CONSTANT W_DATA		: NATURAL := 8;
	CONSTANT W_ZOOM		: NATURAL := bits_of(ZOOM_MAX);
	CONSTANT W_ADDR		: NATURAL := bits_of(RES_H * RES_V - 1);

	-- pixel step at zoom 0 ≈ 4/320 = 3/240 in Q32 (same as Tang BASE)
	CONSTANT RATIO_C : SIGNED(K - 1 DOWNTO 0) := to_signed(16#03333333#, K);
	-- pan step = 8 pixels at zoom 0
	CONSTANT DELTA_C : SIGNED(K - 1 DOWNTO 0) := shift_left(RATIO_C, 3);

	COMPONENT CLKDIV
		GENERIC(
			DIV_MODE : STRING := "2";
			GSREN    : STRING := "false"
		);
		PORT(
			HCLKIN : IN  STD_LOGIC;
			RESETN : IN  STD_LOGIC;
			CALIB  : IN  STD_LOGIC;
			CLKOUT : OUT STD_LOGIC
		);
	END COMPONENT;

	SIGNAL clk_calc, lock_calc	: STD_LOGIC;
	SIGNAL clk_ser, lock_ser	: STD_LOGIC;
	SIGNAL pclk					: STD_LOGIC;

	SIGNAL por_cnt				: UNSIGNED(15 DOWNTO 0) := (OTHERS => '0');
	SIGNAL por					: STD_LOGIC := '1';
	SIGNAL rst					: STD_LOGIC := '1';
	SIGNAL rst_pix_sync			: STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '1');
	SIGNAL rst_pix				: STD_LOGIC;

	SIGNAL rx_data				: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL rx_valid				: STD_LOGIC;
	SIGNAL inc_x, dec_x			: STD_LOGIC;
	SIGNAL inc_y, dec_y			: STD_LOGIC;
	SIGNAL inc_zoom, dec_zoom	: STD_LOGIC;
	SIGNAL cmd_reset			: STD_LOGIC;

	SIGNAL zoom					: UNSIGNED(W_ZOOM - 1 DOWNTO 0);
	SIGNAL heartbeat			: UNSIGNED(26 DOWNTO 0) := (OTHERS => '0');

	SIGNAL rd_en				: STD_LOGIC;
	SIGNAL rd_addr				: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL rd_data				: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);

	SIGNAL rgb					: STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL h_sync, v_sync, de	: STD_LOGIC;
BEGIN

	---------------------------------------------------------------------------
	-- clocks
	---------------------------------------------------------------------------
	PLL_CALC: ENTITY work.pll
		GENERIC MAP(
			FCLKIN		=> "27",
			IDIV_SEL	=> CALC_IDIV,
			FBDIV_SEL	=> CALC_FBDIV,
			ODIV_SEL	=> CALC_ODIV
		)
		PORT MAP(clkin => clk_27, clkout => clk_calc, lock => lock_calc);

	-- 126 MHz = 5x pixel clock (VCO = 504 MHz)
	PLL_SER: ENTITY work.pll
		GENERIC MAP(
			FCLKIN		=> "27",
			IDIV_SEL	=> 2,
			FBDIV_SEL	=> 13,
			ODIV_SEL	=> 4
		)
		PORT MAP(clkin => clk_27, clkout => clk_ser, lock => lock_ser);

	DIV_PIX: CLKDIV
		GENERIC MAP(DIV_MODE => "5", GSREN => "false")
		PORT MAP(HCLKIN => clk_ser, RESETN => lock_ser, CALIB => '0', CLKOUT => pclk);

	---------------------------------------------------------------------------
	-- resets
	---------------------------------------------------------------------------
	PROCESS(clk_calc, lock_calc)
	BEGIN
		IF lock_calc = '0' THEN
			por_cnt <= (OTHERS => '0');
			por <= '1';
		ELSIF RISING_EDGE(clk_calc) THEN
			IF por_cnt /= X"FFFF" THEN
				por_cnt <= por_cnt + 1;
				por <= '1';
			ELSE
				por <= '0';
			END IF;
		END IF;
	END PROCESS;

	PROCESS(clk_calc)
	BEGIN
		IF RISING_EDGE(clk_calc) THEN
			rst <= por OR cmd_reset;
			heartbeat <= heartbeat + 1;
		END IF;
	END PROCESS;

	PROCESS(pclk, lock_ser)
	BEGIN
		IF lock_ser = '0' THEN
			rst_pix_sync <= (OTHERS => '1');
		ELSIF RISING_EDGE(pclk) THEN
			rst_pix_sync <= rst_pix_sync(0) & '0';
		END IF;
	END PROCESS;
	rst_pix <= rst_pix_sync(1);

	---------------------------------------------------------------------------
	-- UART → nav pulses
	---------------------------------------------------------------------------
	RX: ENTITY work.uart_rx
		GENERIC MAP(CLK_HZ => CLK_CALC_HZ, BAUD => 115_200)
		PORT MAP(clk => clk_calc, rx => uart_rx, data => rx_data, valid => rx_valid);

	CMD: ENTITY work.commands
		PORT MAP(
			clk			=> clk_calc,
			data		=> rx_data,
			valid		=> rx_valid,
			inc_x		=> inc_x,
			dec_x		=> dec_x,
			inc_y		=> inc_y,
			dec_y		=> dec_y,
			inc_zoom	=> inc_zoom,
			dec_zoom	=> dec_zoom,
			reset		=> cmd_reset
		);

	---------------------------------------------------------------------------
	-- compute + frame buffer
	---------------------------------------------------------------------------
	MB: ENTITY work.mandelbrot_core
		GENERIC MAP(
			K			=> K,
			RES_H		=> RES_H,
			RES_V		=> RES_V,
			MAX_ITER	=> MAX_ITER,
			ZOOM_MAX	=> ZOOM_MAX,
			W_DATA		=> W_DATA,
			DELTA		=> DELTA_C,
			RATIO		=> RATIO_C
		)
		PORT MAP(
			clk			=> clk_calc,
			rst			=> rst,
			inc_x		=> inc_x,
			dec_x		=> dec_x,
			inc_y		=> inc_y,
			dec_y		=> dec_y,
			inc_zoom	=> inc_zoom,
			dec_zoom	=> dec_zoom,
			zoom_out	=> zoom,
			clk_rd		=> pclk,
			rd_en		=> rd_en,
			rd_addr		=> rd_addr,
			rd_data		=> rd_data
		);

	led(4 DOWNTO 0) <= NOT STD_LOGIC_VECTOR(resize(zoom, 5));
	led(5) <= NOT heartbeat(26);

	---------------------------------------------------------------------------
	-- video + HDMI
	---------------------------------------------------------------------------
	VID: ENTITY work.video
		GENERIC MAP(RES_H => RES_H, RES_V => RES_V, W_DATA => W_DATA)
		PORT MAP(
			clk		=> pclk,
			rd_en	=> rd_en,
			rd_addr	=> rd_addr,
			rd_data	=> rd_data,
			rgb		=> rgb,
			h_sync	=> h_sync,
			v_sync	=> v_sync,
			de		=> de
		);

	HDMI: ENTITY work.hdmi_tx
		PORT MAP(
			pclk		=> pclk,
			sclk		=> clk_ser,
			rst			=> rst_pix,
			rgb			=> rgb,
			de			=> de,
			h_sync		=> h_sync,
			v_sync		=> v_sync,
			tmds_clk_p	=> tmds_clk_p,
			tmds_clk_n	=> tmds_clk_n,
			tmds_d_p	=> tmds_d_p,
			tmds_d_n	=> tmds_d_n
		);
END structural;
