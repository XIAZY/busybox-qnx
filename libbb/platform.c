/*
 * Replacements for common but usually nonstandard functions that aren't
 * supplied by all platforms.
 *
 * Copyright (C) 2009 by Dan Fandrich <dan@coneharvesters.com>, et. al.
 *
 * Licensed under GPLv2, see file LICENSE in this source tree.
 */
#include "libbb.h"

#ifndef HAVE_STRCHRNUL
char* FAST_FUNC strchrnul(const char *s, int c)
{
	while (*s != '\0' && *s != c)
		s++;
	return (char*)s;
}
#endif

#ifndef HAVE_USLEEP
int FAST_FUNC usleep(unsigned usec)
{
	struct timespec ts;
	ts.tv_sec = usec / 1000000u;
	ts.tv_nsec = (usec % 1000000u) * 1000u;
	/*
	 * If a signal has non-default handler, nanosleep returns early.
	 * Our version of usleep doesn't return early
	 * if interrupted by such signals:
	 */
	while (nanosleep(&ts, &ts) != 0)
		continue;
	return 0;
}
#endif

#ifndef HAVE_VASPRINTF
int FAST_FUNC vasprintf(char **string_ptr, const char *format, va_list p)
{
	int r;
	va_list p2;
	char buf[128];

	va_copy(p2, p);
	r = vsnprintf(buf, 128, format, p);
	va_end(p);

	/* Note: can't use xstrdup/xmalloc, they call vasprintf (us) on failure! */

	if (r < 128) {
		va_end(p2);
		*string_ptr = strdup(buf);
		return (*string_ptr ? r : -1);
	}

	*string_ptr = malloc(r+1);
	r = (*string_ptr ? vsnprintf(*string_ptr, r+1, format, p2) : -1);
	va_end(p2);

	return r;
}
#endif

#ifndef HAVE_DPRINTF
/* dprintf is now part of POSIX.1, but was only added in 2008 */
int dprintf(int fd, const char *format, ...)
{
	va_list p;
	int r;
	char *string_ptr;

	va_start(p, format);
	r = vasprintf(&string_ptr, format, p);
	va_end(p);
	if (r >= 0) {
		r = full_write(fd, string_ptr, r);
		free(string_ptr);
	}
	return r;
}
#endif

#ifndef HAVE_MEMRCHR
/* Copyright (C) 2005 Free Software Foundation, Inc.
 * memrchr() is a GNU function that might not be available everywhere.
 * It's basically the inverse of memchr() - search backwards in a
 * memory block for a particular character.
 */
void* FAST_FUNC memrchr(const void *s, int c, size_t n)
{
	const char *start = s, *end = s;

	end += n - 1;

	while (end >= start) {
		if (*end == (char)c)
			return (void *) end;
		end--;
	}

	return NULL;
}
#endif

#ifndef HAVE_MKDTEMP
/* This is now actually part of POSIX.1, but was only added in 2008 */
char* FAST_FUNC mkdtemp(char *template)
{
	/* NB: on error, mktemp returns an empty string, not NULL */
	if (mktemp(template)[0] == '\0' || mkdir(template, 0700) != 0)
		return NULL;
	return template;
}
#endif

#ifndef HAVE_STRCASESTR
/* Copyright (c) 1999, 2000 The ht://Dig Group */
char* FAST_FUNC strcasestr(const char *s, const char *pattern)
{
	int length = strlen(pattern);

	while (*s) {
		if (strncasecmp(s, pattern, length) == 0)
			return (char *)s;
		s++;
	}
	return 0;
}
#endif

#ifndef HAVE_STRSEP
/* Copyright (C) 2004 Free Software Foundation, Inc. */
char* FAST_FUNC strsep(char **stringp, const char *delim)
{
	char *start = *stringp;
	char *ptr;

	if (!start)
		return NULL;

	if (!*delim)
		ptr = start + strlen(start);
	else {
		ptr = strpbrk(start, delim);
		if (!ptr) {
			*stringp = NULL;
			return start;
		}
	}

	*ptr = '\0';
	*stringp = ptr + 1;

	return start;
}
#endif

