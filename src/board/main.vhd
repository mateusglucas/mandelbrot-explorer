-- Board top: Tang Nano 20K (GW2AR-18C)
--
-- clk_calc (138 MHz): UART → commands → mandelbrot_core write path
-- pclk (25.2 MHz): video readout → palette → HDMI 640x480@60
-- Frame buffer is 320x240 BSRAM; video repeats pixels/lines 2x

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY main IS
	PORT (
		clk_27		: IN    std_logic;
		uart_rx       : IN    std_logic;
		led           : OUT   std_logic_vector(5 DOWNTO 0);  -- active low
		tmds_clk_p	: OUT   std_logic;
		tmds_clk_n	: OUT   std_logic;
		tmds_d_p      : OUT   std_logic_vector(2 DOWNTO 0);
		tmds_d_n      : OUT   std_logic_vector(2 DOWNTO 0)
	);
END ENTITY main;

ARCHITECTURE structural OF main IS

	-- clk_calc = 27*(FBDIV+1)/(IDIV+1) = 138 MHz (VCO = 552 MHz; PFD = 3 MHz)
	-- ~15% below Fmax ~162 MHz (coord registered + 4-stage iterator + barrel N=2).
	CONSTANT calc_idiv   : integer := 8;
	CONSTANT calc_fbdiv  : integer := 45;
	CONSTANT calc_odiv   : integer := 4;
	CONSTANT clk_calc_hz : natural := 138_000_000;

	CONSTANT k        : natural := 36;
	CONSTANT res_h    : natural := 320;
	CONSTANT res_v    : natural := 240;
	CONSTANT max_iter : natural := 255;
	CONSTANT zoom_max : natural := 31;
	CONSTANT w_data   : natural := 8;
	CONSTANT w_zoom   : natural := bits_of(zoom_max);
	CONSTANT w_addr   : natural := bits_of(res_h * res_v - 1);

	-- pixel step at zoom 0 ≈ 4/320 = 3/240 in Q32 (same as Tang BASE)
	CONSTANT ratio_c : signed(k - 1 DOWNTO 0) := to_signed(16#03333333#, k);
	-- pan step = 8 pixels at zoom 0
	CONSTANT delta_c : signed(k - 1 DOWNTO 0) := shift_left(ratio_c, 3);

	COMPONENT clkdiv IS
		GENERIC (
			div_mode : string := "2";
			gsren    : string := "false"
		);
		PORT (
			hclkin : IN    std_logic;
			resetn : IN    std_logic;
			calib  : IN    std_logic;
			clkout : OUT   std_logic
		);
	END COMPONENT clkdiv;

	SIGNAL clk_calc, lock_calc	: std_logic;
	SIGNAL clk_ser,  lock_ser     : std_logic;
	SIGNAL pclk                   : std_logic;

	SIGNAL por_cnt      : unsigned(15 DOWNTO 0);
	SIGNAL por          : std_logic;
	SIGNAL rst          : std_logic;
	SIGNAL rst_pix_sync : std_logic_vector(1 DOWNTO 0);
	SIGNAL rst_pix      : std_logic;

	SIGNAL rx_data            : std_logic_vector(7 DOWNTO 0);
	SIGNAL rx_valid           : std_logic;
	SIGNAL inc_x,    dec_x    : std_logic;
	SIGNAL inc_y,    dec_y    : std_logic;
	SIGNAL inc_zoom, dec_zoom : std_logic;
	SIGNAL cmd_reset          : std_logic;

	SIGNAL zoom      : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL heartbeat : unsigned(26 DOWNTO 0);

	SIGNAL rd_en   : std_logic;
	SIGNAL rd_addr : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL rd_data : std_logic_vector(w_data - 1 DOWNTO 0);

	SIGNAL rgb    : std_logic_vector(23 DOWNTO 0);
	SIGNAL h_sync : std_logic;
	SIGNAL v_sync : std_logic;
	SIGNAL de     : std_logic;

BEGIN

	---------------------------------------------------------------------------
	-- clocks
	---------------------------------------------------------------------------
	PLL_CALC : ENTITY work.pll
		GENERIC MAP (
			fclkin       => "27",
			idiv_sel     => CALC_IDIV,
			fbdiv_sel	=> CALC_FBDIV,
			odiv_sel     => CALC_ODIV
		)
		PORT MAP (
			clkin  => clk_27,
			clkout => clk_calc,
			lock   => lock_calc
		);

	-- 126 MHz = 5x pixel clock (VCO = 504 MHz)
	PLL_SER : ENTITY work.pll
		GENERIC MAP (
			fclkin       => "27",
			idiv_sel     => 2,
			fbdiv_sel	=> 13,
			odiv_sel     => 4
		)
		PORT MAP (
			clkin  => clk_27,
			clkout => clk_ser,
			lock   => lock_ser
		);

	DIV_PIX : COMPONENT clkdiv
		GENERIC MAP (
			div_mode => "5", gsren => "false"
		)
		PORT MAP (
			hclkin => clk_ser,
			resetn => lock_ser,
			calib  => '0',
			clkout => pclk
		);

	---------------------------------------------------------------------------
	-- resets
	---------------------------------------------------------------------------
	PROCESS (clk_calc, lock_calc) IS
	BEGIN

		IF (lock_calc = '0') THEN
			por_cnt <= (OTHERS => '0');
			por     <= '1';
		ELSIF RISING_EDGE(clk_calc) THEN
			IF (por_cnt /= x"FFFF") THEN
				por_cnt <= por_cnt + 1;
				por     <= '1';
			ELSE
				por <= '0';
			END IF;
		END IF;

	END PROCESS;

	PROCESS (clk_calc) IS
	BEGIN

		IF RISING_EDGE(clk_calc) THEN
			rst       <= por OR cmd_reset;
			heartbeat <= heartbeat + 1;
		END IF;

	END PROCESS;

	PROCESS (pclk, lock_ser) IS
	BEGIN

		IF (lock_ser = '0') THEN
			rst_pix_sync <= (OTHERS => '1');
		ELSIF RISING_EDGE(pclk) THEN
			rst_pix_sync <= rst_pix_sync(0) & '0';
		END IF;

	END PROCESS;

	rst_pix <= rst_pix_sync(1);

	---------------------------------------------------------------------------
	-- UART → nav pulses
	---------------------------------------------------------------------------
	RX : ENTITY work.uart_rx
		GENERIC MAP (
			clk_hz => CLK_CALC_HZ, baud => 115_200
		)
		PORT MAP (
			clk   => clk_calc,
			rx    => uart_rx,
			data  => rx_data,
			valid => rx_valid
		);

	CMD : ENTITY work.commands
		PORT MAP (
			clk      => clk_calc,
			data     => rx_data,
			valid    => rx_valid,
			inc_x    => inc_x,
			dec_x    => dec_x,
			inc_y    => inc_y,
			dec_y    => dec_y,
			inc_zoom => inc_zoom,
			dec_zoom => dec_zoom,
			reset    => cmd_reset
		);

	---------------------------------------------------------------------------
	-- compute + frame buffer
	---------------------------------------------------------------------------
	MB : ENTITY work.mandelbrot_core
		GENERIC MAP (
			k        => K,
			res_h    => RES_H,
			res_v    => RES_V,
			max_iter => MAX_ITER,
			zoom_max => ZOOM_MAX,
			w_data   => W_DATA,
			delta    => DELTA_C,
			ratio    => RATIO_C
		)
		PORT MAP (
			clk      => clk_calc,
			rst      => rst,
			inc_x    => inc_x,
			dec_x    => dec_x,
			inc_y    => inc_y,
			dec_y    => dec_y,
			inc_zoom => inc_zoom,
			dec_zoom => dec_zoom,
			zoom_out => zoom,
			clk_rd   => pclk,
			rd_en    => rd_en,
			rd_addr  => rd_addr,
			rd_data  => rd_data
		);

	led(4 DOWNTO 0) <= NOT STD_LOGIC_VECTOR(resize(zoom, 5));
	led(5)          <= NOT heartbeat(26);

	---------------------------------------------------------------------------
	-- video + HDMI
	---------------------------------------------------------------------------
	VID : ENTITY work.video
		GENERIC MAP (
			res_h => RES_H, res_v => RES_V, w_data => W_DATA
		)
		PORT MAP (
			clk     => pclk,
			rst     => rst_pix,
			rd_en   => rd_en,
			rd_addr => rd_addr,
			rd_data => rd_data,
			rgb     => rgb,
			h_sync  => h_sync,
			v_sync  => v_sync,
			de      => de
		);

	HDMI : ENTITY work.hdmi_tx
		PORT MAP (
			pclk          => pclk,
			sclk          => clk_ser,
			rst           => rst_pix,
			rgb           => rgb,
			de			=> de,
			h_sync		=> h_sync,
			v_sync		=> v_sync,
			tmds_clk_p	=> tmds_clk_p,
			tmds_clk_n	=> tmds_clk_n,
			tmds_d_p      => tmds_d_p,
			tmds_d_n      => tmds_d_n
		);

END ARCHITECTURE structural;
