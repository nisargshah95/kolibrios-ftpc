;;================================================================================================;;
login_gui: ;//////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Login GUI-specific functions                                                                   ;;
;;------------------------------------------------------------------------------------------------;;
;> none                                                                                           ;;
;;------------------------------------------------------------------------------------------------;;
;< none                                                                                           ;;
;;================================================================================================;;

    ; TODO: print error strings (wrong user, pass, etc.)

  .server_addr:
        mov     [initial_login], 1
  .get_username:
  .win_active:
        jmp     .redraw

  .win_deactive:
        call    gui.main
        call    gui.draw
        jmp     arg_handler.connect

  .redraw:
        call    .draw
        jmp     .still

  align 4
  .draw:
        mcall   12, 1
        mcall   67, 320, 300, 390, 180
        mcall   0, <320,390>, <300,180>, 0x34AABBCC, 0x805080DD, hed

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

        ; draw "connect" button
        mcall   8, <162,65>, <120,25>, 2, 0x007887a6

        ; draw strings
        mcall   4, <3,5>, 0xb0000000, gui_str_usr
        mcall   4, <3,25>, 0xb0000000, gui_str_pass
        mcall   4, <3,45>, 0xb0000000, gui_str_server
        mcall   4, <3,65>, 0xb0000000, gui_str_port
        mcall   4, <3,85>, 0xb0000000, gui_str_path
        mcall   4, <167,125>, 0xb0ffffff, gui_str_connect

        mcall   12, 2
        ret

  align 4
  .still:
        mcall    10     ; wait for event
        dec      eax
        jz       .redraw
        dec      eax
        jz       .key
        dec      eax
        jz       .button

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

        jmp     .still

  .button:
        mcall   17

        dec     ah
        jz      .exit

        dec     ah   ; 'Connect' button clicked
        jz      .win_deactive

        jmp     .still

  .key:
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

        jmp     .still
    
  .exit:
        jmp     gui.exit


gui_str_connect db 'Connect',0
gui_str_usr     db 'Username:',0
gui_str_pass    db 'Password:',0
gui_str_server  db 'Server:',0
gui_str_port    db 'Port:',0
gui_str_path    db 'Path:',0

; login window components
edit_usr edit_box 300,75,5, 0xffffff,0x6f9480,0,0xAABBCC,0,99,param_user,mouse_dd,ed_focus
edit_pass edit_box 300,75,25,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_password,mouse_dd,ed_pass
edit_server edit_box 300,75,45,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_server_addr,mouse_dd,0
edit_port edit_box 50,75,65,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_port,mouse_dd,ed_figure_only
edit_path edit_box 300,75,85,0xffffff,0x6a9480,0,0xAABBCC,0,99,param_path,mouse_dd,0

mouse_dd rd 1