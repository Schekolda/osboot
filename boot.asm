;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Загрузочный сектор ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

use16       ; 16-битная адресация, мы находимся в реальном режиме

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Самый первый сектор на диске (загрузочный сектор) читается BIOS'ом в нулевой
; сегмент памяти, по смещению 7c00h

org 7c00h   ; Дальше, по этому адресу передается управление

; Строка 'org 7c00h' нужна для того, чтобы ассемблер правильно рассчитал
; адреса для меток и переменных. Этим мы ему сообщаем, что программа будет
; загружена в память по адресу 7c00h, и смещение всех меток программы должны
; вестись с этого адреса
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_start:

; Перед установкой стека необходимо запретить все прерывания, чтобы в это время
; работу ничто не сбивало

    cli

; Так как BIOS загружает первый сектор дискеты по адресу 0:7c00, в сегментном
; регистре CS находится 0. Содержимое остальных сегментных регистров не
; определено, и мы загружаем во все нужные нам сегментные регистры то же
; значение, что находится в CS

    mov ax, cs
    mov ds, ax
    mov ss, ax

; Теперь необходимо инициализировать регистр стека SP
; (именно SP, а не ESP, т.к. мы сейчас находимся в 16-битном режиме)

    mov sp, _start

; Вершина стека представлена парой SS:SP - сегмент стека (Stack Segment) и
; указатель вершины стека (Stack Pointer). Метка _start находится в самом
; начале нашей программы, т.е. стек будет располагаться прямо под ней (0:7c00h)
; Стек растет сверху вниз.

; После установки стека мы разрешаем прерывания, устанавливая флаг IF командой
    sti
;

; Далее, очистим экран от загрузочной информации BIOS, чтоб выводить собственные
; сообщений в память видеоадаптера. Для этого воспользуемся прерыванием 10h.
; Параметры:
;   AH = 0 : очистить экран, установить поля, установить видеорежим
;   AL = 3 : текст, 80х25, 16/8 цветов

    mov ax, 0003h
    int 10h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Перед тем, как переключить процессор в защищённый режим, надо выполнить
; некоторые подготовительные действия, а именно:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; 1. Открыть адресную линию А20.
;
; В реальном режиме можно адресовать 1 МБ памяти в формате сегмент:смещение
; (20 бит на адрес). Однако, обратившись, например по адресу FFFF:FFFF, можно
; "прыгнуть" немного выше этой планки, и полученный адрес будет иметь длину 21
; бит. Дело в том, что при разработке процессора 80286, точнее, его шины адреса,
; была допущена ошибка. Она позволила программам в реальном режиме работы
; процессора адресовать память за пределами 1 МБ (так называемая верхняя
; память, High Memory Area или HMA). Поскольку многие старые программы не
; работали с этой памятью, то в чипсеты материнских плат была встроена
; специальная микросхема, блокирующая 20-й разряд шины адреса, благодаря которой
; и была возможна адресация к верхней области памяти. Именно эта микросхема и
; называется Gate A20 (Шлюз A20 или вентиль A20).
;
; В настоящее время все ОС работают в защищенном режиме, и поэтому для нужд
; адресации необходимо как можно раньше разблокировать этот бит.
;
; Для того существует два способа. Первый способ предполагает использование
; контроллера порта PS/2, другой – так называемого порта 92h.
;
; Контроллер порта PS/2 в основном используется для управления периферийными
; устройствами, такими, как клавиатура и мышь. Однако при этом он может
; управлять и микросхемой Gate A20.
;
; Однако низкое быстродействие контроллера PS/2 и сложность процесса управления
; вентилем A20 при помощи этого контролера заставили разработчиков искать другие
; возможности для управления Gate A20. Для этой цели была разработана
; специализированная микросхема, которая получила название порта 92h.
; В настоящее  метод переключения режима процессора при помощи данного порта
; считается основным.
;
;;; Включение A20:
    in al, 92h      ; получить текущее значение из порта
    or al, 2        ; установить второй бит (разблокировать)
    out 92h, al     ; ввести значение в порт
;;;;;;;;;;;;;;;;;;;;;
;
; 2. Подготовить в оперативной памяти глобальную таблицу дескрипторов GDT.
;
; В таблице должны быть созданы дескрипторы для всех сегментов, которые будут
; нужны программе сразу после того, как она переключится в защищённый режим.
;
    lgdt [gd_reg]   ; Загрузка регистра GDTR подготовленной заранее gd_reg
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Для перевода процессора 80286 из реального режима в защищённый можно
; использовать специальную команду LMSW, загружающую регистр состояния
; процессора (Mashine Status Word). Младший бит этого регистра указывает режим
; работы процессора. Значение, равное 0, соответствует реальному режиму работы,
; а значение 1 - защищённому.

    smsw ax         ; сохраняем регистр состояния процессора и загружаем в AX
    or al, 1        ; устанавливаем младший бит PE (Protection Enable)
    lmsw ax         ; загружаем регистр состояния процессора

; Еще один вариант:
; Включение защищенного режима осуществляется путем установки младшего бита
; регистра CR0:
;
;   mov eax, cr0
;   or al, 1
;   mov cr0, eax

; С помощью длинного прыжка мы загружаем селектор нужного сегмента в регистр CS
; (напрямую это сделать нельзя)
; 8 (1000b) - первый дескриптор в GDT, RPL=0
    jmp 0x8: _protected

