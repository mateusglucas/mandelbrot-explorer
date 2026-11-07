-- VUnit testbench for calc_addr: addr = RES_H * row + col

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
	CONSTANT W_ROW	: NATURAL := bits_of(RES_V - 1);
	CONSTANT W_COL	: NATURAL := bits_of(RES_H - 1);
	CONSTANT W_ADDR	: NATURAL := bits_of(RES_H * RES_V - 1);

	SIGNAL row	: UNSIGNED(W_ROW - 1 DOWNTO 0);
	SIGNAL col	: UNSIGNED(W_COL - 1 DOWNTO 0);
	SIGNAL addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0);

	PROCEDURE check(
		CONSTANT r		: NATURAL;
		CONSTANT c		: NATURAL;
		SIGNAL row_s	: OUT UNSIGNED(W_ROW - 1 DOWNTO 0);
		SIGNAL col_s	: OUT UNSIGNED(W_COL - 1 DOWNTO 0);
		SIGNAL addr_s	: IN UNSIGNED(W_ADDR - 1 DOWNTO 0)
	) IS
		VARIABLE expect : NATURAL;
	BEGIN
		row_s <= to_unsigned(r, W_ROW);
		col_s <= to_unsigned(c, W_COL);
		WAIT FOR 1 ns;
		expect := RES_H * r + c;
		check_equal(to_integer(addr_s), expect,
			"row=" & INTEGER'IMAGE(r) & " col=" & INTEGER'IMAGE(c));
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
			row		=> row,
			col		=> col,
			addr	=> addr
		);

	PROCESS
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("corners") THEN
				check(0,         0,         row, col, addr);
				check(0,         RES_H - 1, row, col, addr);
				check(RES_V - 1, 0,         row, col, addr);
				check(RES_V - 1, RES_H - 1, row, col, addr);
			ELSIF run("center") THEN
				check(RES_V / 2, RES_H / 2, row, col, addr);
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
