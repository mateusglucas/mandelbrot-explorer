-- This block performs iterations of the Mandelbrot set using the recursive law z(i+1)=z(i)^2+z_c (where z_c=x_c+j*y_c)
-- When the modulus of z exceeds 2 or the maximum number of iterations is reached, the done signal goes high for one clock cycle.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY iterator IS
	GENERIC(

		K			: NATURAL:=36;  -- number of bits of fixed point representation
		I			: NATURAL:=4;   -- number of integer bits (including the sign bit) 
								    -- worst case is x_c=2-epsilon, y_c=0 -> x_new=2^2+2-epsilon=6-epsilon, y_new=0, 
								    -- which needs 4 bits in integer part (with sign bit)
		MAX_ITER	: NATURAL:=255; -- maximum number of iterations
		W_ADDR		: NATURAL:=17;  -- bits_of(RES_H*RES_V-1)
		W_ITER		: NATURAL:=8    -- bits_of(MAX_ITER)
	);
	PORT
	(
		clk			: IN STD_LOGIC; -- clock signal
		load		: IN STD_LOGIC; -- load signal
		x_c			: IN SIGNED(K-1 DOWNTO 0); -- real part of the complex number z_c
		y_c			: IN SIGNED(K-1 DOWNTO 0); -- imaginary part of the complex number z_c
		addr		: IN UNSIGNED(W_ADDR-1 DOWNTO 0); -- address of the pixel in the framebuffer
		done		: OUT STD_LOGIC; -- done signal
		iter		: OUT UNSIGNED(W_ITER-1 DOWNTO 0); -- number of iterations performed
		addr_out	: OUT UNSIGNED(W_ADDR-1 DOWNTO 0) -- address of the pixel in the framebuffer
	);
END iterator;

ARCHITECTURE behavioral OF iterator IS

SIGNAL x_c_r	: SIGNED (K-1 DOWNTO 0);
SIGNAL y_c_r	: SIGNED (K-1 DOWNTO 0);
SIGNAL iter_r	: UNSIGNED (W_ITER-1 DOWNTO 0);
SIGNAL addr_r	: UNSIGNED (W_ADDR-1 DOWNTO 0);
SIGNAL valid	: STD_LOGIC := '0';

SIGNAL xx: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL xy: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL yy: 			SIGNED (2*K-1 DOWNTO 0);
SIGNAL norm2: 		SIGNED (2*K-1 DOWNTO 0); -- worst case is x_c=2-epsilon, y_c=0 -> x_new=2^2+2-epsilon=6-epsilon, y_new=0 
											 -- -> norm2=(6-epsilon)^2+0^2=36-epsilon, which fits in 2*I=8 bits (with sign bit)
SIGNAL x: 			SIGNED (K-1 DOWNTO 0);
SIGNAL y: 			SIGNED (K-1 DOWNTO 0);
SIGNAL done_aux1:	STD_LOGIC;
SIGNAL done_aux2:	STD_LOGIC;
SIGNAL done_aux:	STD_LOGIC;

BEGIN

xx <= x * x;
yy <= y * y;
xy <= x * y;
norm2 <= xx + yy; 

iter<=iter_r;
addr_out<=addr_r;

done_aux1<= '0' WHEN iter_r<MAX_ITER ELSE '1';
done_aux2<= '0' WHEN SHIFT_RIGHT(norm2, 2*(K-I)) < 4 ELSE '1';
done_aux<=(done_aux1 OR done_aux2) AND valid;
done<=done_aux;

PROCESS(clk)
BEGIN
	IF(RISING_EDGE(clk)) THEN
		IF (load='1') THEN 
			x_c_r<=x_c;
			y_c_r<=y_c;
			x<=x_c;
			y<=y_c;
			addr_r<=addr;
			iter_r<=(OTHERS=>'0');
			valid<='1';
		ELSIF (done_aux='0' AND valid='1') THEN
			x <= (xx(2*K-I-1 DOWNTO K-I) - yy(2*K-I-1 DOWNTO K-I)) + x_c_r;
			y <= xy(2*K-I-2 DOWNTO K-I-1) + y_c_r;
			iter_r<=iter_r+1;
		ELSE
			valid<='0';
		END IF;
	END IF;
END PROCESS;

END behavioral;