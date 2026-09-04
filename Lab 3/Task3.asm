Include irvine32.inc
.data
.code
main PROC
	mov ebx, 90
	call WriteInt
	mov ebx, 5Ah
	call WriteInt
	mov ebx, 01011010b
	call WriteInt
	mov ebx, 'B'
	call WriteInt
	exit
main endp
end main
