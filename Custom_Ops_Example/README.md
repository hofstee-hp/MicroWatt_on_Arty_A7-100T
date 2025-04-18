# Adding custom instructions to Microwatt

In this subdirectory we give an example of how to add custom instructions to the Microwatt processor.

We recommend you look through the presentations on the Power ISA, and the microarchitecture of Microwatt in the parent directory first.
Also, make sure you can build Microwatt and run a simulation in GHDL by following the instructions in the parent directory.

A slide deck posted in the parent directory provides a motivation for specifically adding the instructions in our example, but here we just focus on their implementation and validation.

First a few words on custom instructions. Custom instructions are a double-edged sword. On the one hand, custom instructions can make an application much faster. On the other hand, custom instructions can fragment the architecture. In the powerpc ISA primary opcode 22 is reserved for custom opcodes, and adding custom extensions to your processor doesn't break your compliance with the architecture. At the same time, of course, if you use custom extensions then the toolchains won't natively support them, so you will likely want to limit their use to some very specific functions.

For our example we decided to add instructions with three source registers and a (distinct) destination register. We chose the opcodes to be similar to integer multiply-add instructions that also have three sources and a distinct destination. However, the instructions we implemented in this example only use one or two source operands. The reason we decided to do this is to make our example useful to people who might want to add very powerful instructions that get a lot done in a single operation, and we wanted to make this example easy to adapt.

The instructions we used as our example are:
```
  maddhd    4, RT, RA, RB, RC, 48  - i.e. primary 6b opcode = 4, four 5-bit integer register indentifiers, and 48 for the secondary opcode
  maddhdu   4, RT, RA, RB, RC, 49
  maddld    4, RT, RA, RB, RC, 51
```
  The new instructions we define are:
```
  addbusat   22, RT, RA, RB, RC, 48  - add bytes unsigned saturating, RC is ignored
  subbusat   22, RT, RA, RB, RC, 49  - subtract bytes unsigned saturating, RC is ignored ( byte-wise subtract RB from RA )
  maskbu     22, RT, RA, RB, RC, 50  - for each byte 0x00 -> 0x00 others -> 0xFF
  gbbd       22, RT, RA, RB, RC, 51  - transpose RA, where RA is considered an 8x8 array of bits
```
  We define a new execution unit (custom_unit.vhdl) that will handle these custom instructions:
```
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
```

We modify the Makefile to include this unit in the build process:

```
root@localhost:~/microwatt# diff Makefile.old Makefile
```

```
69a70
> # begin modified for custom unit: added custom_unit.vhdl
74c75
< 	cr_file.vhdl crhelpers.vhdl ppc_fx_insns.vhdl rotator.vhdl \
---
> 	cr_file.vhdl crhelpers.vhdl ppc_fx_insns.vhdl rotator.vhdl custom_unit.vhdl\
77a79
> # end modified for custom unit
```

decode_types.vhdl is updated to add the new instructions and opcode group

```
root@localhost:~/microwatt# diff decode_types.vhdl.old decode_types.vhdl
```

```
5c5,6
<     type insn_type_t is (OP_ILLEGAL, OP_NOP, OP_ADD,
---
> -- begin modified for custom instructions: added OP_CUSTOM
>     	type insn_type_t is (OP_ILLEGAL, OP_NOP, OP_ADD,
9c10
< 			 OP_CNTZ, OP_CROP,
---
> 			 OP_CNTZ, OP_CROP, OP_CUSTOM,
28a30
> -- end modified for custom instructions
283a286,293
> 	-- begin added custom instructions here
> 	-- NOTE: for ease of modification of this code custom instructions are defined as having three 64b integer operands and one 64b integer result
>         INSN_custom_addbusat,
> 	INSN_custom_subbusat,
> 	INSN_custom_maskbu,
> 	INSN_custom_gbbd,
> 	-- add added custom instructions here (and removed some padding)
> 
285,286c295
<         INSN_235,
<         INSN_236, INSN_237, INSN_238, INSN_239,
---
>         INSN_239,
781a791,796
> -- begin added custom opcodes
> 	    when INSN_custom_addbusat => return "010110";
> 	    when INSN_custom_subbusat => return "010110";
> 	    when INSN_custom_maskbu   => return "010110";
> 	    when INSN_custom_gbbd     => return "010110";
> -- end added custom opcodes
```
predecode.vhdl adds support for the new instructions as well

