Include irvine32.inc
.data
marks byte 45,78,90,32,60,49,85
pass byte ?
fail byte ?
m1 byte "Students passed: ",0
m2 byte "Students Failed: ",0
.code
main proc
mov ecx, lengthof marks
mov esi,  0
l1:
mov al,marks[esi]
cmp al, 50
jl failed
	passed: inc pass
			jmp _end

	failed: inc fail   
_end:
inc esi
loop l1
mov edx, offset m1
mov eax, 0
mov al, pass
call writeString
call writedec

call crlf

mov edx, offset m2
mov eax, 0
mov al, fail
call writeString
call writedec

main endp
end main
