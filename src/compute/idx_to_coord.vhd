-- idx_to_coord: converts a pixel index to a coordinate

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

	CONSTANT w_idx : natural := bits_of(res - 1);

	SIGNAL center_r    : signed(k - 1 DOWNTO 0);
	SIGNAL idx_r       : unsigned(w_idx - 1 DOWNTO 0);
	SIGNAL zoom_r      : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL valid_out_r : std_logic;

	SIGNAL   two_idx     : signed(bits_of(2 * (res - 1)) DOWNTO 0); -- 0 to 2*(RES-1) -> bits_of(2*(RES-1)) + 1 bits (+1 for sign bit)
	CONSTANT res_minus_1 : signed(two_idx'HIGH DOWNTO 0) := TO_SIGNED(res - 1, two_idx'LENGTH);
	SIGNAL   diff        : signed(bits_of(res - 1) DOWNTO 0);       -- -(RES-1) to RES-1 -> bits_of(RES-1) + 1 bits (+1 for sign bit)
	SIGNAL   prod        : signed(ratio'LENGTH + diff'LENGTH - 1 DOWNTO 0);
	SIGNAL   shift       : signed(k - 1 DOWNTO 0);

BEGIN

	valid_out <= valid_out_r;

	two_idx <= SIGNED(SHIFT_LEFT(RESIZE(idx_r, two_idx'LENGTH), 1));            -- 2*idx
	diff    <= RESIZE(two_idx - res_minus_1, diff'LENGTH);                      -- diff = 2*idx - (RES-1)
	prod    <= diff * ratio;                                                    -- prod = diff * RATIO
	shift   <= RESIZE(SHIFT_RIGHT(prod, TO_INTEGER(zoom_r) + 1), shift'LENGTH); -- shift = prod / 2^(zoom+1)

	coord <= center_r + shift; -- coord = center + shift

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				valid_out_r <= '0';
			ELSIF (en = '1') THEN
				center_r    <= center;
				idx_r       <= idx;
				zoom_r      <= zoom;
				valid_out_r <= valid_in;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
