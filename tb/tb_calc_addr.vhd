-- VUnit testbench for calc_addr: addr = RES_H * row + col (registered on en)
-- valid_out tracks valid_in when en=1 (pipeline propagate)

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

	SIGNAL clk			: STD_LOGIC := '0';
	SIGNAL rst			: STD_LOGIC := '0';
	SIGNAL en			: STD_LOGIC := '0';
	SIGNAL valid_in		: STD_LOGIC := '0';
	SIGNAL row			: UNSIGNED(W_ROW - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL col			: UNSIGNED(W_COL - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL addr			: UNSIGNED(W_ADDR - 1 DOWNTO 0);
	SIGNAL valid_out	: STD_LOGIC;

	PROCEDURE do_rst(
		SIGNAL rst_s		: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC
	) IS
	BEGIN
		en_s		<= '0';
		valid_in_s	<= '0';
		rst_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s		<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;

	PROCEDURE check_point(
		CONSTANT r			: NATURAL;
		CONSTANT c			: NATURAL;
		CONSTANT msg		: STRING;
		SIGNAL row_s		: OUT UNSIGNED(W_ROW - 1 DOWNTO 0);
		SIGNAL col_s		: OUT UNSIGNED(W_COL - 1 DOWNTO 0);
		SIGNAL valid_in_s	: OUT STD_LOGIC;
		SIGNAL en_s			: OUT STD_LOGIC;
		SIGNAL clk_s		: IN STD_LOGIC;
		SIGNAL addr_s		: IN UNSIGNED(W_ADDR - 1 DOWNTO 0);
		SIGNAL valid_out_s	: IN STD_LOGIC
	) IS
	BEGIN
		row_s		<= to_unsigned(r, W_ROW);
		col_s		<= to_unsigned(c, W_COL);
		valid_in_s	<= '1';
		en_s		<= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s		<= '0';
		WAIT FOR 1 ns;
		check_equal(to_integer(addr_s), RES_H * r + c, msg);
		check_equal(valid_out_s, '1', msg & " valid_out");
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.calc_addr
		GENERIC MAP(
			RES_H	=> RES_H,
			RES_V	=> RES_V
		)
		PORT MAP(
			clk			=> clk,
			rst			=> rst,
			en			=> en,
			valid_in	=> valid_in,
			row			=> row,
			col			=> col,
			addr		=> addr,
			valid_out	=> valid_out
		);

	clk <= NOT clk AFTER CLK_PERIOD / 2;

	PROCESS
		VARIABLE held : NATURAL;
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			do_rst(rst, en, valid_in, clk);

			IF run("corners") THEN
				check_point(0,         0,         "corner 0,0",
					row, col, valid_in, en, clk, addr, valid_out);
				check_point(0,         RES_H - 1, "corner 0,RES_H-1",
					row, col, valid_in, en, clk, addr, valid_out);
				check_point(RES_V - 1, 0,         "corner RES_V-1,0",
					row, col, valid_in, en, clk, addr, valid_out);
				check_point(RES_V - 1, RES_H - 1, "corner last",
					row, col, valid_in, en, clk, addr, valid_out);

			ELSIF run("center") THEN
				check_point(RES_V / 2, RES_H / 2, "center",
					row, col, valid_in, en, clk, addr, valid_out);

			ELSIF run("en_hold") THEN
				check_equal(valid_out, '0', "valid_out after rst");

				check_point(1, 2, "load before hold",
					row, col, valid_in, en, clk, addr, valid_out);
				held := to_integer(addr);
				row			<= to_unsigned(RES_V - 1, W_ROW);
				col			<= to_unsigned(RES_H - 1, W_COL);
				valid_in	<= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(addr), held, "addr must hold when en=0");
				check_equal(valid_out, '1', "valid_out sticky when en=0");

				do_rst(rst, en, valid_in, clk);
				check_equal(valid_out, '0', "valid_out clears on rst");

			ELSIF run("valid_prop") THEN
				-- bubble: en with valid_in=0 -> valid_out=0
				row			<= to_unsigned(1, W_ROW);
				col			<= to_unsigned(2, W_COL);
				valid_in	<= '0';
				en			<= '1';
				WAIT UNTIL rising_edge(clk);
				en			<= '0';
				WAIT FOR 1 ns;
				check_equal(valid_out, '0', "bubble: valid_out follows 0");
				check_equal(to_integer(addr), RES_H * 1 + 2, "addr still updates on en");

				-- then a valid sample
				valid_in	<= '1';
				en			<= '1';
				WAIT UNTIL rising_edge(clk);
				en			<= '0';
				WAIT FOR 1 ns;
				check_equal(valid_out, '1', "valid_out follows 1");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
