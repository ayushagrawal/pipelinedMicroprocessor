library ieee;
use ieee.std_logic_1164.all;

library work;
use work.components.all;

entity microprocessor is
	port(clock_c : in std_logic;
		  reset : in std_logic);
end entity;
		  
architecture mic of microprocessor is
	signal input_if,  output_if  : std_logic_vector(48 downto 0);
	signal input_id,  output_id  : std_logic_vector(80 downto 0);
	signal input_rr,  output_rr  : std_logic_vector(105 downto 0);
	signal input_ex,  output_ex  : std_logic_vector(109 downto 0);
	signal input_mem, output_mem : std_logic_vector(90 downto 0);
	
	signal rfDataInsel_out_w : std_logic_vector(2 downto 0);
	signal r7_enable_out_w : std_logic;
	signal regWrite_w : std_logic;
	signal DataIn_w : std_logic_vector(15 downto 0);  
	signal pcIn_w : std_logic_vector(15 downto 0);
	signal pcRegMux_crtl_w : std_logic;
	signal enable_if,enable_id,enable_rr,enable_ex,enable_mem,counter_reset: std_logic;
	signal clock : std_logic;
	signal dataHazardFlag : std_logic;
	signal A,B : std_logic_vector(15 downto 0);
	signal regA_mux,regB_mux : std_logic_vector(1 downto 0);
	signal bubble,not_bubble : std_logic;
	signal carry_en,zero_en : std_logic;
	signal NOP_ex,NOP_mem,NOP_rr,NOP_decode,NOP_fetch : std_logic;
	signal pc : std_logic_vector(15 downto 0);
	signal pc_hazard : std_logic;
	signal counter_en,pc_reg,counter_en2 : std_logic;
	signal counter_value : std_logic_vector(2 downto 0);
	signal counter_validity,lm_en,lm,lm1 : std_logic;

