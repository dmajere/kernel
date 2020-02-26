#include <kernel/screen.h>
#include <kernel/stdio.h>

void main() {
    //FRAMEBUFFER_POS = 0;
    // *video_memory = 'X';

    clear_screen();
    print_char('X', 0, 0, WHITE_ON_BLACK);
    print_char('X', 0, 79, WHITE_ON_BLACK);
    print_char('X', 24, 0, WHITE_ON_BLACK);
    print_char('X', 24, 79, WHITE_ON_BLACK);

    setcursor(0);

    // // Tests
    kprintf("No special chars line ");
    kprintf("And another one");
    kprintf("\n");
    kprintf("Testing carriage return");
    kprintf("\rWorking\n");
    kprintf("Horizontal\ttab\n");
    kprintf("Vertical\vtab\n");
    kprintf("From\ffeed\n");
    kprintf("Backspace \bline\n");
    kprintf("\bBackspace in front\n");
    kprintf("Zero\0line");
    kprintf("\n");
    kprintf("single: \', double: \", backslash \\, question: \?, alert: \a\n");

    char c = 'B';
    kprintf("print char %c\n", c);
    int digit = 10;
    kprintf("print digit %d\n", digit);
}
