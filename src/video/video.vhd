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
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY video IS
	GENERIC (
		res_h     : natural := 320;
		res_v     : natural := 240;
		w_data	: natural := 8
	);
	PORT (
		clk : IN    std_logic;
		-- memory read
		rd_en   : OUT   std_logic;
		rd_addr : OUT   unsigned(bits_of(res_h * res_v - 1) - 1 DOWNTO 0);
		rd_data : IN    std_logic_vector(w_data - 1 DOWNTO 0);
		-- display
		rgb    : OUT   std_logic_vector(23 DOWNTO 0);
		h_sync : OUT   std_logic;
		v_sync : OUT   std_logic;
		de     : OUT   std_logic
	);
END ENTITY video;

ARCHITECTURE structural OF video IS

	CONSTANT w_addr : natural := bits_of(res_h * res_v - 1);

	SIGNAL px, py : unsigned(9 DOWNTO 0);
	SIGNAL de0    : std_logic;
	SIGNAL hs0    : std_logic;
	SIGNAL vs0    : std_logic;
	SIGNAL de_d   : std_logic_vector(2 DOWNTO 0);
	SIGNAL hs_d   : std_logic_vector(2 DOWNTO 0);
	SIGNAL vs_d   : std_logic_vector(2 DOWNTO 0);

	SIGNAL fb_x      : unsigned(bits_of(res_h - 1) - 1 DOWNTO 0);
	SIGNAL fb_y      : unsigned(bits_of(res_v - 1) - 1 DOWNTO 0);
	SIGNAL addr_comb : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL iter8     : std_logic_vector(7 DOWNTO 0);

BEGIN

	SYNC : ENTITY work.vga_sync
		PORT MAP (
			clk			=> clk,
			v_sync         => vs0,
			h_sync         => hs0,
			active_area	=> de0,
			x              => px,
			y              => py
		);

	-- 2x pixel and line repeat: screen (px,py) → FB (px/2, py/2)
	-- IMPORTANT: unsigned * natural keeps left'length — must widen before *RES_H
	-- (Tang: to_unsigned(RES_H,9)*a_m+b_m). Otherwise addr wraps every 256 and shears.
	fb_x      <= resize(px(9 DOWNTO 1), fb_x'LENGTH);
	fb_y      <= resize(py(9 DOWNTO 1), fb_y'LENGTH);
	addr_comb <= resize(to_unsigned(res_h, 9) * fb_y + resize(fb_x, 9), w_addr);

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			rd_en   <= '1';
			rd_addr <= addr_comb;
			de_d    <= de_d(1 DOWNTO 0) & de0;
			hs_d    <= hs_d(1 DOWNTO 0) & hs0;
			vs_d    <= vs_d(1 DOWNTO 0) & vs0;
		END IF;

	END PROCESS;

	-- zero-extend / truncate stored data to 8-bit iter for palette
	iter8 <= STD_LOGIC_VECTOR(resize(UNSIGNED(rd_data), 8));

	PAL : ENTITY work.palette
		PORT MAP (
			clk  => clk,
			iter => iter8,
			rgb  => rgb
		);

	h_sync <= hs_d(2);
	v_sync <= vs_d(2);
	de     <= de_d(2);

END ARCHITECTURE structural;
