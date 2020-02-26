#include <stdarg.h>
#include <stdbool.h>
#include <kernel/compiler.h>
#include <kernel/types.h>
#include <kernel/ctype.h>
#include <kernel/string.h>


enum errname {
    EFAULT,
};


static noinline
int skip_atoi(const char **s) {
    int i = 0;

    do {
        i = i * 10 + *(*s++) - '0';
    } while(isdigit(**s));

    return i;
}

static noinline
char to_lower(const char c) {
    return c - 'A' + 'a';
}

#define FIELD_WIDTH_MAX ((1 << 23) - 1)
#define PRECISION_MAX ((1 << 15) - 1)

#define SIGN	1		/* unsigned/signed, must be 1 */
#define LEFT	2		/* left justified */
#define PLUS	4		/* show plus */
#define SPACE	8		/* space if plus */
#define ZEROPAD	16		/* pad with zero, must be 16 == '0' - ' ' */
#define SMALL	32		/* use lowercase in hex (must be 32 == 0x20) */
#define SPECIAL	64		/* prefix hex with "0x", octal with "0" */

enum format_type {
	FORMAT_TYPE_NONE, /* Just a string part */
	FORMAT_TYPE_WIDTH,
	FORMAT_TYPE_PRECISION,
	FORMAT_TYPE_CHAR,
	FORMAT_TYPE_STR,
	FORMAT_TYPE_PTR,
	FORMAT_TYPE_PERCENT_CHAR,
	FORMAT_TYPE_INVALID,
	FORMAT_TYPE_LONG_LONG,
	FORMAT_TYPE_ULONG,
	FORMAT_TYPE_LONG,
	FORMAT_TYPE_UBYTE,
	FORMAT_TYPE_BYTE,
	FORMAT_TYPE_USHORT,
	FORMAT_TYPE_SHORT,
	FORMAT_TYPE_UINT,
	FORMAT_TYPE_INT,
	FORMAT_TYPE_SIZE_T,
	FORMAT_TYPE_PTRDIFF
};

/*
 * packed will prevent C from alligning fields as 32bit.
 * fields here are manually alligned. (see type:8 + width:24 = 32)
 */
struct printf_spec {
    unsigned int type:8;
    signed int width:24;
    unsigned int flags:8;
    unsigned int base:8;
    signed int precision:16;
} __packed;

static noinline
char *number(char *buf, char *end, unsigned long long num,
	     struct printf_spec spec)
{
    return buf;
}

static const char *check_pointer_msg(const void *ptr) {
    if (!ptr)
        return "{null}";
    // After adding memory management code,
    // add check for pointer pointing somewhere outise memory
    // paging.
    return (char*)NULL;
}
static void move_right(char *buf, char *end, unsigned len, unsigned spaces)
{
	size_t size;
	if (buf >= end)	/* nowhere to put anything */
		return;
	size = end - buf;
	if (size <= spaces) {
		memset(buf, ' ', size);
		return;
	}
	if (len) {
		if (len > size - spaces)
			len = size - spaces;
		memmove(buf + spaces, buf, len);
	}
	memset(buf, ' ', spaces);
}


/*
 * Handle field width padding for a string.
 * @buf: current buffer position
 * @n: length of string
 * @end: end of output buffer
 * @spec: for field width and flags
 * Returns: new buffer position after padding.
 */
static noinline
char *widen_string(char *buf, int n, char *end, struct printf_spec spec)
{
	unsigned spaces;

	if (n >= spec.width)
		return buf;
	/* we want to pad the sucker */
	spaces = spec.width - n;
	if (!(spec.flags & LEFT)) {
		move_right(buf - n, end, n, spaces);
		return buf + spaces;
	}
	while (spaces--) {
		if (buf < end)
			*buf = ' ';
		++buf;
	}
	return buf;
}

/* Handle string from a well known address. */
static char *string_nocheck(char *buf, char *end, const char *s,
			    struct printf_spec spec)
{
	int len = 0;
	int lim = spec.precision;

	while (lim--) {
		char c = *s++;
		if (!c)
			break;
		if (buf < end)
			*buf = c;
		++buf;
		++len;
	}
	return widen_string(buf, len, end, spec);
}


static char *error_string(char *buf, char *end, const char *s,
			  struct printf_spec spec)
{
	/*
	 * Hard limit to avoid a completely insane messages. It actually
	 * works pretty well because most error messages are in
	 * the many pointer format modifiers.
	 */
	if (spec.precision == -1)
		spec.precision = 2 * sizeof(void *);

	return string_nocheck(buf, end, s, spec);
}

