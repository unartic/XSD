
print_hex:
   pha
      pha	   ; push original A to stack
         lsr
         lsr
         lsr
         lsr      ; A = A >> 4
         jsr print_hex_digit
      pla      ; pull original A back from stack
      and #$0F ; A = A & 0b00001111
      jsr print_hex_digit
   pla
rts

print_hex_digit:
   cmp #$0A
   bpl @letter
   ora #$30    ; PETSCII numbers: 1=$31, 2=$32, etc.
   bra @print
@letter:
   clc
   adc #$37		; PETSCII letters: A=$41, B=$42, etc.
@print:
   sta DEBUG
   ;jsr CHROUT
   rts
   

dbg:
   pha
      pha	   ; push original A to stack
         lsr
         lsr
         lsr
         lsr      ; A = A >> 4
         jsr print_hex_digit_debug
      pla      ; pull original A back from stack
      and #$0F ; A = A & 0b00001111
      jsr print_hex_digit_debug
   pla
rts

dbg_chrout:
   phx
   phy
   pha
      pha	   ; push original A to stack
         lsr
         lsr
         lsr
         lsr      ; A = A >> 4
         jsr print_hex_digit_debug_chrout
      pla      ; pull original A back from stack
      and #$0F ; A = A & 0b00001111
      jsr print_hex_digit_debug_chrout
   
   pla
   ply
   plx
rts

dbg_char:
    sta DEBUG
rts

dbg_lf:
   lda #13
   sta DEBUG
   lda #10
   sta DEBUG
rts

dbglf:
    lda #13
    sta DEBUG

rts

print_hex_digit_debug:
   cmp #$0A
   bpl @letter
   ora #$30    ; PETSCII numbers: 1=$31, 2=$32, etc.
   bra @print
@letter:
   clc
   adc #$37		; PETSCII letters: A=$41, B=$42, etc.
@print:
   ;jsr CHROUT
   sta DEBUG
rts
   
print_hex_digit_debug_chrout:
   cmp #$0A
   bpl @letter
   ora #$30    ; PETSCII numbers: 1=$31, 2=$32, etc.
   bra @print
@letter:
   clc
   adc #$37		; PETSCII letters: A=$41, B=$42, etc.
@print:
   jsr CHROUT_
   ;sta DEBUG
rts   


;debug function
WaitKey:
    pha
    phx
    phy
        :
          
            jsr GETIN
            cmp #0
            beq :-

    
        lda #$07    ;beep
        jsr CHROUT
        :
          
            jsr GETIN
            cmp #0
            beq :-
    ply
    plx
    pla
rts

   
   waitkey:
            
    jsr GETIN
    beq waitkey    
    rts
hlt:   jmp hlt


CAP_Cluster: .asciiz "cluster"

print_fat32_info:
    prnt CAP_BytesPerSector,fat32_BytesPerSec,2
    prnt CAP_SecPerClus,fat32_SecPerClus,1
    prnt CAP_ReserverdSectors,fat32_RsvdSecCnt,2

    prnt CAP_NumOfFats,fat32_NumFATs,1
    prnt CAP_FatSize,fat32_FATSz32,4
    prnt CAP_RootCluster,fat32_RootClus,4

    prnt CAP_LBAStart,fat32_LBAstart,4
    prnt CAP_DataOffset,sd_data_offset,4



    rts



CAP_BytesPerSector: .asciiz "bytes per sector"
CAP_SecPerClus: .asciiz "sectors per cluster"
CAP_ReserverdSectors: .asciiz "reserved sectors"
CAP_NumOfFats:  .asciiz "number of fats"
CAP_FatSize:  .asciiz "fat size"
CAP_RootCluster:  .asciiz "root cluster"
CAP_LBAStart:  .asciiz "lba start"
CAP_DataOffset:  .asciiz "data offset"
