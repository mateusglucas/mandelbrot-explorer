-- mandelbrot: top compute path
--   UART (later) → navigator
--   scheduler → pixel_map → iterator → memory
--   video (later) reads memory
--
-- Control:
--   en(scheduler, pixel_map) = empty
--   load = empty AND valid_out
--   nav_pulse = OR(inc/dec) → rst of scheduler, pixel_map, iterator
--   navigator / memory write side: rst_global only
--   wr_en = done

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY mandelbrot IS
	GENERIC(
		K			: NATURAL := 36;
		I			: NATURAL := 4;
		RES_H		: NATURAL := 320;
		RES_V		: NATURAL := 240;
		MAX_ITER	: NATURAL := 255;
		ZOOM_MAX	: NATURAL := 31;
		W_DATA		: NATURAL := 3;
		DELTA		: SIGNED;		-- pan step at zoom=0
		RATIO		: SIGNED;		-- coord units per pixel at zoom=0
		LAT_COORD	: NATURAL := 1;
		LAT_ADDR	: NATURAL := 1
	);
	PORT(
		clk			: IN  STD_LOGIC;
		rst			: IN  STD_LOGIC;		-- global reset

		-- nav pulses (from UART later)
		inc_x		: IN  STD_LOGIC;
		dec_x		: IN  STD_LOGIC;
		inc_y		: IN  STD_LOGIC;
		dec_y		: IN  STD_LOGIC;
		inc_zoom	: IN  STD_LOGIC;
		dec_zoom	: IN  STD_LOGIC;

		-- memory read port (video later)
		clk_rd		: IN  STD_LOGIC;
		rd_en		: IN  STD_LOGIC;
		rd_addr		: IN  UNSIGNED(bits_of(RES_H * RES_V - 1) - 1 DOWNTO 0);
		rd_data		: OUT STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0)
	);
END mandelbrot;

ARCHITECTURE structural OF mandelbrot IS
	CONSTANT W_ZOOM		: NATURAL := bits_of(ZOOM_MAX);
	CONSTANT W_ADDR		: NATURAL := bits_of(RES_H * RES_V - 1);
	CONSTANT W_ITER		: NATURAL := bits_of(MAX_ITER);
	CONSTANT MEM_SIZE	: NATURAL := RES_H * RES_V;
	CONSTANT W_ROW		: NATURAL := bits_of(RES_V - 1);
	CONSTANT W_COL		: NATURAL := bits_of(RES_H - 1);

	SIGNAL nav_pulse	: STD_LOGIC;
	SIGNAL rst_compute	: STD_LOGIC;

	SIGNAL center_x		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL center_y		: SIGNED(K - 1 DOWNTO 0);
	SIGNAL zoom			: UNSIGNED(W_ZOOM - 1 DOWNTO 0);

	SIGNAL empty		: STD_LOGIC;
	SIGNAL en			: STD_LOGIC;

	SIGNAL row			: UNSIGNED(W_ROW - 1 DOWNTO 0);
	SIGNAL col			: UNSIGNED(W_COL - 1 DOWNTO 0);
	SIGNAL sched_valid	: STD_LOGIC;

	SIGNAL x			: SIGNED(K - 1 DOWNTO 0);
	SIGNAL y			: SIGNED(K - 1 DOWNTO 0);
	SIGNAL addr			: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL valid_out	: STD_LOGIC;

	SIGNAL load			: STD_LOGIC;
	SIGNAL done			: STD_LOGIC;
	SIGNAL iter			: UNSIGNED(W_ITER - 1 DOWNTO 0);
	SIGNAL addr_out		: UNSIGNED(W_ADDR - 1 DOWNTO 0);

	SIGNAL wr_data		: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
BEGIN
	-- any navigation change restarts the compute pipeline
	nav_pulse <= inc_x OR dec_x OR inc_y OR dec_y OR inc_zoom OR dec_zoom;
	rst_compute <= rst OR nav_pulse;

	en   <= empty;
	load <= empty AND valid_out;

	-- colour: top W_DATA bits of iteration count
	wr_data <= std_logic_vector(iter(W_ITER - 1 DOWNTO W_ITER - W_DATA));

	u_nav: ENTITY work.navigator
		GENERIC MAP(
			K			=> K,
			ZOOM_MAX	=> ZOOM_MAX,
			DELTA		=> DELTA
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			inc_x		=> inc_x,
			dec_x		=> dec_x,
			inc_y		=> inc_y,
			dec_y		=> dec_y,
			inc_zoom	=> inc_zoom,
			dec_zoom	=> dec_zoom,
			center_x	=> center_x,
			center_y	=> center_y,
			zoom		=> zoom
		);

	u_sched: ENTITY work.scheduler
		GENERIC MAP(
			RES_H	=> RES_H,
			RES_V	=> RES_V
		)
		PORT MAP(
			clk		=> clk,
			rst		=> rst_compute,
			en		=> en,
			row		=> row,
			col		=> col,
			valid	=> sched_valid
		);

	u_map: ENTITY work.pixel_map
		GENERIC MAP(
			K			=> K,
			RES_H		=> RES_H,
			RES_V		=> RES_V,
			W_ZOOM		=> W_ZOOM,
			RATIO		=> RATIO,
			LAT_COORD	=> LAT_COORD,
			LAT_ADDR	=> LAT_ADDR
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst_compute,
			en			=> en,
			valid_in	=> sched_valid,
			row			=> row,
			col			=> col,
			center_x	=> center_x,
			center_y	=> center_y,
			zoom		=> zoom,
			x			=> x,
			y			=> y,
			addr		=> addr,
			valid_x		=> OPEN,
			valid_y		=> OPEN,
			valid_addr	=> OPEN,
			valid_out	=> valid_out
		);

	u_iter: ENTITY work.iterator
		GENERIC MAP(
			K			=> K,
			I			=> I,
			MAX_ITER	=> MAX_ITER,
			W_ADDR		=> W_ADDR
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst_compute,
			load		=> load,
			x_c			=> x,
			y_c			=> y,
			addr		=> addr,
			done		=> done,
			iter		=> iter,
			addr_out	=> addr_out,
			empty		=> empty
		);

	u_mem: ENTITY work.memory
		GENERIC MAP(
			W_DATA		=> W_DATA,
			MEM_SIZE	=> MEM_SIZE
		)
		PORT MAP(
			clk_wr		=> clk,
			wr_en		=> done,
			wr_addr		=> addr_out,
			wr_data		=> wr_data,
			clk_rd		=> clk_rd,
			rd_en		=> rd_en,
			rd_addr		=> rd_addr,
			rd_data		=> rd_data
		);
END structural;
