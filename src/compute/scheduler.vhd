LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY scheduler IS
	GENERIC (
		res_h : natural := 320;
		res_v : natural := 240
	);
	PORT (
		clk   : IN    std_logic;
		rst   : IN    std_logic;
		en    : IN    std_logic;
		row   : OUT   unsigned(bits_of(res_v - 1) - 1 DOWNTO 0);
		col   : OUT   unsigned(bits_of(res_h - 1) - 1 DOWNTO 0);
		valid : OUT   std_logic
	);
END ENTITY scheduler;

ARCHITECTURE behavioral OF scheduler IS

	SIGNAL done : std_logic;

BEGIN

	PROCESS (clk) IS
	BEGIN

		IF RISING_EDGE(clk) THEN
			IF (rst = '1') THEN
				row   <= (OTHERS => '0');
				col   <= (OTHERS => '0');
				valid <= '0';
				done  <= '0';
			ELSIF (en = '1' AND done = '0') THEN
				IF (valid = '0') THEN
					row   <= (OTHERS => '0');
					col   <= (OTHERS => '0');
					valid <= '1';
				ELSE
					IF (row = res_v - 1) THEN
						IF (col = res_h - 1) THEN
							done  <= '1';
							valid <= '0';
						ELSE
							row <= (OTHERS => '0');
							col <= col + 1;
						END IF;
					ELSE
						row <= row + 1;
					END IF;
				END IF;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
