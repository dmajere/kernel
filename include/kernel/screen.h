#define VGA_DMA_ADDRESS 0xb8000

#define MAX_COLS 80
#define MAX_ROWS 25

#define WHITE_ON_BLACK 0x0f

// Screen device I/O ports
#define REG_SCREEN_CTRL 0x3D4
#define REG_SCREEN_DATA 0x3D5

#define TABSIZE 4

void print_char(const char c, const int row, const int col, char attr);
void clear_screen();
int getcursor();
void setcursor(int offset);
int get_offset(const int row, const int col);