```
root@localhost:~/microwatt# diff predecode.vhdl.old predecode.vhdl
```

```
112a113,119
> -- begin added custom opcodes
> 	-- major opcode 22
> 	2#010110_10000#			   =>  INSN_custom_addbusat,
> 	2#010110_10001#			   =>  INSN_custom_subbusat,
> 	2#010110_10010#			   =>  INSN_custom_maskbu,
> 	2#010110_10011#			   =>  INSN_custom_gbbd,
> -- end added custom opcodes
581a589,591
> 
> 	    	when "010110" => -- 22
> 		    -- custom instructions
```
We modified decode1.vhdl which decodes the primary opcodes
```
root@localhost:~/microwatt# diff decode1.vhdl.old decode1.vhdl
```

```
249a250,255
> -- begin add custom instructions
> 	INSN_custom_addbusat => ( ALU, NONE, OP_CUSTOM, RA,         RB,          RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', NONE),
> 	INSN_custom_subbusat => ( ALU, NONE, OP_CUSTOM, RA,	    RB,		 RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', NONE),
> 	INSN_custom_maskbu   => ( ALU, NONE, OP_CUSTOM, RA,         RB,          RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', NONE),
> 	INSN_custom_gbbd     => ( ALU, NONE, OP_CUSTOM, RA,	    RB,          RCR,  RT,   '0', '0', '0', '0', ZERO, '0', NONE, '0', '0', '0', '0', '0', '0', NONE, '0', '0', NONE),
> -- end add custom instructions
```
as well as decode2.vhdl ... fortunately one of the values for the three-bit output mux that selects between the execution units was not yet used

```
root@localhost:~/microwatt# diff decode2.vhdl.old decode2.vhdl
```

```
225a226,228
> -- begin added OP_CUSTOM
>         OP_CUSTOM   => "110",		-- custom_result
> -- end added OP_CUSTOM
```

Finally we modified execute1.vhdl to add the custom execution unit

```
root@localhost:~/microwatt# diff execute1.vhdl.old execute1.vhdl
```

```
196a197,199
>     -- begin added for custom unit
>     signal custom_result: std_ulogic_vector(63 downto 0);
>     -- end added for custom unit
404a408,418
>     -- begin added for custom unit
>     custom_0: entity work.custom_unit
> 	port map (
>     	    ra => a_in,
>     	    rb => b_in,
> 	    rc => c_in,
> 	    insn => e_in.insn,
> 	    result => custom_result
>             );
>     -- end added for custom unit	
> 	
598a613
>     -- begin modified for custom unit
606a622
> 	custom_result      when "110",
607a624
>     -- end modified for custom unit
```

That's it! Our first sanity check ( used step by step as we were modifying the code ) was to run micropython. Of course micropython doesn't use any of the new instructions, but by testing frequently we would be able to narrow down what change would be the culprit.

Our final step is to check that the new instructions work. We created the following custom.c file in a directory named custom in the microwatt/tests directory, and also copied head.S and powerpc.lds and into this directory from one of the other tests directories

