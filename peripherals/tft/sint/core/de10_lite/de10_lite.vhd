-------------------------------------------------------------------
-- Name        : de0_lite.vhd
-- Author      : 
-- Version     : 0.1
-- Copyright   : Departamento de Eletrônica, Florianópolis, IFSC
-- Description : Projeto base DE10-Lite
-------------------------------------------------------------------
LIBRARY ieee;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

use work.decoder_types.all;

entity de10_lite is 
	generic (
		--! Num of 32-bits memory words 
		IMEMORY_WORDS : integer := 1024;	--!= 4K (1024 * 4) bytes
		DMEMORY_WORDS : integer := 1024  	--!= 2k (512 * 2) bytes
	);


	port (
		---------- CLOCK ----------
		ADC_CLK_10:	in std_logic;
		MAX10_CLK1_50: in std_logic;
		MAX10_CLK2_50: in std_logic;
		
		----------- SDRAM ------------
		DRAM_ADDR: out std_logic_vector (12 downto 0);
		DRAM_BA: out std_logic_vector (1 downto 0);
		DRAM_CAS_N: out std_logic;
		DRAM_CKE: out std_logic;
		DRAM_CLK: out std_logic;
		DRAM_CS_N: out std_logic;		
		DRAM_DQ: inout std_logic_vector(15 downto 0);
		DRAM_LDQM: out std_logic;
		DRAM_RAS_N: out std_logic;
		DRAM_UDQM: out std_logic;
		DRAM_WE_N: out std_logic;
		
		----------- SEG7 ------------
		HEX0: out std_logic_vector(7 downto 0);
		HEX1: out std_logic_vector(7 downto 0);
		HEX2: out std_logic_vector(7 downto 0);
		HEX3: out std_logic_vector(7 downto 0);
		HEX4: out std_logic_vector(7 downto 0);
		HEX5: out std_logic_vector(7 downto 0);

		----------- KEY ------------
		KEY: in std_logic_vector(1 downto 0);

		----------- LED ------------
		LEDR: out std_logic_vector(9 downto 0);

		----------- SW ------------
		SW: in std_logic_vector(9 downto 0);

		----------- VGA ------------
		VGA_B: out std_logic_vector(3 downto 0);
		VGA_G: out std_logic_vector(3 downto 0);
		VGA_HS: out std_logic;
		VGA_R: out std_logic_vector(3 downto 0);
		VGA_VS: out std_logic;
	
		----------- Accelerometer ------------
		GSENSOR_CS_N: out std_logic;
		GSENSOR_INT: in std_logic_vector(2 downto 1);
		GSENSOR_SCLK: out std_logic;
		GSENSOR_SDI: inout std_logic;
		GSENSOR_SDO: inout std_logic;
	
		----------- Arduino ------------
		ARDUINO_IO: inout std_logic_vector(15 downto 0);
		ARDUINO_RESET_N: inout std_logic;
		
		GPIO: inout std_logic_vector(35 downto 0)
	);
	
end entity;


architecture rtl of de10_lite is
	
		
	signal clk : std_logic;
	signal rst : std_logic;
	
	-- Instruction bus signals
	signal idata     : std_logic_vector(31 downto 0);
	signal iaddress  : integer range 0 to IMEMORY_WORDS-1 := 0;
	signal address   : std_logic_vector (9 downto 0);
	
	-- Data bus signals
	signal daddress :  integer range 0 to DMEMORY_WORDS-1;
	signal ddata_r	:  	std_logic_vector(31 downto 0);
	signal ddata_w  :	std_logic_vector(31 downto 0);
	signal dmask    : std_logic_vector(3 downto 0);
	signal dcsel    : std_logic_vector(1 downto 0);
	signal d_we     : std_logic := '0';
	
	signal ddata_r_mem : std_logic_vector(31 downto 0);
	signal d_rd : std_logic;			
	
	-- I/O signals
	signal input_in : std_logic_vector(31 downto 0);
	
	-- PLL signals
	signal locked_sig : std_logic;
	
	-- CPU state signals
	signal state : cpu_state_t;
	signal d_sig : std_logic;	
	
	
	-- TFT signals
	signal clock_tft : std_logic;
	
	
	signal pin_output : unsigned(7 downto 0);
	signal pin_cs     : std_logic := '0';
	signal pin_rs     : std_logic := '0';
	signal pin_wr     : std_logic := '0';
	signal pin_rst    : std_logic := '0';
	signal ret    	  : unsigned(31 downto 0);
	
	signal input_a 	: unsigned(31 downto 0);
	signal input_b 	: unsigned(31 downto 0);
	signal input_c 	: unsigned(31 downto 0);

	