begin
	
	clk_divide : CLOCK_DIVIDER port map (reset => reset,clk => clock_c,half_clk => clock);
	
	IF_ID  : registers generic map(N => 49)  port map(clock => clock, reset => reset, enable => enable_if,  input => input_if,  output => output_if);
	ID_RR  : registers generic map(N => 81)  port map(clock => clock, reset => reset, enable => enable_id,  input => input_id,  output => output_id);
	RR_EX  : registers generic map(N => 106)  port map(clock => clock, reset => reset, enable => enable_rr,  input => input_rr,  output => output_rr);
	EX_MEM : registers generic map(N => 110) port map(clock => clock, reset => reset, enable => enable_ex,  input => input_ex,  output => output_ex);
	MEM_WB : registers generic map(N => 91)  port map(clock => clock, reset => reset, enable => enable_mem, input => input_mem, output => output_mem);

	not_bubble <= (not bubble);
	
	counter_validity <= counter_value(0) and counter_value(1) and counter_value(2);
	lm_en <= counter_value(0) and (not counter_value(1)) and (not counter_value(2));
	lm1 <= counter_en2;
	
	enable_if <= not_bubble and ((not (counter_en or counter_en2)) or counter_validity);
	enable_id <= not_bubble;
	enable_rr <= not_bubble;
	enable_ex <= '1';
	enable_mem <= '1';
	
	
	HazardDU	: hazardDetectionUnit port map(regSel_ex_in => output_rr(22 downto 20),
														 regSel_mem_in => output_ex(12  downto 10),
														 regSel_wb_in => output_mem(8 downto 6),
														 regSel_A => output_id(28 downto 26),
														 regSel_B => output_id(25 downto 23),
														 dataHazardFlag => dataHazardFlag,				-- Can be used for inserting a bubble
														 RR_A_mux_sel => regA_mux,
														 RR_B_mux_sel => regB_mux,
														 counter_en => counter_en,
														 NOP_ex => output_rr(88),
														 NOP_mem => output_ex(109),
														 NOP_wb => output_mem(90),
														 use_B => output_id(63));
	
	forward : forwardingUnit port map(exe_alu => input_ex(92  downto 77),
												 exe_pc1	=> input_ex(28  downto 13),
												 exe_se	=> input_ex(44  downto 29),
												  
												 mem_alu	=> input_mem(24 downto 9),
												 mem_pc1	=> input_mem(56 downto 41),
												 mem_se	=> input_mem(40 downto 25),
												 mem_mem	=> input_mem(72 downto 57),
												  
												 wb_data	=> DataIn_w,
												  
												 data_mux_ex => input_ex(9   downto 8),
												 data_mux_mem => input_mem(5  downto 4),
												  
												 reg_A_mux		=> regA_mux,
												 reg_B_mux		=> regB_mux,
												 
												 regA_actual	=> A,
												 regB_actual	=> B,
												 
												 dataHazardFlag => dataHazardFlag,
												 
												 clock		=> clock,
												 reset 		=> reset,
												 
												 regA			=> input_rr(54 downto 39),
												 regB			=> input_rr(38 downto 23),
												 bubble_en  => bubble);
	
	NOP_fetch <= (not r7_enable_out_w) or (not output_mem(90));
	
	pc_reg <= not_bubble and ((not (counter_en or counter_en2)) or counter_validity);
	
	IFetch : inst_fetch port map(clock => clock,
										  clock_mem => clock_c,
										  reset => reset,
										  pcIn => pcIn_w,
										  pc => input_if(48 downto 33),
										  pc_reg => pc_reg,
										  NOP_in => NOP_fetch,
										  if_id_reg => input_if(32 downto 0),
										  pcRegMux_crtl => pcRegMux_crtl_w);
										  
	NOP_decode <= ((not r7_enable_out_w) or (not output_mem(90))) and output_if(32) and (not pc_hazard);
	
	Decoded: decode port map(	clock	     		=> clock,
										reset				=> reset,
										pc_in				=> output_if(48 downto 33),
										instruction  	=> output_if(31 downto 16),
   									pcPlusOneIn  	=> output_if(15 downto 0),
										NOP_in			=> NOP_decode,
										pc_out			=> pc,
										counter_enable => counter_en,
										counter_en2		=> counter_en2,
										count_val		=> counter_value,
										use_B				=> input_id(63),
										NOP				=> input_id(62),
										conditional		=> input_id(61),
										signExt      	=> input_id(60 downto 45),
										pcPlusOneOut 	=> input_id(44 downto 29),
										A_sel		 		=> input_id(28 downto 26),
										B_sel		 		=> input_id(25 downto 23),
										rf_dataIn_sel	=> input_id(22 downto 20),
										alu_b_muxCrtl	=> input_id(19 downto 18),
										alu_crtl     	=> input_id(17 downto 16),
										pcMux_crtl	 	=> input_id(15),
										pcRegMux_crtl  => input_id(14),
										op2in 	     	=> input_id(13 downto 12),
										rf_dataIn_mux	=> input_id(11 downto 10),
										carryEnable  	=> input_id(9),
										zeroEnable   	=> input_id(8),
										r7_enable		=> input_id(7),
										rf_wren			=> input_id(6),
										beq_pc_crtl  	=> input_id(5),
										rf_wren_mux  	=> input_id(4),
										memWrite_en  	=> input_id(3),
										mem_mux			=> input_id(2),
										counter_mux  	=> input_id(1),
										alu_a_muxCrtl	=> input_id(0));
										
	input_id(79 downto 64) <= pc;
	NOP_rr <= output_id(62) and (not pc_hazard);
	input_id(80) <= lm1;
																	
	RR : registerRead port map(clock						=> clock,
										reset						=> reset,
										r7_enableTo_RF 		=> r7_enable_out_w,						-- From Write Back Stage
										pc1_in					=> pc,
										lm_in						=> output_id(80),
										pc_in						=> output_id(79 downto 64),
										regWrite					=> regWrite_w,							-- From WB
										dataIn					=> DataIn_w,							-- From WB
										dataIn_sel_actual  	=> rfDataInsel_out_w,					-- From WB
										NOP_in					=> NOP_rr,
										NOP_r7					=> input_id(62),
										conditional_in			=> output_id(61),
										signExtin      		=> output_id(60 downto 45),
										pcPlusOnein 			=> output_id(44 downto 29),
										A_selin					=> output_id(28 downto 26),
										B_selin					=> output_id(25 downto 23),
										rf_dataIn_selin		=> output_id(22 downto 20),
										alu_b_muxCrtlin		=> output_id(19 downto 18),
										alu_crtlin     		=> output_id(17 downto 16),
										pcMux_crtlin			=> output_id(15),
										pcRegMux_crtl_in 		=> output_id(14),
										op2inin			 		=> output_id(13 downto 12),
										rf_dataIn_muxin		=> output_id(11 downto 10),
										carryEnablein  		=> output_id(9),
										zeroEnablein   		=> output_id(8),
										r7_enablein	 			=> output_id(7),
										rf_wrenin		 		=> output_id(6),
										beq_pc_crtlin  		=> output_id(5),
										rf_wren_muxin  		=> output_id(4),
										memWrite_enin  		=> output_id(3),
										mem_muxin		 		=> output_id(2),
										counter_muxin  		=> output_id(1),
										alu_a_muxCrtlin		=> output_id(0),
										
										lm_out					=> lm,
										pc_out					=> input_rr(104 downto 89),
										NOP_out					=> input_rr(88),
										conditional_out		=> input_rr(87),
										pcPlusOneOut 			=> input_rr(86 downto 71),
										signExtout      		=> input_rr(70 downto 55),
										regA			 			=> A,
										regB			 			=> B,
										rf_dataIn_selout		=> input_rr(22 downto 20),
										alu_b_muxCrtlout		=> input_rr(19 downto 18),
										alu_crtlout     		=> input_rr(17 downto 16),
										op2inout			 		=> input_rr(15 downto 14),
										rf_dataIn_muxout		=> input_rr(13 downto 12),
										pcMux_crtlout	 		=> input_rr(11),
										pcRegMux_crtl  		=> input_rr(10),
										alu_a_muxCrtlout		=> input_rr(9),
										beq_pc_crtlout  		=> input_rr(8),
										counter_muxout  		=> input_rr(7),
										memWrite_enout  		=> input_rr(6),
										mem_muxout		 		=> input_rr(5),
										rf_wren_muxout  		=> input_rr(4),
										rf_wrenout		 		=> input_rr(3),
										r7_enableout	 		=> input_rr(2),
										zeroEnableout   		=> input_rr(1),
										carryEnableout  		=> input_rr(0));
	
	
	input_rr(105) <= lm;
	
	counter_reset <= (not (output_rr(22)) ) and (not (output_rr(21)) ) and (not (output_rr(20)));
	
	zero_en <= output_rr(1) and not_bubble;		-- So that the carry and zero flags are affected only once
	carry_en <= output_rr(0) and not_bubble;
	
	NOP_ex <= output_rr(88) and ((not r7_enable_out_w) or (not output_mem(90))) and (not pc_hazard);
	
	executed : execute port map ( clock => clock,
											reset => reset,
											counter_reset 		=> counter_reset,
											pc_in					=> output_rr(104 downto 89),
											NOP_in				=> NOP_ex,
											conditional			=> output_rr(87),
											pcPlusOneIn 		=> output_rr(86 downto 71),
											signExtend 			=> output_rr(70 downto 55),
											regA 					=> output_rr(54 downto 39),
											regB 					=> output_rr(38 downto 23),
											rf_dataIn_sel 		=> output_rr(22 downto 20),
											B_mux_sel 			=> output_rr(19 downto 18),
											alu_ctrl				=> output_rr(17 downto 16),
											op2in 				=> output_rr(15 downto 14),
											rf_dataIn_mux 		=> output_rr(13 downto 12),
											pc_mux_ctrl			=> output_rr(11),
											pcRegMux_crtl_in  => output_rr(10),
											A_mux_sel 			=> output_rr(9),
											beq_mux_ctrl 		=> output_rr(8),
											counter_ctrl 		=> output_rr(7),
											memWrite_en			=> output_rr(6),
											mem_mux 				=> output_rr(5),
											rf_wren_mux 		=> output_rr(4),
											rf_wren_out 		=> output_rr(3),
											r7_enable 			=> output_rr(2),
											zeroEnable			=> zero_en,
											carryEnable 		=> carry_en,
											lm_en					=> lm_en,
											lm						=> output_rr(105),
											
											NOP_out				=> input_ex(109),
											pcALUresult 		=> input_ex(108 downto 93),
											ALUresult_out 		=> input_ex(92  downto 77),
											regB_out 			=> input_ex(76  downto 61),
											regA_out 			=> input_ex(60  downto 45),
											signExtendOut 		=> input_ex(44  downto 29),
											pcPlusOneOut 		=> input_ex(28  downto 13),
											rf_dataIn_sel_out => input_ex(12  downto 10),
											rf_dataIn_mux_out => input_ex(9   downto 8),
											pc_mux_ctrl_out 	=> input_ex(7),
											pcRegMux_crtl  	=> input_ex(6),
											memWrite_en_out 	=> input_ex(5),
											mem_mux_out 		=> input_ex(4),
											rf_wren_mux_out 	=> input_ex(3),
											r7_enable_out 		=> input_ex(2),
											rf_wren_out_out 	=> input_ex(1),
											counter_mux_out 	=> input_ex(0)); 

	NOP_mem <= output_ex(109) and ((not r7_enable_out_w) or (not output_mem(90))) and (not pc_hazard);

	memory : mem_access port map (clock 						=> clock,
											clock_mem					=> clock_c,
											reset 						=> reset,
											NOP_in						=> NOP_mem,
											pcAlu_result				=> output_ex(108 downto 93),
											ALUresult 					=> output_ex(92  downto 77),
											regB 							=> output_ex(76  downto 61),
											regA 							=> output_ex(60  downto 45),
											signExtend 					=> output_ex(44  downto 29),
											pcPlusOne 					=> output_ex(28  downto 13),
											rfDataInSel 				=> output_ex(12  downto 10),
											rf_dataIn_mux_ctrl	 	=> output_ex(9   downto 8),
											pcMux_ctrl 					=> output_ex(7),
											pcRegMux_crtl_in 			=> output_ex(6),
											memWrite_en 				=> output_ex(5),
											mem_mux_ctrl	 			=> output_ex(4),
											rf_wren_mux_ctrl 			=> output_ex(3),
											r7_enable 					=> output_ex(2),
											rf_wren 						=> output_ex(1),
											counterMuxIn 				=> output_ex(0),
											
											NOP_out						=> input_mem(90),
											pcRegMux_crtl  			=> input_mem(89),
											pc_mux_out 					=> input_mem(88 downto 73),
											mem_data_out 				=> input_mem(72 downto 57),
											pcPlusOne_out 				=> input_mem(56 downto 41),
											signExtend_out 			=> input_mem(40 downto 25),
											ALUresult_out 				=> input_mem(24 downto 9),
											rfDataInSel_out 			=> input_mem(8  downto 6),
											rf_dataIn_mux_ctrl_out 	=> input_mem(5  downto 4),
											r7_enable_out 				=> input_mem(3),
											rf_wren_mux_ctrl_out 	=> input_mem(2),
											rf_wren_out 				=> input_mem(1),
											counterMuxOut	 			=> input_mem(0));

	writes : writeBack port map(NOP_in								=> output_mem(90),
										 pcRegMux_crtl_in					=> output_mem(89),
										 pc_mux_out 							=> output_mem(88 downto 73),
										 memData_Out 						=> output_mem(72 downto 57),
										 pcPlusOne 							=> output_mem(56 downto 41),
										 signExtender 						=> output_mem(40 downto 25),
										 alu_out 								=> output_mem(24 downto 9),
										 rfDataInSel 						=> output_mem(8 downto 6),
										 rf_dataIn_mux_crtl 				=> output_mem(5 downto 4),
										 r7_enable 							=> output_mem(3),
										 rf_wren_mux_crtl 					=> output_mem(2),
										 rf_wren 								=> output_mem(1),
										 counterMuxOut 						=> output_mem(0),
										
										 r7_enable_out => r7_enable_out_w,
										 regWrite => regWrite_w,
										 DataIn => DataIn_w,
										 pcIn => pcIn_w,
										 rfDataInsel_out => rfDataInsel_out_w,
										 pcRegMux_crtl  => pcRegMux_crtl_w);
										 
	pc_hazard <= pcRegMux_crtl_w and (not(rfDataInsel_out_w(0) and rfDataInsel_out_w(1) and rfDataInsel_out_w(2)));

end mic;
