;	DC7	Port map
;	===========

;			Port Read
;			Read results in  Yellow	<= '0';

;	Address		Byte Read			Word Read									DWord Read
;	===================================================================

;	Base+0		SSSSHCNR			DB7_Din								x86_Dlast(17  downto 0)			;	SSSS=StateOut, H=x86_Hold, C=STOP, N=DB7_NoResponse, R=DB7_Ready

;	Base+1		000CNRDV		xxxxxxDV UUUUUUUU		HostWriteCount HostReadCount	;	C=STOP, R=DB7_Ready, D=HostTxDone , V=HostRxValid, U=USB Data In[7..0]

;	Base+2

;	Base+3

;	Base+4		Last byte read			Last word read							Last dword read
							
;	Base+5


;	=======================================================================


;			Port Write
;			Write results in  Yellow	<= '1';


;	Address		Byte Write			Word Write				DWord Write
;	===================================================================

;	Base+0		FFFFAAAA			Data[15..0]			mmmmYyBB Data8	; FFFFAAAA is Function/Address of DB7 board to be accessed, mm is mode for 32bit write
																												; mmmm=0 : LED addressing.  Y=SetYellow y=value, BB=0,1 2,3 for byte index into LEDRegister, Data8 = LED Register[7..0]/[15..8]/[23..16]/[31..24]
																												; mmmm=1 : Diagnostic Probe Set. Data8 = xxxPPPPP = ProbeSelect	<= x86_Din( 4 downto 0 );
																												
;	Base+1		UUUUUUUU		USBControl											; U=USB Data Out[7..0]

;	Base+2		

;	Base+3

;	Base+4		
							
;	Base+5			-								-						; 



;	DB7 Function Map
;	===============

;	F			Function							Data In												Data Returned
;	======================================================================

;	0		Word0 Write					Apos Bpos mm								 1000 IDID LLLL PPPP				; IDID is just the 4-bit ID set on the board, LLLL is the SATA LS[3..0] input, PPPP = PIO[3..0] = same pins as DB6 LS[3..0].

;	1		Word1 Write			1000011 DDDD ooooo BB																		; DB7 imposes constant(Idle#=1, xx=00, SyncRect=00,  OscDiv=11), DDDD=TDecay(default="1000"), ooooo=TOff(default="10000"), BB=TBlank(default=00 )

;	2		SIO																																			; Selected when SSI_Address=x"2" and SSI_ADR='0' else '0';

;	3		ReadPorts																																; Selected when SSI_Address=x"3" and SSI_STB = '1' and SSI_ADR='0' else '0';

