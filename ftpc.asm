;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                 ;;
;; Copyright (C) KolibriOS team 2013-2014. All rights reserved.    ;;
;; Distributed under terms of the GNU General Public License       ;;
;;                                                                 ;;
;;  ftpc.asm - FTP client for KolibriOS                            ;;
;;                                                                 ;;
;;  Written by hidnplayr@kolibrios.org                             ;;
;;  Modified by nisargshah323@gmail.com (2016)                     ;;
;;                                                                 ;;
;;          GNU GENERAL PUBLIC LICENSE                             ;;
;;             Version 2, June 1991                                ;;
;;                                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format binary as ""

TIMEOUT                 = 3     ; seconds

BUFFERSIZE              = 4096

STATUS_CONNECTING       = 0
STATUS_CONNECTED        = 1
STATUS_NEEDPASSWORD     = 2
STATUS_LOGGED_IN        = 3

OPERATION_NONE          = 0
OPERATION_LIST          = 1
OPERATION_RETR          = 2
OPERATION_STOR          = 3
OPERATION_RDIR          = 4
        
use32
; standard header
        db      'MENUET01'      ; signature
        dd      1               ; header version
        dd      start           ; entry point
        dd      i_end           ; initialized size
        dd      mem+0x1000      ; required memory
        dd      mem+0x1000      ; stack pointer
        dd      buf_cmd         ; parameters
        dd      path            ; path

include 'macros.inc'
macro pcall proc,[arg]  ; to call a proc with multiple args
 {  pushd arg
    call proc }
purge mov,add,sub
include 'proc32.inc'
include 'dll.inc'
include 'network.inc'

include 'box_lib.mac'
include 'load_lib.mac'
    @use_library         ;use load lib macros

include 'console.inc'
include 'connect_gui.inc'
include 'usercommands.inc'
include 'servercommands.inc'
include 'parser.inc'

;;================================================================================================;;
start: ;//////////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Program entry point - initialize heap, load libraries and settings                             ;;
;;------------------------------------------------------------------------------------------------;;
;>                                                                                                ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
; initialize heap for using dynamic blocks
        mcall   68,11
        test    eax,eax
        je      exit2
        
; disable all events except network event
        mcall   40, EV_STACK
; load libraries
        stdcall dll.Load, @IMPORT
        test    eax, eax
        jnz     exit
; find path to main settings file (ftpc.ini)
        mov     edi, path               ; Calculate the length of zero-terminated string
        xor     al, al
        mov     ecx, 1024
        repne   scasb
        dec     edi
        mov     esi, str_ini            ; append it with '.ini', 0
        movsd
        movsb
; get settings from ini
        invoke  ini.get_str, path, str_active, str_ip, str_active_ip, 16, 0
        mov     esi, str_active_ip
  .ip_loop:
        lodsb
        test    al, al
        jz      .ip_ok
        cmp     al, ' '
        je      .ip_ok
        cmp     al, '.'
        jne     .ip_loop
        mov     byte[esi-1], ','
        jmp     .ip_loop
  .ip_ok:
        mov     byte[esi-1], 0

        invoke  ini.get_int, path, str_active, str_port_start, 64000
        mov     [acti_port_start], ax

        invoke  ini.get_int, path, str_active, str_port_stop, 65000
        mov     [acti_port_stop], ax

        invoke  ini.get_str, path, str_general, str_dir, buf_buffer1, BUFFERSIZE, 0
        mcall   30, 1, buf_buffer1                      ; set working directory

; command line arguments should be of the form
; "ftpc ftp://username:password@server:port/path"
; or "ftpc -cli". All other args will be ignored and GUI will be started
        call    console.init
        call    console.cls
        cmp     dword[buf_cmd], 'ftp:'
        je      resolve_args
        cmp     dword[buf_cmd], '-cli'
        je      arg_handler.get_server_addr
        jmp     init_connect_gui


