include irvine32.inc
.data
space dword 10
s2 dword 6
inner dword 7
outer dword ?
arr dword 1, 2, 3, 4, 5
.code
Main PROC

mov ecx, 4
l1:
mov outer, ecx

mov ecx, space
l5:
mov al, ' '
call writechar
loop l5

mov ecx, 3

l2:
mov eax, 8
call writedec
mov al,' '
call writechar
loop l2

call crlf

mov ecx,  outer
loop l1

mov ecx, 4
l3:
mov outer, ecx

mov ecx, s2
mov al, ' '
l6:
call writechar
loop l6
mov eax, s2
add eax, 2
mov s2, eax

mov ecx,  inner
l4:
mov eax, 9
call writedec
mov al,' '
call writechar
loop l4

call crlf
mov ecx, outer

mov eax,  inner
sub eax, 2
mov inner, eax

loop l3

exit
main endp
end main



