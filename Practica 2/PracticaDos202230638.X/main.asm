;===================================================================
; PRACTICA DOS
; Arquitectura de Computadoras y Ensambladores 1
; Centro Universitario de Occidente - USAC - Segundo semestre 2026
;
;   Javier Alejandro Merida Gomez - 202230638
;   
; Descripcion general:
; Se implementa un sistema de control para una alarma contra
; incendios, el cual monitorea cuatro entradas digitales (activacion
; manual, sensor de humo, sensor de temperatura y boton de silencio)
; y controla tres salidas digitales (led verde, led rojo y buzzer)
; de acuerdo con la logica de funcionamiento descrita en el
; enunciado de la practica.
;===================================================================

    LIST P=16F628A

;-------------------------------------------------------------------
; Definicion de registros utilizados, con su direccion de memoria
; (direcciones estandar de la familia de gama media PIC16)
;-------------------------------------------------------------------
STATUS  EQU 0x03      ; Registro de estado del microcontrolador
PORTB   EQU 0x06      ; Registro de datos del puerto B (banco 0)
TRISB   EQU 0x86      ; Registro de direccion de PORTB (banco 1)
RP0     EQU 5          ; Bit selector de banco de memoria, ubicado en STATUS

;-------------------------------------------------------------------
; Palabra de configuracion (Configuration Word, direccion 2007h)
;
; A continuacion se detalla el valor asignado a cada bit, conforme
; a la hoja de datos del PIC16F627A/628A/648A (DS41196G):
;
;   Bit 13 (CP)     = 1  Se desactiva la proteccion del codigo de
;                        programa.
;   Bits 12-9       = 1  Bits no implementados; se leen siempre
;                        como 1.
;   Bit 8  (CPD)    = 1  Se desactiva la proteccion de la memoria
;                        EEPROM de datos.
;   Bit 7  (LVP)    = 0  Se desactiva la programacion en bajo
;                        voltaje.
;   Bit 6  (BOREN)  = 1  Se activa el Brown-out Reset.
;   Bit 5  (MCLRE)  = 1  Se configura el pin RA5 con funcion de
;                        reset externo (MCLR).
;   Bits 4,1,0 (FOSC2:FOSC1:FOSC0) = 1,0,1
;                        Se selecciona el oscilador interno (INTOSC)
;                        sin salida de reloj, de manera que los
;                        pines RA6 y RA7 quedan disponibles como
;                        entradas o salidas de proposito general.
;   Bit 3  (PWRTE)  = 0  Se activa el Power-up Timer (en este bit,
;                        el valor 0 corresponde a la condicion
;                        habilitada).
;   Bit 2  (WDTE)   = 0  Se desactiva el Watchdog Timer.
;
; La combinacion de los bits anteriores produce el valor 0x3F71.
; La direccion 0x2007 no se indica de forma explicita, ya que
; MPASM la determina automaticamente a partir del microcontrolador
; seleccionado mediante la directiva LIST P=16F628A.
;-------------------------------------------------------------------
    __CONFIG 0x3F71

;-------------------------------------------------------------------
; Asignacion de pines de entrada y salida (ver tabla de
; identificacion de entradas y salidas en el informe)
;-------------------------------------------------------------------
#DEFINE MANUAL      PORTB,0     ; Entrada: activacion manual
#DEFINE HUMO         PORTB,1     ; Entrada: sensor de humo
#DEFINE TEMPERATURA  PORTB,2     ; Entrada: sensor de temperatura
#DEFINE SILENCIO     PORTB,3     ; Entrada: boton de silencio/reconocimiento
#DEFINE LED_VERDE    PORTB,4     ; Salida: indicador de estado normal
#DEFINE LED_ROJO     PORTB,5     ; Salida: indicador de condicion de alarma
#DEFINE BUZZER       PORTB,6     ; Salida: senal audible de alarma