static int check_pointer(char **buf, char *end, const char *ptr, struct printf_spec spec) {
    const char *err_msg;

    err_msg = check_pointer_msg(ptr);
    if (err_msg) {
        *buf = error_string(*buf, end, err_msg, spec);
        return -EFAULT;
    }

    return 0;
}

static noinline
char *string(char *buf, char *end, const char *s, struct printf_spec spec) {
    if(check_pointer(&buf, end, s, spec))
        return buf;

    return string_nocheck(buf, end, s, spec);
}

int format_decode(const char *fmt, struct printf_spec *spec) {
    const char *start = fmt;
    char qualifier;

    /*
     * We get here if we exit early on previous iteration,
     * see width calculation
     */
    if (spec->type == FORMAT_TYPE_WIDTH) {
        if (spec->width < 0) {
            spec->width = -spec->width;
            spec->flags |= LEFT;
        }
        spec->type = FORMAT_TYPE_NONE;
        goto precision;
    }

    /*
     * We get here if we exit early on previous iteration,
     * see precision calculation
     */
    if (spec->type == FORMAT_TYPE_PRECISION) {
        if (spec->precision < 0)
            spec->precision = 0;
        spec->type = FORMAT_TYPE_NONE;
        goto qualifier;
    }

    /* default */
    spec->type = FORMAT_TYPE_NONE;

    for (; *fmt; ++fmt)
        if(*fmt == '%')
            break;

    if (start != fmt || !*fmt) {
        return fmt - start;
    }

    spec->flags = 0;
    while(1) {
        bool found = true;
        ++fmt;

        switch(*fmt) {
        case '-': spec->flags |= LEFT; break;
        case '+': spec->flags |= PLUS; break;
        case ' ': spec->flags |= SPACE; break;
        case '#': spec->flags |= SPECIAL; break;
        case '0': spec->flags |= ZEROPAD; break;
        default: found = false;
        }

        if (!found)
            break;
    }

// width
    spec->width = -1;
    if (isdigit(*fmt)) {
        spec->width = skip_atoi(&fmt);
    } else if(*fmt == '*') {
        /*
         * A field width or precision may be `*' instead of a digit string.
         * In this case an argument supplies the field width or precision.
        */
        spec->type = FORMAT_TYPE_WIDTH;
        return ++fmt - start;
    }

precision:
    spec->precision = -1;
    if (*fmt == '.') {
        ++fmt;
        if (isdigit(*fmt)) {
            spec->precision = skip_atoi(&fmt);
            if(spec->precision < 0)
                spec->precision = 0;
        } else if(*fmt == '*') {
            spec->type = FORMAT_TYPE_PRECISION;
            return ++fmt - start;
        }
    }
qualifier:
    qualifier = 0;
    if (*fmt == 'h' || to_lower(*fmt) == 'l' || *fmt == 'z' || *fmt == 't') {
        qualifier = *fmt++;
        if(qualifier == *fmt) {
            if (qualifier == 'l') {
                qualifier = 'L';
                ++fmt;
            } else if (qualifier == 'h') {
                qualifier = 'H';
                ++fmt;
            }
        }
    }

    spec->base = 10;
    switch(*fmt) {
    case 'c':
        spec->type = FORMAT_TYPE_CHAR;
        return ++fmt - start;
    case 's':
        spec->type = FORMAT_TYPE_STR;
        return ++fmt - start;
    case 'p':
        spec->type = FORMAT_TYPE_PTR;
        return ++fmt - start;
    case '%':
        spec->type = FORMAT_TYPE_PERCENT_CHAR;
        return ++fmt - start;
    case 'o':
        spec->base = 8;
        break;
    case 'x':
        spec->base |= SMALL;
    case 'X':
        spec->base = 16;
        break;
    case 'd':
    case 'i':
        spec->flags |= SIGN;
    case 'u':
        break;
	case 'n':
		/*
		 * Since %n poses a greater security risk than
		 * utility, treat it as any other invalid or
		 * unsupported format specifier.
		 */
		/* Fall-through */
	default:
		//WARN_ONCE(1, "Please remove unsupported %%%c in format string\n", *fmt);
		spec->type = FORMAT_TYPE_INVALID;
		return fmt - start;
	}

    if (qualifier == 'L')
        spec->type = FORMAT_TYPE_LONG_LONG;
    else if (qualifier == 'l')
        // FORMAT_TYPE_ULONG + SIGN != FORMAT_TYPE_LONG
        spec->type = FORMAT_TYPE_ULONG + (spec->flags & SIGN);
    else if (qualifier == 'z')
        spec->type = FORMAT_TYPE_SIZE_T;
    else if (qualifier == 't')
        spec->type = FORMAT_TYPE_PTRDIFF;
    else if (qualifier == 'H')
        // FORMAT_TYPE_UBYTE + SIGN != FORMAT_TYPE_BYTE
        spec->type = FORMAT_TYPE_UBYTE + (spec->flags & SIGN);
    else if (qualifier == 'h')
        // FORMAT_TYPE_USHORT + SIGN != FORMAT_TYPE_SHORT
        spec->type = FORMAT_TYPE_USHORT + (spec->flags & SIGN);
    else
        // FORMAT_TYPE_UINT + SIGN != FORMAT_TYPE_INT
        spec->type = FORMAT_TYPE_UINT + (spec->flags & SIGN);

    return ++fmt - start;
}

