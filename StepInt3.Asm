;=====================================================================================
; x64dbg plugin SDK for Masm - fearless 2015
;
; StepInt3.asm
;
;-------------------------------------------------------------------------------------
.686
.MMX
.XMM
.x64

option casemap : none
option win64 : 11
option frame : auto
option stackbase : rsp

_WIN64 EQU 1
WINVER equ 0501h

;DEBUG64 EQU 1

IFDEF DEBUG64
    PRESERVEXMMREGS equ 1
    includelib \JWasm\lib\x64\Debug64.lib
    DBG64LIB equ 1
    DEBUGEXE textequ <'\Jwasm\bin\DbgWin.exe'>
    include \JWasm\include\debug64.inc
    .DATA
    RDBG_DbgWin	DB DEBUGEXE,0
    .CODE
ENDIF

Include x64dbgpluginsdk.inc               ; Main x64dbg Plugin SDK for your program, and prototypes for the main exports 

Include StepInt3.inc                   ; plugin's include file

pluginit	        PROTO :QWORD            ; Required prototype and export for x64dbg plugin SDK
plugstop            PROTO                   ; Required prototype and export for x64dbg plugin SDK
plugsetup           PROTO :QWORD            ; Required prototype and export for x64dbg plugin SDK
;=====================================================================================


.CONST
PLUGIN_VERSION      EQU 1

.DATA
align 01
PLUGIN_NAME         DB "StepInt3",0

.DATA?
;-------------------------------------------------------------------------------------
; GLOBAL Plugin SDK variables
;-------------------------------------------------------------------------------------
align 08

PUBLIC              pluginHandle
PUBLIC              hwndDlg
PUBLIC              hMenu
PUBLIC              hMenuDisasm
PUBLIC              hMenuDump
PUBLIC              hMenuStack

pluginHandle        DD ?
hwndDlg             DQ ?
hMenu               DD ?
hMenuDisasm         DD ?
hMenuDump           DD ?
hMenuStack          DD ?
;-------------------------------------------------------------------------------------


.CODE

;=====================================================================================
; Main entry function for a DLL file  - required.
;-------------------------------------------------------------------------------------
DllMain PROC hInst:HINSTANCE, fdwReason:DWORD, lpvReserved:LPVOID
    .IF fdwReason == DLL_PROCESS_ATTACH
        mov rax, hInst
        mov hInstance, rax
    .ENDIF
    mov rax,TRUE
    ret
DllMain Endp


;=====================================================================================
; pluginit - Called by debugger when plugin.dp64 is loaded - needs to be EXPORTED
; 
; Arguments: initStruct - a pointer to a PLUG_INITSTRUCT structure
;
; Notes:     you must fill in the pluginVersion, sdkVersion and pluginName members. 
;            The pluginHandle is obtained from the same structure - it may be needed in
;            other function calls.
;
;            you can call your own setup routine from within this function to setup 
;            menus and commands, and pass the initStruct parameter to this function.
;
;-------------------------------------------------------------------------------------
pluginit PROC FRAME USES RBX initStruct:QWORD
    mov rbx, initStruct

    ; Fill in required information of initStruct, which is a pointer to a PLUG_INITSTRUCT structure
    mov eax, PLUGIN_VERSION
    mov [rbx].PLUG_INITSTRUCT.pluginVersion, eax
    mov eax, PLUG_SDKVERSION
    mov [rbx].PLUG_INITSTRUCT.sdkVersion, eax
    Invoke lstrcpy, Addr [rbx].PLUG_INITSTRUCT.pluginName, Addr PLUGIN_NAME
    
    mov rbx, initStruct
    mov eax, [rbx].PLUG_INITSTRUCT.pluginHandle
    mov pluginHandle, eax
    
    ; Do any other initialization here
    ; Construct plugin's .ini file from module filename
    Invoke GetModuleFileName, hInstance, Addr StepInt3Ini, SIZEOF StepInt3Ini
    Invoke lstrlen, Addr StepInt3Ini
    lea rbx, StepInt3Ini
    add rbx, rax
    sub rbx, 4 ; move back past 'dp32' extention
    mov byte ptr [rbx], 0 ; null so we can use lstrcat
    Invoke lstrcat, rbx, Addr szIni ; add 'ini' to end of string instead    
    
	mov rax, TRUE
	ret
