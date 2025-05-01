.include "inc/macro.s"

.export sd_current_cluster          
.export sd_init_files_list         
.export sd_get_next_file
.export sd_init

SHOW_DEBUG = 0

SPI_CTRL = $9F3F
SPI_DATA = $9F3E

GO_IDLE_STATE = $40
CMD55 = $77
ACMD41 = $69
READ_SECTOR = $51

VBR_BytesPerSector = $0b
VBR_NumberOfFats = $10
VBR_SectorsPerCluster = $0d
VBR_ReservedSectors = $0e

VBR_SectorsPerFact = $24
VBR_RootCluster = $2c


FAT32_START_PARTITION_TABLE = $01BE


.segment "GOLDENRAM"
    sd_buffer:      .res 256
    sd_buffer_2:    .res 256


    cnt:    .res 1


    sd_sector_count: .res 1
    sd_current_cluster: .res 4      ;starting cluster of sequense to read
    sd_fat_offset:  .res 2  ;byte offset
    sd_data_offset: .res 4  ;sector
    sd_is_lfn:      .res 1
    sd_sequense_type:   .res 1

    sd_lfn_buffer:  .res 255
    sd_lfn_buffer_index:    .res 1
    sd_lfn_buffer_end:  .res 1
    sd_current_partition:    .res 1
    sd_eos:         .res 1
    sd_state:       .res 1
    sd_entry_counter:   .res 1


    fat32_BytesPerSec:  .res 2  ;$0B+$0C
    fat32_SecPerClus:  .res 1   ;$0D
    fat32_RsvdSecCnt:   .res 4  ;$0E+$0F (actualy two bytes!)
    fat32_NumFATs:  .res 1      ;$10
    fat32_FATSz32:  .res 4      ;$24 - $27
    fat32_RootClus: .res 4      ;$2C - $2F
    fat32_LBAstart: .res 4
    
    
.segment "ZEROPAGE"
    sd_cmd:     .res 6
    sd_cmd_tmp: .res 4
.segment "DATA"

.segment "CODE"

.include "inc/x16.s"
.include "inc/debug.s"

;-------------------------------------
; Call before using "sd_get_next_file"
;-------------------------------------
sd_init_files_list:
    stz sd_eos
    stz sd_sector_count    
    stz sd_state    ;no sector loaded
    stz sd_is_lfn   ;are we in lfn?
    stz sd_sequense_type
    
    lda #(255-13)   ;lfn entries are stored backwards
    sta sd_lfn_buffer_index
    rts

goto_read_next_sector:  jmp read_next_sector
goto_at_end_if_files_list_3:    jmp at_end_if_files_list_3
goto_to_next_file:  jmp to_next_file
goto_entry_is_lfn:  jmp entry_is_lfn

;----------------------------------------------------------------------
; Expects:
; - that 'sd_init' is called first
; - that 'sd_init_files_list' is called first
; - r5 -> pointer to where the filename and info should be stored in ram
; - sd_current_cluster -> clusternumber of the beginning of a directory entry
;
; Format for result en memory location in r5:
;    $00: fat32 attribute byte (bit4 is set=directory)
;    $01: len of filename (max 255)
;    $03-($03+[len of filename]): the filename
;    $03+[len of filename]: 4 bytes file size in bytes little endian
;    $03+[len of filename]+4: 4 bytes cluster number first data entry little endian
;
; if $00 has value of #$FF -> no more files
; NOTE: if sectorsize <>512 bytes, this function will not work
;----------------------------------------------------------------------
sd_get_next_file:
    stz sd_is_lfn
    lda #(255-13)   ;lfn entries are stored backwards
    sta sd_lfn_buffer_index  
    
    ;copy pointer to keep r5 intact
    lda r5
    sta r1
    lda r5+1
    sta r1+1

