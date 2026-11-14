-- Up/down saturating counter: 0 .. MAX
-- Width derived from MAX via bits_of.

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY counter IS
	GENERIC (
		max : natural := 31
	);
	PORT (
		clk	: IN    std_logic;
		rst	: IN    std_logic;
		inc	: IN    std_logic;
		dec	: IN    std_logic;
		cnt	: OUT   unsigned(bits_of(max) - 1 DOWNTO 0)
	);
END ENTITY counter;

ARCHITECTURE behavioral OF counter IS

	SIGNAL cnt_i : unsigned(bits_of(max) - 1 DOWNTO 0);

BEGIN

	cnt <= cnt_i;

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				cnt_i <= (OTHERS => '0');
			ELSIF (inc = '1' XOR dec = '1') THEN
				IF (inc = '1') THEN
					IF (cnt_i < max) THEN
						cnt_i <= cnt_i + 1;
					END IF;
				ELSE -- dec = '1'
					IF (cnt_i > 0) THEN
						cnt_i <= cnt_i - 1;
					END IF;
				END IF;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
