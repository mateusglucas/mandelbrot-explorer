-- VUnit testbench for calc_addr: addr = RES_H * row + col (registered on en)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_calc_addr IS
	GENERIC(
		runner_cfg	: STRING;
		RES_H		: NATURAL := 320;
		RES_V		: NATURAL := 240
	);
END tb_calc_addr;

ARCHITECTURE sim OF tb_calc_addr IS
	CONSTANT W_ROW		: NATURAL := bits_of(RES_V - 1);
	CONSTANT W_COL		: NATURAL := bits_of(RES_H - 1);
	CONSTANT W_ADDR		: NATURAL := bits_of(RES_H * RES_V - 1);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;

	SIGNAL clk		: STD_LOGIC := '0';
	SIGNAL en		: STD_LOGIC := '0';
	SIGNAL row		: UNSIGNED(W_ROW - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL col		: UNSIGNED(W_COL - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL addr		: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL valid	: STD_LOGIC;

	PROCEDURE check_point(
		CONSTANT r		: NATURAL;
		CONSTANT c		: NATURAL;
		CONSTANT msg	: STRING;
		SIGNAL row_s	: OUT UNSIGNED(W_ROW - 1 DOWNTO 0);
		SIGNAL col_s	: OUT UNSIGNED(W_COL - 1 DOWNTO 0);
		SIGNAL en_s		: OUT STD_LOGIC;
		SIGNAL clk_s	: IN STD_LOGIC;
		SIGNAL addr_s	: IN UNSIGNED(W_ADDR - 1 DOWNTO 0);
		SIGNAL valid_s	: IN STD_LOGIC
	) IS
	BEGIN
		row_s	<= to_unsigned(r, W_ROW);
		col_s	<= to_unsigned(c, W_COL);
		en_s	<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s	<= '0';
		WAIT FOR 1 ns;
		check_equal(to_integer(addr_s), RES_H * r + c, msg);
		check_equal(valid_s, '1', msg & " valid");
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.calc_addr
		GENERIC MAP(
			RES_H	=> RES_H,
			W_COL	=> W_COL,
			W_ROW	=> W_ROW,
			W_ADDR	=> W_ADDR
		)
		PORT MAP(
			clk		=> clk,
			en		=> en,
			row		=> row,
			col		=> col,
			addr	=> addr,
			valid	=> valid
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE held : NATURAL;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("corners") THEN
				check_point(0,         0,         "corner 0,0",
					row, col, en, clk, addr, valid);
				check_point(0,         RES_H - 1, "corner 0,RES_H-1",
					row, col, en, clk, addr, valid);
				check_point(RES_V - 1, 0,         "corner RES_V-1,0",
					row, col, en, clk, addr, valid);
				check_point(RES_V - 1, RES_H - 1, "corner last",
					row, col, en, clk, addr, valid);

			ELSIF run("center") THEN
				check_point(RES_V / 2, RES_H / 2, "center",
					row, col, en, clk, addr, valid);

			ELSIF run("en_hold") THEN
				check_point(1, 2, "load before hold",
					row, col, en, clk, addr, valid);
				held := to_integer(addr);
				-- change inputs with en=0: addr holds, valid clears
				row	<= to_unsigned(RES_V - 1, W_ROW);
				col	<= to_unsigned(RES_H - 1, W_COL);
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(addr), held, "addr must hold when en=0");
				check_equal(valid, '0', "valid must clear when en=0");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
