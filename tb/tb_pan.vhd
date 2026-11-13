-- VUnit testbench for pan:
--   center +=/-= max(SHIFT_RIGHT(DELTA, zoom), 1) when inc XOR dec
--   rst clears center to 0

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_pan IS
	GENERIC(
		runner_cfg	: STRING;
		K			: NATURAL := 16;
		W_ZOOM		: NATURAL := 4;
		-- DELTA in Q fixed-point as integer bit pattern
		DELTA_FP	: INTEGER := 256
	);
END tb_pan;

ARCHITECTURE sim OF tb_pan IS
	CONSTANT CLK_PERIOD	: TIME := 10 ns;
	CONSTANT DELTA_C	: SIGNED(K - 1 DOWNTO 0) := to_signed(DELTA_FP, K);

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL rst		: STD_LOGIC := '0';
	SIGNAL zoom		: UNSIGNED(W_ZOOM - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL inc		: STD_LOGIC := '0';
	SIGNAL dec_s	: STD_LOGIC := '0';
	SIGNAL center	: SIGNED(K - 1 DOWNTO 0);

	FUNCTION step_of(CONSTANT z : NATURAL) RETURN SIGNED IS
		VARIABLE d : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		d := shift_right(resize(DELTA_C, K), z);
		IF d = 0 THEN
			d := to_signed(1, K);
		END IF;
		RETURN d;
	END FUNCTION;

	PROCEDURE tick(SIGNAL clk_s : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk_s);
	END PROCEDURE;

	PROCEDURE do_reset(
		SIGNAL rst_s	: OUT STD_LOGIC;
		SIGNAL inc_s	: OUT STD_LOGIC;
		SIGNAL dec_o	: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		inc_s	<= '0';
		dec_o	<= '0';
		rst_s	<= '1';
		tick(clk_s);
		rst_s	<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.pan
		GENERIC MAP(
			K		=> K,
			W_ZOOM	=> W_ZOOM,
			DELTA	=> DELTA_C
		)
		PORT MAP(
			clk		=> clk,
			rst		=> rst,
			zoom	=> zoom,
			inc		=> inc,
			dec		=> dec_s,
			center	=> center
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE exp : SIGNED(K - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("reset") THEN
				-- dirty state then reset
				zoom	<= to_unsigned(0, W_ZOOM);
				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				do_reset(rst, inc, dec_s, clk);
				check_equal(center, 0, "center after reset");

			ELSIF run("inc_dec_zoom0") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom <= to_unsigned(0, W_ZOOM);
				exp := (OTHERS => '0');

				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				exp := exp + step_of(0);
				check_equal(center, exp, "inc once zoom=0");

				tick(clk);
				WAIT FOR 1 ns;
				exp := exp + step_of(0);
				check_equal(center, exp, "inc twice zoom=0");

				inc		<= '0';
				dec_s	<= '1';
				tick(clk);
				WAIT FOR 1 ns;
				exp := exp - step_of(0);
				check_equal(center, exp, "dec once zoom=0");

			ELSIF run("zoom_halves_step") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom	<= to_unsigned(1, W_ZOOM);
				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, step_of(1), "inc zoom=1");

				do_reset(rst, inc, dec_s, clk);
				zoom	<= to_unsigned(2, W_ZOOM);
				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, step_of(2), "inc zoom=2");

			ELSIF run("clamp_to_one") THEN
				-- large zoom => SHIFT_RIGHT goes to 0 => step forced to 1
				do_reset(rst, inc, dec_s, clk);
				zoom	<= to_unsigned(K - 2, W_ZOOM);
				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, to_signed(1, K), "inc clamps to +1");

				dec_s	<= '1';
				inc		<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, to_signed(0, K), "dec clamps to -1");

			ELSIF run("hold") THEN
				do_reset(rst, inc, dec_s, clk);
				zoom	<= to_unsigned(0, W_ZOOM);
				inc		<= '1';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				exp := center;

				-- neither: hold
				inc		<= '0';
				dec_s	<= '0';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, exp, "hold when inc=dec=0");

				-- both: XOR false => hold
				inc		<= '1';
				dec_s	<= '1';
				tick(clk);
				WAIT FOR 1 ns;
				check_equal(center, exp, "hold when inc=dec=1");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