;;================================================================================================;;
arg_handler: ;////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Passes user input from console/GUI to FTP core and the other way around                        ;;
;;------------------------------------------------------------------------------------------------;;
;> esp+4 = pointer to the argument passed to the function                                         ;;
;> use_params = command line arguments to be used - 1 (yes) or 0 (no)                             ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
; Resolve server address and port
  .get_server_addr:
        cmp     [use_params], 1
        je      connect_gui_active
        call    console.cls
        jmp     console.server_addr

  .get_cmd:
        jmp     console.get_cmd

  .print:
        invoke  con_write_asciiz, [esp+4]
        ret     4

; set flags (change text color)
  .set_flags:
        invoke  con_set_flags, [esp+4]
        ret     4

  .get_username:
; request username
        mov     dword[buf_cmd], "USER"
        mov     byte[buf_cmd+4], " "
        cmp     [use_params], 1
        je      .copy_user
        jmp     console.get_username

  .copy_user: 
; copy user name to buf_cmd (for command line args)
        mov     edi, buf_cmd+5
        mov     esi, param_user
  @@:
        lodsb
        stosb
        cmp     byte [esi-1], 0
        jne     @b
        mov     word[edi-1], 0x0a0d

        lea     esi, [edi+1-buf_cmd]
        jmp     .send

  .get_pass:
; request password
        mov     dword[buf_cmd], "PASS"
        mov     byte[buf_cmd+4], " "
        cmp     [use_params], 1
        je      .copy_password
        mov     esi, buf_cmd+5
        jmp     console.get_pass

  .copy_password:
; copy password to buf_cmd (for command line args)
        mov     edi, buf_cmd+5
        mov     esi, param_password
  @@:
        lodsb
        stosb
        cmp     byte [esi-1], 0
        jne     @b
        mov     word[edi-1], 0x0a0d

        lea     esi, [edi+1-buf_cmd]
        jmp     .send

  .get_path:
; copy path from param_path to buf_cmd
        mov     dword[buf_cmd], "CWD "
        mov     edi, buf_cmd+4
        mov     esi, param_path
  @@:
        lodsb
        stosb
        cmp     byte [esi-1], 0
        jne     @b
        mov     word[edi-1], 0x0a0d

        lea     esi, [edi+1-buf_cmd]
        jmp     .send

  .send:
  ; and send it to the server
        ;int3
        mcall   send, [controlsocket], buf_cmd, , 0
        mov     [param_user], 0     ; at wait_for_usercommand, if [param_user]
                                    ; is 0, that means show GUI again, dont
                                    ; take value from param_user
        stdcall arg_handler.print, str_newline
        stdcall arg_handler.set_flags, 0x07     ; reset color
        
        jmp     wait_for_servercommand


;;================================================================================================;;
server_connect: ;/////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Establishes a connection to the FTP server (common block for all interfaces)                   ;;
;? .do_port - Port is specified by the user and needs to be converted from ASCII                  ;;
;;------------------------------------------------------------------------------------------------;;
;> esi = pointer to the first character of port no.                                               ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
; resolve port if specified
  .do_port:
        xor     eax, eax
        xor     ebx, ebx
        mov     byte [esi-1], 0
  .portloop:
        lodsb
        cmp     al, 0x20
        jbe     .port_done
        sub     al, '0'
        jnb     @f
        mov     eax, str_err_host
        jmp     error
    @@: cmp     al, 9
        jna     @f
        mov     eax, str_err_host
        jmp     error
    @@: lea     ebx, [ebx*4 + ebx]
        shl     ebx, 1
        add     ebx, eax
        jmp     .portloop

  .port_done:
        xchg    bl, bh
        mov     [sockaddr1.port], bx
        jmp     .done

  .default_port:
        mov     [sockaddr1.port], 21 shl 8
        jmp     .done

  .done:
; delete terminating '\n'
        mov     esi, buf_cmd
  @@:
        lodsb
        cmp     al, 0x20
        ja      @r
        mov     byte [esi-1], 0

; Say to the user that we're resolving
        stdcall arg_handler.set_flags, 0x07     ; reset color
        pcall   arg_handler.print, str_resolve, buf_cmd
; resolve name
        push    esp     ; reserve stack place
        invoke  getaddrinfo, buf_cmd, 0, 0, esp
        pop     esi
; test for error
        test    eax, eax
        jz      @f
        mov     eax, str_err_resolve
        jmp     error
    @@:
