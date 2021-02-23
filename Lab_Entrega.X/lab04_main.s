
;-----------Laboratorio 03 Micros------------ 

; Archivo: lab04_main.S
; Dispositivo: PIC16F887
; Autor: Brandon Garrido 
; Compilador: pic-as (v2.30), MPLABX v5.45
;
; Programa: Presionar RB0 o RB7 para inc o dec con interrupciones
; Hardware: LEDs en el puerto A - Display puerto C
;
; Creado: 21 de febrero, 2021

PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT   ; Oscillator Selection bits (RC oscillator: CLKOUT function on RA6/OSC2/CLKOUT pin, RC on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
    
  
UP EQU 0
DOWN EQU 7
 
 
;----------------macros----------------------
 
reiniciar_tmr0 macro ; macro para reutilizar reinicio de tmr0
    movlw 178 ; valor de n para (256-n)
    movwf TMR0 ; delay inicial TMR0
    bcf T0IF
 endm
  
;------------------variables-------------------
PSECT udata_bank0 ;common memory
    contador : DS 1 ;1 byte -> para bucle
    conteo : DS 1 ;1 byte -> para contador de display timer0
    
PSECT udata_shr ;common memory
    W_TEMP: DS 1 ;1 byte
    STATUS_TEMP: DS 1; 1 byte

PSECT resVect, class=CODE, abs, delta=2

;---------------- vector reset --------------------

ORG 00h	    ;posición 0000h para el reset 
resetVec:
    PAGESEL main
    goto main
    

PSECT code, delta=2, abs
ORG 100h    ;posicion para el código
 
 
tabla: ; tabla de valor de pines encendido para mostrar x valor en el display
    clrf PCLATH
    bsf PCLATH, 0 ; PCLATH = 01 PCL = 02
    andlw 0x0f ; para solo llegar hasta f
    addwf PCL ;PC = PCLATH + PCL + W
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;A
    retlw 01111100B ;B
    retlw 00111001B ;C
    retlw 01011110B ;D
    retlw 01111001B ;E
    retlw 01110001B ;F
 

    
PSECT intVect, class=CODE, abs, delta=2
;---------------- vector de interrupcion --------------------
ORG 04h ;posición 0x0004

push: ;Preservar los valores de W y las banderas
    movwf W_TEMP
    swapf STATUS, W
    movwf STATUS_TEMP 
    
isr: ; rutina de interrupción
    btfsc RBIF ;verificar si la bandera de interrupción PORTB esta levantada
    call int_iocb
    btfsc T0IF ; verifica si la bandera de interrupcion tmr0 esta levantada
    call int_tmr0

pop: ; para re-obtener los valores de W y de las banderas de status
    swapf STATUS_TEMP, W
    movwf STATUS
    swapf W_TEMP, F
    swapf W_TEMP, W
    retfie ; finalizar interrupción
    
;--- subrutina de interrupcion----
int_iocb:; 
    banksel PORTA
    btfss PORTB, UP ;verificar pin activado como pull-up
    incf PORTA
    btfss PORTB, DOWN ;verificar pin activado como pull-up
    decf PORTA
    
    bcf RBIF ; limpiar bandera
    
    return

;-----------subrutina de interrupción timer 0------------------
int_tmr0: 
    reiniciar_tmr0
    incf contador
    movf contador, W
    sublw 50  ; repetir 50 veces -> 50 * 20ms = 1000ms
    btfss ZERO ; STATUS 2 , cero
    goto return_tmr0 ; repite hasque que sea cero w
    clrf contador
    incf conteo
    movwf conteo, W
    call tabla
    movwf PORTD
    
    
return_tmr0:
    return
 
    
;----------- Configuración -----------------------

main:
    
    call config_io ; PORTA salida; RB7 y RB0 como input
    call config_reloj ;4MHz
    call config_tmr0 ; tmr0 a 20ms
    call config_iocrb ; configurar interrup on change en puerto b
    call config_int_enable ; configurar banderas de interrupción
    
     
    
;----------------loop principal--------------------
    
loop:
   
    movf PORTA, W ; valor del conteo a W
    call tabla ; obtener equivalente en display 
    movwf PORTC ; mostrar display
    
    
   goto loop	   ;loop forever

config_iocrb:
    banksel TRISA
    bsf IOCB, UP
    bsf IOCB, DOWN ; setear IOC en los pines 0 y 7 del puerto B
    
    banksel PORTA
    movf PORTB, W ; al leer termina condición del mismatch
    bcf RBIF
    
    return
  
config_int_enable:; INTCON
    bsf GIE ; banderas globales
    bsf RBIE ; habilitar banderas de interrupción puertos B
    bcf RBIF
    bsf T0IE ; habilitar banderas de interrupción tmr0
    bcf T0IF
    
    return
   
config_reloj:
    banksel OSCCON
    bsf IRCF2 ; IRCF = 110 (4MHz) 
    bsf IRCF1
    bcf IRCF0
    bsf SCS ; reloj interno
    
    return
    
config_io:
    banksel ANSEL ;banco 11
    clrf ANSEL
    clrf ANSELH ; habilitar puertos digitales A y B
    
    banksel TRISA ;banco 01
    clrf TRISA
    clrf TRISC
    clrf TRISD ; setear puertos A,C,D como salidas
    bsf TRISB, UP ;up y down como entradas
    bsf TRISB, DOWN
    
    bcf OPTION_REG, 7 ;habilitar pull-ups
    bsf WPUB, UP
    bsf WPUB, DOWN
    
    banksel PORTA ; banco 00
    clrf PORTA
    clrf PORTC
    clrf PORTD ; limpiar salidas
    
    return

    
    ;t=4 * (T_osc) * (256-n) (Preescaler) = 20ms
config_tmr0:
    banksel TRISA
    bcf T0CS ; reloj interno
    bcf PSA ; prescaler
    bsf PS2 
    bsf PS1 
    bsf PS0 ; PS = 111 (1:256)
    banksel PORTA
    
    reiniciar_tmr0
      
    return
    
   
    
end