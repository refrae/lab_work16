section .data
    msg_start db "Текущий адрес границы кучи: 0x", 0
    msg_len equ $ - msg_start

    msg_success db 10, "Память успешно выделена. Записываем данные..", 10
    msg_success_len equ $ - msg_success

    msg_done db 10, "Память успешно возвращена ядру Linux.", 10, 0
    msg_done_len equ $ - msg_done

    test_str db "Привет от студентов колледжа! Память работает.", 10
    test_str_len equ $ - test_str

section .bss
    initial_brk resq 1    ; Переменная для хранения исходной границы кучи
    new_brk     resq 1    ; Переменная для хранения новой границы кучи
    buffer      resb 16   ; Буфер для перевода адреса в шестнадцатеричный формат

section .text
    global _start

_start:
    ; --- 1. Узнаем текущую границу кучи (sys_brk со значением 0) ---
    mov rax, 12           ; Номер системного вызова sys_brk для x86_64
    mov rdi, 0            ; Передаем 0, чтобы получить текущий адрес
    syscall
    mov [initial_brk], rax ; Сохраняем полученный адрес

    ; Выведем текст "Текущий адрес границы кучи..."
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, msg_start
    mov rdx, msg_len
    syscall

    ; Переводим адрес из rax в строку для вывода на экран
    mov rax, [initial_brk]
    call print_hex

    ; --- 2. Увеличиваем кучу на 4096 байт (1 страница) ---
    mov rax, 12           ; sys_brk
    mov rdi, [initial_brk]
    add rdi, 4096         ; Сдвигаем границу вверх на 4 КБ
    syscall
    mov [new_brk], rax    ; В rax возвращается новый адрес program break

    ; Проверяем, изменился ли адрес
    cmp rax, [initial_brk]
    je .exit_error        ; Если адрес остался прежним - ядро отказало

    ; Выводим сообщение об успешном выделении
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, msg_success
    mov rdx, msg_success_len
    syscall

    ; --- 3. Работаем с выделенной виртуальной памятью ---
    ; Исходный адрес initial_brk теперь является началом нашей доступной зоны
    mov rsi, test_str     ; Источник: наша строка
    mov rdi, [initial_brk] ; Приемник: выделенная память кучи
    mov rcx, test_str_len ; Сколько байт копировать
    cld
    rep movsb             ; Копируем строку в кучу

    ; Выводим строку НАПРЯМУЮ из кучи на экран
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, [initial_brk] ; Указываем на адрес в куче
    mov rdx, test_str_len
    syscall

    ; ОПАСНЫЙ СТУДЕНЧЕСКИЙ ЭКСПЕРИМЕНТ:
    ; Если попробовать записать данные по адресу [new_brk] + 10,
    ; операционная система Linux мгновенно прибьет программу с ошибкой Segmentation Fault,
    ; так как этот адрес лежит за пределами разрешенной зоны VMA кучи.

    ; --- 4. Возвращаем память ядру (сдвигаем brk назад) ---
    mov rax, 12           ; sys_brk
    mov rdi, [initial_brk] ; Возвращаем границу в исходное состояние
    syscall

    ; Выводим сообщение о завершении
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, msg_done
    mov rdx, msg_done_len
    syscall

    ; --- 5. Корректное завершение программы (sys_exit) ---
    mov rax, 60           ; sys_exit
    mov rdi, 0            ; Код возврата 0
    syscall

.exit_error:
    mov rax, 60           ; sys_exit в случае ошибки
    mov rdi, 1            ; Код возврата 1
    syscall

; --- Вспомогательная функция перевода числа в HEX и его вывода ---
print_hex:
    mov rcx, 16           ; Будем обрабатывать 16 полубайт (64-битный адрес)
    mov rbx, buffer
.loop:
    rol rax, 4            ; Сдвигаем влево на 4 бита
    mov dl, al
    and dl, 0x0F          ; Выделяем младшие 4 бита
    add dl, '0'
    cmp dl, '9'
    jbe .store
    add dl, 7             ; Если буква (A-F)
.store:
    mov [rbx], dl
    inc rbx
    loop .loop

    ; Выводим полученную строку на экран
    mov rax, 1            ; sys_write
    mov rdi, 1            ; stdout
    mov rsi, buffer
    mov rdx, 16
    syscall
    ret
    
