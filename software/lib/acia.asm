; -----------------------------------------------------------------
;   Register addresses
; -----------------------------------------------------------------

!address IO_1_ACIA_DATA_REGISTER    = IO_1 + $0
!address IO_1_ACIA_STATUS_REGISTER  = IO_1 + $1
!address IO_1_ACIA_COMMAND_REGISTER = IO_1 + $2
!address IO_1_ACIA_CONTROL_REGISTER = IO_1 + $3

; -----------------------------------------------------------------
;   Status bits
; -----------------------------------------------------------------

ACIA_STATUS_PARITY_ERROR_DETECTED           = 1 << 0
ACIA_STATUS_FRAMING_ERROR_DETECTED          = 1 << 1
ACIA_STATUS_OVERRUN_HAS_OCCURRED            = 1 << 2
ACIA_STATUS_RECEIVER_DATA_REGISTER_FULL     = 1 << 3
ACIA_STATUS_TRANSMITTER_DATA_REGISTER_EMPTY = 1 << 4
ACIA_STATUS_DATA_CARRIER_DETECT_HIGH        = 1 << 5
ACIA_STATUS_DATA_SET_READY_HIGH             = 1 << 6
ACIA_STATUS_INTERRUPT_OCCURRED              = 1 << 7

; -----------------------------------------------------------------
;   Control bits
; -----------------------------------------------------------------

ACIA_CONTROL_BAUD_RATE_115200 = 0  << 0
ACIA_CONTROL_BAUD_RATE_50     = 1  << 0
ACIA_CONTROL_BAUD_RATE_75     = 2  << 0
ACIA_CONTROL_BAUD_RATE_109_92 = 3  << 0
ACIA_CONTROL_BAUD_RATE_134_58 = 4  << 0
ACIA_CONTROL_BAUD_RATE_150    = 5  << 0
ACIA_CONTROL_BAUD_RATE_300    = 6  << 0
ACIA_CONTROL_BAUD_RATE_600    = 7  << 0
ACIA_CONTROL_BAUD_RATE_1200   = 8  << 0
ACIA_CONTROL_BAUD_RATE_1800   = 9  << 0
ACIA_CONTROL_BAUD_RATE_2400   = 10 << 0
ACIA_CONTROL_BAUD_RATE_3600   = 11 << 0
ACIA_CONTROL_BAUD_RATE_4800   = 12 << 0
ACIA_CONTROL_BAUD_RATE_7200   = 13 << 0
ACIA_CONTROL_BAUD_RATE_9600   = 14 << 0
ACIA_CONTROL_BAUD_RATE_19200  = 15 << 0
ACIA_CONTROL_RECEIVER_CLOCK_EXTERNAL  = 0 << 4
ACIA_CONTROL_RECEIVER_CLOCK_BAUD_RATE = 1 << 4
ACIA_CONTROL_WORD_LENGTH_8 = 0 << 5
ACIA_CONTROL_WORD_LENGTH_7 = 1 << 5
ACIA_CONTROL_WORD_LENGTH_6 = 2 << 5
ACIA_CONTROL_WORD_LENGTH_5 = 3 << 5
ACIA_CONTROL_STOPBIT_1 = 0 << 7
ACIA_CONTROL_STOPBIT_2 = 1 << 7 ; 1.5 when word length is 5

; -----------------------------------------------------------------
;   Command bits
; -----------------------------------------------------------------