```
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "console.h"

#define asm	__asm__ volatile

void print_string(const char *str)
{
	for (; *str; ++str)
		putchar(*str);
}

void print_hex(const char *str0, unsigned long val, int ndigits, const char *str1)
{
	print_string(str0);
	
	int i, x;

	for (i = (ndigits - 1) * 4; i >= 0; i -= 4) {
		x = (val >> i) & 0xf;
		if (x >= 10)
			putchar(x + 'a' - 10);
		else
			putchar(x + '0');
	}
			
	print_string(str1);
}

int test_1(void)
{

	long i;
	
	// Assembly macros and functions to facilitate using the new instructions in inline assembly

	asm (".macro custom_addbusat rt:req,ra:req,rb:req,rc:req\n" \
                ".long 22<<26 | ((\\rt&0x1f) << 21) | ((\\ra&0x1f) << 16) | ((\\rb&0x1f) << 11) |((\\rc&0x1f) << 6) | 48\n" \
                ".endm\n");

	long
	addbusat (long *src)
	{
	  long rt;
	  long ra = src[0];
	  long rb = src[1];
	  long rc = src[2];

	  asm ("custom_addbusat %0,%1,%2,%3\n\t"
           : "=r" (rt)
           : "r" (ra), "r" (rb), "r" (rc));
  	  return rt;
	}

        asm (".macro custom_subbusat rt:req,ra:req,rb:req,rc:req\n" \
                ".long 22<<26 | ((\\rt&0x1f) << 21) | ((\\ra&0x1f) << 16) | ((\\rb&0x1f) << 11) |((\\rc&0x1f) << 6) | 49\n" \
                ".endm\n");

        long
        subbusat (long *src)
        {
          long rt;
          long ra = src[0];
          long rb = src[1];
          long rc = src[2];

          asm ("custom_subbusat %0,%1,%2,%3\n\t"
           : "=r" (rt)
           : "r" (ra), "r" (rb), "r" (rc));
          return rt;
        }

	asm (".macro custom_maskbu rt:req,ra:req,rb:req,rc:req\n" \
                ".long 22<<26 | ((\\rt&0x1f) << 21) | ((\\ra&0x1f) << 16) | ((\\rb&0x1f) << 11) |((\\rc&0x1f) << 6) | 50\n" \
                ".endm\n");

        long
        maskbu (long *src)
        {
          long rt;
          long ra = src[0];
          long rb = src[1];
          long rc = src[2];

          asm ("custom_maskbu %0,%1,%2,%3\n\t"
           : "=r" (rt)
           : "r" (ra), "r" (rb), "r" (rc));
          return rt;
        }

	asm (".macro custom_gbbd rt:req,ra:req,rb:req,rc:req\n" \
                ".long 22<<26 | ((\\rt&0x1f) << 21) | ((\\ra&0x1f) << 16) | ((\\rb&0x1f) << 11) |((\\rc&0x1f) << 6) | 51\n" \
                ".endm\n");

        long
        gbbd (long *src)
        {
          long rt;
          long ra = src[0];
          long rb = src[1];
          long rc = src[2];

          asm ("custom_gbbd %0,%1,%2,%3\n\t"
           : "=r" (rt)
           : "r" (ra), "r" (rb), "r" (rc));
          return rt;
        }

	// Simple tests of new instructions
	
	struct custom_tests {
        	long op22_regs[3];
	} custom_tests[] = {
        	{ { 0x8080808080808080, 0x8080808080808080, 0x0000000000000000} },
		{ { 0x00020304050607ff, 0xfafafafafafafafa, 0x0000000000000000} },
	};

	long results_addbusat;
        long results_subbusat;
        long results_maskbu;
        long results_gbbd;

	print_string("\r\n");
	for (i = 0; i < sizeof(custom_tests) / sizeof(custom_tests[0]); ++i) {
		results_addbusat = addbusat(custom_tests[i].op22_regs);
		results_subbusat = subbusat(custom_tests[i].op22_regs);
		results_maskbu   = maskbu(custom_tests[i].op22_regs);
		results_gbbd     = gbbd(custom_tests[i].op22_regs); 
                print_hex("test no.", i, 2, "\r\n");
		print_hex("a: 0x",custom_tests[i].op22_regs[0], 16, "  ");
		print_hex("b: 0x",custom_tests[i].op22_regs[1], 16, "  ");
		print_hex("c: 0x",custom_tests[i].op22_regs[2], 16, "  ");
                print_hex("addbusat:",results_addbusat, 16, " ");
		print_hex("subbusat:",results_subbusat, 16, " ");
		print_hex("maskbu:",results_maskbu, 16, " ");
		print_hex("gbbd:",results_gbbd, 16, "\r\n ");
        }
        
	// Spiking neural net example
	
        long ns = 0x0000000000000000;   // neuron state internal side initial state
        long nl = 0x0101010101010101;   // neuron by cycle leakage
        long ei = 0x00ffffff00ffff00;	// external inputs ( one byte per activation )
	long ii;			// internal inputs ( one byte per activation )
	long ea = 0x1040080a00090000;   // synaptic connections matrix external inputs 
        long ia = 0x0000082014400204;   // synaptic connections matrix internal inputs
        long es = 0x0000200000001004;   // inhibiting synaptic connections matrix external inputs
        long is = 0x0000000000080000;   // inhibiting synaptic connections matrix internal inputs
	long dum0=0, dum1=0, tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7, tmp8, tmp9, tmp10, tmp11, tmp12, tmp13, tmp14, tmp15;
	
	print_hex("Spiking Neural Net",0, 0, "\r\n");
	print_hex("initial neuron state   : 0x", ns, 16, "\r\n");
	print_hex("neuron by cycle leakage: 0x", nl, 16, "\r\n");
	print_hex("External activations   : 0x", ei, 16, "\r\n");
	print_hex("ext. add. conn.  matrix: 0x", ea, 16, "\r\n");
        print_hex("int. add. conn.  matrix: 0x", ia, 16, "\r\n");
	print_hex("ext. inh. conn.  matrix: 0x", es, 16, "\r\n");
        print_hex("int. inh. conn.  matrix: 0x", is, 16, "\r\n");

	for (i = 0; i < 3; ++i) {

        	asm ("custom_maskbu %0,%1,%2,%3\n\t" : "=r" (ii) : "r" (ns), "r" (dum0), "r" (dum1));
        
                asm ("and %0,%1,%2\n\t" : "=r" (tmp0) : "r" (ei), "r" (ea));
                asm ("and %0,%1,%2\n\t" : "=r" (tmp1) : "r" (ii), "r" (ia));
                asm ("and %0,%1,%2\n\t" : "=r" (tmp2) : "r" (ei), "r" (es));
                asm ("and %0,%1,%2\n\t" : "=r" (tmp3) : "r" (ii), "r" (is));

		asm ("custom_gbbd %0,%1,%2,%3\n\t" : "=r" (tmp4) : "r" (tmp0), "r" (dum0), "r" (dum1));
        	asm ("custom_gbbd %0,%1,%2,%3\n\t" : "=r" (tmp5) : "r" (tmp1), "r" (dum0), "r" (dum1));
        	asm ("custom_gbbd %0,%1,%2,%3\n\t" : "=r" (tmp6) : "r" (tmp2), "r" (dum0), "r" (dum1));
        	asm ("custom_gbbd %0,%1,%2,%3\n\t" : "=r" (tmp7) : "r" (tmp3), "r" (dum0), "r" (dum1));

		asm("popcntb %0, %1\n\t" : "=r" (tmp8) : "r" (tmp4));
        	asm("popcntb %0, %1\n\t" : "=r" (tmp9) : "r" (tmp5));
        	asm("popcntb %0, %1\n\t" : "=r" (tmp10) : "r" (tmp6));
        	asm("popcntb %0, %1\n\t" : "=r" (tmp11) : "r" (tmp7));

        	asm ("custom_addbusat %0,%1,%2,%3\n\t" : "=r" (tmp12) : "r" (tmp8), "r" (tmp9), "r" (dum1));
        	asm ("custom_addbusat %0,%1,%2,%3\n\t" : "=r" (tmp13) : "r" (tmp10), "r" (tmp11), "r" (dum1));
        	asm ("custom_subbusat %0,%1,%2,%3\n\t" : "=r" (tmp14) : "r" (tmp13), "r" (tmp12), "r" (dum1));
        	asm ("custom_addbusat %0,%1,%2,%3\n\t" : "=r" (tmp15) : "r" (ns), "r" (tmp14), "r" (dum1));
        	asm ("custom_subbusat %0,%1,%2,%3\n\t" : "=r" (ns) : "r" (nl), "r" (tmp15), "r" (dum1));

		print_hex("Iteration              : ", i, 2, "\r\n");
        	print_hex("neuron state           : 0x", ns, 16, "\r\n");
		print_hex("External activations   : 0x", ei, 16, "\r\n");
		print_hex("Internal activations   : 0x", ii, 16, "\r\n");
		print_hex("popcntb(gbbd(ei & ea)) : 0x", tmp8, 16, "\r\n");
        	print_hex("popcntb(gbbd(ii & ia)) : 0x", tmp9, 16, "\r\n");
        	print_hex("popcntb(gbbd(ei & es)) : 0x", tmp10, 16, "\r\n");
        	print_hex("popcntb(gbbd(ii & ia)) : 0x", tmp11, 16, "\r\n");
		print_hex("state delta            : 0x", tmp14, 16, "\r\n");
		print_hex("leakage delta          : 0x", nl, 16, "\r\n");
		print_hex("new state              : 0x", ns, 16, "\r\n");
	}

	return 0;
}

int main(void)
{
	console_init();

	test_1();

	return 0;
}
```

