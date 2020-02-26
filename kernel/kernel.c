#include <kernel/screen.h>
#include <kernel/stdio.h>
#include <kernel/string.h>

void erase(const int row) {
    int cursor = getcursor();
    for (int c = 0; c < MAX_COLS; c ++)
        print_char(' ', row, c, 0);
    setcursor(cursor);
}

void scroll() {
    char *dst = (char *) VGA_DMA_ADDRESS;
    char *src = (char *) VGA_DMA_ADDRESS + 2 * MAX_COLS;
    size_t length = 2 * MAX_COLS * (MAX_ROWS - 1);
    memcpy(dst, src, length);
}

void main() {
    clear_screen();
    setcursor(0);

    for (int i = 0; i < 2 * MAX_ROWS; i++) {
        kprintf("Line: %c\n", i + '0');
    }
}