sd_get_next_file_no_reset:    
    lda sd_state
    bne sector_loaded
        jsr read_sequence

        stz sd_entry_counter
    sector_loaded:
    lda #1
    sta sd_state
    
    lda sd_entry_counter
    cmp #16             ;512 bytes per sector...CAN BE DIFFERENT!!!!
    beq goto_read_next_sector
    
    jsr set_r0_to_entry_counter
   
    
    ;Process entry
    lda (r0)
    beq goto_at_end_if_files_list_3
    cmp #$E5    ;deleted
    beq goto_to_next_file

    ldy #$0B    ;attributes
    
    lda (r0),y
    cmp #$0f
    beq goto_entry_is_lfn
    AND #%00000010  ;check if file is hidden
    bne goto_to_next_file    
         ;entry is short filename, or last one of lfn
        ;assume lfn for now
        sta (r1)    ;store attribute flags byte
        lda sd_is_lfn
        bne copy_filename_from_lfnbuffer
            ;copy filename from entry
            ldx #0
            :
                lda (r0),y
                sta sd_lfn_buffer,y
                iny
                cpy #11
                bne :-
            sty sd_lfn_buffer_end
            lda #0
            bra continu_populate_user_buffer
        
        copy_filename_from_lfnbuffer:
        lda sd_lfn_buffer_index
        clc
        adc #13
        continu_populate_user_buffer:
        tax
        ldy #2
        stz cnt
        :
            lda sd_lfn_buffer,x
            sta (r1),y
            inc cnt
            inx
            iny
            cpx sd_lfn_buffer_end
            bne :-
        phy       
            ;store len of filename
            ldy #1
            lda cnt
            sta (r1),y
        ply 

        ;add size via low ram buffer
        phy
            ldy #$1c
            ldx #0
            :
                lda (r0),y
                sta sd_cmd_tmp,x
                iny
                inx
                cpy #$20
                bne :-
        ply
        ldx #0
        :
            lda sd_cmd_tmp,x
            sta (r1),y
            iny
            inx
            cpx #4
            bne :-        
            
        ;add firstcluster number via low ram buffer 
        phy
            ;lo: $1a+$1b, high $14+$15
            ldy #$1a
            lda (r0),y
            sta sd_cmd_tmp
            iny
            lda (r0),y
            sta sd_cmd_tmp+1
            
            ldy #$14
            lda (r0),y
            sta sd_cmd_tmp+2
            iny
            lda (r0),y
            sta sd_cmd_tmp+3
        
        ply
        ldx #0
        :
            lda sd_cmd_tmp,x
            sta (r1),y
            iny
            inx
            cpx #4
            bne :- 
       inc sd_entry_counter
    rts

entry_is_lfn:
    ;read filename chars from 3 position within the file list entry. Unrolled for better performance
    ldx sd_lfn_buffer_index
    
    read_lfn_entry $01,$0B
    read_lfn_entry $0E,$1A
    read_lfn_entry $1C,$20

    lda sd_is_lfn
    bne not_first_part2
        stx sd_lfn_buffer_end 
    not_first_part2:
    inc sd_is_lfn
    lda sd_lfn_buffer_index
    sec
    sbc #13
    sta sd_lfn_buffer_index
    ;continu on next entry
to_next_entry:
    inc sd_entry_counter
    jmp sector_loaded

read_next_sector:
    stz sd_state
    jmp sd_get_next_file_no_reset

to_next_file:
    stz sd_is_lfn
    lda #(255-13)   ;lfn entries are stored backwards
    sta sd_lfn_buffer_index    
    
    inc sd_entry_counter
    jmp sd_get_next_file

at_end_if_files_list_3:
    ;mark no more files
    lda #$FF
    sta (r1)
    rts
 
set_r0_to_entry_counter:
    lda #<sd_buffer
    sta r0
    lda #>sd_buffer
    sta r0+1
    
    ldx sd_entry_counter
    beq no_offset
    :
        clc
        lda r0
        adc #32
        sta r0
        lda r0+1
        adc #0
        sta r0+1
        dex
        bne :-
    no_offset:
    rts
    
    