ACIA_COMMAND_DATA_TERMINAL_READY_DEASSERT = 0 << 0
ACIA_COMMAND_DATA_TERMINAL_READY_ASSERT   = 1 << 0
ACIA_COMMAND_RECEIVER_IRQ_ENABLED  = 0 << 1
ACIA_COMMAND_RECEIVER_IRQ_DISABLED = 1 << 1
ACIA_COMMAND_TRANSMITTER_CONTROL_REQUEST_TO_SEND_DEASSERT_TRANSMITTER_DISABLED            = 0 << 2
ACIA_COMMAND_TRANSMITTER_CONTROL_REQUEST_TO_SEND_ASSERT_INTERRUPT_ENABLED                 = 1 << 2 ; Do not use
ACIA_COMMAND_TRANSMITTER_CONTROL_REQUEST_TO_SEND_ASSERT_INTERRUPT_DISABLED                = 2 << 2
ACIA_COMMAND_TRANSMITTER_CONTROL_REQUEST_TO_SEND_ASSERT_INTERRUPT_DISABLED_TRANSMIT_BREAK = 3 << 2
ACIA_COMMAND_RECEIVER_ECHO_DISABLED = 0 << 4
ACIA_COMMAND_RECEIVER_ECHO_ENABLED  = 1 << 4 ; Bit 2 and 3 must be zero.
ACIA_COMMAND_RECEIVER_PARITY_DISABLED = 0 << 5
ACIA_COMMAND_RECEIVER_PARITY_ENABLED  = 1 << 5 ; Parity should never be enabled
ACIA_CONTROL_PARITY_ODD                  = 0 << 6 ; Parity should never be enabled
ACIA_CONTROL_PARITY_EVEN                 = 1 << 6 ; Parity should never be enabled
ACIA_CONTROL_PARITY_MARK_CHECK_DISABLED  = 2 << 6 ; Parity should never be enabled
ACIA_CONTROL_PARITY_SPACE_CHECK_DISABLED = 3 << 6 ; Parity should never be enabled

!ifdef FLAG_ACIA_IRQ {
  !set .command_irq_bits = ACIA_COMMAND_RECEIVER_IRQ_ENABLED
} else {
  !set .command_irq_bits = ACIA_COMMAND_RECEIVER_IRQ_DISABLED
}

; -----------------------------------------------------------------
;   Workspace
; -----------------------------------------------------------------

!address rx_buffer_rptr = $0200 ; 1 byte
!address rx_buffer_wptr = $0201 ; 1 byte
!address rx_buffer      = $0202 ; 16 bytes
rx_buffer_size = 16

; -----------------------------------------------------------------
;   acia_init(): Programatically resets and initializes the ACIA as well as the internal workspace.
; -----------------------------------------------------------------

acia_init         stz IO_1_ACIA_STATUS_REGISTER   ; programmatically reset the chip by writing the status register
                                                  ; weirdly enough, that does not reset ALL the internal registers,
                                                  ; see the datasheet.

                  stz rx_buffer_rptr              ; reset internal state
                  stz rx_buffer_wptr

                  ldx # rx_buffer_size - 1        ; zero out the internal buffer
-                 stz rx_buffer,X
                  dex
                  bpl -

                  ; set up the ACIA with
                  ; - baud rate 300 (smallest supported by MCP2221A)
                  ; - no external receiver clock, RxC pin outputs the baud rate
                  ; - 8 bit word length
                  ; - 1 stop bit
                  lda # ACIA_CONTROL_BAUD_RATE_115200 | ACIA_CONTROL_RECEIVER_CLOCK_BAUD_RATE | ACIA_CONTROL_WORD_LENGTH_8 | ACIA_CONTROL_STOPBIT_1
                  sta IO_1_ACIA_CONTROL_REGISTER

                  ; further set up the ACIA with
                  ; - /DTR = Low
                  ; - IRQ bits from FLAG_ACIA_IRQ
                  ; - /RTS = Low, Transmitter enabled, transmitter IRQ off
                  ; - Echo mode disabled
                  ; - Parity disabled
                  lda # ACIA_COMMAND_DATA_TERMINAL_READY_ASSERT | .command_irq_bits | ACIA_COMMAND_TRANSMITTER_CONTROL_REQUEST_TO_SEND_ASSERT_INTERRUPT_DISABLED | ACIA_COMMAND_RECEIVER_ECHO_DISABLED | ACIA_COMMAND_RECEIVER_PARITY_DISABLED
                  sta IO_1_ACIA_COMMAND_REGISTER

                  rts

; -----------------------------------------------------------------
;   acia_sync_putc(): Sends a byte over serial. Blocking loop until transmit is available.
;
;   Parameters:
;       A = byte to send
; -----------------------------------------------------------------

