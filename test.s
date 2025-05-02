.segment "DATA"
    file_buffer:    .res 500
    file_buffer_len_filename     = file_buffer+1
    file_buffer_start_filename   = file_buffer+2
    
    file_to_search_for: .asciiz "x16emu.exe"

.segment "CODE"

    jsr get_cluster_nr
    
    ;r10 to r10+3 = $FFFFFFFF if no match, else = cluster nr
    lda r10+3
    jsr dbg_chrout
    lda r10+2
    jsr dbg_chrout
    lda r10+1
    jsr dbg_chrout
    lda r10
    jsr dbg_chrout
    lda #$0d
    jsr CHROUT
    
    ;copy r10 to sd_current_cluster for conversion from cluster to sector
    lda r10
    sta sd_current_cluster
    lda r10+1
    sta sd_current_cluster+1
    lda r10+2
    sta sd_current_cluster+2
    lda r10+3
    sta sd_current_cluster+3
    
    stz sd_sector_count
    jsr cluster_to_sector
    
    ;sd_cmd_tmp holds sector nr
    lda sd_cmd_tmp+3
    jsr dbg_chrout
    lda sd_cmd_tmp+2
    jsr dbg_chrout
    lda sd_cmd_tmp+1
    jsr dbg_chrout
    lda sd_cmd_tmp
    jsr dbg_chrout
    
    jsr sd_is_contineous_sequence
    bcs file_is_not_in_sequence
    lda #'1'
    jsr CHROUT
rts
    
file_is_not_in_sequence:
    lda #'0'
    jsr CHROUT
rts


get_cluster_nr:
  
    
    ;all $FF's indicates, file not found
    lda #$FF
    sta r10
    sta r10+1
    sta r10+2
    sta r10+3


    jsr sd_init  ;init sd-card
    ;now sd_current_cluster contains the starting cluser of the root dir
    
    ;get ready to do a directory listing
    jsr sd_init_files_list

    ;set location to store filename info
    lda #<file_buffer
    sta r5
    lda #>file_buffer
    sta r5+1
    
    list_loop:
     
        jsr sd_get_next_file
      
        lda file_buffer
        cmp #$FF    ;indicates no more files
        beq at_end_of_list9      
          
        lda file_buffer_len_filename   ;store file len
        inc
        sta cnt
       
        ldx #0
        compare_loop:
            lda file_to_search_for,x
            jsr a_to_lowercase
            cmp #0
            beq match_found ;nul-byte encountered
            cmp file_buffer_start_filename,x
            bne list_loop   ;no match, try next
            inx
            cpx cnt
            bne compare_loop
        bra list_loop
        
    at_end_of_list9:
    rts

    match_found:
        clc
        lda file_buffer+1   ;get len of filename
        adc #6              ;one byte for attribute byte,+4 for file len bytes
        tay
        ldx #0
        :
            lda file_buffer,y
            sta r10,x
            iny
            inx
            cpx #4
            bne :-
    rts



;Example of show files list 
show_files_list:
    ;goto iso mode and clear screen
    clc
    lda #1
    jsr SCREEN_SET_CHARSET 
    lda #$0F ;E
    jsr CHROUT
    
    
    ;init sd-card
    jsr sd_init
    ;now sd_current_cluster contains the starting cluser of the root dir
    
    ;change sd_current_cluster to little endian starting cluser of a directory to list it
    ;or to a files first cluster to read it
    
    
    ;get ready to do a directory listing
    jsr sd_init_files_list
    
    ;set location to store filename info
    lda #<file_buffer
    sta r5
    lda #>file_buffer
    sta r5+1
    
    file_list_loop:
        jsr sd_get_next_file
        lda file_buffer
        cmp #$FF
        beq at_end_file_files_list2
        
        ;Print Filename
        ldx file_buffer+1
        ldy #0
        :
            lda file_buffer+2,y
            jsr CHROUT
            iny
            dex
            bne :-
        lda #' '
        jsr CHROUT
        ;Print file size
        ldx #4
        :
            lda file_buffer+2,y
            jsr dbg_chrout
            iny
            dex
            bne :-

        lda #' '
        jsr CHROUT
        ;print first sector
        ldx #4
        :
            lda file_buffer+2,y
            jsr dbg_chrout
            iny
            dex
            bne :-
                        
        lda #$0D
        jsr CHROUT
       ; jsr dbg_lf
     
        bra file_list_loop
    
    
    at_end_file_files_list2:
    
    rts

.include "sd.s"