;--------------------------------------
; Initializes sd-card
; TODO: check if read command needs number in sectors or bytes
;--------------------------------------
sd_init:
    ;LBAStart is the offset for before data clusters
    stz32Bit fat32_LBAstart
    stz32Bit fat32_RsvdSecCnt
    stz sd_current_partition
  
    jsr init_sd_card
    
    ;read first secor (params are still $00)
    lda #READ_SECTOR
    sta sd_cmd
    jsr read_sector_internal

    ;check for partition table
    lda sd_buffer+FAT32_START_PARTITION_TABLE+4
    cmp #$0c
    beq is_fat_32_partition
    cmp #$0d
    beq is_fat_32_partition    

    ;no partition table, so is boot sector
    jmp handle_bootsector

    
  
  
    is_fat_32_partition:
        ;max 4 partities
        ;16 bytes per partition entry
        ;todo: cp:1
       
        ;sd_current_partition x 16.
        lda sd_current_partition
        asl
        asl
        asl
        asl
        tax
        
        lda sd_buffer+FAT32_START_PARTITION_TABLE+8,x
        sta fat32_LBAstart
        sta sd_cmd+4
        
        lda sd_buffer+FAT32_START_PARTITION_TABLE+9,x
        sta fat32_LBAstart+1
        sta sd_cmd+3
        
        lda sd_buffer+FAT32_START_PARTITION_TABLE+10,x
        sta fat32_LBAstart+2
        sta sd_cmd+2
        
        lda sd_buffer+FAT32_START_PARTITION_TABLE+11,x
        sta fat32_LBAstart+3
        sta sd_cmd+1
        
        jsr read_sector_internal
        ;bootsector is now in buffer
        
    handle_bootsector:
        ;Extract info from bootsector
        ;volume label
       ; ldy #0
        ;:
        ;    lda sd_buffer+$47,y
          ;  jsr dbg_char
        ;    iny
        ;    cpy #11
        ;    bne :-
       ; jsr dbg_lf
        
        ;store bytes per sector
        lda sd_buffer+VBR_BytesPerSector
        sta fat32_BytesPerSec
        lda sd_buffer+VBR_BytesPerSector+1
        sta fat32_BytesPerSec+1
        
        ;store Sectors per cluster
        lda sd_buffer+VBR_SectorsPerCluster
        sta fat32_SecPerClus
        
        ;Store Reserverd Sector Count
        lda sd_buffer+VBR_ReservedSectors
        sta fat32_RsvdSecCnt
        lda sd_buffer+VBR_ReservedSectors+1
        sta fat32_RsvdSecCnt+1        
        
        ;store Number of fats
        lda sd_buffer+VBR_NumberOfFats
        sta fat32_NumFATs

        ;Store sectors per fat
        lda sd_buffer+VBR_SectorsPerFact
        sta fat32_FATSz32
        lda sd_buffer+VBR_SectorsPerFact+1
        sta fat32_FATSz32+1
        lda sd_buffer+VBR_SectorsPerFact+2
        sta fat32_FATSz32+2
        lda sd_buffer+VBR_SectorsPerFact+3
        sta fat32_FATSz32+3

        ;Store cluster number of the root directory. subtract 2 to get correct offset
        sec
        lda sd_buffer+VBR_RootCluster
        sbc #2
        sta fat32_RootClus
        lda sd_buffer+VBR_RootCluster+1
        sbc #0
        sta fat32_RootClus+1
        lda sd_buffer+VBR_RootCluster+2
        sbc #0
        sta fat32_RootClus+2
        lda sd_buffer+VBR_RootCluster+3
        sbc #0
        sta fat32_RootClus+3

        
        
        ;Calculate first data sector
        
        ;load fat size
        stz32Bit sd_cmd_tmp

        lda fat32_RsvdSecCnt
        sta sd_cmd_tmp
        lda fat32_RsvdSecCnt+1
        sta sd_cmd_tmp+1

        ;add fat size per FAT, normaly 2 fats
        ldx fat32_NumFATs
        :
            adc32bit sd_cmd_tmp,fat32_FATSz32
            dex
            bne :-

        ;now we have first data sector??
        ldx fat32_SecPerClus
        :
            adc32bit sd_cmd_tmp,fat32_RootClus
            dex
            bne :-  
              
        adc32bit sd_cmd_tmp,fat32_LBAstart
                  
           
        ;from little endian to big endian
        lda sd_cmd_tmp+3   
        sta sd_data_offset+3
        sta sd_cmd+1
        
        lda sd_cmd_tmp+2   
        sta sd_data_offset+2
        sta sd_cmd+2
        
        lda sd_cmd_tmp+1   
        sta sd_data_offset+1
        sta sd_cmd+3
        
        lda sd_cmd_tmp+0   
        sta sd_data_offset+0
        sta sd_cmd+4
        
        stz32Bit sd_current_cluster
        
        lda #2      ;root dir starts at cluster 2
        sta sd_current_cluster
        
        ;jsr print_fat32_info       ;debug info   
        
  