We create a Makefile:

```
TEST=custom

include ../Makefile.test
```
If in the custom directory we type
```
make
```
followed by
```
powerpc64le-linux-gnu-objdump -d custom.o
```
and we look in the output we find:
```
...
 340:	00 00 20 39 	li      r9,0
 344:	72 4a 7d 5a 	rlmi    r29,r19,r9,9,25
 348:	38 d0 ca 7f 	and     r10,r30,r26
 34c:	38 d8 6e 7e 	and     r14,r19,r27
 350:	38 90 d9 7f 	and     r25,r30,r18
 354:	08 00 80 3f 	lis     r28,8
 358:	38 e0 7c 7e 	and     r28,r19,r28
 35c:	73 4a 4a 59 	rlmi.   r10,r10,r9,9,25
 360:	73 4a ce 59 	rlmi.   r14,r14,r9,9,25
 364:	73 4a 39 5b 	rlmi.   r25,r25,r9,9,25
 368:	73 4a 9c 5b 	rlmi.   r28,r28,r9,9,25
 36c:	f4 00 54 7d 	popcntb r20,r10
 370:	f4 00 ce 7d 	popcntb r14,r14
 374:	f4 00 39 7f 	popcntb r25,r25
 378:	f4 00 9c 7f 	popcntb r28,r28
 37c:	70 72 14 59 	rlmi    r20,r8,r14,9,24
 380:	70 e2 19 58 	rlmi    r25,r0,r28,9,24
 384:	71 42 a0 5a 	rlmi.   r0,r21,r8,9,24
 388:	70 aa bd 5b 	rlmi    r29,r29,r21,9,24
 38c:	01 01 00 3d 	lis     r8,257
 390:	01 01 08 61 	ori     r8,r8,257
 394:	0e 00 08 79 	rldimi  r8,r8,32,0
 398:	71 ea a8 5b 	rlmi.   r8,r29,r29,9,24
 39c:	02 00 a0 38 	li      r5,2
 3a0:	78 b3 c4 7e 	mr      r4,r22
 3a4:	78 fb e6 7f 	mr      r6,r31
 3a8:	78 7b e3 7d 	mr      r3,r15
 3ac:	78 00 01 f9 	std     r8,120(r1)
 3b0:	01 00 d6 3a 	addi    r22,r22,1
... ( bunch of code for the print statements )
 494:	03 00 36 2c 	cmpdi   r22,3
 498:	a8 fe 82 40 	bne     340 <test_1+0x340>
...
```
and while the disassembler does not have support for the new instructions we defined, we see that indeed each of the lines with custom assembly that we added resulted in one opcode. Also, keep in mind that the bytes on the left are reversed from what you see in the instruction definitions in the power architecture manual. Thus the last byte is the first, and the first 6 bits of "0x58","0x59","0x5a", or "0x5b" are 0101 10.. indeed corresponding to primary opcode 22.

