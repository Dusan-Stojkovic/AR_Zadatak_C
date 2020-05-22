#autor: Dušan Stojković INDEX ra140-2019
.section .data
    string1:	.ascii "Unesite tekst:\t\0"
    len1 = .-string1
    string2:	.ascii "Resenje je: \0"
    len2 = .-string2
    string3:	.ascii "Greska: Prekoracenje\n\0"
    len3 = .-string3
    string4:	.ascii "Greska: Pogresan operand\n\0"
    len4 = .-string4
    string5:	.ascii "Greska: Ima vise od 2 heks broja\n\0"
    len5 = .-string5
    string6:	.ascii "Greska: Drugi broj veci od prvog\n\0"
    len6 = .-string6
    izrazlim = 50
    izraz:       .fill izrazlim, 1, 0       #unos korisnika
    rezlim = 50 
    rezultat:    .fill rezlim, 1, 0         #ispis rezultata
.section .text
.globl main
#int unos(char* string, int strlen);        vraca duzinu stringa u %eax
.macro unos u_string, duz_max=$0
    movl $3, %eax
    movl $0, %ebx
    leal \u_string, %ecx
    movl \duz_max, %edx
    int $0x80
.endm
#void ispis(char* string, int strlen);
ispis:
    pushl %ebp
    movl %esp, %ebp
    movl $4, %eax
    movl $1, %ebx
    movl 12(%ebp), %ecx
    movl 8(%ebp), %edx
    int $0x80
    jmp kraj_func

main:                           #pocetak programa
    pushl $string1
    pushl $len1
    call ispis                  
 
    unos izraz, $izrazlim       

    pushl $izraz
    pushl %eax
    call izracunati             #glavna funkcija, sadrzi gramatiku kojom parsira unos
                                
    call konvertuj              #rezultat izracunavanja je u %eax i konvertuje se u znakovni oblik

    movl $1, %eax               #sve greske i uspesi se ovde zavrsavaju
    int $0x80

kraj_func:                      #kraj svake funkcije je uvek isti
    movl %ebp, %esp
    popl %ebp
    ret

izracunati:                     #int izracunaj(char* izraz, int izrlim);
    pushl %ebp
    movl %esp, %ebp
    movl 12(%ebp), %esi
    movl 8(%ebp), %edx
    cmpb $43, (%esi)            #izracunaj proverava ispravnost izraza (+, -)
        je predznak_plus    
    cmpb $45, (%esi)
        je predznak_minus
    # greska u predznaku
    pushl $string4
    pushl $len4
    call ispis
    movl $1, %ebx
    jmp kraj_func
    
    predznak_plus:
        pushl $1
        jmp primarni
    predznak_minus:
        pushl $-1
        jmp primarni
    
    operacija:                  #racnamo rezultat operacije na dva broja
        cmpb $2, %cl            #primeri sa 0,1 broja se ignorisu!
            jne kraj_func       
        movl -8(%ebp), %eax
        movl -12(%ebp), %edx
        imull -4(%ebp), %edx    # -4(%ebx) sadrzi operaciju! 
        addl %edx, %eax
        imull $2, %eax
        cmpl $0, %eax
            jg kraj_func
        # greska: drugi broj veci od prvog
        pushl $string5
        pushl $len5
        call ispis
        movl $6, %ebx
        jmp kraj_func

primarni:                   #odredjuje brojeve i pretvara ih u interni oblik
    movl $0, %eax           #privremena promenjiva cifri
    movw $0, %cx            #ch broji cifre : cl broji brojeve
    movl $0, %edi           #brojac karaktera
    switch:                 #rasclanjuje cifre i noise
        incl %edi
        cmpl %edx, %edi
            je operacija
        cmpb $47, (%esi, %edi, 1)
            jl preskoci
        cmpb $58, (%esi, %edi, 1)
            jl cifra_09            
        cmpb $64, (%esi, %edi, 1)
            jl preskoci
        cmpb $71, (%esi, %edi, 1)
            jl cifra_AF
        cmpb $96, (%esi, %edi, 1)
            jl preskoci
        cmpb $103, (%esi, %edi, 1)
            jl cifra_af

        preskoci:           #noise se preskace 
            cmpl $0, %eax   #kontrola %eax = 0 nije prvi noise %eax != 0 novi noise
                je switch  
            movb $0, %ch 
            incb %cl        
            cmpb $2, %cl       
                jg prekoracenje_brojeva
            shrl $4, %eax   #ne ocekuju se vise cifra za ovaj broj; ispravka
            pushl %eax
            movl $0, %eax
            jmp switch

    #svaka od ovih funkcija cifra modifikuju prvih 4 bita %eax
    cifra_09:
        addb (%esi, %edi, 1), %al
        subb $48, %al
        jmp konstruktor
    cifra_AF:
        addb (%esi, %edi, 1), %al
        subb $55, %al
        jmp konstruktor
    cifra_af:
        addb (%esi, %edi, 1), %al
        subb $87, %al
    konstruktor:            #konstruktor pravi mesta za jos cifra u %eax
        addb $4, %ch        #svaka cifra zauzima 4 bita!
        cmpb $32, %ch
            je prekoracenje_cifra
        shll $4, %eax
        jmp switch
    # greska: broj veci od 32 bit
    prekoracenje_cifra:
        pushl $string3
        pushl $len3
        call ispis
        movl $2, %ebx
        jmp kraj_func
    # greska: vise od N brojeva
    prekoracenje_brojeva:
        pushl $string5
        pushl $len5
        call ispis
        movl $3, %ebx
        jmp kraj_func

konvertuj:                      #int konvertuj(); -- odve se rezultat i stampa!
    pushl %ebp                  
    movl %esp, %ebp             
    cmpl $0, %ebx               #u slucaju greske u izracunavanju konvertuj salje izlazni kod dalje
        jne kraj_func
    leal rezultat, %esi
    movl $0, %edi
    movl $10, %ecx
    dec_cifra:                  #svaki karakter se pojedinacno salje na stack
        xorl %edx, %edx
        div %ecx
        addb $48, %dl
        pushl %edx
        incl %edi
        andl %eax, %eax
        jnz dec_cifra
    movl $0, %ecx
    popuni:                     #ovde se stack prazni u obrnutom redosledu
        cmpl %ecx, %edi
            je novi_red
        popl %edx
        movb %dl, (%esi, %ecx, 1)
        incl %ecx
        jmp popuni
    novi_red:                   #kozmeticki dodatak
        movb $10, (%esi, %edi, 1)
        incl %edi
        pushl $rezultat
        pushl %edi
        call ispis
        movl $0, %ebx
        jmp kraj_func
