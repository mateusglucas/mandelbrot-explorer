-- mandelbrot_core: fractal compute path
--   UART → navigator
--   scheduler → pixel_map → iterator → memory
--   video reads memory (clk_rd domain)
--
-- Control:
--   en(scheduler, pixel_map) = empty
--   load = empty AND valid_out
--   nav_pulse = OR(inc/dec) → rst of scheduler, pixel_map, iterator
--   navigator / memory write side: rst_global only
--   wr_en = done

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY mandelbrot_core IS
	GENERIC (
		k			: natural := 36;
		i			: natural := 4;
		res_h		: natural := 320;
		res_v		: natural := 240;
		max_iter     : natural := 255;
		zoom_max     : natural := 31;
		w_data       : natural := 8;	-- store iter bits for palette
		delta		: signed;          -- pan step at zoom=0
		ratio		: signed;          -- coord units per pixel at zoom=0
		lat_coord	: natural := 2;
		lat_addr     : natural := 1
	);
	PORT (
		clk : IN    std_logic;
		rst : IN    std_logic; -- global reset

		-- nav pulses (from UART / commands)
		inc_x       : IN    std_logic;
		dec_x       : IN    std_logic;
		inc_y       : IN    std_logic;
		dec_y       : IN    std_logic;
		inc_zoom	: IN    std_logic;
		dec_zoom	: IN    std_logic;

		zoom_out	: OUT   unsigned(bits_of(zoom_max) - 1 DOWNTO 0);

		-- memory read port (video)
		clk_rd  : IN    std_logic;
		rd_en   : IN    std_logic;
		rd_addr : IN    unsigned(bits_of(res_h * res_v - 1) - 1 DOWNTO 0);
		rd_data : OUT   std_logic_vector(w_data - 1 DOWNTO 0)
	);
END ENTITY mandelbrot_core;

ARCHITECTURE structural OF mandelbrot_core IS

	CONSTANT w_zoom   : natural := bits_of(zoom_max);
	CONSTANT w_addr   : natural := bits_of(res_h * res_v - 1);
	CONSTANT w_iter   : natural := bits_of(max_iter);
	CONSTANT mem_size : natural := res_h * res_v;
	CONSTANT w_row    : natural := bits_of(res_v - 1);
	CONSTANT w_col    : natural := bits_of(res_h - 1);

	SIGNAL nav_pulse      : std_logic;
	SIGNAL rst_compute	: std_logic;

	SIGNAL center_x : signed(k - 1 DOWNTO 0);
	SIGNAL center_y : signed(k - 1 DOWNTO 0);
	SIGNAL zoom     : unsigned(w_zoom - 1 DOWNTO 0);

	SIGNAL empty : std_logic;
	SIGNAL en    : std_logic;

	SIGNAL row			: unsigned(w_row - 1 DOWNTO 0);
	SIGNAL col			: unsigned(w_col - 1 DOWNTO 0);
	SIGNAL sched_valid	: std_logic;

	SIGNAL x         : signed(k - 1 DOWNTO 0);
	SIGNAL y         : signed(k - 1 DOWNTO 0);
	SIGNAL addr      : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL valid_out : std_logic;

	SIGNAL load     : std_logic;
	SIGNAL done     : std_logic;
	SIGNAL iter     : unsigned(w_iter - 1 DOWNTO 0);
	SIGNAL addr_out : unsigned(w_addr - 1 DOWNTO 0);

	SIGNAL wr_data : std_logic_vector(w_data - 1 DOWNTO 0);

BEGIN

	-- any navigation change restarts the compute pipeline
	nav_pulse   <= inc_x OR dec_x OR inc_y OR dec_y OR inc_zoom OR dec_zoom;
	rst_compute <= rst OR nav_pulse;

	en   <= empty;
	load <= empty AND valid_out;

	-- store low W_DATA bits of iter (palette expects raw count)
	wr_data <= std_logic_vector(resize(iter, w_data));

	U_NAV : ENTITY work.navigator
		GENERIC MAP (
			k           => k,
			zoom_max	=> zoom_max,
			delta       => delta
		)
		PORT MAP (
			clk      => clk,
			rst      => rst,
			inc_x    => inc_x,
			dec_x    => dec_x,
			inc_y    => inc_y,
			dec_y    => dec_y,
			inc_zoom => inc_zoom,
			dec_zoom => dec_zoom,
			center_x => center_x,
			center_y => center_y,
			zoom     => zoom
		);

	zoom_out <= zoom;

	U_SCHED : ENTITY work.scheduler
		GENERIC MAP (
			res_h	=> res_h,
			res_v	=> res_v
		)
		PORT MAP (
			clk   => clk,
			rst   => rst_compute,
			en    => en,
			row   => row,
			col   => col,
			valid => sched_valid
		);

	U_MAP : ENTITY work.pixel_map
		GENERIC MAP (
			k			=> k,
			res_h		=> res_h,
			res_v		=> res_v,
			w_zoom       => W_ZOOM,
			ratio		=> ratio,
			lat_coord	=> lat_coord,
			lat_addr     => lat_addr
		)
		PORT MAP (
			clk           => clk,
			rst           => rst_compute,
			en			=> en,
			valid_in      => sched_valid,
			row           => row,
			col           => col,
			center_x      => center_x,
			center_y      => center_y,
			zoom          => zoom,
			x             => x,
			y             => y,
			addr          => addr,
			valid_x       => OPEN,
			valid_y       => OPEN,
			valid_addr	=> OPEN,
			valid_out     => valid_out
		);

	U_ITER : ENTITY work.iterator
		GENERIC MAP (
			k        => k,
			i        => i,
			max_iter => max_iter,
			w_addr   => W_ADDR
		)
		PORT MAP (
			clk      => clk,
			rst      => rst_compute,
			load     => load,
			x_c      => x,
			y_c      => y,
			addr     => addr,
			done     => done,
			iter     => iter,
			addr_out => addr_out,
			empty    => empty
		);

	U_MEM : ENTITY work.memory
		GENERIC MAP (
			w_data   => w_data,
			mem_size => MEM_SIZE
		)
		PORT MAP (
			clk_wr  => clk,
			wr_en   => done,
			wr_addr => addr_out,
			wr_data => wr_data,
			clk_rd  => clk_rd,
			rd_en   => rd_en,
			rd_addr => rd_addr,
			rd_data => rd_data
		);

END ARCHITECTURE structural;
