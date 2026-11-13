-- Shift register: delay d by N cycles when en=1. N=0 is a wire.

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY pipe_delay IS
	GENERIC (
		N : NATURAL := 0;
		W : NATURAL := 1
	);
	PORT (
		clk	: IN  STD_LOGIC;
		rst	: IN  STD_LOGIC;
		en	: IN  STD_LOGIC;
		d	: IN  STD_LOGIC_VECTOR(W - 1 DOWNTO 0);
		q	: OUT STD_LOGIC_VECTOR(W - 1 DOWNTO 0)
	);
END pipe_delay;

ARCHITECTURE behavioral OF pipe_delay IS
BEGIN
	g_wire: IF N = 0 GENERATE
		q <= d;
	END GENERATE;

	g_pipe: IF N > 0 GENERATE
		TYPE pipe_t IS ARRAY (0 TO N - 1) OF STD_LOGIC_VECTOR(W - 1 DOWNTO 0);
		SIGNAL pipe : pipe_t;
	BEGIN
		q <= pipe(N - 1);

		PROCESS(clk)
		BEGIN
			IF RISING_EDGE(clk) THEN
				IF rst = '1' THEN
					pipe <= (OTHERS => (OTHERS => '0'));
				ELSIF en = '1' THEN
					pipe(0) <= d;
					pipe(1 TO N - 1) <= pipe(0 TO N - 2);
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;
END behavioral;
