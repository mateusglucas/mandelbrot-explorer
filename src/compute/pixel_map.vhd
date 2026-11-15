-- pixel_map: (row,col) + centers/zoom → (x, y, addr)
-- Two idx_to_coord + calc_addr in parallel; outputs aligned to max latency.

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY pixel_map IS
	GENERIC (
		k			: natural := 36;
		res_h		: natural := 320;
		res_v		: natural := 240;
		w_zoom       : natural := 5;
		ratio		: signed;
		lat_coord	: natural := 3; -- latency of idx_to_coord
		lat_addr     : natural := 1  -- latency of calc_addr
	);
	PORT (
		clk      : IN    std_logic;
		rst      : IN    std_logic;
		en       : IN    std_logic;
		valid_in : IN    std_logic;
		row      : IN    unsigned(bits_of(res_v - 1) - 1 DOWNTO 0);
		col      : IN    unsigned(bits_of(res_h - 1) - 1 DOWNTO 0);
		center_x : IN    signed(k - 1 DOWNTO 0);
		center_y : IN    signed(k - 1 DOWNTO 0);
		zoom     : IN    unsigned(w_zoom - 1 DOWNTO 0);
		x        : OUT   signed(k - 1 DOWNTO 0);
		y        : OUT   signed(k - 1 DOWNTO 0);
		addr     : OUT   unsigned(bits_of(res_h * res_v - 1) - 1 DOWNTO 0);
		-- post-align observation (must stay equal)
		valid_x       : OUT   std_logic;
		valid_y       : OUT   std_logic;
		valid_addr	: OUT   std_logic;
		valid_out     : OUT   std_logic
	);
END ENTITY pixel_map;

ARCHITECTURE structural OF pixel_map IS

	CONSTANT lat_max  : natural := maximum(lat_coord, lat_addr);
	CONSTANT dl_coord : natural := lat_max - lat_coord;
	CONSTANT dl_addr  : natural := lat_max - lat_addr;
	CONSTANT w_addr   : natural := bits_of(res_h * res_v - 1);

	SIGNAL x_raw    : signed(k - 1 DOWNTO 0);
	SIGNAL y_raw    : signed(k - 1 DOWNTO 0);
	SIGNAL addr_raw : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL vx_raw   : std_logic;
	SIGNAL vy_raw   : std_logic;
	SIGNAL va_raw   : std_logic;

	SIGNAL x_d    : std_logic_vector(k - 1 DOWNTO 0);
	SIGNAL y_d    : std_logic_vector(k - 1 DOWNTO 0);
	SIGNAL addr_d : std_logic_vector(w_addr - 1 DOWNTO 0);
	SIGNAL vx_d   : std_logic_vector(0 DOWNTO 0);
	SIGNAL vy_d   : std_logic_vector(0 DOWNTO 0);
	SIGNAL va_d   : std_logic_vector(0 DOWNTO 0);

BEGIN

	U_X : ENTITY work.idx_to_coord
		GENERIC MAP (
			k         => k,
			res       => res_h,
			w_zoom	=> w_zoom,
			ratio     => ratio
		)
		PORT MAP (
			clk          => clk,
			rst          => rst,
			en           => en,
			valid_in     => valid_in,
			center       => center_x,
			idx          => col,
			zoom         => zoom,
			coord		=> x_raw,
			valid_out	=> vx_raw
		);

	U_Y : ENTITY work.idx_to_coord
		GENERIC MAP (
			k         => k,
			res       => res_v,
			w_zoom	=> w_zoom,
			ratio     => ratio
		)
		PORT MAP (
			clk          => clk,
			rst          => rst,
			en           => en,
			valid_in     => valid_in,
			center       => center_y,
			idx          => row,
			zoom         => zoom,
			coord		=> y_raw,
			valid_out	=> vy_raw
		);

	U_ADDR : ENTITY work.calc_addr
		GENERIC MAP (
			res_h	=> res_h,
			res_v	=> res_v
		)
		PORT MAP (
			clk          => clk,
			rst          => rst,
			en           => en,
			valid_in     => valid_in,
			row          => row,
			col          => col,
			addr         => addr_raw,
			valid_out	=> va_raw
		);

	-- pad shorter paths to LAT_MAX
	D_X : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_COORD, w => k
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => std_logic_vector(x_raw),
			q   => x_d
		);

	D_Y : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_COORD, w => k
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => std_logic_vector(y_raw),
			q   => y_d
		);

	D_ADDR : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_ADDR, w => W_ADDR
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => std_logic_vector(addr_raw),
			q   => addr_d
		);

	D_VX : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_COORD, w => 1
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => (0 => vx_raw),
			q   => vx_d
		);

	D_VY : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_COORD, w => 1
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => (0 => vy_raw),
			q   => vy_d
		);

	D_VA : ENTITY work.pipe_delay
		GENERIC MAP (
			n => DL_ADDR, w => 1
		)
		PORT MAP (
			clk => clk,
			rst => rst,
			en  => en,
			d   => (0 => va_raw),
			q   => va_d
		);

	x             <= signed(x_d);
	y             <= signed(y_d);
	addr          <= unsigned(addr_d);
	valid_x       <= vx_d(0);
	valid_y       <= vy_d(0);
	valid_addr	<= va_d(0);
	valid_out     <= vx_d(0) AND vy_d(0) AND va_d(0);

END ARCHITECTURE structural;
