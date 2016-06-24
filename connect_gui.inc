init_connect_gui:
;universal load library/libraries
sys_load_library  library_name, path, library_path, system_path, \
err_message_found_lib, head_f_l, myimport, err_message_import, head_f_i
;if return code =-1 then exit, else nornary work
    cmp      eax,-1
    jz       connect_gui_exit
    mcall    40,0x27          ; set up a mask for expected events

red_connect_win:
    call     draw_window
align 4
still:
    mcall    10     ; wait for event
    dec      eax
    jz       red_connect_win
    dec      eax
    jz       key
    dec      eax
    jz       button

    push    dword edit_usr
    call    [edit_box_mouse]

    push    dword edit_pass
    call    [edit_box_mouse]

    push    dword edit_server
    call    [edit_box_mouse]

    push    dword edit_port
    call    [edit_box_mouse]

    push    dword edit_path
    call    [edit_box_mouse]

    jmp     still

button:
    mcall   17

    dec     ah
    je      connect_gui_exit

    dec     ah   ; 'Connect' button clicked
    jne     still
    jmp     connect_gui_deactive

connect_gui_exit:

    mcall   -1

key:
    mcall   2

    push    dword edit_usr
    call    [edit_box_key]

    push    dword edit_pass
    call    [edit_box_key]

    push    dword edit_server
    call    [edit_box_key]

    push    dword edit_port
    call    [edit_box_key]

    push    dword edit_path
    call    [edit_box_key]

    jmp     still


align 4
draw_window:
    mcall   12, 1
    mcall   0, (320*65536+390), (300*65536+180), 0x34AABBCC, 0x805080DD, hed

    push    dword edit_usr
    call    [edit_box_draw]

    push    dword edit_pass
    call    [edit_box_draw]

    push    dword edit_server
    call    [edit_box_draw]

    push    dword edit_port
    call    [edit_box_draw]

    push    dword edit_path
    call    [edit_box_draw]

    call    draw_button
    call    draw_strings

    mcall   12, 2
    ret

draw_button:
    mcall   8, <162,65>, <120,25>, 2, 0x007887a6    ; connect button
    ret

draw_strings:   ; draw strings for boxes and buttons
    mcall   4, <3,5>, 0xb0000000, gui_str_usr
    mcall   4, <3,25>, 0xb0000000, gui_str_pass
    mcall   4, <3,45>, 0xb0000000, gui_str_server
    mcall   4, <3,65>, 0xb0000000, gui_str_port
    mcall   4, <3,85>, 0xb0000000, gui_str_path
    mcall   4, <167,125>, 0xb0ffffff, str_connect_button
    ret

connect_gui_active:
    mcall   9, buf_cmd, -1 ; store thread information
    mov     ecx, dword[buf_cmd+30] ; get pid
    mcall   18, 21,  ; get thread slot
    mov     ecx, eax
    mcall   18, 3,  ; make window active
    jmp     red_connect_win

connect_gui_deactive:
    mcall   9, buf_cmd, -1
    mov     ecx, dword[buf_cmd+30] ; get pid
    mcall   18, 21,  ; get thread slot
    mov     ecx, eax
    mcall   18, 1,  ; make window deactive
    jmp     arg_handler.connect
    

system_path     db '/sys/lib/'
library_name    db 'box_lib.obj',0

err_message_found_lib    db 'cannot load library box_lib.obj',0
str_connect_button       db 'Connect',0
gui_str_usr              db 'Username:',0
gui_str_pass             db 'Password:',0
gui_str_server           db 'Server:',0
gui_str_port             db 'Port:',0
gui_str_path             db 'Path:',0

head_f_i:
head_f_l              db 'System error',0
err_message_import    db 'Error on load import library box_lib.obj',0

myimport:

edit_box_draw    dd    aEdit_box_draw
edit_box_key     dd    aEdit_box_key
edit_box_mouse   dd    aEdit_box_mouse
version_ed       dd    aVersion_ed

    dd    0
    dd    0

aEdit_box_draw   db 'edit_box',0
aEdit_box_key    db 'edit_box_key',0
aEdit_box_mouse  db 'edit_box_mouse',0
aVersion_ed      db 'version_ed',0

edit_usr edit_box 300,75,5, 0xffffff,0x6f9480,0,0xAABBCC,0,99,param_user,mouse_dd,ed_focus
edit_pass edit_box 300,75,25,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_password,mouse_dd,ed_pass
edit_server edit_box 300,75,45,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_server_addr,mouse_dd,0
edit_port edit_box 50,75,65,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_port,mouse_dd,ed_figure_only
edit_path edit_box 300,75,85,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_path,mouse_dd,0

hed db     'FTP Client',0

mouse_dd        rd 1
;thread_info     rb 1024
library_path    rb 4096