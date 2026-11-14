-- This block performs iterations of the Mandelbrot set using the recursive law z(i+1)=z(i)^2+z_c (where z_c=x_c+j*y_c)
-- When the modulus of z exceeds 2 or the maximum number of iterations is reached, the done signal goes high for one clock cycle.

LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;
	USE ieee.numeric_std.ALL;
	USE work.utils.ALL;

ENTITY iterator IS
	GENERIC (
		k : natural := 36; -- number of bits of fixed point representation
		i : natural := 4;  -- number of integer bits (including the sign bit)
		-- worst case is x_c=2-epsilon, y_c=0 -> x_new=2^2+2-epsilon=6-epsilon, y_new=0,
		-- which needs 4 bits in integer part (with sign bit)
		max_iter : natural := 255; -- maximum number of iterations
		w_addr   : natural := 17   -- bits_of(RES_H*RES_V-1)
	);
	PORT (
		clk      : IN    std_logic;                                -- clock signal
		rst      : IN    std_logic;                                -- reset signal
		load     : IN    std_logic;                                -- load signal
		x_c      : IN    signed(k - 1 DOWNTO 0);                   -- real part of the complex number z_c
		y_c      : IN    signed(k - 1 DOWNTO 0);                   -- imaginary part of the complex number z_c
		addr     : IN    unsigned(w_addr - 1 DOWNTO 0);            -- address of the pixel in the framebuffer
		done     : OUT   std_logic;                                -- done signal
		iter     : OUT   unsigned(bits_of(max_iter) - 1 DOWNTO 0); -- number of iterations performed
		addr_out : OUT   unsigned(w_addr - 1 DOWNTO 0);            -- address of the pixel in the framebuffer
		empty    : OUT   std_logic                                 -- ready to receive a new point
	);
END ENTITY iterator;

ARCHITECTURE behavioral OF iterator IS

	SIGNAL x_c_r     : signed(k - 1 DOWNTO 0);
	SIGNAL y_c_r     : signed(k - 1 DOWNTO 0);
	SIGNAL iter_r	: unsigned(bits_of(max_iter) - 1 DOWNTO 0);
	SIGNAL addr_r	: unsigned(w_addr - 1 DOWNTO 0);
	SIGNAL valid     : std_logic;

	SIGNAL xx    : signed(2 * k - 1 DOWNTO 0);
	SIGNAL xy    : signed(2 * k - 1 DOWNTO 0);
	SIGNAL yy    : signed(2 * k - 1 DOWNTO 0);
	SIGNAL norm2 : signed(2 * k - 1 DOWNTO 0); -- worst case is x_c=2-epsilon, y_c=0 -> x_new=2^2+2-epsilon=6-epsilon, y_new=0
	-- -> norm2=(6-epsilon)^2+0^2=36-epsilon, which fits in 2*I=8 bits (with sign bit)
	SIGNAL x         : signed(k - 1 DOWNTO 0);
	SIGNAL y         : signed(k - 1 DOWNTO 0);
	SIGNAL done_aux1 :	std_logic;
	SIGNAL done_aux2 :	std_logic;
	SIGNAL done_aux  :	std_logic;

BEGIN

	xx    <= x * x;
	yy    <= y * y;
	xy    <= x * y;
	norm2 <= xx + yy;

	iter     <= iter_r;
	addr_out <= addr_r;

	done_aux1 <= '0' WHEN iter_r < max_iter ELSE
	             '1';
	done_aux2 <= '0' WHEN SHIFT_RIGHT(norm2, 2 * (k - i)) < 4 ELSE
	             '1';
	done_aux  <= (done_aux1 OR done_aux2) AND valid;
	done      <= done_aux;
	empty     <= (NOT valid) OR done_aux;

	PROCESS (clk) IS
	BEGIN

		IF (RISING_EDGE(clk)) THEN
			IF (rst = '1') THEN
				valid <= '0';
			ELSIF (load = '1') THEN
				x_c_r  <= x_c;
				y_c_r  <= y_c;
				x      <= x_c;
				y      <= y_c;
				addr_r <= addr;
				iter_r <= (OTHERS => '0');
				valid  <= '1';
			ELSIF (done_aux = '0' AND valid = '1') THEN
				x      <= (xx(2 * k - i - 1 DOWNTO k - i) - yy(2 * k - i - 1 DOWNTO k - i)) + x_c_r;
				y      <= xy(2 * k - i - 2 DOWNTO k - i - 1) + y_c_r;
				iter_r <= iter_r + 1;
			ELSE
				valid <= '0';
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
