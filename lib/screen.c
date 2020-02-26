#include <stdbool.h>
#include <kernel/types.h>
#include <kernel/string.h>
#include <kernel/asm.h>
#include <kernel/screen.h>

int get_offset(const int row, const int col)
{
    if (row >= MAX_ROWS || col >= MAX_COLS)
        return -1;
    return (row * MAX_COLS + col) * 2;
}

int get_offset_row(const int offset) {
    return  offset / (2 * MAX_COLS);
}

int get_offset_col(int offset) {
    return (offset - (get_offset_row(offset) * 2 * MAX_COLS)) / 2;
}

int carriagereturn(const int offset) {
    return get_offset_row(offset) * 2 * MAX_COLS;
}

int newline(const int offset) {
    return (get_offset_row(offset) + 1) * 2 * MAX_COLS;
}

int horizontaltab(const int offset) {
    int next_line = newline(offset);
    return offset + TABSIZE > next_line ? next_line : offset + TABSIZE;
}

int verticaltab(const int offset) {
    return offset + 2 * MAX_COLS;
}

void eraserow(const int row) {
    // int cursor = getcursor();
    for (int c = 0; c < MAX_COLS; c ++)
        print_char(' ', row, c, 0);
    // setcursor(cursor);
}

void scrollup() {
    char *dst = (char *) VGA_DMA_ADDRESS;
    char *src = (char *) VGA_DMA_ADDRESS + 2 * MAX_COLS;
    size_t length = 2 * MAX_COLS * (MAX_ROWS - 1);
    memcpy(dst, src, length);
}

int handle_scrolling(int offset) {
    int framelimit = 2 * MAX_COLS * MAX_ROWS;
    if (offset >= framelimit) {
        scrollup();
        eraserow(MAX_ROWS - 1);
        offset = get_offset(MAX_ROWS - 1, 0);
    }
    return offset;
}
void print_char(const char c, const int row, const int col, char attr)
{
    bool printable = false;
    char *memory = (char *) VGA_DMA_ADDRESS;
    if (!attr)
        attr = WHITE_ON_BLACK;

    int offset;
    if (row >= 0 && col >= 0)
        offset = get_offset(row, col);
    else
        offset = getcursor();

    switch(c) {
        case '\b':
            offset -= 2;
            offset = offset > 0 ? offset : 0;
            break;
        case '\r':
            offset = carriagereturn(offset);
            break;
        case '\n':
            offset = newline(offset);
            break;
        case '\t':
            offset = horizontaltab(offset);
            break;
        case '\v':
            offset = verticaltab(offset);
            break;
        case '\f':
            offset = verticaltab(offset);
            break;
        case '\0': return;
        default: printable=true; break;
    }
    offset = handle_scrolling(offset);
    if (printable) {
        memory[offset++] = c;
        memory[offset++] = attr;
    }
    setcursor(offset);
}


void clear_screen()
{
    for (int i = 0; i < MAX_ROWS; i++)
        for (int j = 0; j < MAX_COLS; j++)
            print_char(' ', i, j, WHITE_ON_BLACK);
    setcursor(get_offset(0, 0));
}

int getcursor()
{
    /*
     * The device uses its control register as an index
     * to select its internal registers, of which we are
     * interested in:
     * reg14: high byte cursor offset
     * reg15: low byte cursor offset
     * Once the enternal register was selected, we can read or write
     * to data register.
     */
     port_byte_out(REG_SCREEN_CTRL , 14);
     int offset = port_byte_in(REG_SCREEN_DATA) << 8;
     port_byte_out(REG_SCREEN_CTRL , 15);
     offset += port_byte_in(REG_SCREEN_DATA);
     /*
      * Since the cursor offset reported by the VGA hardware is the
      * number of characters, we multiply by two to convert it to
      * a character cell offset.
      */
     return offset * 2;
}

void setcursor(int offset)
{
    offset /= 2;
    port_byte_out(REG_SCREEN_CTRL , 14);
    port_byte_out(REG_SCREEN_DATA , (unsigned char)(offset >> 8));
    port_byte_out(REG_SCREEN_CTRL , 15);
    port_byte_out(REG_SCREEN_DATA, (unsigned char)(offset & 0xff));
}
