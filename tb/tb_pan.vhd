-- VUnit testbench for pan:
--   center +=/-= max(SHIFT_RIGHT(DELTA, zoom), 1) when inc XOR dec
--   rst clears center to 0

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_pan IS
	GENERIC (
		runner_cfg	: string;
		k             : natural := 16;
		w_zoom		: natural := 4;
		-- DELTA in Q fixed-point as integer bit pattern
		delta_fp	: integer := 256
	);
END ENTITY tb_pan;

ARCHITECTURE sim OF tb_pan IS

	CONSTANT clk_period	: time                   := 10 ns;
	CONSTANT delta_c       : signed(k - 1 DOWNTO 0) := to_signed(delta_fp, k);

	SIGNAL clk    : std_logic := '0';
	SIGNAL rst    : std_logic;
	SIGNAL zoom   : unsigned(w_zoom - 1 DOWNTO 0);
	SIGNAL inc    : std_logic;
	SIGNAL dec_s  : std_logic;
	SIGNAL center : signed(k - 1 DOWNTO 0);

	FUNCTION step_of (
		CONSTANT z : natural
	) RETURN signed IS

		VARIABLE d : signed(K - 1 DOWNTO 0);

	BEGIN

		d := shift_right(resize(DELTA_C, K), z);

		IF (d = 0) THEN
			d := to_signed(1, K);
		END IF;

		RETURN d;

	END FUNCTION step_of;

	PROCEDURE tick (
		SIGNAL clk_s : IN std_logic
	) IS
	BEGIN

		WAIT UNTIL rising_edge(clk_s);

	END PROCEDURE tick;

	PROCEDURE do_reset (
		SIGNAL rst_s	: OUT std_logic;
		SIGNAL inc_s	: OUT std_logic;
		SIGNAL dec_o	: OUT std_logic;
		SIGNAL clk_s	: IN std_logic
	) IS
	BEGIN

		inc_s	<= '0';
		dec_o	<= '0';
		rst_s	<= '1';
		tick(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;

	END PROCEDURE do_reset;

BEGIN

	DUT : ENTITY work.pan
		GENERIC MAP (
			k         => k,
			w_zoom	=> w_zoom,
			delta     => DELTA_C
		)
		PORT MAP (
			clk       => clk,
			rst       => rst,
			zoom      => zoom,
			inc       => inc,
			dec       => dec_s,
			center	=> center
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE exp : signed(k - 1 DOWNTO 0);

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("reset") THEN
				-- dirty state then reset
				zoom  <= to_unsigned(0, w_zoom);
				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				do_reset(rst, inc, dec_s, clk);
				check_equal(center, 0, "center after reset");
			ELSIF run("inc_dec_zoom0") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom <= to_unsigned(0, w_zoom);
				exp  := (OTHERS => '0');

				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				exp   := exp + step_of(0);
				check_equal(center, exp, "inc once zoom=0");

				tick(clk);
				WAIT FOR 1 ns;
				exp := exp + step_of(0);
				check_equal(center, exp, "inc twice zoom=0");

				inc   <= '0';
				dec_s <= '1';
				tick(clk);
				WAIT FOR 1 ns;
				exp   := exp - step_of(0);
				check_equal(center, exp, "dec once zoom=0");
			ELSIF run("zoom_halves_step") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom  <= to_unsigned(1, w_zoom);
				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, step_of(1), "inc zoom=1");

				do_reset(rst, inc, dec_s, clk);
				zoom  <= to_unsigned(2, w_zoom);
				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, step_of(2), "inc zoom=2");
			ELSIF run("clamp_to_one") THEN
				-- large zoom => SHIFT_RIGHT goes to 0 => step forced to 1
				do_reset(rst, inc, dec_s, clk);
				zoom  <= to_unsigned(k - 2, w_zoom);
				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, to_signed(1, k), "inc clamps to +1");

				dec_s <= '1';
				inc   <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, to_signed(0, k), "dec clamps to -1");
			ELSIF run("hold") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom  <= to_unsigned(0, w_zoom);
				inc   <= '1';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				exp   := center;

				-- neither: hold
				inc   <= '0';
				dec_s <= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, exp, "hold when inc=dec=0");

				-- both: XOR false => hold
				inc   <= '1';
				dec_s <= '1';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, exp, "hold when inc=dec=1");
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