;===================================================================
; VECTOR DE RESET
; Se establece la direccion de inicio del programa en la posicion
; 0x00, correspondiente al vector de reset del dispositivo.
;===================================================================
    ORG     0x00
    GOTO    INICIO

    ORG     0x05

;===================================================================
; INICIO
; Se realiza la configuracion inicial del microcontrolador antes de
; ingresar al ciclo principal del programa.
;===================================================================
INICIO:

    BSF     STATUS,RP0      ; Se selecciona el banco 1 de memoria,
                             ; requerido para modificar TRISB

    MOVLW   0x0F            ; Se define 00001111: los pines RB0-RB3
                             ; se configuran como entradas y los
                             ; pines RB4-RB6 como salidas
    MOVWF   TRISB

    BCF     STATUS,RP0      ; Se retorna al banco 0 de memoria

    CLRF    PORTB            ; Se inicializan todas las salidas en
                             ; estado bajo (apagado)

;===================================================================
; MAIN_LOOP
; Ciclo principal del programa. Se realiza la lectura continua de
; las entradas y, en funcion de su estado, se determina la
; condicion del sistema.
;===================================================================
MAIN_LOOP:

    ; Se verifica el estado de la activacion manual. La instruccion
    ; BTFSC omite la siguiente linea unicamente si el bit se
    ; encuentra en 0; por lo tanto, si MANUAL = 1 se ejecuta el
    ; salto a la rutina de alarma manual.
    BTFSC   MANUAL
    GOTO    ALARMA_MANUAL

    ; Se evalua la condicion conjunta de humo y temperatura. Si el
    ; sensor de humo se encuentra en 0, no es necesario continuar
    ; la verificacion y el sistema retorna al estado normal.
    BTFSS   HUMO
    GOTO    NORMAL

    ; Se verifica el sensor de temperatura. Si su valor es 0, el
    ; sistema tambien retorna al estado normal.
    BTFSS   TEMPERATURA
    GOTO    NORMAL

    ; En caso de que ambos sensores indiquen una condicion de
    ; riesgo, se ejecuta la rutina correspondiente a la alarma
    ; activada por sensores.
    GOTO    ALARMA_SENSOR

;-------------------------------------------------------------------
; NORMAL
; Se establece el estado normal del sistema, sin condiciones de
; riesgo presentes.
;-------------------------------------------------------------------
NORMAL:
    BSF     LED_VERDE        ; Se enciende el led verde
    BCF     LED_ROJO         ; Se apaga el led rojo
    BCF     BUZZER           ; Se desactiva el buzzer
    GOTO    MAIN_LOOP

;-------------------------------------------------------------------
; ALARMA_MANUAL
; Se atiende la condicion de activacion manual, la cual tiene
; prioridad sobre las demas entradas del sistema. En este estado,
; el buzzer permanece activo de forma permanente, sin posibilidad
; de ser silenciado.
;-------------------------------------------------------------------
ALARMA_MANUAL:
    BCF     LED_VERDE
    BSF     LED_ROJO
    BSF     BUZZER
    GOTO    MAIN_LOOP

;-------------------------------------------------------------------
; ALARMA_SENSOR
; Se atiende la condicion de riesgo detectada por los sensores de
; humo y temperatura. El led rojo permanece encendido mientras la
; condicion de riesgo se mantenga presente, independientemente del
; estado del boton de silencio.
;-------------------------------------------------------------------
ALARMA_SENSOR:
    BCF     LED_VERDE
    BSF     LED_ROJO

    ; Se verifica el estado del boton de silencio. Si SILENCIO = 1,
    ; se desactiva el buzzer sin modificar el estado del led rojo.
    BTFSC   SILENCIO
    GOTO    SIL_ON

    BSF     BUZZER
    GOTO    MAIN_LOOP

SIL_ON:
    BCF     BUZZER            ; Se silencia el buzzer por
                              ; solicitud del usuario
    GOTO    MAIN_LOOP

    END