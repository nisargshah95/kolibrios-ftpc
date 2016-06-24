;;================================================================================================;;
console: ;////////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Console-specific functions - initialization, clear screen,                                     ;;
;? .get_cmd - Takes user command as input from the console                                        ;;
;? .server_addr - Gets server address from user in the form address:port                          ;;
;? .get_username/.get_pass - Takes username/password as input from the user                       ;;
;;------------------------------------------------------------------------------------------------;;
;>                                                                                                ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;

  dd .init
  dd .server_addr
  dd .get_username
  dd .get_cmd
  dd .exit

  .init:
; load console library
        stdcall dll.Load, @import_console
; initialize console
        invoke  con_start, 1
        invoke  con_init, 120, 43, 120, 300, str_title
        invoke  con_cls
; Welcome user
        invoke  con_write_asciiz, str_welcome
        ret

  .server_addr:
        mov     [initial_login], 1
        invoke  con_cls
        invoke  con_set_flags, 0x07
; ask for server addr
        invoke  con_write_asciiz, str_srv_addr
; write prompt (in green color)
        invoke  con_set_flags, 0x0a
        invoke  con_write_asciiz, str_prompt
; read string
        invoke  con_gets, param_server_addr, 256
; check for exit
        test    eax, eax
        jz      .exit
        cmp     byte [param_server_addr], 10
        jz      .exit

  .port:
        invoke  con_write_asciiz, str_port
        invoke  con_gets, param_port, 256

; read username
  .get_username:
        invoke  con_set_flags, 0x0a
        invoke  con_write_asciiz, str_user
        invoke  con_gets, param_user, 256

; read password
  .get_pass:
        invoke  con_write_asciiz, str_pass
        invoke  con_set_flags, 0x00             ; black text on black background for password
        invoke  con_gets, param_password, 256
        invoke  con_set_flags, 0x0a

        cmp     [initial_login], 1
        jne     arg_handler.copy_user
        mov     [initial_login], 0

; get initial path
  .get_path:
        invoke  con_write_asciiz, str_path
        invoke  con_gets, param_path, 256
        invoke  con_write_asciiz, str_newline

        jmp     arg_handler.connect

  .get_cmd:
; write prompt
        invoke  con_write_asciiz, str_prompt
; read string
        invoke  con_gets, buf_cmd, 256

; print a newline and reset the color back to grey
        invoke  con_write_asciiz, str_newline
        invoke  con_set_flags, 0x07

        jmp     wait_for_usercommand.parse_cmd

  .exit:
        invoke  con_exit, 1
        ret


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