/* Test rationale:
 *
 * Older ppc64 kernels don't properly flush dcache to icache before
 * giving a cleared page to userspace.  With some exceedingly hairy
 * code, this attempts to test for this bug.  
 *
 * This test will never trigger (obviously) on machines with coherent
 * icache and dcache (including x86 and POWER5).  On any given run,
 * even on a buggy kernel there's a chance the bug won't trigger -
 * either because we don't get the same physical page back when we
 * remap, or because the icache happens to get flushed in the interim.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include <unistd.h>
#include <signal.h>
#include <sys/mman.h>

#include <hugetlbfs.h>

#include "hugetests.h"

#define COPY_SIZE	128
#define NUM_REPETITIONS	128	/* Seems to be enough to trigger reliably */

void cacheflush(void *p)
{
#ifdef __powerpc__
	asm volatile("dcbst 0,%0; sync; icbi 0,%0; isync" : : "r"(p));
#endif
}


void jumpfunc(int copy, void *p)
{
	/* gcc bug workaround: if there is exactly one &&label
	 * construct in the function, gcc assumes the computed goto
	 * goes there, leading to the complete elision of the goto in
	 * this case */
	void *l = &&dummy;
	l = &&jumplabel;

	if (copy) {
		memcpy(p, l, COPY_SIZE);
		cacheflush(p);
	}

	goto *p;
 dummy:
	printf("unreachable?\n");

 jumplabel:
	return;
}

sigjmp_buf sig_escape;
void *sig_expected;

static void sig_handler(int signum, siginfo_t *si, void *uc)
{
	if (signum == SIGILL) {
		verbose_printf("SIGILL at %p (sig_expected=%p)\n", si->si_addr,
			       sig_expected);
		if (si->si_addr == sig_expected) {
			siglongjmp(sig_escape, 1);
		}
		FAIL("SIGILL somewhere unexpected");
	}
	if (signum == SIGBUS) {
		verbose_printf("SIGBUS at %p (sig_expected=%p)\n", si->si_addr,
			       sig_expected);
		if (sig_expected
		    && (ALIGN((unsigned long)sig_expected, gethugepagesize())
			== (unsigned long)si->si_addr)) {
			siglongjmp(sig_escape, 2);
		}
		FAIL("SIGBUS somewhere unexpected");
	}
}

void test_once(int fd)
{
	int hpage_size = gethugepagesize();
	void *p, *q;

	ftruncate(fd, 0);

	if (sigsetjmp(sig_escape, 1)) {
		sig_expected = NULL;
		return;
	}

	p = mmap(NULL, 2*hpage_size, PROT_READ|PROT_WRITE|PROT_EXEC,
		 MAP_SHARED, fd, 0);
	if (p == MAP_FAILED)
		FAIL("mmap() 1");

	ftruncate(fd, hpage_size);

	q = p + hpage_size - COPY_SIZE;

	jumpfunc(1, q);

	ftruncate(fd, 0);
	p = mmap(p, hpage_size, PROT_READ|PROT_WRITE|PROT_EXEC,
		 MAP_SHARED|MAP_FIXED, fd, 0);
	if (p == MAP_FAILED)
		FAIL("mmap() 2");

	q = p + hpage_size - COPY_SIZE;
	sig_expected = q;

	jumpfunc(0, q); /* This should SIGILL */

	FAIL("icache unclean");
}

int main(int argc, char *argv[])
{
	int fd;
	int err;
	int i;

	test_init(argc, argv);

	struct sigaction sa = {
		.sa_sigaction = sig_handler,
		.sa_flags = SA_SIGINFO,
	};

	err = sigaction(SIGILL, &sa, NULL);
	if (err)
		FAIL("Can't install SIGILL handler");

	err = sigaction(SIGBUS, &sa, NULL);
	if (err)
		FAIL("Can't install SIGBUS handler");

	fd = hugetlbfs_unlinked_fd();
	if (fd < 0)
		CONFIG();

	for (i = 0; i < NUM_REPETITIONS; i++)
		test_once(fd);

	PASS();
}
