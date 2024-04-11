masm
model small
.stack 256
.data
	postfix dw 255 dup (0)
	len_postfix dw 0
	input db 255 dup (0)
	len_input dw 0
	res db 0,0,0,0
	len_res dw 0
	num dw 0
	cur_num_size dw 0
	num_parentheses db 0 ;+1 for opening and -1 for closing
	temp dw 0
	ret_address dw 0
	res_size equ 4 ;defines the maximum number of digits for all numbers
	powers dw 1,10,100,1000
	op_const dw 10000
;program messages
	result_mes db "= $"
	invalid_char db "Invalid symbol! Please try again.$"
	invalid_parentheses db "Invalid parentheses! Please try again.$"
	invalid_expression db "Invalid expression! Please try again.$"
	invalid_num db "Error! Number with too many digits encountered!$"
	missing_operator db "Error! Missing operator! Please try again.$"
	missing_parentheses db "Error! Missing parentheses! Please try again.$"
	division_by_0 db "Error! Division by 0 encountered!$"
	
.code
error_message macro mes
	call reset_data
	mov dx, offset mes
	mov ah,09h
	int 21h
	call new_line
	call new_line
endm

new_input proc
	xor di,di
input_loop:
	mov ah,01h
	int 21h
	
	cmp al,'d'
	je command_d
	cmp al,8 ;I'm adding this because I keep pressing it by habit and it ruins the entire thing
	je command_bs
	cmp al,'c'
	je command_c
	cmp al,'e'
	je command_e
	
	cmp al,13 ;enter
	je command_enter
	
	;write symbol in string
	mov input[di],al
	inc di
	
	jmp input_loop
	
command_d:
	call delete_symbol
	jmp input_loop
command_bs:
	call delete_symbol_bs
	jmp input_loop
command_c:
	call clear_input_line
	jmp input_loop
command_e:
	call clear_console
	ret
command_enter:
	ret
new_input endp
	
process_num proc
	cmp cur_num_size,0
	je not_num
	
	pop ret_address
	mov temp,ax
	mov cx,cur_num_size
	xor bx,bx
get_num:
	pop dx
    mov ax,powers[bx]
    mul dx
    add num,ax
    add bx,2
    loop get_num
	
	mov ax,num
	mov postfix[di],ax
	add di,2
	
	mov cur_num_size,0
	mov num,0
	mov ax,temp
	push ret_address
not_num:
	ret
process_num endp

process_operator proc
	call set_priority
	cmp dx,-1
	je op_done
	cmp dx,-2
	je op_done
	cmp ah,4 ;ignore unary '+'
	je op_done
	pop ret_address
	cmp sp,256 ;if stack is empty
	je push_operator_no_comp
	pop dx
	cmp dl,'('
	je push_operator_w_comp
	cmp ah,dh
	jg push_operator_w_comp
	jle pop_operator
push_operator_w_comp:
	push dx
push_operator_no_comp:
	push ax
	push ret_address
	ret
pop_operator:
	xor dh,dh
	add dx,op_const
	mov postfix[di],dx
	add di,2
	cmp sp,256 ;if stack is empty
	je push_operator_no_comp
	pop dx
	cmp dl,'('
	je push_operator_w_comp
	cmp ah,dh
	jg push_operator_w_comp
	jle pop_operator
op_done:
	ret
process_operator endp

set_priority proc
	cmp al,'+'
	je check_if_unary
	cmp al,'-'
	je check_if_unary
	cmp al,'*'
	je p2
	cmp al,'/'
	je p2
done:
	ret

check_if_unary:
	mov ah,1 ;priority 1 if they are binary
	cmp si,1
	je unary
	cmp input[si-2],')'
	je done
	cmp input[si-2],'('
	je unary
	cmp input[si-2],'0'
	jl has_error_missing_par
	jmp done
p2: ;'*' and '/'
	mov ah,2 ;priority 2 if there is no error
	cmp si,1
	je has_error_exp
	cmp input[si-2],')'
	je done
	cmp input[si-2],'0'
	jl has_error_exp
	jmp done
unary:
	cmp al,'-'
	je p3
	jne p4
p3: ;unary '-' - negation
	mov ah,3
	mov al,'!'
	jmp done
p4: ;unary '+'
	mov ah,4
	jmp done
has_error_exp:
	mov dx,-1
	ret
has_error_missing_par:
	mov dx,-2
	ret