void set_field_width(struct printf_spec *spec, const int width) {
    spec->width = width;
    if (spec->width != width)
        // Tried to set width higher than awailable
        spec->width = clamp(width, -FIELD_WIDTH_MAX, FIELD_WIDTH_MAX);

}

void set_field_precision(struct printf_spec *spec, const int precision) {
    spec->precision = precision;
    if (spec->precision != precision)
        spec->precision = clamp(precision, 0, PRECISION_MAX);
}

int vsnprintf(char *buf, size_t size, const char *fmt, va_list args)
{
    unsigned long long num;
    char *str, *end;
    struct printf_spec spec = {0};

    if (size > INT_MAX)
        return -1;

    str = buf;
    end = str + size;


    if (end < str) {
        end = ((char*)-1);
        size = end - str;
    }

    while(*fmt) {
        const char *old_fmt = fmt;
        int read = format_decode(fmt, &spec);

        fmt += read;

        switch(spec.type) {
        case FORMAT_TYPE_NONE: {
            int copy = read;
            if (str < end) {
                if (copy > end - str)
                    copy = end - str;
                memcpy(str, old_fmt, copy);
            }
            str += read;
            break;
        }
        case FORMAT_TYPE_WIDTH:
            set_field_width(&spec, va_arg(args, int));
            break;
        case FORMAT_TYPE_PRECISION:
            set_field_precision(&spec, va_arg(args, int));
            break;
        case FORMAT_TYPE_CHAR: {
            char c;
            if (!(spec.flags & LEFT)) {
                while (--spec.width > 0) {
                    if (str < end)
                        *str = ' ';
                    ++str;
                }
            }
            c = (char) va_arg(args, int);
            *str = c;
            ++str;
            while(--spec.width > 0) {
                if(str < end)
                    *str = ' ';
                ++str;
            }
            break;
        }
        case FORMAT_TYPE_STR:
            str = string(str, end, va_arg(args, char *), spec);
        /*
		case FORMAT_TYPE_PTR:
			str = pointer(fmt, str, end, va_arg(args, void *),
				      spec);
			while (isalnum(*fmt))
				fmt++;
			break;
        */

		case FORMAT_TYPE_PERCENT_CHAR:
			if (str < end)
				*str = '%';
			++str;
			break;

		case FORMAT_TYPE_INVALID:
			/*
			 * Presumably the arguments passed gcc's type
			 * checking, but there is no safe or sane way
			 * for us to continue parsing the format and
			 * fetching from the va_list; the remaining
			 * specifiers and arguments would be out of
			 * sync.
			 */
			goto out;

		default:
			switch (spec.type) {
			case FORMAT_TYPE_LONG_LONG:
				num = va_arg(args, long long);
				break;
			case FORMAT_TYPE_ULONG:
				num = va_arg(args, unsigned long);
				break;
			case FORMAT_TYPE_LONG:
				num = va_arg(args, long);
				break;
			case FORMAT_TYPE_SIZE_T:
				if (spec.flags & SIGN)
					num = va_arg(args, ssize_t);
				else
					num = va_arg(args, size_t);
				break;
            /*
			case FORMAT_TYPE_PTRDIFF:
				num = va_arg(args, ptrdiff_t);
				break;
            */
			case FORMAT_TYPE_UBYTE:
				num = (unsigned char) va_arg(args, int);
				break;
			case FORMAT_TYPE_BYTE:
				num = (signed char) va_arg(args, int);
				break;
			case FORMAT_TYPE_USHORT:
				num = (unsigned short) va_arg(args, int);
				break;
			case FORMAT_TYPE_SHORT:
				num = (short) va_arg(args, int);
				break;
			case FORMAT_TYPE_INT:
				num = (int) va_arg(args, int);
				break;
			default:
				num = va_arg(args, unsigned int);
			}

			str = number(str, end, num, spec);
        }

    }
out:
    if (size > 0) {
        if (str < end)
            *str = '\0';
        else
            end[-1] = '\0';
    }
    return str-buf;
}