begin
	
	 pll_inst: entity work.pll
 	port map(
 		areset => '0',
 		inclk0 => MAX10_CLK1_50,
 		c0     => clk,
 		c1     => clock_tft,
 		locked => locked_sig
 	);
 	
 	rst <= SW(9);
 

 tft_inst : entity work.tft
	port map(
		clk        => clock_tft,
		daddress   => daddress,
		dcsel      => dcsel,
		d_we       => d_we,
		input_a    => input_a,
		input_b    => input_b,
		input_c    => input_c,
		ret        => ret,
		pin_output => pin_output,
		pin_cs     => pin_cs,
		pin_rs     => pin_rs,
		pin_wr     => pin_wr,
		pin_rst    => pin_rst
	);
	
	ARDUINO_IO(8) <= std_logic(pin_output(0));
	ARDUINO_IO(9) <= std_logic(pin_output(1));
	ARDUINO_IO(2) <= std_logic(pin_output(2));
	ARDUINO_IO(3) <= std_logic(pin_output(3));
	ARDUINO_IO(4) <= std_logic(pin_output(4));
	ARDUINO_IO(5) <= std_logic(pin_output(5));
	ARDUINO_IO(6) <= std_logic(pin_output(6));
	ARDUINO_IO(7) <= std_logic(pin_output(7)); 
	
	GPIO(35) <= pin_cs;
	GPIO(34) <= pin_rs;
	GPIO(33) <= pin_wr;
	
	GPIO(32) <= SW(0);
	GPIO(31) <= '1';

	GPIO(30) <= not(SW(0));--pin_rst; --
	
	process(pin_wr)
	begin
		
	
	end process;
	
	
	--Softcore ------------------------------------------------------------------------

	-- Dummy out signals
	DRAM_DQ <= ddata_r(15 downto 0);
	--ARDUINO_IO <= ddata_r(31 downto 16);
	LEDR(9) <= SW(9);
	DRAM_ADDR(9 downto 0) <= address;
		
	-- IMem shoud be read from instruction and data buses
	-- Not enough RAM ports for instruction bus, data bus and in-circuit programming
	process(d_rd, dcsel, daddress, iaddress)
	begin
		if (d_rd = '1') and (dcsel = "00") then
			address <= std_logic_vector(to_unsigned(daddress,10));
		else
			address <= std_logic_vector(to_unsigned(iaddress,10));
		end if;		
	end process;

	-- 32-bits x 1024 words quartus RAM (dual port: portA -> riscV, portB -> In-System Mem Editor
	iram_quartus_inst: entity work.iram_quartus
		port map(
			address => address,
			byteena => "1111",
			clock   => clk,
			data    => (others => '0'),
			wren    => '0',
			q       => idata
		);
	
	-- Data Memory RAM
	dmem: entity work.dmemory
		generic map(
			MEMORY_WORDS => DMEMORY_WORDS
		)
		port map(
			rst     => rst,
			clk     => clk,
			data    => ddata_w,
			address => daddress,
			we      => d_we,
			csel    => dcsel(0),
			signal_ext => d_sig,
			dmask   => dmask,
			q       => ddata_r_mem
		);
	
	-- Adress space mux ((check sections.ld) -> Data chip select:
	-- 0x00000    ->    Instruction memory
	-- 0x20000    ->    Data memory
	-- 0x40000    ->    Input/Output generic address space		
	with dcsel select 
		ddata_r <= idata when "00",
		           ddata_r_mem when "01",
		           input_in when "10",
		           (others => '0') when others;
	
	-- Softcore instatiation
	myRisc: entity work.core
		generic map(
			IMEMORY_WORDS => IMEMORY_WORDS,
			DMEMORY_WORDS => DMEMORY_WORDS
		)
		port map(			
			clk      => clk,
			rst      => rst,
			iaddress => iaddress,
			idata    => idata,
			daddress => daddress,
			ddata_r  => ddata_r,
			ddata_w  => ddata_w,
			d_we     => d_we,
			d_rd     => d_rd,
			dcsel    => dcsel,
			d_sig 	 => d_sig,
			dmask    => dmask,
			state    => state
		);
	
	-- Output register (Dummy LED blinky)
	process(clk, rst)
	begin		
		if rst = '1' then
			--LEDR(3 downto 0) <= (others => '0');			
			HEX0 <= (others => '1');
			HEX1 <= (others => '1');
			HEX2 <= (others => '1');
			HEX3 <= (others => '1');
			HEX4 <= (others => '1');
			HEX5 <= (others => '1');			
		else
			if rising_edge(clk) then		
				if (d_we = '1') and (dcsel = "10")then					
					-- ToDo: Simplify comparators
					-- ToDo: Maybe use byte addressing?  
					--       x"01" (word addressing) is x"04" (byte addressing)
					if to_unsigned(daddress, 32)(8 downto 0) = x"01" then										
						--LEDR(4 downto 0) <= ddata_w(4 downto 0);
					elsif to_unsigned(daddress, 32)(8 downto 0) = x"02" then
					 	HEX0 <= ddata_w(7 downto 0);
						HEX1 <= ddata_w(15 downto 8);
						HEX2 <= ddata_w(23 downto 16);
						HEX3 <= ddata_w(31 downto 24);
						HEX4 <= (others => '1');
						HEX5 <= (others => '1');
					
					elsif to_unsigned(daddress, 32)(8 downto 0) = x"08" then
						input_a <= unsigned(ddata_w);
					elsif to_unsigned(daddress, 32)(8 downto 0) = x"09" then
						input_b <= unsigned(ddata_w);
					elsif to_unsigned(daddress, 32)(8 downto 0) = x"0A" then
						input_c <= unsigned(ddata_w);
					
					end if;				
				end if;
			end if;
		end if;		
	end process;
	
	
	-- Input register
	process(clk, rst)
	begin		
		if rst = '1' then
			input_in <= (others => '0');
		else
			if rising_edge(clk) then		
				input_in <= (others => '0');
				if (d_rd = '1') and (dcsel = "10") then
					input_in(4 downto 0) <= SW(4 downto 0);
				end if;
			end if;
		end if;		
	end process;
	
end;

