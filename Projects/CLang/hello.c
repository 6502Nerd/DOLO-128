#include <stdlib.h>
#include <stdio.h>
#include <conio.h>

void delay() {
    volatile int i;
    for(i=0; i<10000; i++) {
        i++;
        --i;
    }
}

int main() {
    char input1[10], c;
    int count;

    printf("Hello world\r");
    delay();

    printf("Enter something: ");
    scanf("%s", input1);
    printf("The string was %s\r", input1);
    count=0;
    while (input1[count]!=0) {
        printf("%d ", input1[count]);
        count++;
        delay();
    }   
    printf("\r");
    do {
        c = getch();
        printf("%d ", c);
    } while (c!='\r');

    return 0xadde;
}