/* vi: set sw=4 ts=4: */
/*
 * Utility routines.
 *
 * Copyright (C) 2024 Denys Vlasenko
 *
 * Licensed under GPLv2, see file LICENSE in this source tree.
 */
#include <sched.h>
#include "libbb.h"

unsigned long* FAST_FUNC get_malloc_cpu_affinity(int pid, unsigned *sz)
{
	unsigned long *mask = NULL;
	unsigned sz_in_bytes = *sz;

#if defined(__QNX__)
	/* no sched_getaffinity(): every processor that is online */
	{
		long n = sysconf(_SC_NPROCESSORS_ONLN);
		unsigned i;
		if (n < 1)
			n = 1;
		while (sz_in_bytes * 8 < (unsigned long)n)
			sz_in_bytes *= 2;
		mask = xzalloc(sz_in_bytes);
		for (i = 0; i < (unsigned long)n; i++)
			mask[i / (8 * sizeof(long))] |= 1ul << (i % (8 * sizeof(long)));
		*sz = sz_in_bytes;
		return mask;
	}
#else
	for (;;) {
		mask = xrealloc(mask, sz_in_bytes);
		if (sched_getaffinity(pid, sz_in_bytes, (void*)mask) == 0)
			break; /* got it */
		sz_in_bytes *= 2;
		if (errno == EINVAL && (int)sz_in_bytes > 0)
			continue;
		bb_perror_msg_and_die("can't %cet pid %d's affinity", 'g', pid);
	}
	//bb_error_msg("get mask[0]:%lx sz_in_bytes:%d", mask[0], sz_in_bytes);
	*sz = sz_in_bytes;
	return mask;
#endif
}
