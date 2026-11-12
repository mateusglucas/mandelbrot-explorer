-- VUnit testbench for memory (simple dual-port RAM)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_memory IS
	GENERIC(
		runner_cfg	: STRING;
		W_ADDR		: NATURAL := 5;
		W_DATA		: NATURAL := 3;
		MEM_SIZE	: NATURAL := 16
	);
END tb_memory;

ARCHITECTURE sim OF tb_memory IS
	CONSTANT CLK_PERIOD : TIME := 10 ns;

	SIGNAL clk_wr	: STD_LOGIC := '0';
	SIGNAL wr_en	: STD_LOGIC := '0';
	SIGNAL wr_addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_data	: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0) := (OTHERS => '0');

	SIGNAL clk_rd	: STD_LOGIC := '0';
	SIGNAL rd_en	: STD_LOGIC := '0';
	SIGNAL rd_addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rd_data	: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);

	PROCEDURE tick_wr(SIGNAL clk_s : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk_s);
	END PROCEDURE;

	PROCEDURE tick_rd(SIGNAL clk_s : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk_s);
	END PROCEDURE;

	PROCEDURE write_word(
		CONSTANT a		: NATURAL;
		CONSTANT d		: STD_LOGIC_VECTOR;
		SIGNAL wr_en_s	: OUT STD_LOGIC;
		SIGNAL wr_addr_s: OUT UNSIGNED(W_ADDR - 1 DOWNTO 0);
		SIGNAL wr_data_s: OUT STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		wr_addr_s	<= to_unsigned(a, W_ADDR);
		wr_data_s	<= d;
		wr_en_s		<= '1';
		tick_wr(clk_s);
		wr_en_s		<= '0';
	END PROCEDURE;

	PROCEDURE read_word(
		CONSTANT a		: NATURAL;
		SIGNAL rd_en_s	: OUT STD_LOGIC;
		SIGNAL rd_addr_s: OUT UNSIGNED(W_ADDR - 1 DOWNTO 0);
		SIGNAL clk_s	: IN STD_LOGIC
	) IS
	BEGIN
		rd_addr_s	<= to_unsigned(a, W_ADDR);
		rd_en_s		<= '1';
		tick_rd(clk_s);
		rd_en_s		<= '0';
		WAIT FOR 1 ns;
	END PROCEDURE;
BEGIN
	DUT: ENTITY work.memory
		GENERIC MAP(
			W_ADDR		=> W_ADDR,
			W_DATA		=> W_DATA,
			MEM_SIZE	=> MEM_SIZE
		)
		PORT MAP(
			clk_wr		=> clk_wr,
			wr_en		=> wr_en,
			wr_addr		=> wr_addr,
			wr_data		=> wr_data,
			clk_rd		=> clk_rd,
			rd_en		=> rd_en,
			rd_addr		=> rd_addr,
			rd_data		=> rd_data
		);

	-- shared clock for simplicity
	clk_wr <= NOT clk_wr AFTER CLK_PERIOD / 2;
	clk_rd <= clk_wr;

	PROCESS
		VARIABLE held : STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("write_read") THEN
				write_word(0, "001", wr_en, wr_addr, wr_data, clk_wr);
				write_word(1, "010", wr_en, wr_addr, wr_data, clk_wr);
				write_word(MEM_SIZE - 1, "111", wr_en, wr_addr, wr_data, clk_wr);

				read_word(0, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("001"), "data @0");

				read_word(1, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("010"), "data @1");

				read_word(MEM_SIZE - 1, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("111"), "data @last");

			ELSIF run("init_zero") THEN
				read_word(3, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("000"), "unread addr is 0");

			ELSIF run("overwrite") THEN
				write_word(5, "101", wr_en, wr_addr, wr_data, clk_wr);
				write_word(5, "011", wr_en, wr_addr, wr_data, clk_wr);
				read_word(5, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("011"), "last write wins");

			ELSIF run("rd_hold") THEN
				write_word(2, "110", wr_en, wr_addr, wr_data, clk_wr);
				read_word(2, rd_en, rd_addr, clk_rd);
				held := rd_data;

				-- rd_en=0: rd_data holds previous value
				rd_en	<= '0';
				rd_addr	<= to_unsigned(0, W_ADDR);
				tick_rd(clk_rd);
				WAIT FOR 1 ns;
				check_equal(rd_data, held, "rd_data holds when rd_en=0");

			ELSIF run("out_of_range") THEN
				-- write beyond MEM_SIZE must be ignored
				write_word(0, "001", wr_en, wr_addr, wr_data, clk_wr);
				wr_addr	<= to_unsigned(MEM_SIZE, W_ADDR);
				wr_data	<= "111";
				wr_en	<= '1';
				tick_wr(clk_wr);
				wr_en	<= '0';

				read_word(0, rd_en, rd_addr, clk_rd);
				check_equal(rd_data, std_logic_vector'("001"), "OOR write ignored");
				held := rd_data;

				-- OOR read does not update rd_data
				rd_addr	<= to_unsigned(MEM_SIZE, W_ADDR);
				rd_en	<= '1';
				tick_rd(clk_rd);
				WAIT FOR 1 ns;
				check_equal(rd_data, held, "OOR read leaves rd_data unchanged");
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
