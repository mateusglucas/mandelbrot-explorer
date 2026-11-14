LIBRARY ieee;
	USE ieee.std_logic_1164.ALL;

PACKAGE utils IS

	FUNCTION bits_of (
		n : NATURAL
	) RETURN NATURAL;  -- ceil(log2(n))

END PACKAGE utils;

PACKAGE BODY utils IS

	FUNCTION bits_of (
		n : NATURAL
	) RETURN NATURAL IS

		VARIABLE v : natural;
		VARIABLE r : natural;

	BEGIN

		v := n;
		r := 0;

		IF (n = 0) THEN
			RETURN 1;
		END IF;

		WHILE v > 0 LOOP

			v := v / 2;
			r := r + 1;

		END LOOP;

		RETURN r;

	END FUNCTION bits_of;

END PACKAGE BODY utils;
