
.macro read_lfn_entry start,end
.scope
    ldy #start 
    :
        lda (r0),y
        beq skip_char
        cmp #$FF
        beq skip_char
        sta sd_lfn_buffer,x
        inx
        skip_char:
        iny
        iny
        cpy #end
        bne :-

.endscope
.endmacro

.macro prnt caption,value,nrofbytes
.scope
    ldx #0
    :
        lda caption,x
        beq :+
        jsr dbg_char
        inx
        bra :-  
    :
    lda #':'
    jsr dbg_char
    lda #' '
    jsr dbg_char
    ldx #nrofbytes
    dex
    :
        lda value,x
        jsr dbg
        dex
        cpx #$FF
        bne :-
    jsr dbg_lf
.endscope
.endmacro

.macro prntDebug caption,value,nrofbytes
.scope
    lda #SHOW_DEBUG
    beq skip_debug
    prnt caption,value,nrofbytes
    
    skip_debug:
.endscope
.endmacro

.macro adc32bit v1,v2
    clc
    lda v1
    adc v2
    sta v1
    
    lda v1+1
    adc v2+1
    sta v1+1
    
    lda v1+2
    adc v2+2
    sta v1+2
    
    lda v1+3
    adc v2+3
    sta v1+3
    

.endmacro

.macro stz32Bit vl
    stz vl
    stz vl+1
    stz vl+2
    stz vl+3

.endmacro 