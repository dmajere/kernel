#include <kernel/types.h>
#include <kernel/string.h>

char* itoa(int num, char* str, int base)
{
    int i = 0;
    int isNegative = 0;

    if (num == 0) {
        str[i++] = '0';
        str[i] = '\0';
        return str;
    }
    if (num < 0 && base == 10) {
        isNegative = 1;
        num = -num;
    }

    while (num != 0) {
        int rem = num % base;
        str[i++] = (rem > 9) ? (rem-10) + 'a': rem + '0';
        num = num / base;
    }

    if (isNegative)
        str[i++] = '-';

    str[i] = '\0';

    reverse(str, i);

    return str;
}

void reverse(char str[], const int length)
{
    char tmp;
    int start = 0;
    int end = length - 1;
    while (start++ < end--) {
        tmp = *(str+start);
        *(str+start) = *(str+end);
        *(str+end) = tmp;
    }
}

int strlen(const char *s)
{
    int i = 0;
    while (*s++)
        i++;
    return i;
}

void *memcpy(void *dest, const void *src, size_t length)
{
    char *tmp = (char*) dest;
    const char *s = (char*) src;

    while(length--)
        *tmp++ = *s++;
    return dest;
}
/**
 * memset - Fill a region of memory with the given value
 * @s: Pointer to the start of the area.
 * @c: The byte to fill the area with
 * @count: The size of the area.
 *
 * Do not use memset() to access IO space, use memset_io() instead.
 */
void *memset(void *s, int c, size_t count)
{
	char *xs = s;

	while (count--)
		*xs++ = c;
	return s;
}
/**
 * memmove - Copy one area of memory to another
 * @dest: Where to copy to
 * @src: Where to copy from
 * @count: The size of the area.
 *
 * Unlike memcpy(), memmove() copes with overlapping areas.
 */
void *memmove(void *dest, const void *src, size_t count)
{
	char *tmp;
	const char *s;

	if (dest <= src) {
		tmp = dest;
		s = src;
		while (count--)
			*tmp++ = *s++;
	} else {
		tmp = dest;
		tmp += count;
		s = src;
		s += count;
		while (count--)
			*--tmp = *--s;
	}
	return dest;
}