pluginit endp


;=====================================================================================
; plugstop - Called by debugger when the plugin.dp64 is unloaded - needs to be EXPORTED
;
; Arguments: none
; 
; Notes:     perform cleanup operations here, clearing menus and other housekeeping
;
;-------------------------------------------------------------------------------------
plugstop PROC FRAME
    
    ; remove any menus, unregister any callbacks etc
    Invoke _plugin_menuclear, hMenu
    Invoke GuiAddLogMessage, Addr szPluginUnloaded
    
    mov rax, TRUE
    ret
plugstop endp


;=====================================================================================
; plugsetup - Called by debugger to initialize your plugins setup - needs to be EXPORTED
;
; Arguments: setupStruct - a pointer to a PLUG_SETUPSTRUCT structure
; 
; Notes:     setupStruct contains useful handles for use within x64dbg, mainly Qt 
;            menu handles (which are not supported with win32 api) and the main window
;            handle with this information you can add your own menus and menu items 
;            to an existing menu, or one of the predefined supported right click 
;            context menus: hMenuDisam, hMenuDump & hMenuStack
;            
;            plugsetup is called after pluginit. 
;-------------------------------------------------------------------------------------
plugsetup PROC FRAME USES RBX setupStruct:QWORD
    LOCAL hIconData:ICONDATA
    mov rbx, setupStruct

    ; Extract handles from setupStruct which is a pointer to a PLUG_SETUPSTRUCT structure  
    mov rax, [rbx].PLUG_SETUPSTRUCT.hwndDlg
    mov hwndDlg, rax
    mov eax, [rbx].PLUG_SETUPSTRUCT.hMenu
    mov hMenu, eax
    mov eax, [rbx].PLUG_SETUPSTRUCT.hMenuDisasm
    mov hMenuDisasm, eax
    mov eax, [rbx].PLUG_SETUPSTRUCT.hMenuDump
    mov hMenuDump, eax
    mov eax, [rbx].PLUG_SETUPSTRUCT.hMenuStack
    mov hMenuStack, eax
    
    ; Do any setup here: add menus, menu items, callback and commands etc
    Invoke GuiAddLogMessage, Addr szStepInt3Info
    Invoke _plugin_menuaddentry, hMenu, MENU_STEPINT3, Addr szStepInt3

    Invoke StepInt3LoadMenuIcon, IMG_STEPINT3, Addr hIconData
    .IF rax == TRUE
        Invoke _plugin_menuseticon, hMenu, Addr hIconData
    .ENDIF    

    Invoke StepInt3LoadMenuIcon, IMG_MENU_CHECK, Addr hImgCheck
    Invoke StepInt3LoadMenuIcon, IMG_MENU_NOCHECK, Addr hImgNoCheck
    
    Invoke IniGetStepInt3Enabled
    mov g_StepInt3Enabled, rax
    .IF rax == 1
        Invoke _plugin_menuentryseticon, pluginHandle, MENU_STEPINT3, Addr hImgCheck
        Invoke GuiAddLogMessage, Addr szLogStepInt3Enabled
    .ELSE
        Invoke _plugin_menuentryseticon, pluginHandle, MENU_STEPINT3, Addr hImgNoCheck
        Invoke GuiAddLogMessage, Addr szLogStepInt3Disabled
    .ENDIF

    mov rax, TRUE
    ret
plugsetup endp


