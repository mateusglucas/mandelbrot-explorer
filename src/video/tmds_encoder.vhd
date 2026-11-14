-- codificador TMDS (DVI 1.0): 8 bits de dados -> 10 bits com balanceamento DC
-- fora da area ativa (de='0') envia os simbolos de controle correspondentes a c1,c0

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

ENTITY tmds_encoder IS
	PORT (
		clk   : IN    std_logic;
		data  : IN    std_logic_vector(7 DOWNTO 0);
		c0    : IN    std_logic;
		c1    : IN    std_logic;
		de    : IN    std_logic;
		q_out : OUT   std_logic_vector(9 DOWNTO 0)
	);
END ENTITY tmds_encoder;

ARCHITECTURE behavioral OF tmds_encoder IS

	SIGNAL disparidade : signed(4 DOWNTO 0);

BEGIN

	PROCESS (clk) IS

		VARIABLE n1d : integer RANGE 0 TO 8;
		VARIABLE n1q : integer RANGE 0 TO 8;
		VARIABLE n0q : integer RANGE 0 TO 8;
		VARIABLE q_m : std_logic_vector(8 DOWNTO 0);
		VARIABLE dif : signed(4 DOWNTO 0);
		VARIABLE c   : std_logic_vector(1 DOWNTO 0);

	BEGIN

		IF (RISING_EDGE(clk)) THEN
			n1d := 0;

			FOR i IN 0 TO 7 LOOP

				IF (data(i) = '1') THEN
					n1d := n1d + 1;
				END IF;

			END LOOP;

			q_m(0) :=data(0);
			IF (n1d > 4 OR (n1d = 4 AND data(0) = '0')) THEN

				FOR i IN 1 TO 7 LOOP

					q_m(i) :=q_m(i - 1) XNOR data(i);

				END LOOP;

				q_m(8) :='0';
			ELSE

				FOR i IN 1 TO 7 LOOP

					q_m(i) :=q_m(i - 1) XOR data(i);

				END LOOP;

				q_m(8) :='1';
			END IF;

			n1q := 0;

			FOR i IN 0 TO 7 LOOP

				IF (q_m(i) = '1') THEN
					n1q := n1q + 1;
				END IF;

			END LOOP;

			n0q := 8 - n1q;
			dif :=TO_SIGNED(n1q, 5) - TO_SIGNED(n0q, 5);

			IF (de = '0') THEN
				c := c1 & c0;

				CASE c IS

					WHEN "00" =>

						q_out <= "1101010100";

					WHEN "01" =>

						q_out <= "0010101011";

					WHEN "10" =>

						q_out <= "0101010100";

					WHEN OTHERS =>

						q_out <= "1010101011";

				END CASE;

				disparidade <= (OTHERS => '0');
			ELSIF (disparidade = 0 OR n1q = n0q) THEN
				q_out(9) <= NOT q_m(8);
				q_out(8) <= q_m(8);
				IF (q_m(8) = '1') THEN
					q_out(7 DOWNTO 0) <= q_m(7 DOWNTO 0);
					disparidade       <= disparidade + dif;
				ELSE
					q_out(7 DOWNTO 0) <= NOT q_m(7 DOWNTO 0);
					disparidade       <= disparidade - dif;
				END IF;
			ELSIF ((disparidade > 0 AND n1q > n0q) OR (disparidade < 0 AND n0q > n1q)) THEN
				q_out(9)          <= '1';
				q_out(8)          <= q_m(8);
				q_out(7 DOWNTO 0) <= NOT q_m(7 DOWNTO 0);
				IF (q_m(8) = '1') THEN
					disparidade <= disparidade + 2 - dif;
				ELSE
					disparidade <= disparidade - dif;
				END IF;
			ELSE
				q_out(9)          <= '0';
				q_out(8)          <= q_m(8);
				q_out(7 DOWNTO 0) <= q_m(7 DOWNTO 0);
				IF (q_m(8) = '0') THEN
					disparidade <= disparidade - 2 + dif;
				ELSE
					disparidade <= disparidade + dif;
				END IF;
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