; write results
        stdcall arg_handler.print, str8         ; ' (',0
        mov     eax, [esi+addrinfo.ai_addr]     ; convert IP address to decimal notation
        mov     eax, [eax+sockaddr_in.sin_addr] ;
        mov     [sockaddr1.ip], eax             ;
        invoke  inet_ntoa, eax                  ;
        pcall   arg_handler.print, eax, str9    ; <ip>,')',10,0
        invoke  freeaddrinfo, esi               ; free allocated memory
; open the socket
        mcall   socket, AF_INET4, SOCK_STREAM, 0
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_socket
        jmp     error
    @@: mov     [controlsocket], eax
; connect to the server
        stdcall arg_handler.print, str_connect
        mcall   connect, [controlsocket], sockaddr1, 18
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_connect
        jmp     error
    @@: mov     [status], STATUS_CONNECTING
; Tell the user we're waiting for the server now.
        stdcall arg_handler.print, str_waiting

; Reset 'offset' variable, it's used by the data receiver
        mov     [offset], 0

;;================================================================================================;;
wait_for_servercommand: ;/////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Checks if any data received from the server is present in buffer.                              ;;
;? If not, receives and displays it                                                               ;;
;;------------------------------------------------------------------------------------------------;;
;>                                                                                                ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
; Any commands still in our buffer?
        cmp     [offset], 0
        je      .receive                        ; nope, receive some more
        mov     esi, [offset]
        mov     edi, buf_cmd
        mov     ecx, [size]
        add     ecx, esi
        jmp     .byteloop

; receive socket data
  .receive:
        mcall   26, 9
        add     eax, TIMEOUT*100
        mov     [timeout], eax
  .receive_loop:
        mcall   23, 50          ; Wait for event with timeout
        mcall   26, 9
        cmp     eax, [timeout]
        jl      @f
        mov     eax, str_err_timeout
        jmp     error
    @@: mcall   recv, [controlsocket], buf_buffer1, BUFFERSIZE, MSG_DONTWAIT
        test    eax, eax
        jnz     .got_data
        cmp     ebx, EWOULDBLOCK
        je      @f
        mov     eax, str_err_recv
        jmp     error
    @@: jmp     .receive_loop

  .got_data:
        mov     [offset], 0

; extract commands, copy them to "buf_cmd" buffer
        lea     ecx, [eax + buf_buffer1]         ; ecx = end pointer
        mov     esi, buf_buffer1                 ; esi = current pointer
        mov     edi, buf_cmd
  .byteloop:
        cmp     esi, ecx
        jae     wait_for_servercommand
        lodsb
        cmp     al, 10                          ; excellent, we might have a command
        je      .got_command
        cmp     al, 13                          ; just ignore this byte
        je      .byteloop
        stosb
        jmp     .byteloop
  .got_command:                                 ; we have a newline check if its a command
        cmp     esi, ecx
        je      .no_more_data
        mov     [offset], esi
        sub     ecx, esi
        mov     [size], ecx
        jmp     .go_cmd
  .no_more_data:
        mov     [offset], 0
  .go_cmd:
        lea     ecx, [edi - buf_cmd]                  ; length of command
        xor     al, al
        stosb

        stdcall arg_handler.set_flags, 0x03     ; change color
        pcall   arg_handler.print, buf_cmd, str_newline     ; ; print servercommand
        stdcall arg_handler.set_flags, 0x07     ; reset color

        jmp     server_parser                   ; parse command



;;================================================================================================;;
wait_for_usercommand: ;///////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Reads first four characters of FTP command entered by the user and compares it                 ;;
;? with valid FTP commands. Jumps to appropriate handling routine in usercommands.inc             ;;
;;------------------------------------------------------------------------------------------------;;
;> status = socket connection status                                                              ;;
;> buf_cmd = command entered by the user                                                          ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;

; Are there any files in the transfer queue?

        cmp     [queued], 0
        ja      transfer_queued                 ; Yes, transfer those first.

; change color to green for user input
        stdcall arg_handler.set_flags, 0x0a

