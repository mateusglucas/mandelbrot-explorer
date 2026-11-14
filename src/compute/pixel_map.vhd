-- pixel_map: (row,col) + centers/zoom → (x, y, addr)
-- Two idx_to_coord + calc_addr in parallel; outputs aligned to max latency.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY pixel_map IS
	GENERIC(
		K			: NATURAL := 36;
		RES_H		: NATURAL := 320;
		RES_V		: NATURAL := 240;
		W_ZOOM		: NATURAL := 5;
		RATIO		: SIGNED;
		LAT_COORD	: NATURAL := 1;  -- latency of idx_to_coord
		LAT_ADDR	: NATURAL := 1   -- latency of calc_addr
	);
	PORT(
		clk			: IN  STD_LOGIC;
		rst			: IN  STD_LOGIC;
		en			: IN  STD_LOGIC;
		valid_in	: IN  STD_LOGIC;
		row			: IN  UNSIGNED(bits_of(RES_V - 1) - 1 DOWNTO 0);
		col			: IN  UNSIGNED(bits_of(RES_H - 1) - 1 DOWNTO 0);
		center_x	: IN  SIGNED(K - 1 DOWNTO 0);
		center_y	: IN  SIGNED(K - 1 DOWNTO 0);
		zoom		: IN  UNSIGNED(W_ZOOM - 1 DOWNTO 0);
		x			: OUT SIGNED(K - 1 DOWNTO 0);
		y			: OUT SIGNED(K - 1 DOWNTO 0);
		addr		: OUT UNSIGNED(bits_of(RES_H * RES_V - 1) - 1 DOWNTO 0);
		-- post-align observation (must stay equal)
		valid_x		: OUT STD_LOGIC;
		valid_y		: OUT STD_LOGIC;
		valid_addr	: OUT STD_LOGIC;
		valid_out	: OUT STD_LOGIC
	);
END pixel_map;

ARCHITECTURE structural OF pixel_map IS
	CONSTANT LAT_MAX	: NATURAL := maximum(LAT_COORD, LAT_ADDR);
	CONSTANT DL_COORD	: NATURAL := LAT_MAX - LAT_COORD;
	CONSTANT DL_ADDR	: NATURAL := LAT_MAX - LAT_ADDR;
	CONSTANT W_ADDR		: NATURAL := bits_of(RES_H * RES_V - 1);

	SIGNAL x_raw		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL y_raw		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL addr_raw		: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL vx_raw		: STD_LOGIC;
	SIGNAL vy_raw		: STD_LOGIC;
	SIGNAL va_raw		: STD_LOGIC;

	SIGNAL x_d			: STD_LOGIC_VECTOR(K - 1 DOWNTO 0);
	SIGNAL y_d			: STD_LOGIC_VECTOR(K - 1 DOWNTO 0);
	SIGNAL addr_d		: STD_LOGIC_VECTOR(W_ADDR - 1 DOWNTO 0);
	SIGNAL vx_d			: STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL vy_d			: STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL va_d			: STD_LOGIC_VECTOR(0 DOWNTO 0);
BEGIN
	u_x: ENTITY work.idx_to_coord
		GENERIC MAP(
			K		=> K,
			RES		=> RES_H,
			W_ZOOM	=> W_ZOOM,
			RATIO	=> RATIO
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			center		=> center_x,
			idx			=> col,
			zoom		=> zoom,
			coord		=> x_raw,
			valid_out	=> vx_raw
		);

	u_y: ENTITY work.idx_to_coord
		GENERIC MAP(
			K		=> K,
			RES		=> RES_V,
			W_ZOOM	=> W_ZOOM,
			RATIO	=> RATIO
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			center		=> center_y,
			idx			=> row,
			zoom		=> zoom,
			coord		=> y_raw,
			valid_out	=> vy_raw
		);

	u_addr: ENTITY work.calc_addr
		GENERIC MAP(
			RES_H	=> RES_H,
			RES_V	=> RES_V
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			row			=> row,
			col			=> col,
			addr		=> addr_raw,
			valid_out	=> va_raw
		);

	-- pad shorter paths to LAT_MAX
	d_x: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_COORD, W => K)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => std_logic_vector(x_raw), q => x_d);

	d_y: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_COORD, W => K)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => std_logic_vector(y_raw), q => y_d);

	d_addr: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_ADDR, W => W_ADDR)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => std_logic_vector(addr_raw), q => addr_d);

	d_vx: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_COORD, W => 1)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => (0 => vx_raw), q => vx_d);

	d_vy: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_COORD, W => 1)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => (0 => vy_raw), q => vy_d);

	d_va: ENTITY work.pipe_delay
		GENERIC MAP(N => DL_ADDR, W => 1)
		PORT MAP(clk => clk, rst => rst, en => en,
			d => (0 => va_raw), q => va_d);

	x			<= signed(x_d);
	y			<= signed(y_d);
	addr		<= unsigned(addr_d);
	valid_x		<= vx_d(0);
	valid_y		<= vy_d(0);
	valid_addr	<= va_d(0);
	valid_out	<= vx_d(0) AND vy_d(0) AND va_d(0);
END structural;
