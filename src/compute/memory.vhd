-- Dual-port frame buffer (calc write / video read)

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY memory IS
	GENERIC (
		w_data   : natural := 3;
		mem_size : natural := 76800
	);
	PORT (
		clk_wr  : IN    std_logic;
		wr_en   : IN    std_logic;
		wr_addr : IN    unsigned(bits_of(mem_size - 1) - 1 DOWNTO 0);
		wr_data : IN    std_logic_vector(w_data - 1 DOWNTO 0);

		clk_rd  : IN    std_logic;
		rd_en   : IN    std_logic;
		rd_addr : IN    unsigned(bits_of(mem_size - 1) - 1 DOWNTO 0);
		rd_data : OUT   std_logic_vector(w_data - 1 DOWNTO 0)
	);
END ENTITY memory;

ARCHITECTURE behavioral OF memory IS

	TYPE memory_type IS ARRAY(0 TO MEM_SIZE - 1) OF std_logic_vector(W_DATA - 1 DOWNTO 0);

	SIGNAL mem : memory_type;

BEGIN

	PROCESS (clk_wr) IS
	BEGIN

		IF (RISING_EDGE(clk_wr)) THEN
			IF ((wr_en = '1') AND (wr_addr < mem_size)) THEN
				mem(TO_INTEGER(wr_addr)) <= wr_data;
			END IF;
		END IF;

	END PROCESS;

	PROCESS (clk_rd) IS
	BEGIN

		IF (RISING_EDGE(clk_rd)) THEN
			IF ((rd_en = '1') AND (rd_addr < mem_size)) THEN
				rd_data <= mem(TO_INTEGER(rd_addr));
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