These are the commands to make and run the test.
```
root@localhost:~/microwatt/tests/custom# make
powerpc64le-linux-gnu-gcc -Os -g -Wall -std=c99 -nostdinc -msoft-float -mno-string -mno-multiple -mno-vsx -mno-altivec -mlittle-endian -fno-stack-protector -mstrict-align -ffreestanding -fdata-sections -ffunction-sections -I ../../include -isystem /usr/lib/gcc-cross/powerpc64le-linux-gnu/13/include   -c -o custom.o custom.c
powerpc64le-linux-gnu-ld -T powerpc.lds -o custom.elf custom.o head.o console.o
powerpc64le-linux-gnu-ld: warning: custom.elf has a LOAD segment with RWX permissions
powerpc64le-linux-gnu-objcopy -O binary custom.elf custom.bin
../../scripts/bin2hex.py custom.bin > custom.hex
root@localhost:~/microwatt/tests/custom# cp custom.bin main_ram.bin
root@localhost:~/microwatt/tests# ~/microwatt/core_tb > /dev/null
```

The above command sends the debug output to /dev/null
Running the test takes several minutes ( likely due to all the instructions needed for the emulated I/O ).
```
test no.00
a: 0x8080808080808080  b: 0x8080808080808080  c: 0x0000000000000000  addbusat:ffffffffffffffff subbusat:0000000000000000 maskbu:ffffffffffffffff gbbd:ff00000000000000
 test no.01
a: 0x00020304050607ff  b: 0xfafafafafafafafa  c: 0x0000000000000000  addbusat:fafcfdfeffffffff subbusat:faf8f7f6f5f4f300 maskbu:00ffffffffffffff gbbd:01010101011f672b
 Spiking Neural Net
initial neuron state   : 0x0000000000000000
neuron by cycle leakage: 0x0101010101010101
External activations   : 0x00ffffff00ffff00
ext. add. conn.  matrix: 0x1040080a00090000
int. add. conn.  matrix: 0x0000082014400204
ext. inh. conn.  matrix: 0x0000200000001004
int. inh. conn.  matrix: 0x0000000000080000
Iteration              : 00
neuron state           : 0x0000000002000000
External activations   : 0x00ffffff00ffff00
Internal activations   : 0x0000000000000000
popcntb(gbbd(ei & ea)) : 0x0001000003000101
popcntb(gbbd(ii & ia)) : 0x0000000000000000
popcntb(gbbd(ei & es)) : 0x0000010100000000
popcntb(gbbd(ii & ia)) : 0x0000000000000000
state delta            : 0x0001000003000101
leakage delta          : 0x0101010101010101
new state              : 0x0000000002000000
Iteration              : 01
neuron state           : 0x0000000004000000
External activations   : 0x00ffffff00ffff00
Internal activations   : 0x00000000ff000000
popcntb(gbbd(ei & ea)) : 0x0001000003000101
popcntb(gbbd(ii & ia)) : 0x0000000100010000
popcntb(gbbd(ei & es)) : 0x0000010100000000
popcntb(gbbd(ii & ia)) : 0x0000000000000000
state delta            : 0x0001000003010101
leakage delta          : 0x0101010101010101
new state              : 0x0000000004000000
Iteration              : 02
neuron state           : 0x0000000006000000
External activations   : 0x00ffffff00ffff00
Internal activations   : 0x00000000ff000000
popcntb(gbbd(ei & ea)) : 0x0001000003000101
popcntb(gbbd(ii & ia)) : 0x0000000100010000
popcntb(gbbd(ei & es)) : 0x0000010100000000
popcntb(gbbd(ii & ia)) : 0x0000000000000000
state delta            : 0x0001000003010101
leakage delta          : 0x0101010101010101
new state              : 0x0000000006000000
```
which is what we were expecting! 

## Building with fusesoc

To build with fusesoc we need to update $microwatt.core$

```
root@localhost:~/microwatt# diff microwatt.core.old microwatt.core
```

```
30a31
>       - custom_unit.vhdl
```