rts

cluster_to_sector:
    
    prntDebug CAP_Cluster,sd_current_cluster,4
   

    ;(sd_current_cluster * fat32_SecPerClus) + sd_data_offset
    stz32Bit sd_cmd_tmp
    
    ldx fat32_SecPerClus
    :
        adc32bit sd_cmd_tmp,sd_current_cluster
        dex
        bne :-
    adc32bit sd_cmd_tmp,sd_data_offset

    ldx fat32_SecPerClus
        :
        sec
        lda sd_cmd_tmp
        sbc #2
        sta sd_cmd_tmp
        lda sd_cmd_tmp+1
        sbc #0
        sta sd_cmd_tmp+1
        lda sd_cmd_tmp+2
        sbc #0
        sta sd_cmd_tmp+2
        lda sd_cmd_tmp+3
        sbc #0
        sta sd_cmd_tmp+3
        dex
        bne :-
    
    
    ;add sd_sector_count
    clc
    lda sd_cmd_tmp
    adc sd_sector_count
    sta sd_cmd_tmp
    
    lda sd_cmd_tmp+1
    adc #0
    sta sd_cmd_tmp+1
    lda sd_cmd_tmp+2
    adc #0
    sta sd_cmd_tmp+2
    lda sd_cmd_tmp+3
    adc #0
    sta sd_cmd_tmp+3
      
    ;big endian to little endian
    lda sd_cmd_tmp
    sta sd_cmd+4
    lda sd_cmd_tmp+1
    sta sd_cmd+3
    lda sd_cmd_tmp+2
    sta sd_cmd+2
    lda sd_cmd_tmp+3
    sta sd_cmd+1
    
    rts



goto_continue_read: jmp continue_read


;--------------------------------
; Read the next sector of a sequence. A sequence can be a directory listing or the content of a file
; 
; If 'SectorsPerCluster'>1 then we read sequential sectors. Else, we find the next clusternr in fat1
; 
; TODO: calculations can be optimized
;--------------------------------
read_sequence:
    lda sd_sector_count
    cmp fat32_SecPerClus
    bne goto_continue_read

    ;Get next clusternr from FAT
    ;Fat Entry = LBAStart + ReservedSectors + (current cluster * 4)
    prntDebug CAP_Cluster,sd_current_cluster,4
    
    stz32Bit sd_cmd_tmp

    ;calculate fat1 sector + offset in sector
    lda sd_current_cluster
    sta sd_cmd_tmp
    and #$7F        ;get remainder
    sta sd_fat_offset
    stz sd_fat_offset+1

    lda sd_current_cluster+1
    sta sd_cmd_tmp+1
    lda sd_current_cluster+2
    sta sd_cmd_tmp+2
    lda sd_current_cluster+3
    sta sd_cmd_tmp+3
    
    ;time 4 as each entry is 4 bytes long
    asl sd_fat_offset
    rol sd_fat_offset+1
    asl sd_fat_offset
    rol sd_fat_offset+1
    
    ;divide by 128 (128 cluster allocations per sector) (quotient)
    LDX #7              ; 7 shifts
    ShiftLoop:
        lsr sd_cmd_tmp+3    
        ror sd_cmd_tmp+2   
        ror sd_cmd_tmp+1
        ror sd_cmd_tmp
        dex
        bne ShiftLoop    
    
    ;Add LBAStart
    adc32bit sd_cmd_tmp,fat32_LBAstart

    ;add reserved sector count
    adc32bit sd_cmd_tmp,fat32_RsvdSecCnt

    ;cmd_tmp to cmd
    lda sd_cmd_tmp+3
    sta sd_cmd+1
    lda sd_cmd_tmp+2
    sta sd_cmd+2
    lda sd_cmd_tmp+1
    sta sd_cmd+3
    lda sd_cmd_tmp
    sta sd_cmd+4

    jsr read_sector_internal
    
    ;get next cluster from fat1
        clc
        lda #<sd_buffer
        adc sd_fat_offset
        sta r0
        lda #>sd_buffer
        adc sd_fat_offset+1
        sta r0+1
        
        ldy #0
        :
            lda (r0),y
            sta sd_current_cluster,y
            iny
            cpy #4
            bne :- 

    ;check for and of sequense: TODO: optimize!!!s
    lda sd_current_cluster+3
    cmp #$0F
    bne not_end_of_sequence
    lda sd_current_cluster+2
    cmp #$FF
    bne not_end_of_sequence
    lda sd_current_cluster+1
    cmp #$FF
    bne not_end_of_sequence
    lda sd_current_cluster
    cmp #$FF
    beq is_end_of_sequence
    cmp #$F8
    beq is_end_of_sequence
    
    bra not_end_of_sequence
    is_end_of_sequence:
    sec
    rts
    
    not_end_of_sequence:

    stz sd_sector_count
    
    continue_read:

    jsr cluster_to_sector
    lda sd_sequense_type
    beq get_files_list
    jsr read_sector
    bra cont
    get_files_list:
    jsr read_sector_internal
    cont:
    inc sd_sector_count
    
    clc
    rts