set_priority endp

print_result proc
	pop ret_address
	
	mov ah,09h
	mov dx,offset result_mes
	int 21h
	
	pop bx ;res in bx
	cmp bx,0
	jl print_minus

format_res:
	mov ax,bx ;move res to ax
	xor dx,dx ;for correct division
	mov di,res_size
	
	cmp ax,2560
    jl less_than_2560 ;important for the type of division after we remove 1 digit
    
    dec di
	inc len_res
    mov bx,10
    div bx
    add dx,'0'
    mov res[di],dl
    xor dx,dx
less_than_2560:
    mov dl,10
get_res_char:
    dec di
	inc len_res
    div dl
    add ah,'0'
    mov res[di],ah
    xor ah,ah
    cmp ax,0
    jne get_res_char

	mov ah,02h
	mov cx,len_res
print_res:
	mov dl,res[di]
	int 21h
	inc di
	loop print_res
	
	mov len_res,0
	call new_line
	call new_line
	push ret_address
	ret
print_minus:
	mov ax,-1
	mul bx
	mov bx,ax
	mov ah,02h
	mov dl,'-'
	int 21h
	jmp format_res
	
print_result endp

clear_console proc
	mov ah,0
	mov al,2
	int 10h
	nop
	ret
clear_console endp

new_line proc
	mov ah,02h
	mov dl,13
	int 21h
	mov dl,10
	int 21h
	ret
new_line endp

delete_symbol_bs proc
	cmp di,0
	je ret_bs

    ;delete symbol from console view
	mov ah,02h
    mov dl,32
	int 21h
    mov dl,8
	int 21h
	
	;delete symbol from input string
	dec di
	mov input[di],0
	
ret_bs: 
    ret
delete_symbol_bs endp

delete_symbol proc
	;deletes the 'd'
	mov ah,02h
	mov dl,8
	int 21h
    mov dl,32
	int 21h
    mov dl,8
	int 21h	
	
	cmp di,0
	je ret1

    ;delete symbol from console view
	mov ah,02h
	mov dl,8
	int 21h
    mov dl,32
	int 21h
    mov dl,8
	int 21h
	
	;delete symbol from input string
	dec di
	mov input[di],0
	
ret1: 
    ret
delete_symbol endp

clear_input_line proc
	mov ah,02h
	mov dl,13
	int 21h
	mov dl,32
	int 21h
	
	cmp di,0
	je ret2
	
	mov cx,di
l1:
	dec di
	mov input[di],0
	int 21h
	loop l1
	
ret2:
	mov dl,13
	int 21h
	ret
clear_input_line endp

reset_data proc ;resets all of the variables to prepare them for another expression
	cmp di,0
	je postfix_empty
	mov cx,di
	xor di,di
empty_postfix:
	mov postfix[di],0
	add di,2
	loop empty_postfix

postfix_empty:	
	mov cx,len_input
	xor di,di
empty_input:
	mov input[di],0
	inc di
	loop empty_input
	
	mov cx,res_size
	xor di,di
empty_result:
	mov res[di],0
	inc di
	loop empty_result
	
	mov num_parentheses,0
	mov cur_num_size,0
	
	pop ret_address
empty_stack:
	cmp sp,256
	je all_empty
	pop dx
	jmp empty_stack
	
all_empty:
	xor dx,dx
	push ret_address
	ret
reset_data endp


main:
	mov ax,@data
	mov ds,ax
	
	call clear_console
	
beginning:
	call new_input
	cmp al,13 ;enter
	je end_of_expression
	jmp exit

error_char:
	error_message invalid_char
	jmp beginning
	
end_of_expression:
	mov len_input,di
	cmp di,0
	jne has_length
	jmp error_expression
has_length:
	cmp input[di-1],'0'
	jl maybe_oper
	jmp no_operator_at_end
maybe_oper:
	cmp input[di-1],')'
	jle no_operator_at_end
	jmp error_expression
no_operator_at_end:
	xor di,di
	xor si,si
	
loop_over_input:
	cmp si,len_input
	jge empty_stack_into_postfix
	
	mov al,input[si]
	inc si
	
	cmp al,'9'
	jg error_char
	cmp al,'0'
	jl not_digit
	jmp digit
not_digit:
	call process_num
	
	cmp al,'('
	jl error_char
	jne j2
	jmp open_parentheses
