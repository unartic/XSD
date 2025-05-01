

; Convert 16 bbit value to ascii
bin_to_ascii:
    phy
    phx
    LDY #4              ; we gaan van minst naar meest significant digit (index 4..0)

bin_to_ascii_convert_loop:
    ; 16-bit deling door 10 (resultaat in BIN, rest in A)
    JSR divide_by_10      ; => A = rest (digit), BIN = quotient
    CLC
    ADC #$30            ; converteer naar PETSCII
    STA (ptr_bin_to_ascii),Y
    DEY
    BPL bin_to_ascii_convert_loop
    
    ldy #0
    :
        lda (ptr_bin_to_ascii),y
        cmp #$30
        bne no_more_zero
        lda #' '
        sta (ptr_bin_to_ascii),y
        iny
        cpy #4
        bne :-
        
    no_more_zero:
    plx
    ply
    RTS

divide_by_10:
    stz bin_to_ascii_remainder ; clear remainder
    LDX #16             ; 16 bits

divide_loop:
    ASL bin_to_ascii_value             ; shift left low byte
    ROL bin_to_ascii_value+1           ; shift into high byte
    ROL bin_to_ascii_remainder             ; rotate into remainder

    LDA bin_to_ascii_remainder
    CMP #10
    BCC skip_sub
    SBC #10
    STA bin_to_ascii_remainder
    INC bin_to_ascii_value             ; this is our new quotient bit
skip_sub:
    DEX
    BNE divide_loop

    LDA bin_to_ascii_remainder             ; remainder = digit
    RTS
    

;switch to rambank data for active panel
switch_bank_data:
    pha
    lda view_mode
    beq view_files_list_data
    lda #RAMBANK_PARTITIONS_DATA
    sta $00
    pla
    rts
    
    view_files_list_data:
    
    lda #RAMBANK_DATA_LEFT
    jsr add_active_tab
  

    lda view_mode
    beq continue_switch    
    lda #RAMBANK_PARTITIONS_DATA
    sta $00    
    continue_switch:
    pla
    rts
    
switch_bank_files:
    lda view_mode
    beq view_files_list
    lda #RAMBANK_PARTITIONS
    sta $00
    rts
    view_files_list:
    lda #RAMBANK_FILES_LEFT
    jmp add_active_tab
;    clc
;    adc tab_active
;    sta $00
;    rts

switch_bank_lfn:
    lda #RAMBANK_LFN_LEFT
add_active_tab:
    clc
    adc tab_active
    sta $00
    rts

switch_bank_partitions:
    lda #RAMBANK_PARTITIONS
    sta $00
    rts

plot_vera:
    ;x=line
    ;y=col
    
    ;always less then 255
    tya     ;we could pass the col in A directly.... minor improvement
    asl
    sta VERA_addr_low
    
    txa
    clc
    adc #$B0
    sta VERA_addr_low+1

    lda #$21
    sta VERA_addr_low+2
    rts

set_ptr_to_rambank:
    stz ptr
    lda #$A0
    sta ptr+1
    rts

set_ptr_files_list_to_rambank:
    stz ptr_files_list
    lda #$A0
    sta ptr_files_list+1
    rts

;we can remove this subroutine if we calc both offsets once
;and change a general one on tabswitch....
calc_col_offset:
    lda tab_active
    beq not_at_right_tab
        clc
        adc tab_cols
    not_at_right_tab:
    tay
    iny
    rts
    
dec_ptr:
    lda ptr
    bne :+
        dec ptr+1
    :
    dec ptr
    rts

inc_ptr:
    inc ptr
    bne :+
        inc ptr+1
    :
    rts
    
inc_ptr_lfn:
    inc ptr_lfn
    bne :+
        inc ptr_lfn+1
    :
    rts    
    
;set ptr to start of the file record in highram
set_ptr_to_file:
    jsr switch_bank_data
    jsr set_ptr_to_rambank
   
    lda page_offset
    clc
    adc page_line
    tax
    jsr switch_bank_files
    cpx #0
    beq skip_advance_pointer
    ;Multiplication takes about 20cycles per row. Using VERAFX multiplication is about
    ;100cycles. So from 5 rows multiplication is faster, though code will be
    ;larger. For now no optimization. Maybe in the future
    :
        lda ptr
        clc
        adc #FILES_RECORD_LEN
        sta ptr
        bcc :+
            inc ptr+1 
        :
        dex
        bne :--
        
    skip_advance_pointer:
    rts
    
advance_ptr_files_list_one_record:
    lda ptr_files_list
    clc
    adc #FILES_RECORD_LEN
    sta ptr_files_list
    bcc :+
        inc ptr_files_list+1
    :
    rts

set_vera_to_incr_one:
    lda VERA_addr_low+2
    AND #$01
    ORA #$10
    sta VERA_addr_low+2
    rts
    
    
.macro SET_SYMBOL_TO_PTR msymbol,mptr
    lda #<msymbol
    sta mptr
    lda #>msymbol
    sta mptr+1
.endmacro

.macro COPY_ZP src,dest
    lda src
    sta dest
    lda src+1
    sta dest+1
.endmacro