acia_sync_putc    tax                             ; move byte to X register

                  !ifndef FLAG_ACIA_XMIT_BUG {    ; if we're using an ACIA without the Xmit bug (eg. R6551)
                    lda # ACIA_STATUS_TRANSMITTER_DATA_REGISTER_EMPTY
-                   bit IO_1_ACIA_STATUS_REGISTER ; wait until we can transmit
                    beq -
                  }

                  stx IO_1_ACIA_DATA_REGISTER     ; transmit byte

                  !ifdef FLAG_ACIA_XMIT_BUG {     ; if we're using an ACIA with the Xmit bug (eg. W65C51N)
                    +delay_medium_ms 1000.0/30    ; wait for the byte to be transmitted
                                                  ; With a 8N1 configuration, 10 bits need to go out per byte
                                                  ; At 300 baud, that's 1/30s per byte
                  }

                  rts

; -----------------------------------------------------------------
;   acia_sync_getc(): Receives a byte over serial. Blocking loop until something is received.
;
;   Returns:
;       A: byte received
;       P: n,z set from A
; -----------------------------------------------------------------
; TODO: Check for error conditions (parity, overrun, framing)
acia_sync_getc    lda # ACIA_STATUS_RECEIVER_DATA_REGISTER_FULL
-                 bit IO_1_ACIA_STATUS_REGISTER   ; wait until a byte is available
                  beq -

                  lda IO_1_ACIA_DATA_REGISTER     ; get received byte

                  rts

; -----------------------------------------------------------------
;   acia_async_getc(): If a byte has been received over serial, return it in the A register and set the carry.
;                      If not, clear the carry.
;
;   Returns:
;       A: byte received
;       P: n,z set from A
;          c=1 if byte received, c=0 if no byte received
; -----------------------------------------------------------------

acia_async_getc   ldx rx_buffer_rptr              ; compare r/w pointers
                  cpx rx_buffer_wptr
                  bne +                           ; if the two pointers are equal, no byte has been received
                  clc                             ; clear carry and return
                  rts

+                 lda rx_buffer,X                 ; else, load the received byte

                  cpx # rx_buffer_size - 1        ; check if read pointer = rx_buffer_size - 1 and reset if yes, if not increment
                  bne +                           ; if not, just increment
                  ldx # $ff                       ; if yes, reset it to $ff and increment (effectively set it to 0)
+                 inx

                  stx rx_buffer_rptr              ; save new pointer

                  and # $ff                       ; ensure flags are set by the value of A
                  sec                             ; set carry to signify a byte is present
                  rts

; -----------------------------------------------------------------
;   acia_int_handler(): Check if the ACIA has raised an interrupt, and if yes process it using the procedure
;                            outline in Rockwell's R6551 datasheet "Status Register Operation"
; -----------------------------------------------------------------

acia_int_handler  lda IO_1_ACIA_STATUS_REGISTER
                  bmi +                           ; n flag is set to ACIA_STATUS_INTERRUPT_OCCURRED by lda.
                  rts                             ; If it is 1, an ACIA interrupt occurred, else we return
+
                  bit # ACIA_STATUS_RECEIVER_DATA_REGISTER_FULL
                  beq +
                  jsr .acia_int_rx
+
                  rts

; -----------------------------------------------------------------
;   .acia_int_rx(): Handle a receiver interrupt.
;
;   Parameters:
;       A = ACIA status register at time of interrupt
; -----------------------------------------------------------------

.acia_int_rx      ldx IO_1_ACIA_DATA_REGISTER     ; load data register, this will clear the interrupt
                                                  ; as well as the status register bits

                  bit # ACIA_STATUS_OVERRUN_HAS_OCCURRED
                  bne .acia_handle_overrun

                  bit # ACIA_STATUS_FRAMING_ERROR_DETECTED
                  bne .acia_handle_framing_error

                  bit # ACIA_STATUS_PARITY_ERROR_DETECTED
                  bne .acia_handle_parity_error

                  txa                             ; add data byte to rx buffer
                  ldx rx_buffer_wptr
                  sta rx_buffer,X

                  cpx # rx_buffer_size - 1        ; check if write pointer = rx_buffer_size - 1
                  bne +                           ; if yes, set it to FF so it wraps to 0 with the increment
                  ldx # $ff
+
                  inx                             ; increment and save new pointer
                  stx rx_buffer_wptr

                  rts

.acia_handle_overrun
.acia_handle_framing_error
.acia_handle_parity_error
                  rts                             ; don't handle these errors for now
