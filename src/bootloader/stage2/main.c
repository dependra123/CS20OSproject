#include "stdint.h"
#include "stdio.h"

/// @brief 
/// @param bootDrive 
/// @return 
void _cdecl cstart_(uint16_t bootDrive){
    //test wether the following commands work with printf
    /*
        lenght parmas:
            hh
            h
            l
            ll
        Specifers:
            c
            s
            %
            d
            u
            X
            x
            p
            o
    */
     //test all of them

    //cobine 3 printf calls in 1
    printf("Formated string: %s %c %d\r\n", "Hello World!", 'c', -123);
    printf("Formated: %i %x %p %o %hd %hi %hhu %hhd\r\n", -5678, 0xdead, 0xbeef, 012345, (short)27, (short)-42, (unsigned char)0x12, (signed char)-0x12);
    printf("Formated: %lld\r\n", 9223372036854775807);    
    for(;;);
}
