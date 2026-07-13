init:
;----USER SETTINGS----

; Turn on and turn off values for temperature and humidity as 16 bit numbers
; The sensor counts in decimal 
	SYMBOL TempH = 6852 ; 29 degrees (C)
	SYMBOL TempL = 6703 ; 27.5 degrees (C)
	SYMBOL HumH = 13443 ; 82% Humidity
	SYMBOL HumL = 12131 ; 74% Humidity
	SYMBOL mRPM = 100 ; 151 = 900 RPM 
	SYMBOL Mode = 3 ; 1 = tempature only, 2 = humidty only, 3 = both
	
	
;----PROGRAM VARIABLE USE----
	SYMBOL HUM = W0 ; 16 bit humidity
	SYMBOL TEMP = W1 ; 16 bit temperature
	SYMBOL status = B4 ; HIH satus (must be 0)
	SYMBOL Fstatus = B5 ; fan bit status (0 = off, 1 = on)
	SYMBOL MODE = B6 ; fan mode
	SYMBOL FMODE = B7 ; to track which input turned the fan on (Temperature, Humidity, or both)
; FMODE bit 0 = Temperature and 1 = Humidity 
	SYMBOL RPM = W4	; to measure Fan RPM	
; Note: Fan = 4 = MOSFET G on C.4
	SYMBOL Fan = 4;
; Note: Buzzer = 0 = piezo on C.0
	SYMBOL Buzzer = 0;
; Note: RPMin = 3 = Fan tach on C.3
	SYMBOL RPMin = 3

	let MODE = UMode ; get fan bit status, Fstatus = 1 if fan GPIO is on
	Fstatus = pinc.4
	gosub FanOff  	; should boot up off but switch it to be sure
	let Fstatus = 0
; I2C address is $27 shifted=$4e
	hi2csetup I2CMASTER, $4E, i2cslow, i2cbyte
	let B5 = $ff		; dummy arg
	pause 30		; wait past command window
	gosub PU_tone

; ----MAIN LOOP----
main:	
;get temperature and humidity
	hi2cout (B5)	; wake up kick to start measurement cycle
	pause 60		; wait for measurement cycle (nominally 36.65 ms)
	hi2cin (B1)		; Hum hi
	hi2cin (B0)		; Hum low
	hi2cin (B3)		; Tem hi
	hi2cin (B2)		; Tem lo
	let status = B1 & %11000000	; get status bits
	let B1 = B1 & %00111111		; mask status
	let W1 = W1/4				; shift temperature	
; if status is not 0, we have a read error indicating either a
; transmission error or a sensor error. 
; ** This results in an error trap. **
	if status<>0 then
		goto TerrorS
	endif	
; handle fan on/off depending on the operating mode
MODE1:
; mode 1 is temperature only
	if MODE = 1 then
		if TEMP >= TempH then
			gosub FanOn
	      endif
		if TEMP <= TempL then
			gosub FanOff
		endif  
	endif
MODE2:
; mode 2 is humidity only
	if MODE = 2 then
		if HUM >= HumH then 
              gosub FanOn
		endif
		if HUM <= HumL then
		  gosub FanOff
		endif
	endif
MODE3:
; mode 3 is both humidity and temperature
	if MODE = 3 then
		; If fan is off, should we turn it on?
		if Fstatus = 0 then
			if TEMP >= TempH then
				FMODE= FMODE|1	;set b0
				gosub FanON
			endif
			if HUM >= Humh then
				FMODE= FMODE|2	;set b1
				gosub FanOn
			endif
		elseif Fstatus = 1 then
		;else
		; if fan is on should we turn it off?
			if TEMP <= TempL then
				FMODE= FMODE&2	;reset b0
			endif
			if HUM <= HumL then
				FMODE= FMODE&1	;reset b1
			endif
			if FMODE = 0 then
				gosub FanOff
			endif
		endif
	endif

next1:
; get fan bit status, Fstatus = 1 if fan GPIO is on
	Fstatus = pinc.4
; delay for 10 seconds before looping
	pause 5000;
; check fan RPM as part of the 10 sec delay	
	count RPMin,5000,RPM			
	if Fstatus=1 then
		if RPM < mRPM then			
			goto TerrorF ; fan error - RPM too low!
		endif
	elseif Fstatus = 0 then
	;else
		if RPM >= mRPM then
			goto TerrorF  ; fan error - RPM too high!
		endif
	endif 
	goto main
;--------------------------------
; Error Traps (infinite loops)
; sensor or transmission error - give continuous fast beeps 
TerrorS:	
	switchon Buzzer
	pause 35
	switchoff Buzzer
	pause 100    
	goto TerrorS
; Fan RPM eror - give continuous slow beeps 
TerrorF:
	switchon Buzzer
	pause 75
	switchoff Buzzer
	pause 300    
	goto TerrorF
;--------------------------------
; subroutines
FanOn:
	if pinc.4 = 0 then switchon Fan endif
	return
FanOff:
	if pinc.4 = 1 then switchoff Fan endif
	return
PU_tone:
; power up - three beeps
	switchon Buzzer
	pause 100
	switchoff Buzzer
	pause 100
	switchon Buzzer
	pause 100
	switchoff Buzzer
	pause 100
	switchon Buzzer
	pause 100
	switchoff Buzzer
	return