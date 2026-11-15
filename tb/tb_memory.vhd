-- VUnit testbench for memory (dual-port RAM)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

LIBRARY vunit_lib;
	CONTEXT vunit_lib.vunit_context;

ENTITY tb_memory IS
	GENERIC (
		runner_cfg	: string;
		w_data		: natural := 3;
		mem_size      : natural := 12
	);
END ENTITY tb_memory;

ARCHITECTURE sim OF tb_memory IS

	CONSTANT w_addr		: natural := bits_of(mem_size - 1);
	CONSTANT clk_period	: time    := 10 ns;

	SIGNAL clk_wr     : std_logic := '0';
	SIGNAL wr_en      : std_logic;
	SIGNAL wr_addr	: unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL wr_data	: std_logic_vector(w_data - 1 DOWNTO 0);

	SIGNAL clk_rd     : std_logic := '0';
	SIGNAL rd_en      : std_logic;
	SIGNAL rd_addr	: unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL rd_data	: std_logic_vector(w_data - 1 DOWNTO 0);

BEGIN

	DUT : ENTITY work.memory
		GENERIC MAP (
			w_data => w_data, mem_size => mem_size
		)
		PORT MAP (
			clk_wr     => clk_wr,
			wr_en      => wr_en,
			wr_addr	=> wr_addr,
			wr_data	=> wr_data,
			clk_rd     => clk_rd,
			rd_en      => rd_en,
			rd_addr	=> rd_addr,
			rd_data	=> rd_data
		);

	clk_wr <= NOT clk_wr AFTER clk_period / 2;
	clk_rd <= clk_wr;

	PROCESS IS

		VARIABLE held : std_logic_vector(w_data - 1 DOWNTO 0);

	BEGIN

		test_runner_setup(runner, runner_cfg);

		WHILE test_suite LOOP

			IF run("write_read") THEN
				wr_addr                               <= to_unsigned(0, w_addr);
				wr_data                               <= "001";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr                               <= to_unsigned(1, w_addr);
				wr_data                               <= "010";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr                               <= to_unsigned(mem_size - 1, w_addr);
				wr_data                               <= "111";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';

				rd_en   <= '1';
				rd_addr <= to_unsigned(0, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("001"), "data @0");
				rd_addr <= to_unsigned(1, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("010"), "data @1");
				rd_addr <= to_unsigned(mem_size - 1, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("111"), "data @last");
				rd_en   <= '0';
			ELSIF run("init_zero") THEN
				rd_en   <= '1';
				rd_addr <= to_unsigned(3, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("000"), "unread addr is 0");
				rd_en   <= '0';
			ELSIF run("overwrite") THEN
				wr_addr                               <= to_unsigned(5, w_addr);
				wr_data                               <= "101";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr                               <= to_unsigned(5, w_addr);
				wr_data                               <= "011";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				rd_en                                 <= '1';
				rd_addr                               <= to_unsigned(5, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("011"), "last write wins");
				rd_en                                 <= '0';
			ELSIF run("rd_hold") THEN
				wr_addr                               <= to_unsigned(2, w_addr);
				wr_data                               <= "110";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				rd_en                                 <= '1';
				rd_addr                               <= to_unsigned(2, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				held                                  := rd_data;

				-- rd_en=0: rd_data holds previous value
				rd_en   <= '0';
				rd_addr <= to_unsigned(0, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, held, "rd_data holds when rd_en=0");
			ELSIF run("out_of_range") THEN
				wr_addr                               <= to_unsigned(0, w_addr);
				wr_data                               <= "001";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';
				wr_addr                               <= to_unsigned(mem_size, w_addr);
				wr_data                               <= "111";
				wr_en                                 <= '1';
				WAIT UNTIL rising_edge(clk_wr); wr_en <= '0';

				rd_en   <= '1';
				rd_addr <= to_unsigned(0, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, std_logic_vector'("001"), "OOR write ignored");
				held    := rd_data;

				rd_addr <= to_unsigned(mem_size, w_addr);
				WAIT UNTIL rising_edge(clk_rd); WAIT FOR 1 ns;
				check_equal(rd_data, held, "OOR read leaves rd_data unchanged");
				rd_en   <= '0';
			END IF;

		END LOOP;

		test_runner_cleanup(runner);

	END PROCESS;

END ARCHITECTURE sim;