j2:
	cmp al,')'
	jne j1
	jmp close_parenteses
j1:
	cmp al,','
    je error_char
    cmp al,'.'
    je error_char
	
	jmp operator
	
empty_stack_into_postfix:
	cmp num_parentheses,0 ;missing closing parentheses
	je correct_parentheses
	jmp error_parentheses
correct_parentheses:
	cmp sp,256
	je is_empty
	pop dx
	cmp dl,9 ;has unprocessed number in it
	jg no_num
	jmp unprocessed_num
no_num:
	xor dh,dh
	add dx,op_const
	mov postfix[di],dx ;put operator in postfix
	add di,2
	jmp empty_stack_into_postfix
is_empty:

	cmp di,0
	jne has_length2
	jmp error_expression
has_length2:
	mov len_postfix,di
	xor di,di
	xor si,si

loop_over_postfix:
	cmp si,len_postfix
	jge postfix_is_read
	
	mov bx,postfix[si]
	add si,2
	
	cmp bx,op_const
	jl operand
	
	sub bx,op_const
	cmp bx,'!'
	je negation
	
	cmp bx,'+'
	je addition
	
	cmp bx,'-'
	je subtraction
	
	cmp bx,'*'
	je multiplication
	
	jmp division
		
postfix_is_read:
	call print_result
	call reset_data
	jmp beginning

operand:
	push bx
	jmp loop_over_postfix
	
negation:
	pop bx
	mov ax,-1
	mul bx
	push ax
	jmp loop_over_postfix

addition:
	pop ax
	pop dx
	add ax,dx
	cmp ax,9999
	jle fits_top
	jmp error_num
fits_top:
	cmp ax,-9999
	jge fits_bottom
	jmp error_num
fits_bottom:
	push ax
	jmp loop_over_postfix
	
subtraction:
	pop ax
	pop dx
	sub dx,ax
	cmp dx,9999
	jle fits_top2
	jmp error_num
fits_top2:
	cmp dx,-9999
	jge fits_bottom2
	jmp error_num
fits_bottom2:
	push dx
	jmp loop_over_postfix

multiplication:
	pop ax
	pop dx
	imul dx
	jno correct_mul
	jmp error_num
correct_mul:
	push ax
	jmp loop_over_postfix
	
division:
	pop bx ;divisor
	cmp bx,0
	jne not_zero
	jmp error_division_by_0
not_zero:
	pop ax ;dividend
	cmp ax,0
	jl negative
	jmp positive
negative:
	mov dx,0FFFFh
	jmp final_div
positive:
	xor dx,dx
	jmp final_div
final_div:
	idiv bx
	push ax
	jmp loop_over_postfix
	
unprocessed_num:
	push dx
	call process_num
	jmp empty_stack_into_postfix

digit:
	inc cur_num_size
    cmp cur_num_size,res_size
    jg error_num
	
	sub al,'0'
	xor ah,ah
	push ax
	jmp loop_over_input
	
open_parentheses:
	cmp si,1
	je move_on
	cmp input[si-2],'0'
	jl move_on
	jmp error_missing_operator
move_on:
	xor ah,ah
	push ax
	inc num_parentheses
	jmp loop_over_input
	
close_parenteses:
	dec num_parentheses
	cmp num_parentheses,0
	jl error_parentheses
	
	cmp si,len_input
	jge pop_until_par
	cmp input[si-2],'('
	je error_expression
	cmp input[si],'0'
	jl pop_until_par
	jmp error_missing_operator
	
	
pop_until_par:	
	pop dx
	cmp dl,'('
	je done_parentheses
	xor dh,dh
	add dx,op_const
	mov postfix[di],dx
	add di,2
	jmp pop_until_par
	
done_parentheses:
	jmp loop_over_input

operator:
	call process_operator
	cmp dx,-1
	je error_expression
	cmp dx,-2
	je error_missing_parentheses
	jmp loop_over_input
	
;different errors
error_num:
	error_message invalid_num
	jmp beginning
error_parentheses:
	error_message invalid_parentheses
	jmp beginning
error_expression:
	error_message invalid_expression
	jmp beginning
error_division_by_0:
	error_message division_by_0
	jmp beginning
error_missing_operator:
	error_message missing_operator
	jmp beginning
error_missing_parentheses:
	error_message missing_parentheses
	jmp beginning

exit:
	mov ax,4c00h
	int 21h
end main