;=====================================================================================
; CBMENUENTRY - Called by debugger when a menu item is clicked - needs to be EXPORTED
;
; Arguments: cbType
;            cbInfo - a pointer to a PLUG_CB_MENUENTRY structure. The hEntry contains 
;            the resource id of menu item identifiers
;  
; Notes:     hEntry can be used to determine if the user has clicked on your plugins
;            menu item(s) and to do something in response to it.
;            Needs to be PROC C type procedure call to be compatible with debugger
;-------------------------------------------------------------------------------------
CBMENUENTRY PROC FRAME USES RBX cbType:QWORD, cbInfo:QWORD
    mov rbx, cbInfo
    xor rax, rax
    mov eax, [rbx].PLUG_CB_MENUENTRY.hEntry
    
    .IF eax == MENU_STEPINT3
        Invoke IniGetStepInt3Enabled
        .IF rax == 1
            mov g_StepInt3Enabled, 0
            Invoke IniSetStepInt3Enabled, 0
            Invoke _plugin_menuentryseticon, pluginHandle, MENU_STEPINT3, Addr hImgNoCheck
            Invoke GuiAddLogMessage, Addr szLogStepInt3Disabled
        .ELSE
            mov g_StepInt3Enabled, 1
            Invoke IniSetStepInt3Enabled, 1
            Invoke _plugin_menuentryseticon, pluginHandle, MENU_STEPINT3, Addr hImgCheck
            Invoke GuiAddLogMessage, Addr szLogStepInt3Enabled
        .ENDIF
    .ENDIF
    
    ret

CBMENUENTRY endp


;=====================================================================================
; CBINITDEBUG - Called by debugger when a program is debugged - needs to be EXPORTED
;
; Arguments: cbType
;            cbInfo - a pointer to a PLUG_CB_INITDEBUG structure. 
;            The szFileName item contains name of file being debugged. 
;  
; Notes:     
;            
;            Needs to be PROC C type procedure call to be compatible with debugger
;-------------------------------------------------------------------------------------
CBINITDEBUG PROC FRAME USES RBX cbType:QWORD, cbInfo:QWORD
    mov rbx, cbInfo
    mov rax, [rbx]
    mov DebugFilename, rax
    mov rax, TRUE
    ret
CBINITDEBUG endp



;=====================================================================================
; CBEXCEPTION
;-------------------------------------------------------------------------------------
CBEXCEPTION PROC FRAME USES RBX cbType:QWORD, cbInfo:QWORD
    LOCAL dwException:DWORD
    LOCAL bii:BASIC_INSTRUCTION_INFO ; basic 
    
    .IF g_StepInt3Enabled == 0 ; is it disabled?
        mov rax, TRUE
        ret
    .ENDIF
    
    mov rbx, cbInfo
    mov rbx, [rbx].PLUG_CB_EXCEPTION.Exception ; rbx is pointer to EXCEPTION_DEBUG_INFO
    mov eax, dword ptr [rbx] ; exception code in eax
    mov dwException, eax

    .IF dwException == EXCEPTION_BREAKPOINT ; 80000003h
        ; Get current address and then module name from that address
        Invoke GuiSelectionGet, GUI_DISASSEMBLY, Addr sel
        _DbgFunctions ModPathFromAddr, sel.start, Addr szModuleFilename, MAX_PATH        
        
        ; check we arent in ntdll.dll
        Invoke InString, 1, Addr szModuleFilename, Addr szNtdll
        .IF rax > 0
            ; we are, so swallow exception and continue onwards
            Invoke DbgCmdExec, Addr szCon
            Invoke DbgCmdExec, Addr szRun
            Invoke GuiAddLogMessage, Addr szStepInt3NtdllSkipping
            mov rax, TRUE
            ret
        .ENDIF
        
        ; not in ntdll.dll, so check modulename = name passed on cbdebuginit, just to be sure we are ok
        Invoke szCmp, DebugFilename, Addr szModuleFilename
        .IF rax == 0
            Invoke DbgCmdExec, Addr szCon
            Invoke DbgCmdExec, Addr szRun
            Invoke szCopy, Addr szStepInt3FoundNotModule, Addr szStepInt3LogMsg
            Invoke JustFnameExt, Addr szModuleFilename, Addr szStepInt3FoundModule
            Invoke szCatStr, Addr szStepInt3LogMsg, Addr szStepInt3FoundModule
            Invoke szCatStr, Addr szStepInt3LogMsg, Addr szStepInt3IgnoreContinue
            Invoke GuiAddLogMessage, Addr szStepInt3LogMsg
            
        .ELSE
            ; disassemble the instruction at the breakpoint_exception address and copy it to a string
            Invoke DbgDisasmFastAt, sel.start, Addr bii
            lea rbx, bii.instruction
            Invoke szCopy, rbx, Addr szInstruction
            
            ; compare to see if its an int3 instruction, if so we skip it and tell user in the log
            Invoke szCmp, Addr szInstruction, Addr szInt3
            .IF rax == 0 ;  mo match
                ;PrintText 'No Match with Int3'
            .ELSE
                ;Invoke DbgCmdExec, Addr szCon
                Invoke DbgCmdExec, Addr szSkip
                Invoke GuiAddLogMessage, Addr szStepInt3FoundSkipping
            .ENDIF
        .ENDIF

    .ENDIF

    mov rax, TRUE
    ret