; If we are not yet connected, request username/password

        cmp     [status], STATUS_CONNECTED
        jne     @f
        cmp     [param_user], 0
        jne     arg_handler.get_username
        jmp     connect_gui_active
  @@:
        cmp     [status], STATUS_NEEDPASSWORD
        je      arg_handler.get_pass

        jmp     arg_handler.get_cmd

  .parse_cmd:
        cmp     dword[buf_cmd], "cwd "
        je      cmd_cwd

        cmp     dword[buf_cmd], "mkd "
        je      cmd_mkd

        cmp     dword[buf_cmd], "rmd "
        je      cmd_rmd

        cmp     dword[buf_cmd], "pwd" + 10 shl 24
        je      cmd_pwd

        cmp     dword[buf_cmd], "bye" + 10 shl 24
        je      cmd_bye

        cmp     dword[buf_cmd], "rdir"
        je      cmd_rdir
        
        cmp     byte[buf_cmd+4], " "
        jne     @f

        cmp     dword[buf_cmd], "lcwd"
        je      cmd_lcwd

        cmp     dword[buf_cmd], "retr"
        je      cmd_retr

        cmp     dword[buf_cmd], "stor"
        je      cmd_stor

        cmp     dword[buf_cmd], "dele"
        je      cmd_dele

  @@:
        cmp     byte[buf_cmd+4], 10
        jne     @f

        cmp     dword[buf_cmd], "list"
        je      cmd_list

        cmp     dword[buf_cmd], "help"
        je      cmd_help

        cmp     dword[buf_cmd], "cdup"
        je      cmd_cdup

  @@:
; Uh oh.. unknown command, tell the user and wait for new input
        stdcall arg_handler.print, str_unknown
        jmp     wait_for_usercommand


; files for rdir operation are queued
transfer_queued:

        mov     esi, [ptr_queue]                ; always pointing to current part of ptr_fname_start
        mov     edi, buf_cmd+5                  ; always point to filename for retr command
  .build_filename:
        lodsb   
        stosb
        cmp     al, 10
        je      .get_file                       ; filename ends with character 10
        test    al, al
        jnz     .build_filename

        ; Error occured, we reached the end of the buffer before [queued] reached 0
        mov     [queued], 0
        mcall   68, 13, [ptr_fname]             ; free buffer
        test    eax, eax
        jz      error_heap
        jmp     wait_for_usercommand

  .get_file:
        mov     byte[edi], 0                    ; end filename with 0 byte
        mov     [ptr_queue], esi
        dec     [queued]
        jnz     cmd_retr

        mcall   68, 13, [ptr_fname]             ; free buffer
        test    eax, eax
        jz      error_heap
        jmp     cmd_retr



open_dataconnection:

        test    [mode], 1
        jnz     .active

        mcall   send, [controlsocket], str_PASV, str_PASV.length, 0
        ret

  .active:
        mcall   socket, AF_INET4, SOCK_STREAM, 0
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_socket
        jmp     error
    @@: mov     [datasocket], eax

        mov     ax, [acti_port_start]
        xchg    al, ah
        mov     [sockaddr2.port], ax

        mcall   bind, [datasocket], sockaddr2, 18
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_bind
        jmp     error
    @@:

        mcall   listen, [datasocket], 1
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_listen
        jmp     error
    @@:

        mov     dword[buf_buffer1], 'PORT'
        mov     byte[buf_buffer1+4], ' '
        mov     edi, buf_buffer1+5
        mov     esi, str_active_ip
  .loop:
        lodsb
        test    al, al
        jz      .ip_ok
        stosb
        jmp     .loop
  .ip_ok:
        mov     al, ','
        stosb
        movzx   eax, byte[sockaddr2.port+0]
        call    dword_ascii
        mov     al, ','
        stosb
        movzx   eax, byte[sockaddr2.port+1]
        call    dword_ascii
        mov     ax, 0x0a0d
        stosw
        lea     esi, [edi - buf_buffer1]
        mcall   send, [controlsocket], buf_buffer1, , 0

        mcall   accept, [datasocket], sockaddr2, 18        ; time to accept the awaiting connection..
        cmp     eax, -1
        jne     @f
        mov     eax, str_err_accept
        jmp     error
    @@: push    eax
        mcall   close, [datasocket]
        pop     [datasocket]

        mcall   recv, [controlsocket], buf_buffer1, BUFFERSIZE, 0

        ret