#if defined(__QNX__)
size_t FAST_FUNC strnlen(const char *s, size_t n)
{
	const char *end = memchr(s, '\0', n);
	return end ? (size_t)(end - s) : n;
}

/* The time in *tm, taken as UTC, in seconds since 1970. Like mktime(),
 * fields out of their range are carried over; tm_wday and tm_yday are
 * not set. */
time_t FAST_FUNC timegm(struct tm *tm)
{
	long long year = tm->tm_year + 1900LL + tm->tm_mon / 12;
	int mon = tm->tm_mon % 12;
	long long era, days;
	unsigned yoe, doy, doe;

	if (mon < 0) {
		mon += 12;
		year--;
	}
	/* Days since 1970-01-01 of the first of that month: the year is
	 * counted from March, so that the leap day is its last. */
	year -= mon < 2;
	era = (year >= 0 ? year : year - 399) / 400;
	yoe = (unsigned)(year - era * 400);
	doy = (153 * (mon + (mon < 2 ? 10 : -2)) + 2) / 5;
	doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
	days = era * 146097 + (long long)doe - 719468 + (tm->tm_mday - 1);
	return (time_t)(((days * 24 + tm->tm_hour) * 60 + tm->tm_min) * 60 + tm->tm_sec);
}

# if !defined(__SSP__)
/* Parts of the SDK's static C library that get linked in (regcomp,
 * scandir, popen, strptime ...) were compiled with the stack protector,
 * whose two names QNX 6.5's libc.so does not have. Where BusyBox itself
 * is built without the protector, they are supplied here. */
void *__stack_chk_guard = (void *)0x9e3779b9;
void __stack_chk_fail(void);
void __stack_chk_fail(void)
{
	static const char msg[] ALIGN1 = "stack smashing detected\n";
	write(2, msg, sizeof(msg) - 1);
	abort();
}
# endif

char* FAST_FUNC strndup(const char *s, size_t n)
{
	size_t len = strnlen(s, n);
	char *p = malloc(len + 1);
	if (p) {
		memcpy(p, s, len);
		p[len] = '\0';
	}
	return p;
}
#endif

#ifndef HAVE_STPCPY
char* FAST_FUNC stpcpy(char *p, const char *to_add)
{
	while ((*p = *to_add) != '\0') {
		p++;
		to_add++;
	}
	return p;
}
#endif

#ifndef HAVE_STPNCPY
char* FAST_FUNC stpncpy(char *p, const char *to_add, size_t n)
{
	while (n != 0 && (*p = *to_add) != '\0') {
		p++;
		to_add++;
		n--;
	}
	return p;
}
#endif

#ifndef HAVE_GETLINE
ssize_t FAST_FUNC getline(char **lineptr, size_t *n, FILE *stream)
{
	int ch;
	char *line = *lineptr;
	size_t alloced = *n;
	size_t len = 0;

	do {
		ch = fgetc(stream);
		if (ch == EOF)
			break;
		if (len + 1 >= alloced) {
			alloced += alloced/4 + 64;
			line = xrealloc(line, alloced);
		}
		line[len++] = ch;
	} while (ch != '\n');

	if (len == 0)
		return -1;

	line[len] = '\0';
	*lineptr = line;
	*n = alloced;
	return len;
}
#endif

#ifndef HAVE_TTYNAME_R
int ttyname_r(int fd, char *buf, size_t buflen)
{
	int r;
	char path[sizeof("/proc/self/fd/%d") + sizeof(int)*3];

	if (!isatty(fd))
		return errno == EINVAL ? ENOTTY : errno;
	sprintf(path, "/proc/self/fd/%d", fd);
	r = readlink(path, buf, buflen);
	if (r < 0)
		return errno;
	if (r >= buflen)
		return ERANGE;
	buf[r] = '\0';
	return 0;
}
#endif
