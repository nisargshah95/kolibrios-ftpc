;;================================================================================================;;
parse_args: ;/////////////////////////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? parses command line arguments of type                                                          ;;
;? ftp://user:password@server:port/folder/subfolder type urls and attempts to connect             ;;
;? automatically                                                                                  ;;
;;------------------------------------------------------------------------------------------------;;
;> buf_cmd = pointer to command line arguments                                                    ;;
;;------------------------------------------------------------------------------------------------;;
;< use_params = 1 (resolution successful) / 0 (unsuccessful)                                      ;;
;;================================================================================================;;

        cmp     dword[buf_cmd], 'ftp:'
        jne     @f
        mov     esi, buf_cmd
        jmp     .start
  @@:
        mov     esi, buf_cmd+5

  .start:
        ; check ftp://
        cmp     dword[esi], 'ftp:'
        jne     .error
        cmp     word[esi+4], '//'
        jne     .error

        ; parse user
        lea     edi, [param_user]
  .user:
        lodsb
        cmp     al, 0
        je      .error
        stosb
        cmp     byte [esi], ':'
        jne     .user
        mov     byte [edi], 0

        ; parse password
        inc     esi
        lea     edi, [param_password]
  .pass:   
        lodsb
        cmp     al, 0
        je      .error
        stosb
        cmp     byte [esi], '@'
        jne     .pass
        mov     byte [edi], 0
  
        ; parse server address
        inc     esi
        mov     edi, param_server_addr
  .addr:
        lodsb
        cmp     al, 0
        je      .error
        stosb
        cmp     byte [esi], ':'
        jne     .addr
        mov     byte [edi], 0

        ; parse port
        inc     esi
        lea     edi, [param_port]
  .port:
        lodsb
        cmp     al, 0
        je      .error
        stosb
        cmp     byte [esi], '/'
        jne     .port
        mov     byte [edi], 0        

        ; parse path
        inc     esi
        lea     edi, [param_path]
  .path:   
        lodsb
        stosb
        cmp     byte [esi], 0
        jne     .path
        mov     byte [edi], 0

        ; parameters parsed successfully
        mov     [use_params], 1
        jmp     arg_handler.connect

  .error:
        mov     eax, str_err_params
        jmp     error
