-- Up/down saturating counter: 0 .. MAX
-- Width derived from MAX via bits_of.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

ENTITY counter IS
	GENERIC (
		MAX : NATURAL := 31
	);
	PORT (
		clk	: IN  STD_LOGIC;
		rst	: IN  STD_LOGIC;
		inc	: IN  STD_LOGIC;
		dec	: IN  STD_LOGIC;
		cnt	: OUT UNSIGNED(bits_of(MAX) - 1 DOWNTO 0)
	);
END counter;

ARCHITECTURE behavioral OF counter IS
	SIGNAL cnt_i : UNSIGNED(bits_of(MAX) - 1 DOWNTO 0);
BEGIN
	cnt <= cnt_i;

	PROCESS(clk)
	BEGIN
		IF RISING_EDGE(clk) THEN
			IF rst = '1' THEN
				cnt_i <= (OTHERS => '0');
			ELSIF inc = '1' XOR dec = '1' THEN
				IF inc = '1' THEN
					IF cnt_i < MAX THEN
						cnt_i <= cnt_i + 1;
					END IF;
				ELSE -- dec = '1'
					IF cnt_i > 0 THEN
						cnt_i <= cnt_i - 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
END behavioral;
