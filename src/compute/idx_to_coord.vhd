-- idx_to_coord: converts a pixel index to a coordinate
-- latency n_barrel_stages+3 (en=1): diff, prod/2, n_barrel barrel slices, then registered coord;
-- n_barrel_stages = ceil(w_zoom / zoom_bits_per_stage)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY idx_to_coord IS
	GENERIC (
		k                   : natural := 36; -- number of bits of coordinates
		res                 : natural;       -- pixels resolution
		w_zoom              : natural := 5;  -- bits_of(zoom)
		zoom_bits_per_stage : natural := 2;  -- max zoom bits per barrelstage
		ratio               : signed         -- units of coord per pixel at zoom=0
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

	CONSTANT res_minus_1     : unsigned(bits_of(res - 1) - 1 DOWNTO 0) := TO_UNSIGNED(res - 1, bits_of(res - 1));
	CONSTANT n_barrel_stages : natural                                 := (w_zoom + zoom_bits_per_stage - 1) / zoom_bits_per_stage; -- barrel shifter stages: ceil(w_zoom / zoom_bits_per_stage)
	SIGNAL   diff            : signed(bits_of(res - 1) DOWNTO 0);                                                                   -- -(RES-1) to RES-1 -> bits_of(RES-1) + 1 bits (+1 for sign bit)

	TYPE center_array IS ARRAY(1 TO n_barrel_stages + 2) OF signed(k - 1 DOWNTO 0);

	TYPE zoom_array IS ARRAY(1 TO n_barrel_stages + 1) OF unsigned(w_zoom - 1 DOWNTO 0);

	TYPE shift_array IS ARRAY(2 TO n_barrel_stages + 2) OF signed(ratio'LENGTH + diff'LENGTH - 1 DOWNTO 0);

	SIGNAL center_a : center_array;
	SIGNAL zoom_a   : zoom_array;
	SIGNAL shift_a  : shift_array;
	SIGNAL valid    : std_logic_vector(1 TO n_barrel_stages + 3);

BEGIN

	valid_out <= valid(valid'HIGH);

	PROCESS (clk) IS

		VARIABLE two_idx : signed(bits_of(2 * (res - 1)) DOWNTO 0); -- 0 to 2*(RES-1) -> bits_of(2*(RES-1)) + 1 bits (+1 for sign bit)

		VARIABLE lo    : natural RANGE 0 TO w_zoom - 1;
		VARIABLE hi    : natural RANGE 0 TO w_zoom - 1;
		VARIABLE slice : natural RANGE 0 TO 2 ** zoom_bits_per_stage - 1;

	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				valid <= (OTHERS => '0');
			ELSIF (en = '1') THEN
				-- first stage
				center_a(1) <= center;
				zoom_a(1)   <= zoom;
				valid(1)    <= valid_in;
				two_idx     := SIGNED(SHIFT_LEFT(RESIZE(idx, two_idx'LENGTH), 1));                         -- 2*idx
				diff        <= RESIZE(two_idx - SIGNED(RESIZE(res_minus_1, two_idx'LENGTH)), diff'LENGTH); -- diff = 2*idx - (RES-1)

				-- second stage
				center_a(2) <= center_a(1);
				zoom_a(2)   <= zoom_a(1);
				valid(2)    <= valid(1);
				shift_a(2)  <= SHIFT_RIGHT(diff * ratio, 1);                                               -- first shift right by 1. shift = prod / 2^(zoom+1)

				-- sequence of barrel shifters - single barrel shifter would produce high delay
				FOR i IN 1 TO n_barrel_stages LOOP

					IF (i < n_barrel_stages) THEN
						zoom_a(i + 2) <= zoom_a(i + 1);
					END IF;
					center_a(i + 2) <= center_a(i + 1);
					valid(i + 2)    <= valid(i + 1);

					lo             := (i - 1) * zoom_bits_per_stage;
					hi             := minimum(i * zoom_bits_per_stage, w_zoom) - 1;
					slice          :=TO_INTEGER(zoom_a(i + 1)(hi DOWNTO lo));                              -- zoom bits for this stage
					shift_a(i + 2) <= SHIFT_RIGHT(shift_a(i + 1), slice * 2 ** lo);

				END LOOP;

				-- last stage
				coord             <= center_a(center_a'HIGH) + RESIZE(shift_a(shift_a'HIGH), k);           -- coord = center + shift
				valid(valid'HIGH) <= valid(valid'HIGH - 1);
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
