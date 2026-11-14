-- Video readout for a RES_H x RES_V frame buffer shown as 640x480
-- (each FB pixel/line repeated 2x). Drives memory read ports and
-- emits RGB + sync aligned with palette latency.
--
-- Pipeline (pclk):
--   0: vga_sync (x,y,de,hs,vs)
--   1: rd_addr registered, sync delayed
--   2: memory returns rd_data (external, 1-cycle)
--   3: palette RGB; sync delayed to match

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY video IS
	GENERIC(
		RES_H	: NATURAL := 320;
		RES_V	: NATURAL := 240;
		W_DATA	: NATURAL := 8
	);
	PORT(
		clk			: IN  STD_LOGIC;
		-- memory read
		rd_en		: OUT STD_LOGIC;
		rd_addr		: OUT UNSIGNED(bits_of(RES_H * RES_V - 1) - 1 DOWNTO 0);
		rd_data		: IN  STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
		-- display
		rgb			: OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
		h_sync		: OUT STD_LOGIC;
		v_sync		: OUT STD_LOGIC;
		de			: OUT STD_LOGIC
	);
END video;

ARCHITECTURE structural OF video IS
	CONSTANT W_ADDR : NATURAL := bits_of(RES_H * RES_V - 1);

	SIGNAL px, py			: UNSIGNED(9 DOWNTO 0);
	SIGNAL de0, hs0, vs0	: STD_LOGIC;
	SIGNAL de_d				: STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
	SIGNAL hs_d				: STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
	SIGNAL vs_d				: STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');

	SIGNAL fb_x				: UNSIGNED(bits_of(RES_H - 1) - 1 DOWNTO 0);
	SIGNAL fb_y				: UNSIGNED(bits_of(RES_V - 1) - 1 DOWNTO 0);
	SIGNAL addr_comb		: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL iter8			: STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN
	SYNC: ENTITY work.vga_sync
		PORT MAP(
			clk			=> clk,
			v_sync		=> vs0,
			h_sync		=> hs0,
			active_area	=> de0,
			x			=> px,
			y			=> py
		);

	-- 2x pixel and line repeat: screen (px,py) → FB (px/2, py/2)
	-- IMPORTANT: unsigned * natural keeps left'length — must widen before *RES_H
	-- (Tang: to_unsigned(RES_H,9)*a_m+b_m). Otherwise addr wraps every 256 and shears.
	fb_x <= resize(px(9 DOWNTO 1), fb_x'length);
	fb_y <= resize(py(9 DOWNTO 1), fb_y'length);
	addr_comb <= resize(to_unsigned(RES_H, 9) * fb_y + resize(fb_x, 9), W_ADDR);

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			rd_en  <= '1';
			rd_addr <= addr_comb;
			de_d <= de_d(1 DOWNTO 0) & de0;
			hs_d <= hs_d(1 DOWNTO 0) & hs0;
			vs_d <= vs_d(1 DOWNTO 0) & vs0;
		END IF;
	END PROCESS;

	-- zero-extend / truncate stored data to 8-bit iter for palette
	iter8 <= STD_LOGIC_VECTOR(resize(UNSIGNED(rd_data), 8));

	PAL: ENTITY work.palette
		PORT MAP(
			clk		=> clk,
			iter	=> iter8,
			rgb		=> rgb
		);

	h_sync <= hs_d(2);
	v_sync <= vs_d(2);
	de     <= de_d(2);
END structural;
