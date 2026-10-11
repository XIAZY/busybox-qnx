/* vi: set sw=4 ts=4: */
/*
 * getopt() and getopt_long() for QNX.
 *
 * QNX 6.5's C library has no getopt_long(), and its getopt() knows neither
 * the "+" and "-" at the start of the option string nor options after the
 * other arguments, all of which BusyBox counts on. These are the two
 * functions of musl libc (src/misc/getopt.c, src/misc/getopt_long.c),
 * for single-byte option characters, with BusyBox's messages.
 *
 * Copyright (C) 2005-2020 Rich Felker, et al.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
#include "libbb.h"

#if defined(__QNX__)

#include <getopt.h>

/* optarg, optind, opterr and optopt are the C library's own. Where the
 * next option character is, inside argv[optind]: */
static int optpos;

static void getopt_msg(const char *msg, const char *opt, int len)
{
	bb_error_msg("%s: %.*s", msg, len, opt);
}

int FAST_FUNC bb_getopt(int argc, char *const argv[], const char *optstring)
{
	int i;
	char c, d;
	char *optchar;

	if (!optind) {
		optpos = 0;
		optind = 1;
	}

	if (optind >= argc || !argv[optind])
		return -1;

	if (argv[optind][0] != '-') {
		if (optstring[0] == '-') {
			optarg = argv[optind++];
			return 1;
		}
		return -1;
	}

	if (!argv[optind][1])
		return -1;

	if (argv[optind][1] == '-' && !argv[optind][2])
		return optind++, -1;

	if (!optpos)
		optpos++;
	optchar = argv[optind] + optpos;
	c = *optchar;
	optpos++;

	if (!argv[optind][optpos]) {
		optind++;
		optpos = 0;
	}

	if (optstring[0] == '-' || optstring[0] == '+')
		optstring++;

	i = 0;
	do {
		d = optstring[i];
		if (d)
			i++;
	} while (d && d != c);

	if (d != c || c == ':') {
		optopt = (unsigned char)c;
		if (optstring[0] != ':' && opterr)
			getopt_msg("unrecognized option", optchar, 1);
		return '?';
	}
	if (optstring[i] == ':') {
		optarg = NULL;
		if (optstring[i+1] != ':' || optpos) {
			optarg = argv[optind++];
			if (optpos)
				optarg += optpos;
			optpos = 0;
		}
		if (optind > argc) {
			optopt = (unsigned char)c;
			if (optstring[0] == ':')
				return ':';
			if (opterr)
				getopt_msg("option requires an argument", optchar, 1);
			return '?';
		}
	}
	return (unsigned char)c;
}

static void permute(char *const *argv, int dest, int src)
{
	char **av = (char **)argv;
	char *tmp = av[src];
	int i;
	for (i = src; i > dest; i--)
		av[i] = av[i-1];
	av[dest] = tmp;
}

static int getopt_long_core(int argc, char *const *argv, const char *optstring,
		const struct option *longopts, int *idx)
{
	optarg = NULL;
	if (longopts && argv[optind][0] == '-'
	 && argv[optind][1] == '-' && argv[optind][2]
	) {
		int colon = optstring[optstring[0] == '+' || optstring[0] == '-'] == ':';
		int i, cnt, match = 0;
		char *arg = NULL, *opt, *start = argv[optind] + 1;

		for (cnt = i = 0; longopts[i].name; i++) {
			const char *name = longopts[i].name;
			opt = start;
			if (*opt == '-')
				opt++;
			while (*opt && *opt != '=' && *opt == *name)
				name++, opt++;
			if (*opt && *opt != '=')
				continue;
			arg = opt;
			match = i;
			if (!*name) {
				cnt = 1;
				break;
			}
			cnt++;
		}
		if (cnt == 1) {
			i = match;
			opt = arg;
			optind++;
			if (*opt == '=') {
				if (!longopts[i].has_arg) {
					optopt = longopts[i].val;
					if (colon || !opterr)
						return '?';
					getopt_msg("option does not take an argument",
						longopts[i].name, strlen(longopts[i].name));
					return '?';
				}
				optarg = opt + 1;
			} else if (longopts[i].has_arg == required_argument) {
				optarg = argv[optind];
				if (!optarg) {
					optopt = longopts[i].val;
					if (colon)
						return ':';
					if (!opterr)
						return '?';
					getopt_msg("option requires an argument",
						longopts[i].name, strlen(longopts[i].name));
					return '?';
				}
				optind++;
			}
			if (idx)
				*idx = i;
			if (longopts[i].flag) {
				*longopts[i].flag = longopts[i].val;
				return 0;
			}
			return longopts[i].val;
		}
		optopt = 0;
		if (!colon && opterr)
			getopt_msg(cnt ? "option is ambiguous" : "unrecognized option",
				argv[optind] + 2, strlen(argv[optind] + 2));
		optind++;
		return '?';
	}
	return bb_getopt(argc, argv, optstring);
}

int FAST_FUNC bb_getopt_long(int argc, char *const *argv, const char *optstring,
		const struct option *longopts, int *idx)
{
	int ret, skipped, resumed;

	if (!optind) {
		optpos = 0;
		optind = 1;
	}
	if (optind >= argc || !argv[optind])
		return -1;
	skipped = optind;
	if (optstring[0] != '+' && optstring[0] != '-') {
		int i;
		for (i = optind; ; i++) {
			if (i >= argc || !argv[i])
				return -1;
			if (argv[i][0] == '-' && argv[i][1])
				break;
		}
		optind = i;
	}
	resumed = optind;
	ret = getopt_long_core(argc, argv, optstring, longopts, idx);
	if (resumed > skipped) {
		int i, cnt = optind - resumed;
		for (i = 0; i < cnt; i++)
			permute(argv, skipped, optind - 1);
		optind = skipped + cnt;
	}
	return ret;
}

#endif /* __QNX__ */