use32
_protected:

; Загрузим регистры DS и SS селектором сегмента данных
    mov ax, 0x10
    mov ds, ax
    mov ss, ax


; Проверяем, если мы находимся в защищенном режиме, командой smsw
    smsw ax     ; сохраняем слово состояния машины и загружаем его в AX
    and ax, 1   ; AX=1 если ЦПУ в защищенном режиме, и AX=0 если в реальном
    cmp ax, 1
    je load_hello32
    mov esi, hello16
    jmp print

load_hello32:
    mov esi, hello32

print:
    call kputs

; Завесим процессор
    hlt
    jmp short $


cursor:    dd 0
%define VIDEO_RAM 0xB8000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Функция выполняет прямой вывод в память видеоадаптера которая находится в
; VGA-картах (и не только) по адресу 0xB8000
;
kputs:
    pusha
.loop:
    lodsb
    test al, al
    jz .quit

    mov ecx, [cursor]
    mov [VIDEO_RAM+ecx*2], al
    inc dword [cursor]
    jmp short .loop

.quit:
    popa
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;;;;;;;;;;;;;;;;;;;;;; Глобальная таблица дескрипторов ;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Это служебная структура данных в архитектуре x86, определяющая глобальные
; (общие для всех задач) сегменты. Её расположение в физической памяти и размер
; определяются системным регистром GDTR.
;
; Каждый дескриптор занимает в памяти по 8 байт, а значит, размер таблицы не
; может превышать 8192 дескрипторов, поскольку один дескриптор занимает 8 байт,
; а лимит в регистре GDTR — двухбайтный и хранит размер таблицы минус один
; (максимальное значение лимита — 65535), а 8192 x 8 = 65536.

gdt:

; Особенностью GDT является то, что у неё запрещён доступ к первому
; (то есть нулевому) дескриптору. Обращение к нему вызывает исключение #GP, что
; предотвращает обращение к памяти с использованием незагруженного сегментного
; регистра
;
    dw 0, 0, 0, 0   ; Нулевой дескриптор
;;;;;;;;;;;;;;;;;;;;;
;
;
; Дескриптор сегмента данных
;
;;;;;;;;;;;;;;;;;;;;;
    db 0xFF         ; Segment Limit
    db 0xFF         ; Используется для вычисления размера сегмента
;;;;;;;;;;;;;;;;;;;;;
    db 0x00         ; Base Address
    db 0x00         ; Базовый адрес сегмента в линейном адресном пространстве
    db 0x00         ;
;;;;;;;;;;;;;;;;;;;;;
                    ; 1 бит - для сегмента кода называется Read Enable, для
                    ; сегмента данных - Write Enable
    db 10011010b    ; В случае сегмента кода управляет возможностью чтения его
                    ; содержимого, в случае данных - модификации. Если флаг
                    ; установлен то можно, если нет, то нельзя
                    ;
                    ; 3 бит - Code/Data
                    ; Если флаг установлен, дескриптор описывает сегмент кода,
                    ; если сброшен - сегмент данных.
;;;;;;;;;;;;;;;;;;;;;
                    ;
    db 11001111b    ; 0-3 биты - старшие 4 бита поля Segment Limit
                    ;
                    ; 7 бит - Granularity
                    ; Используется для вычисления размера сегмента, определяет в
                    ; каких единицах он указан. Если флаг сброшен - размер
                    ; сегмента указан в байтах, если установлен - в 4096 блоках
                    ; (4096 == 1000h)
;;;;;;;;;;;;;;;;;;;;;
                    ;
    db 0x00         ; Старший байт поля Base Address
;;;;;;;;;;;;;;;;;;;;;
;
; Если Segment Limit – 0, G – 0, то размер сегмента 1 байт.
; Если Segment Limit – 0, G – 1, то размер сегмента 4096 байт.
; Если Segment Limit – FFFFFh (максимальное 20-ти битное число),
;                  G – 0, то размер сегмента 100000h байт (1 Мб).
; Если Segment Limit – FFFFFh, G – 1, то размер сегмента 100000000h байт (4 Гб).
;
; Таким образом, размер сегмента данных 4Гб,
;
; Дескриптор сегмента  данных, размер сегмента 4Гб, базовый адрес 0, Read/Write

    db 0xFF         ;
    db 0xFF         ; Базой=0 и Лимитом=4Гб
    db 0
    db 0
    db 0
    db 10010010b    ;
    db 0xCF
    db 0

; Значение, которое мы загрузим в GDTR:

gd_reg:

; Регистр содержит два поля:

; Лимит (16 бит), определяющий размер таблицы в байтах.
;
; При инициализации операционной системы глобальная дескрипторная таблица обычно
; создаётся на полное количество (8192) дескрипторов. 

    dw 8192

; Линейный адрес (32 бита), по которому должна быть расположена дескрипторная
; таблица

    dd gdt

; Виртуальный адрес начала таблицы загружается в регистр GDTR специальной
; ассемблерной инструкцией LGDT (англ. Load GDT)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

hello32:    db 'Hello from the world of 32-bit Protected Mode', 0
hello16:    db 'hello from the world of 16-bit Real Mode', 0

    times 510-($-$$) db 0
    dw 0xaa55
