-- This block performs iterations of the Mandelbrot set using the recursive law z(i+1)=z(i)^2+z_c (where z_c=x_c+j*y_c)
-- When |z|^2 >= 4 or max_iter is reached, done goes high for one cycle.
-- 4-stage pipe: (1) z/meta (2) products (3) products+norm2 (4) products + registered done;

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

	-- first stage
	SIGNAL x : signed(k - 1 DOWNTO 0);
	SIGNAL y : signed(k - 1 DOWNTO 0);

	-- second stage
	SIGNAL xx_2 : signed(2 * k - 1 DOWNTO 0);
	SIGNAL xy_2 : signed(2 * k - 1 DOWNTO 0);
	SIGNAL yy_2 : signed(2 * k - 1 DOWNTO 0);

	-- third stage
	SIGNAL xx_3  : signed(2 * k - 1 DOWNTO 0);
	SIGNAL xy_3  : signed(2 * k - 1 DOWNTO 0);
	SIGNAL yy_3  : signed(2 * k - 1 DOWNTO 0);
	SIGNAL norm2 : signed(2 * k - 1 DOWNTO 0); -- worst case is x_c=2-epsilon, y_c=0 -> x_new=2^2+2-epsilon=6-epsilon, y_new=0
	-- -> norm2=(6-epsilon)^2+0^2=36-epsilon, which fits in 2*i=8 bits (with sign bit)

	-- fourth stage
	SIGNAL xx_4     : signed(2 * k - 1 DOWNTO 0);
	SIGNAL xy_4     : signed(2 * k - 1 DOWNTO 0);
	SIGNAL yy_4     : signed(2 * k - 1 DOWNTO 0);
	SIGNAL done_aux :	std_logic;

	-- arrays for the stages ( suffixed: ports already use x_c/y_c/addr/iter )

	TYPE coord_array IS ARRAY(1 TO 4) OF signed(k - 1 DOWNTO 0);

	TYPE addr_array IS ARRAY(1 TO 4) OF unsigned(w_addr - 1 DOWNTO 0);

	TYPE iter_array IS ARRAY(1 TO 4) OF unsigned(bits_of(max_iter) - 1 DOWNTO 0);

	SIGNAL x_c_a  : coord_array;
	SIGNAL y_c_a  : coord_array;
	SIGNAL addr_a : addr_array;
	SIGNAL iter_a : iter_array;
	SIGNAL valid  : std_logic_vector(1 TO 4);

BEGIN

	done     <= done_aux;
	iter     <= iter_a(iter_a'HIGH);
	addr_out <= addr_a(addr_a'HIGH);
	empty    <= (NOT valid(valid'HIGH)) OR done_aux;

	PROCESS (clk) IS

		VARIABLE done_aux1 :	std_logic;
		VARIABLE done_aux2 :	std_logic;

	BEGIN

		IF (RISING_EDGE(clk)) THEN
			IF (rst = '1') THEN
				valid <= (OTHERS => '0');
			ELSE
				-- first stage
				IF (load = '1') THEN
					x         <= x_c;
					y         <= y_c;
					x_c_a(1)  <= x_c;
					y_c_a(1)  <= y_c;
					addr_a(1) <= addr;
					iter_a(1) <= (OTHERS => '0');
					valid(1)  <= '1';
				ELSIF (done_aux = '0' AND valid(valid'HIGH) = '1') THEN
					x         <= (xx_4(2 * k - i - 1 DOWNTO k - i) - yy_4(2 * k - i - 1 DOWNTO k - i)) + x_c_a(x_c_a'HIGH);
					y         <= xy_4(2 * k - i - 2 DOWNTO k - i - 1) + y_c_a(y_c_a'HIGH);
					x_c_a(1)  <= x_c_a(x_c_a'HIGH);
					y_c_a(1)  <= y_c_a(y_c_a'HIGH);
					addr_a(1) <= addr_a(addr_a'HIGH);
					iter_a(1) <= iter_a(iter_a'HIGH) + 1;
					valid(1)  <= valid(valid'HIGH);
				ELSE
					valid(1) <= '0';
				END IF;

				-- second stage
				xx_2 <= x * x;
				yy_2 <= y * y;
				xy_2 <= x * y;

				-- third stage
				xx_3  <= xx_2;
				yy_3  <= yy_2;
				xy_3  <= xy_2;
				norm2 <= xx_2 + yy_2;

				-- fourth stage
				xx_4      <= xx_3;
				yy_4      <= yy_3;
				xy_4      <= xy_3;
				done_aux1 := '0' WHEN iter_a(3) < max_iter ELSE '1';
				-- norm2 >= 4 (theoretical escape condition is norm2>4)
				done_aux2 := OR(norm2(norm2'HIGH DOWNTO 2 * (k - i) + 2));
				done_aux  <= (done_aux1 OR done_aux2) AND valid(3);

				-- shift the arrays
				x_c_a(2 TO x_c_a'HIGH)   <= x_c_a(1 TO x_c_a'HIGH - 1);
				y_c_a(2 TO y_c_a'HIGH)   <= y_c_a(1 TO y_c_a'HIGH - 1);
				addr_a(2 TO addr_a'HIGH) <= addr_a(1 TO addr_a'HIGH - 1);
				iter_a(2 TO iter_a'HIGH) <= iter_a(1 TO iter_a'HIGH - 1);
				valid(2 TO valid'HIGH)   <= valid(1 TO valid'HIGH - 1);
			END IF;
		END IF;

	END PROCESS;

END ARCHITECTURE behavioral;