;------------------------------
; Reads sectornr from CMD info (r1)
;------------------------------
read_sector:
    jsr send_spi_cmd

	lda SPI_CTRL;
	ora #$04    ;set bit 5 AutoTX
	sta SPI_CTRL

    ;expecting 512 bytes
	lda SPI_DATA    ;init first transfer
    nop ;give spi time to send and receive a byte
    nop 
    lda SPI_DATA     ;Expect $00
    nop ;give spi time to send and receive a byte
    nop
    lda SPI_DATA     ;Expect $FE


    ;we can unroll this even further to increase performance
    ;read first 256 bytes
    ldy #0
    :
        lda SPI_DATA
        sta (r1),y       
        iny
        bne :- 
    inc r1+1
    ;read second 256 bytes
    ldy #0
    :
        lda SPI_DATA
        sta (r1),y       
        iny
        bne :- 
    dec r1+1
rts

;Reads sector to sd_buffer
read_sector_internal:
    lda r1
    pha
    lda r1+1
    pha
        lda #<sd_buffer
        sta r1
        lda #>sd_buffer
        sta r1+1        
        jsr read_sector
    pla
    sta r1+1
    pla
    sta r1
    rts
  

send_spi_cmd:
    ldx #6  ;send 6 bytes
    ldy #0
    :
        lda sd_cmd,y
        sta SPI_DATA
        jsr wait_spi
        iny
        dex
        bne :-
    rts

;we can do this inline to prevent jsr/rts for performance (use macro)
wait_spi:
    bit SPI_CTRL   ;  update gflags
    bmi wait_spi    ; if bit 7 is set, keep looping
    rts

wait_response:
    lda #$FF
    sta SPI_DATA
    jsr wait_spi
    lda SPI_DATA
    cmp #$FF
    beq wait_response
    rts

init_sd_card:
    ;slow clock and enable SD
    lda #%00000010
    sta SPI_CTRL
    
    ;pass about 80us
    lda #$FF
    ldx #10
    :
        sta SPI_DATA
        jsr wait_spi
        dex
        bne :-

    lda #%00000011     ; bit1 = slow, bit0 = 1 → CS low (asserted)
    sta SPI_CTRL

    ;Clear command    
    ldx #5
    :
        stz sd_cmd,x
        dex
        bne :-
    
    
    lda #GO_IDLE_STATE
    sta sd_cmd
    jsr send_spi_cmd
    jsr wait_response

       

wait:
    lda #CMD55
    sta sd_cmd
    jsr send_spi_cmd
    jsr wait_response


    lda #ACMD41
    sta sd_cmd
    jsr send_spi_cmd
    jsr wait_response

    cmp #0
    bne wait

    ;disable slow clock
    lda SPI_CTRL
    and #%11111101
    sta SPI_CTRL
    rts
    


a_to_lowercase:
    cmp #$41
    bcc not_in_range21
    cmp #$5B
    bcs not_in_range21
    clc                    
    adc #$20              
    not_in_range21:
    rts

