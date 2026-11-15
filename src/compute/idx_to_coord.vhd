-- idx_to_coord: converts a pixel index to a coordinate
-- latency 2 (en=1): stage1 diff, stage2 prod=diff*ratio; coord combo from stage2

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY idx_to_coord IS
	GENERIC (
		k      : natural := 36; -- number of bits of coordinates
		res    : natural;       -- pixels resolution
		w_zoom : natural := 5;  -- bits_of(zoom)
		ratio  : signed         -- units of coord per pixel at zoom=0
	);
	PORT (
		clk          : IN    std_logic;
		rst          : IN    std_logic;
		en           : IN    std_logic;
		valid_in     : IN    std_logic;
		center       : IN    signed(k - 1 DOWNTO 0);
		idx          : IN    unsigned(bits_of(res - 1) - 1 DOWNTO 0); -- 0 to RES-1
		zoom         : IN    unsigned(w_zoom - 1 DOWNTO 0);
		coord		: OUT   signed(k - 1 DOWNTO 0);
		valid_out	: OUT   std_logic
	);
END ENTITY idx_to_coord;

ARCHITECTURE behavioral OF idx_to_coord IS

	SIGNAL center_1 : signed(k - 1 DOWNTO 0);
	SIGNAL center_2 : signed(k - 1 DOWNTO 0);

	SIGNAL zoom_1 : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL zoom_2 : unsigned(w_zoom - 1 DOWNTO 0);

	SIGNAL valid : std_logic_vector(1 DOWNTO 0);

	CONSTANT res_minus_1 : unsigned(bits_of(res - 1) - 1 DOWNTO 0) := TO_UNSIGNED(res - 1, bits_of(res - 1));
	SIGNAL   diff        : signed(bits_of(res - 1) DOWNTO 0);       -- -(RES-1) to RES-1 -> bits_of(RES-1) + 1 bits (+1 for sign bit)
	SIGNAL   prod        : signed(ratio'LENGTH + diff'LENGTH - 1 DOWNTO 0);
	SIGNAL   shift       : signed(k - 1 DOWNTO 0);

BEGIN

	valid_out <= valid(1);

	shift <= RESIZE(SHIFT_RIGHT(prod, TO_INTEGER(zoom_2) + 1), shift'LENGTH); -- shift = prod / 2^(zoom+1)
	coord <= center_2 + shift;                                                -- coord = center + shift

	PROCESS (clk) IS

		VARIABLE two_idx : signed(bits_of(2 * (res - 1)) DOWNTO 0); -- 0 to 2*(RES-1) -> bits_of(2*(RES-1)) + 1 bits (+1 for sign bit)

	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				valid <= (OTHERS => '0');
			ELSIF (en = '1') THEN
				-- first stage
				center_1 <= center;
				zoom_1   <= zoom;
				two_idx  := SIGNED(SHIFT_LEFT(RESIZE(idx, two_idx'LENGTH), 1));                         -- 2*idx
				diff     <= RESIZE(two_idx - SIGNED(RESIZE(res_minus_1, two_idx'LENGTH)), diff'LENGTH); -- diff = 2*idx - (RES-1)

				-- second stage
				center_2 <= center_1;
				zoom_2   <= zoom_1;
				prod     <= diff * ratio;

				-- valid signals
				valid(0) <= valid_in;
				valid(1) <= valid(0);
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