; eax = input
; edi = ptr where to write
dword_ascii:

        push    edx ebx ecx
        mov     ebx, 10
        xor     ecx, ecx

       @@:
        xor     edx, edx
        div     ebx
        add     edx, '0'
        push    dx
        inc     ecx
        test    eax, eax
        jnz     @r

       @@:
        pop     ax
        stosb
        dec     ecx
        jnz     @r

        pop     ecx ebx edx
        ret

;;================================================================================================;;
error: ;//////////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Generic error routine. Prints the error string passed to it.                                   ;;
;;------------------------------------------------------------------------------------------------;;
;> eax = pointer to the error string                                                              ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;
        push    eax
        stdcall arg_handler.set_flags, 0x0c              ; print errors in red
        pop     eax
        stdcall arg_handler.print, eax
        jmp     wait_for_keypress

; Error handling block for filesystem errors
error_fs:
        
        cmp     eax, 12
        jne     @f
        mov     ebx, str_fs_err_12
  @@:
        cmp     eax, 11
        jne     @f
        mov     ebx, str_fs_err_11
  @@:
        cmp     eax, 10
        jne     @f
        mov     ebx, str_fs_err_10
  @@:
        cmp     eax, 9
        jne     @f
        mov     ebx, str_fs_err_9
  @@:
        cmp     eax, 8
        jne     @f
        mov     ebx, str_fs_err_8
  @@:
        cmp     eax, 7
        jne     @f
        mov     ebx, str_fs_err_7
  @@:
        cmp     eax, 6
        jne     @f
        mov     ebx, str_fs_err_6
  @@:
        cmp     eax, 5
        jne     @f
        mov     ebx, str_fs_err_5
  @@:
        cmp     eax, 3
        jne     @f
        mov     ebx, str_fs_err_3
  @@:
        cmp     eax, 2
        jne     @f
        mov     ebx, str_fs_err_2
  @@:
        mov     edi, fs_error_code
        call    dword_ascii    ; convert error code in eax to ascii
        stdcall arg_handler.set_flags, 0x0c              ; print errors in red
        pcall   arg_handler.print, str_err_fs, fs_error_code, ebx
        mov     word[fs_error_code], '  '   ; clear error code for next time
        stdcall arg_handler.set_flags, 0x0a

        jmp     wait_for_usercommand

error_heap:
        stdcall arg_handler.set_flags, 0x0c              ; print errors in red
        stdcall arg_handler.print, str_err_heap
        
wait_for_keypress:
        stdcall arg_handler.set_flags, 0x07             ; reset color to grey
        stdcall arg_handler.print, str_push
        invoke  con_getch2
        mcall   close, [controlsocket]
        call    console.cls
        jmp     console.server_addr

done:
        invoke  con_exit, 1

exit:
        mcall   close, [controlsocket]
exit2:  
        mcall   -1



; data
str_title       db 'FTP client',0
str_welcome     db 'FTP client for KolibriOS v0.12',10
                db 10,0
str_srv_addr    db 'Please enter ftp server address.',10,0

str_ftp         db 'ftp://',0

