;;================================================================================================;;
console: ;////////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Console-specific functions - initialization, clear screen,                                     ;;
;? .get_cmd - Takes user command as input from the console                                        ;;
;? .server_addr - Gets server address from user in the form address:port                          ;;
;? .username/.password - Takes username/password as input from the user                           ;;
;;------------------------------------------------------------------------------------------------;;
;>                                                                                                ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
  .init:
; load console library
        stdcall dll.Load, @import_console
; initialize console
        invoke  con_start, 1
        invoke  con_init, 120, 43, 120, 300, str_title
        ret
  .cls:
; Clear screen
        invoke  con_cls
; Welcome user
        invoke  con_write_asciiz, str_welcome
        ret
  .server_addr:
        invoke  con_set_flags, 0x07
; ask for server addr
        invoke  con_write_asciiz, str_srv_addr
; write prompt (in green color)
        invoke  con_set_flags, 0x0a
        invoke  con_write_asciiz, str_prompt
; read string
        invoke  con_gets, buf_cmd, 256
; check for exit
        test    eax, eax
        jz      done
        cmp     byte [buf_cmd], 10
        jz      done
; reset color back to grey and print newline
        invoke  con_set_flags, 0x07
        invoke  con_write_asciiz, str_newline
; check whether port specified with hostname after ':'
        mov     esi, buf_cmd
  @@:
        lodsb
        cmp     al, ':'
        je      server_connect.do_port
        cmp     al, 0x20
        ja      @r
        jmp     server_connect.default_port

  .get_cmd:
; write prompt
        invoke  con_write_asciiz, str_prompt
; read string
        invoke  con_gets, buf_cmd, 256

; print a newline and reset the color back to grey
        invoke  con_write_asciiz, str_newline
        invoke  con_set_flags, 0x07

        jmp     wait_for_usercommand.parse_cmd

; read username
  .get_username:
        invoke  con_write_asciiz, str_user
        mov     esi, buf_cmd+5
        invoke  con_gets, esi, 256

        jmp     .send

; read password
  .get_pass:
        invoke  con_write_asciiz, str_pass
        invoke  con_set_flags, 0x00             ; black text on black background for password
        invoke  con_gets, esi, 256
        jmp     .send

  .send:
; find end of string
        mov     edi, buf_cmd+5
        mov     ecx, 256
        xor     al, al
        repne   scasb
        cmp     [use_params], 1
        je      @f
        mov     word[edi-2], 0x0a0d

        lea     esi, [edi-buf_cmd]
        jmp     server_connect.send


; import
align 4
@import_console:

library console, 'console.obj'

import  console,        \
        con_start,      'START',        \
        con_init,       'con_init',     \
        con_write_asciiz,'con_write_asciiz',     \
        con_exit,       'con_exit',     \
        con_gets,       'con_gets',\
        con_cls,        'con_cls',\
        con_getch2,     'con_getch2',\
        con_set_cursor_pos, 'con_set_cursor_pos',\
        con_write_string, 'con_write_string',\
        con_get_flags,  'con_get_flags', \
        con_set_flags,  'con_set_flags'