-- VUnit testbench for calc_addr: addr = RES_H * row + col (registered on en)
-- valid_out tracks valid_in when en=1 (pipeline propagate)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_calc_addr IS
	GENERIC (
		runner_cfg	: string;
		res_h         : natural := 320;
		res_v         : natural := 240
	);
END ENTITY tb_calc_addr;

ARCHITECTURE sim OF tb_calc_addr IS

	CONSTANT w_row         : natural := bits_of(res_v - 1);
	CONSTANT w_col         : natural := bits_of(res_h - 1);
	CONSTANT w_addr		: natural := bits_of(res_h * res_v - 1);
	CONSTANT clk_period	: time    := 10 ns;

	SIGNAL clk       : std_logic := '0';
	SIGNAL rst       : std_logic;
	SIGNAL en        : std_logic;
	SIGNAL valid_in  : std_logic;
	SIGNAL row       : unsigned(w_row - 1 DOWNTO 0);
	SIGNAL col       : unsigned(w_col - 1 DOWNTO 0);
	SIGNAL addr      : unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL valid_out : std_logic;

	PROCEDURE do_rst (
		SIGNAL rst_s         : OUT std_logic;
		SIGNAL en_s          : OUT std_logic;
		SIGNAL valid_in_s	: OUT std_logic;
		SIGNAL clk_s         : IN std_logic
	) IS
	BEGIN

		en_s          <= '0';
		valid_in_s	<= '0';
		rst_s         <= '1';
		WAIT UNTIL rising_edge(clk_s);
		rst_s         <= '0';
		WAIT FOR 1 ns;

	END PROCEDURE do_rst;

	PROCEDURE check_point (
		CONSTANT r			: natural;
		CONSTANT c			: natural;
		CONSTANT msg          : string;
		SIGNAL row_s          : OUT unsigned(w_row - 1 DOWNTO 0);
		SIGNAL col_s          : OUT unsigned(w_col - 1 DOWNTO 0);
		SIGNAL valid_in_s     : OUT std_logic;
		SIGNAL en_s           : OUT std_logic;
		SIGNAL clk_s          : IN std_logic;
		SIGNAL addr_s         : IN unsigned(w_addr - 1 DOWNTO 0);
		SIGNAL valid_out_s	: IN std_logic
	) IS
	BEGIN

		row_s         <= to_unsigned(r, W_ROW);
		col_s         <= to_unsigned(c, W_COL);
		valid_in_s	<= '1';
		en_s          <= '1';
		WAIT UNTIL rising_edge(clk_s);
		en_s          <= '0';
		WAIT FOR 1 ns;
		check_equal(to_integer(addr_s), RES_H * r + c, msg);
		check_equal(valid_out_s, '1', msg & " valid_out");

	END PROCEDURE check_point;

BEGIN

	DUT : ENTITY work.calc_addr
		GENERIC MAP (
			res_h	=> res_h,
			res_v	=> res_v
		)
		PORT MAP (
			clk          => clk,
			rst          => rst,
			en           => en,
			valid_in     => valid_in,
			row          => row,
			col          => col,
			addr         => addr,
			valid_out	=> valid_out
		);

	clk <= NOT clk AFTER clk_period / 2;

	PROCESS IS

		VARIABLE held : natural;

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			do_rst(rst, en, valid_in, clk);

			IF run("corners") THEN
				check_point(0,         0,         "corner 0,0",
	            row, col, valid_in, en, clk, addr, valid_out);
				check_point(0,         res_h - 1, "corner 0,RES_H-1",
	            row, col, valid_in, en, clk, addr, valid_out);
				check_point(res_v - 1, 0,         "corner RES_V-1,0",
	            row, col, valid_in, en, clk, addr, valid_out);
				check_point(res_v - 1, res_h - 1, "corner last",
	            row, col, valid_in, en, clk, addr, valid_out);
			ELSIF run("center") THEN
				check_point(res_v / 2, res_h / 2, "center",
	            row, col, valid_in, en, clk, addr, valid_out);
			ELSIF run("en_hold") THEN
				check_equal(valid_out, '0', "valid_out after rst");

				check_point(1, 2, "load before hold",
	            row, col, valid_in, en, clk, addr, valid_out);
				held     := to_integer(addr);
				row      <= to_unsigned(res_v - 1, w_row);
				col      <= to_unsigned(res_h - 1, w_col);
				valid_in <= '0';
				WAIT UNTIL rising_edge(clk);
				WAIT FOR 1 ns;
				check_equal(to_integer(addr), held, "addr must hold when en=0");
				check_equal(valid_out, '1', "valid_out sticky when en=0");

				do_rst(rst, en, valid_in, clk);
				check_equal(valid_out, '0', "valid_out clears on rst");
			ELSIF run("valid_prop") THEN
				-- bubble: en with valid_in=0 -> valid_out=0
				row      <= to_unsigned(1, w_row);
				col      <= to_unsigned(2, w_col);
				valid_in <= '0';
				en       <= '1';
				WAIT UNTIL rising_edge(clk);
				en       <= '0';
				WAIT FOR 1 ns;
				check_equal(valid_out, '0', "bubble: valid_out follows 0");
				check_equal(to_integer(addr), res_h * 1 + 2, "addr still updates on en");

				-- then a valid sample
				valid_in	<= '1';
				en          <= '1';
				WAIT UNTIL rising_edge(clk);
				en          <= '0';
				WAIT FOR 1 ns;
				check_equal(valid_out, '1', "valid_out follows 1");
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
