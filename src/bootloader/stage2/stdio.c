#include "stdio.h"
#include "x86.h"


void putc(char c){
    x86_VideoWriteChartTeletype(c ,0);
}

void puts(const char* str){
    while(*str){
        putc(*str);
        str++;
    }
}

#define printfStateNormal       0
#define printfStateLenght       1
#define printfStateShort        2
#define printfStateLong         3
#define printfStateSpec         4

#define printfLenghtDefault     0 
#define printfLenghtShortShort  1
#define printfLenghtShort       2
#define printfLenghtLong        3
#define printfLenghtLongLong    4

int* printfNum(int* argp, int lenght, bool sign, int radix);

void _cdecl printf(const char* fmt, ...){
    
    int* argp = (int*)&fmt;
    int state = printfStateNormal;
    int lenght = printfLenghtDefault;
    int radix = 10;
    bool sign = false;

    argp++;
    while(*fmt){
        switch (state)
        {
            case printfStateNormal:
                switch (*fmt)
                {
                    case '%':       state = printfStateLenght;
                                    break;
                    default:        putc(*fmt);
                                    break;
                }
                break;
            
            case printfStateLenght:
                switch (*fmt)
                {
                    case 'h':  lenght = printfLenghtShort;
                                state = printfStateShort;
                                break;
                    case 'l':  lenght = printfLenghtLong;
                                state = printfStateLong;
                                break;
                    
                    default:    goto printfStateSpec_;
                }
                break;
            case printfStateShort:
                if(*fmt == 'h')
                {
                    lenght = printfLenghtShortShort;
                    state = printfStateSpec;
                }
                else goto printfStateSpec_;
                break;
            case printfStateLong:
                if(*fmt == 'l')
                {
                    lenght = printfLenghtLongLong;
                    state = printfStateSpec;
                }
                else goto printfStateSpec_;
                break;
            case printfStateSpec:
                printfStateSpec_:
                switch (*fmt)
                {
                    case 'c':   putc((char)*argp);
                                argp++;
                                break;

                    case 's':   puts(*(char**) argp);
                                argp++;
                                break;

                    case '%':   putc('%');
                                break;

                    case 'd':
                    case 'i':   radix = 10; sign = true;
                                argp = printfNum(argp, lenght, sign, radix);
                                break;
                    case 'u':   radix = 10; sign = false;
                                argp = printfNum(argp, lenght, sign, radix);
                                break;
                    case 'X':
                    case 'x':
                    case 'p':   radix = 16; sign = false;
                                argp = printfNum(argp, lenght, sign, radix);
                                break;
                    case 'o':   radix = 8; sign = false;
                                argp = printfNum(argp, lenght, sign, radix);
                                break;
                    
                    default:    break;
                }
                state   = printfStateNormal;
                lenght  = printfLenghtDefault;
                radix   = 10;    
                sign    = false;
                break;
        
        }
        fmt++;
    }
}

const char hex[] = "0123456789abcdef";

int* printfNum(int* argp, int lenght, bool sign, int radix){
    char buffer[32];
    unsigned long long num;
    int numSign = 1;
    int pos = 0;

    switch (lenght)
    {
        case printfLenghtShortShort:
        case printfLenghtShort:
        case printfLenghtDefault:
            if(sign){
                int n = *argp;
                if(n<0){
                    numSign = -1;
                    n = -n;
                }
                num = (unsigned long long)n;                
            }
            else{
                num = *(unsigned int*)argp;
            }
            argp++;
            break;
        case printfLenghtLong:
            if(sign){
                long int n = *(long int*) *argp;
                if(n<0){
                    numSign = -1;
                    n = -n;
                }
                num = (unsigned long long)n;
                
            }
            else{
                num = *(unsigned long int*)argp;
            }
            argp+=2;
            break;
        case printfLenghtLongLong:
            if(sign){
                    long long int n = *(long long int*)argp;
                    if(n<0){
                        numSign = -1;
                        n = -n;
                    }
                    num = (unsigned long long)n;
                    
                }
                else{
                  num = *(unsigned long long*)argp;
                }
                argp+=4;
                break;
        
        
    }
    //convert to ascii
    do{
        uint32_t rem;
        
        x86_div64_32(num, radix, &num, &rem);
        buffer[pos++] = hex[rem];

    }while(num>0);

    if(sign && numSign <0){
        buffer[pos++] = '-';
    }
    while(--pos >= 0){
        putc(buffer[pos]);
    }
    return argp;


}
