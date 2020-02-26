#include <kernel/types.h>

int strlen(const char *s);
void reverse(char str[], const int length);
char* itoa(int num, char* str, int base);

void *memset(void *s, int c, size_t count);
void *memmove(void *dest, const void *src, size_t count);
void *memcpy(void *dest, const void *src, size_t length);
