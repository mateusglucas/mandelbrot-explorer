-- VUnit testbench for memory (dual-port RAM)

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.utils.all;

LIBRARY vunit_lib;
CONTEXT vunit_lib.vunit_context;

ENTITY tb_memory IS
	GENERIC(
		runner_cfg	: STRING;
		W_DATA		: NATURAL := 3;
		MEM_SIZE	: NATURAL := 12
	);
END tb_memory;

ARCHITECTURE sim OF tb_memory IS
	CONSTANT W_ADDR		: NATURAL := bits_of(MEM_SIZE - 1);
	CONSTANT CLK_PERIOD	: TIME := 10 ns;

	SIGNAL clk_wr	: STD_LOGIC := '0';
	SIGNAL wr_en	: STD_LOGIC := '0';
	SIGNAL wr_addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL wr_data	: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0) := (OTHERS => '0');

	SIGNAL clk_rd	: STD_LOGIC := '0';
	SIGNAL rd_en	: STD_LOGIC := '0';
	SIGNAL rd_addr	: UNSIGNED(W_ADDR - 1 DOWNTO 0) := (OTHERS => '0');
	SIGNAL rd_data	: STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
BEGIN
	DUT: ENTITY work.memory
		GENERIC MAP(W_DATA => W_DATA, MEM_SIZE => MEM_SIZE)
		PORT MAP(
			clk_wr	=> clk_wr,
			wr_en	=> wr_en,
			wr_addr	=> wr_addr,
			wr_data	=> wr_data,
			clk_rd	=> clk_rd,
			rd_en	=> rd_en,
			rd_addr	=> rd_addr,
			rd_data	=> rd_data
		);

	clk_wr <= NOT clk_wr AFTER CLK_PERIOD / 2;
	clk_rd <= clk_wr;

	PROCESS
		VARIABLE held : STD_LOGIC_VECTOR(W_DATA - 1 DOWNTO 0);
	BEGIN
		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP
			IF run("write_read") THEN
				wr_addr <= to_unsigned(0, W_ADDR); wr_data <= "001"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr <= to_unsigned(1, W_ADDR); wr_data <= "010"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr <= to_unsigned(MEM_SIZE - 1, W_ADDR); wr_data <= "111"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';

				rd_en <= '1';
				rd_addr <= to_unsigned(0, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("001"), "data @0");
				rd_addr <= to_unsigned(1, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("010"), "data @1");
				rd_addr <= to_unsigned(MEM_SIZE - 1, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("111"), "data @last");
				rd_en <= '0';

			ELSIF run("init_zero") THEN
				rd_en <= '1';
				rd_addr <= to_unsigned(3, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("000"), "unread addr is 0");
				rd_en <= '0';

			ELSIF run("overwrite") THEN
				wr_addr <= to_unsigned(5, W_ADDR); wr_data <= "101"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr <= to_unsigned(5, W_ADDR); wr_data <= "011"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				rd_en <= '1';
				rd_addr <= to_unsigned(5, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("011"), "last write wins");
				rd_en <= '0';

			ELSIF run("rd_hold") THEN
				wr_addr <= to_unsigned(2, W_ADDR); wr_data <= "110"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				rd_en <= '1';
				rd_addr <= to_unsigned(2, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				held := rd_data;

				-- rd_en=0: rd_data holds previous value
				rd_en <= '0';
				rd_addr <= to_unsigned(0, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, held, "rd_data holds when rd_en=0");

			ELSIF run("out_of_range") THEN
				wr_addr <= to_unsigned(0, W_ADDR); wr_data <= "001"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr <= to_unsigned(MEM_SIZE, W_ADDR); wr_data <= "111"; wr_en <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';

				rd_en <= '1';
				rd_addr <= to_unsigned(0, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("001"), "OOR write ignored");
				held := rd_data;

				rd_addr <= to_unsigned(MEM_SIZE, W_ADDR);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, held, "OOR read leaves rd_data unchanged");
				rd_en <= '0';
			END IF;
		END LOOP;

		test_runner_cleanup(runner);
	END PROCESS;
END sim;
