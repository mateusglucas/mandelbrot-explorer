-- idx_to_coord: converts a pixel index to a coordinate

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY idx_to_coord IS
	GENERIC(
		K			: NATURAL:=36;  -- number of bits of coordinates
		RES		    : NATURAL;      -- pixels resolution
		W_ZOOM		: NATURAL:=5;   -- bits_of(zoom)
		RATIO		: SIGNED        -- units of coord per pixel at zoom=0
	);
	PORT
	(
		clk			: IN STD_LOGIC;
		rst			: IN STD_LOGIC;
		en			: IN STD_LOGIC;
		center		: IN SIGNED   (K-1 DOWNTO 0);
		idx			: IN UNSIGNED (bits_of(RES-1)-1 DOWNTO 0); -- 0 to RES-1
		zoom		: IN UNSIGNED (W_ZOOM-1 DOWNTO 0);
		coord		: OUT SIGNED  (K-1 DOWNTO 0);
		valid		: OUT STD_LOGIC
	);
END idx_to_coord;

ARCHITECTURE behavioral OF idx_to_coord IS
CONSTANT W_IDX: NATURAL := bits_of(RES-1);

SIGNAL center_r: SIGNED (K-1 DOWNTO 0);
SIGNAL idx_r: UNSIGNED (W_IDX-1 DOWNTO 0);
SIGNAL zoom_r: UNSIGNED (W_ZOOM-1 DOWNTO 0);
SIGNAL valid_r: STD_LOGIC;

SIGNAL two_idx: SIGNED (bits_of(2*(RES-1)) DOWNTO 0); -- 0 to 2*(RES-1) -> bits_of(2*(RES-1)) + 1 bits (+1 for sign bit)
CONSTANT RES_MINUS_1: SIGNED (two_idx'HIGH DOWNTO 0) := TO_SIGNED(RES-1, two_idx'LENGTH);
SIGNAL diff: SIGNED (bits_of(RES-1) DOWNTO 0); -- -(RES-1) to RES-1 -> bits_of(RES-1) + 1 bits (+1 for sign bit)
SIGNAL prod: SIGNED (RATIO'LENGTH + diff'LENGTH - 1 DOWNTO 0);
SIGNAL shift: SIGNED (K-1 DOWNTO 0);

BEGIN
	valid<=valid_r;
	
	two_idx <= SIGNED(SHIFT_LEFT(RESIZE(idx_r, two_idx'LENGTH), 1)); -- 2*idx
	diff <= RESIZE(two_idx - RES_MINUS_1, diff'LENGTH); -- diff = 2*idx - (RES-1)
	prod <= diff * RATIO; -- prod = diff * RATIO
	shift <= RESIZE(SHIFT_RIGHT(prod, TO_INTEGER(zoom_r)+1), shift'LENGTH); -- shift = prod / 2^(zoom+1)

	coord <= center_r + shift; -- coord = center + shift

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF rst='1' THEN
				valid_r <= '0';
			ELSIF en='1' THEN
				center_r <= center;
				idx_r <= idx;
				zoom_r <= zoom;
				valid_r <= '1';
			END IF;
		END IF;
	END PROCESS;
END behavioral;