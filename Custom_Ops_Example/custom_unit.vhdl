library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.common.all;

entity custom_unit is
    port (ra: in std_ulogic_vector(63 downto 0);
          rb: in std_ulogic_vector(63 downto 0);
          rc: in std_ulogic_vector(63 downto 0);
          insn: in std_ulogic_vector(31 downto 0);
          result: out std_ulogic_vector(63 downto 0)
      );
end entity custom_unit;

architecture behaviour of custom_unit is
signal tmpr: std_ulogic_vector(63 downto 0);

function sat_byte_add(a: std_ulogic_vector(7 downto 0); b:std_ulogic_vector(7 downto 0)) return  std_ulogic_vector is
        variable tmpa: std_ulogic_vector(8 downto 0);
	variable tmpb: std_ulogic_vector(7 downto 0);
begin
	tmpa := std_ulogic_vector(unsigned("0"&a) + unsigned("0"&b));
	tmpb := ( others => tmpa(8) );
       	return tmpa(7 downto 0) or tmpb;

end;

function sat_byte_sub(a: std_ulogic_vector(7 downto 0); b:std_ulogic_vector(7 downto 0)) return  std_ulogic_vector is
	variable tmpa: std_ulogic_vector(8 downto 0);
	variable tmpb: std_ulogic_vector(7 downto 0);
begin
        tmpa := std_logic_vector(unsigned("0"&b) - unsigned("0"&a));
        tmpb := ( others => tmpa(8) );
        return tmpa(7 downto 0) and not tmpb;

end;

begin
    custom_0: process(all)

    begin
        -- four different instructions
        case insn(1 downto 0) is
            when "00" =>  -- INSN_custom_addbusat
		    for i in 7 downto 0 loop
			    result(8*i+7 downto 8*i) <= sat_byte_add(ra(8*i+7 downto 8*i), rb(8*i+7 downto 8*i));
		    end loop;
            when "01" =>  -- INSN_custom_subbusat
		    for i in 7 downto 0 loop
                            result(8*i+7 downto 8*i) <= sat_byte_sub(ra(8*i+7 downto 8*i), rb(8*i+7 downto 8*i));
                    end loop;
            when "10" =>  -- INSN_custom_maskbu
		    for i in 7 downto 0 loop
			    if ra(8*i + 7 downto 8*i) = "00000000" then
				    result(8*i + 7 downto 8*i) <= "00000000";
			    else
				    result(8*i + 7 downto 8*i) <= "11111111";
			    end if;
            	    end loop;
	    when others => -- INSN_custom_gbbd
		    for i in 0 to 7 loop
			    for j in 0 to 7 loop
				    result(8*i + j) <= ra(i + 8*j);
			    end loop;
		    end loop; 
        end case;
    end process;
end behaviour;
