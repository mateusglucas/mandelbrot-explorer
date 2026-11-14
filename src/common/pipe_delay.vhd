-- Shift register: delay d by N cycles when en=1. N=0 is a wire.

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;

ENTITY pipe_delay IS
	GENERIC (
		n : natural := 0;
		w : natural := 1
	);
	PORT (
		clk	: IN    std_logic;
		rst	: IN    std_logic;
		en     : IN    std_logic;
		d      : IN    std_logic_vector(w - 1 DOWNTO 0);
		q      : OUT   std_logic_vector(w - 1 DOWNTO 0)
	);
END ENTITY pipe_delay;

ARCHITECTURE behavioral OF pipe_delay IS

BEGIN

	G_WIRE : IF N = 0 GENERATE
		q <= d;
	END GENERATE G_WIRE;

	G_PIPE : IF N > 0 GENERATE

		TYPE pipe_t IS ARRAY(0 TO N - 1) OF std_logic_vector(W - 1 DOWNTO 0);

		SIGNAL pipe : pipe_t;
	BEGIN
		q <= pipe(n - 1);

		PROCESS (clk) IS
		BEGIN

			IF RISING_EDGE(clk) THEN
				IF (rst = '1') THEN
					pipe <= (OTHERS => (OTHERS => '0'));
				ELSIF (en = '1') THEN
					pipe(0)          <= d;
					pipe(1 TO n - 1) <= pipe(0 TO n - 2);
				END IF;
			END IF;

		END PROCESS;

	END GENERATE G_PIPE;

END ARCHITECTURE behavioral;