str_prompt      db '> ',0
str_resolve     db 'Resolving ',0
str_newline     db 10,0
str_err_resolve db 10,'Name resolution failed.',10,0
str_err_socket  db 10,'[75,0 socket]: Error creating a socket',10,0
str_err_bind    db 10,'[75,2 bind]: Error binding to socket',10,0
str_err_listen  db 10,'[75,3 listen]: Cannot accept incoming connections',10,0
str_err_accept  db 10,'[75,5 accept]: Error accepting a connection',10,0
str_err_recv    db 10,'[75,7 recv]: Error receiving data from server',10,0
str_err_heap    db 10,'Cannot allocate memory from heap.',10,0
str_err_timeout db 10,'Timeout - no response from server.',10,0
str_err_connect db 10,'[75,4 connect]: Cannot connect to the server.',10,0
str_err_host    db 10,'Invalid hostname.',10,0
str_err_params  db 10,'Invalid parameters',10,0
str_err_fs      db 10,'File system error: code ',0
fs_error_code   db '  ',0    ; file system error code
str_fs_err_2    db ' [Function is not supported for the given file system]',10,0
str_fs_err_3    db ' [Unknown file system]',10,0
str_fs_err_5    db ' [File/Folder not found]',10,0
str_fs_err_6    db ' [End of file, EOF]',10,0
str_fs_err_7    db ' [Pointer lies outside of application memory]',10,0
str_fs_err_8    db ' [Disk is full]',10,0
str_fs_err_9    db ' [File system error]',10,0
str_fs_err_10   db ' [Access denied]',10,0
str_fs_err_11   db ' [Device error]',10,0
str_fs_err_12   db ' [File system requires more memory]',10,0
str8            db ' (',0
str9            db ')',10,0
str_push        db 'Push any key to continue.',0
str_connect     db 'Connecting...',10,0
str_waiting     db 'Waiting for welcome message.',10,0
str_user        db "username: ",0
str_pass        db "password: ",0
str_unknown     db "Unknown command or insufficient parameters - type help for more information.",10,0
str_lcwd        db "Local working directory is now: ",0
str_bytes_done  db '          ',0
str_downloaded  db 'Downloaded ',0
str_bytes       db ' bytes',13,0

str_open        db "opening data socket",10,0
str_close       db 10,"closing data socket",10,0
str_dot         db '.',0

str_help        db "available commands:",10
                db 10
                db "bye             - close the connection",10
                db "cdup            - change to parent of current directory on the server",10
                db "cwd <directory> - change working directoy on the server",10
                db "dele <file>     - delete file from the server",10
                db "list            - list files and folders in current server directory",10
                db "lcwd <path>     - change local working directory",10
                db "mkd <directory> - make directory on the server",10
                db "pwd             - print server working directory",10
                db "retr <file>     - retreive file from the server",10
                db "rmd <directory> - remove directory from the server",10
                db "stor <file>     - store file on the server",10
                db "rdir            - retreive all files from current server dir",10
                db 10,0

str_ini         db '.ini', 0
str_active      db 'active', 0
str_port_start  db 'port_start', 0
str_port_stop   db 'port_stop', 0
str_ip          db 'ip', 0
str_dir         db 'dir', 0
str_general     db 'general', 0

queued          dd 0
mode            db 0    ; passive = 0, active = 1


; FTP strings

str_PASV        db 'PASV',13,10
.length = $ - str_PASV

sockaddr1:
        dw AF_INET4
.port   dw ?
.ip     dd ?
        rb 10

sockaddr2:
        dw AF_INET4
.port   dw ?
.ip     dd ?
        rb 10

folder_info:
        dd  5
        times 3 dd 0
        dd  folder_buf
        db  0
        dd  buf_cmd+5
folder_buf  rb 40


; import
align 4
@IMPORT:

library network, 'network.obj', libini, 'libini.obj'

import  network,        \
        getaddrinfo,    'getaddrinfo',  \
        freeaddrinfo,   'freeaddrinfo', \
        inet_ntoa,      'inet_ntoa'

import  libini,         \
        ini.get_str,    'ini_get_str',\
        ini.get_int,    'ini_get_int'


i_end:

; uninitialised data

status          db ?

controlsocket   dd ?
datasocket      dd ?
offset          dd ?
size            dd ?
operation       dd ?
timeout         dd ?

ptr_fname       dd ?
size_fname      dd ?
ptr_queue       dd ?

acti_port_start dw ?
acti_port_stop  dw ?
acti_port       dw ?

str_active_ip   rb 16

filestruct:
  .subfn        dd ?
  .offset       dd ?
                dd ?
  .size         dd ?
  .ptr          dd ?
  .name         rb 1024

buf_buffer1     rb BUFFERSIZE+1
buf_buffer2     rb BUFFERSIZE+1
buf_cmd         rb 1024                 ; buffer for holding command string

path            rb 1024

use_params      db 0
param_user      rb 1024
param_password  rb 1024
param_server_addr rb 1024
param_path      rb 1024
param_port      rb 6

mem: