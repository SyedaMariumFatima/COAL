Include irvine32.inc
.data
	num1 WORD 500
	num2 WORD 200
.code
main PROC
	mov ax, num1
	mov bx, num2
	add ax, bx
	exit
main endp
end main