CBEXCEPTION endp


;=====================================================================================
; StepInt3LoadMenuIcon - Loads RT_RCDATA png resource and assigns it to ICONDATA
; Returns TRUE in eax if succesful or FALSE otherwise.
;-------------------------------------------------------------------------------------
StepInt3LoadMenuIcon PROC FRAME USES RBX dqImageResourceID:QWORD, lpIconData:QWORD
    LOCAL hRes:QWORD
    
    ; Load image for our menu item
    Invoke FindResource, hInstance, dqImageResourceID, RT_RCDATA ; load png image as raw data
    .IF rax != NULL
        mov hRes, rax
        Invoke SizeofResource, hInstance, hRes
        .IF rax != 0
            mov rbx, lpIconData
            mov [rbx].ICONDATA.size_, rax
            Invoke LoadResource, hInstance, hRes
            .IF rax != NULL
                Invoke LockResource, rax
                .IF rax != NULL
                    mov rbx, lpIconData
                    mov [rbx].ICONDATA.data, rax
                    mov rax, TRUE
                .ELSE
                    ;PrintText 'Failed to lock resource'
                    mov rax, FALSE
                .ENDIF
            .ELSE
                ;PrintText 'Failed to load resource'
                mov rax, FALSE
            .ENDIF
        .ELSE
            ;PrintText 'Failed to get resource size'
            mov rax, FALSE
        .ENDIF
    .ELSE
        ;PrintText 'Failed to find resource'
        mov rax, FALSE
    .ENDIF    
    ret

StepInt3LoadMenuIcon ENDP




;**************************************************************************
; IniGetStepInt3Enabled
;**************************************************************************
IniGetStepInt3Enabled PROC
    Invoke GetPrivateProfileInt, Addr szStepInt3, Addr szEnabled, 1, Addr StepInt3Ini
    ret
IniGetStepInt3Enabled ENDP


;**************************************************************************
; IniSetStepInt3Enabled
;**************************************************************************
IniSetStepInt3Enabled PROC dqValue:QWORD
    .IF dqValue == 1
        Invoke WritePrivateProfileString, Addr szStepInt3, Addr szEnabled, Addr szOne, Addr StepInt3Ini
    .ELSE
        Invoke WritePrivateProfileString, Addr szStepInt3, Addr szEnabled, Addr szZero, Addr StepInt3Ini
    .ENDIF
    mov rax, dqValue
    ret
IniSetStepInt3Enabled ENDP


;**************************************************************************
; Strip path name to just filename with extention
;**************************************************************************
JustFnameExt PROC FRAME USES RSI RDI FilePathName:QWORD, FileName:QWORD
	LOCAL LenFilePathName:QWORD
	LOCAL nPosition:QWORD
	
	Invoke lstrlen, FilePathName
	mov LenFilePathName, rax
	mov nPosition, rax
	
	.IF LenFilePathName == 0
	    mov rdi, FileName
		mov byte ptr [rdi], 0
		mov rax, FALSE
		ret
	.ENDIF
	
	mov rsi, FilePathName
	add rsi, rax
	
	mov rax, nPosition
	.WHILE rax != 0
		movzx rax, byte ptr [rsi]
		.IF al == '\' || al == ':' || al == '/'
			inc rsi
			.BREAK
		.ENDIF
		dec rsi
		dec nPosition
		mov rax, nPosition
	.ENDW
	mov rdi, FileName
	mov rax, nPosition
	.WHILE rax != LenFilePathName
		movzx rax, byte ptr [rsi]
		mov byte ptr [rdi], al
		inc rdi
		inc rsi
		inc nPosition
		mov rax, nPosition
	.ENDW
	mov byte ptr [rdi], 0h ; null out filename
	mov rax, TRUE
	ret

JustFnameExt	ENDP



END DllMain
















