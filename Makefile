PREFIX = /usr/local

BASEOBJS = hugeutils.o version.o
LIBOBJS = $(BASEOBJS) elflink.o morecore.o debug.o syscall.o
INSTALL_OBJ_LIBS = libhugetlbfs.so libhugetlbfs.a
LDSCRIPT_TYPES = B BDT
LDSCRIPT_DIST_ELF = elf32ppclinux elf64ppc elf_i386 elf_x86_64
INSTALL_OBJSCRIPT = ld.hugetlbfs
VERSION=version.h
SOURCE = $(shell find . -maxdepth 1 ! -name version.h -a -name '*.[h]')
SOURCE += *.c *.lds Makefile
NODEPTARGETS=<version.h> <clean>

INSTALL = install

LDFLAGS = --no-undefined-version -Wl,--version-script=version.lds
CFLAGS = -O2 -Wall -fPIC -g
CPPFLAGS = -D__LIBHUGETLBFS__

ARCH = $(shell uname -m | sed -e s/i.86/i386/)

ifeq ($(ARCH),ppc64)
CC64 = gcc -m64
ELF64 = elf64ppc
LIB64 = lib64
LIB32 = lib
ifneq ($(BUILDTYPE),NATIVEONLY)
CC32 = gcc
ELF32 = elf32ppclinux
endif
else
ifeq ($(ARCH),ppc)
CC32 = gcc
ELF32 = elf32ppclinux
LIB32 = lib
else
ifeq ($(ARCH),i386)
CC32 = gcc
ELF32 = elf_i386
LIB32 = lib
else
ifeq ($(ARCH),x86_64)
CC64 = gcc -m64
ELF64 = elf_x86_64
LIB64 = lib64
LIB32 = lib
ifneq ($(BUILDTYPE),NATIVEONLY)
CC32 = gcc -m32
ELF32 = elf_i386
endif
endif
endif
endif
endif

ifdef CC32
OBJDIRS += obj32
endif
ifdef CC64
OBJDIRS +=  obj64
endif

LIBDIR32 = $(PREFIX)/$(LIB32)
LIBDIR64 = $(PREFIX)/$(LIB64)
LDSCRIPTDIR = $(PREFIX)/share/libhugetlbfs/ldscripts
BINDIR = $(PREFIX)/share/libhugetlbfs
SBINDIR = $(PREFIX)/sbin
DOCDIR = $(PREFIX)/share/doc/libhugetlbfs

EXTRA_DIST = \
	README \
	HOWTO \
	LGPL-2.1

INSTALL_LDSCRIPTS = $(foreach type,$(LDSCRIPT_TYPES),$(LDSCRIPT_DIST_ELF:%=%.x$(type)))

ifdef V
VECHO = :
else
VECHO = echo "	"
.SILENT:
endif

DEPFILES = $(LIBOBJS:%.o=%.d)

all:	libs tests

.PHONY:	tests libs

libs:	$(foreach file,$(INSTALL_OBJ_LIBS),$(OBJDIRS:%=%/$(file)))

tests:	libs # Force make to build the library first
tests:	tests/all

tests/%:
	$(MAKE) -C tests OBJDIRS="$(OBJDIRS)" CC32="$(CC32)" CC64="$(CC64)" ELF32="$(ELF32)" ELF64="$(ELF64)" $*

check:	all
	cd tests; ./run_tests.sh

checkv:	all
	cd tests; ./run_tests.sh -vV

func:	all
	cd tests; ./run_tests.sh -t func

funcv:	all
	cd tests; ./run_tests.sh -t func -vV

stress:	all
	cd tests; ./run_tests.sh -t stress

stressv: all
	cd tests; ./run_tests.sh -t stress -vV

# Don't want to remake objects just 'cos the directory timestamp changes
$(OBJDIRS): %:
	@mkdir -p $@

# <Version handling>
$(VERSION): always
	@$(VECHO) VERSION
	./localversion version $(SOURCE)
always:
# </Version handling>

snapshot: $(VERSION)

.SECONDARY:

# This trick forces a static copy of libc's syscall() function into
# the library.  This is particularly useful for reporting errors from
# elflink.c while our PLT is unmapped

obj32/syscall.o:
	$(CC32) -o $@ -Wl,-r -Wl,--undefined=syscall -nostdlib -lc

obj64/syscall.o:
	$(CC64) -o $@ -Wl,-r -Wl,--undefined=syscall -nostdlib -lc

obj32/%.o: %.c
	@$(VECHO) CC32 $@
	@mkdir -p obj32
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

obj64/%.o: %.c
	@$(VECHO) CC64 $@
	@mkdir -p obj64
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -c $<

%/libhugetlbfs.a: $(foreach OBJ,$(LIBOBJS),%/$(OBJ))
	@$(VECHO) AR $@
	$(AR) $(ARFLAGS) $@ $^

obj32/libhugetlbfs.so: $(LIBOBJS:%=obj32/%)
	@$(VECHO) LD32 "(shared)" $@
	$(CC32) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

obj64/libhugetlbfs.so: $(LIBOBJS:%=obj64/%)
	@$(VECHO) LD64 "(shared)" $@
	$(CC64) $(LDFLAGS) -shared -o $@ $^ $(LDLIBS)

obj32/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC32) $(CPPFLAGS) -E $< > $@

obj64/%.i:	%.c
	@$(VECHO) CPP $@
	$(CC64) $(CPPFLAGS) -E $< > $@

obj32/%.s:	%.c
	@$(VECHO) CC32 -S $@
	$(CC32) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

obj64/%.s:	%.c
	@$(VECHO) CC64 -S $@
	$(CC64) $(CPPFLAGS) $(CFLAGS) -o $@ -S $<

clean:
	@$(VECHO) CLEAN
	rm -f *~ *.o *.so *.a *.d *.i core a.out $(VERSION)
	rm -rf obj*
	rm -f ldscripts/*~
	rm -f libhugetlbfs-sock
	$(MAKE) -C tests clean

%.d: %.c $(VERSION)
	@$(CC) $(CPPFLAGS) -MM -MT "$(foreach DIR,$(OBJDIRS),$(DIR)/$*.o) $@" $< > $@

# Workaround: Don't build dependencies for certain targets
#    When the include below is executed, make will use the %.d target above to
# generate missing files.  For certain targets (clean, version.h, etc) we don't
# need or want these dependency files, so don't include them in this case.
ifeq (,$(findstring <$(MAKECMDGOALS)>,$(NODEPTARGETS)))
-include $(DEPFILES)
endif

obj32/install:
	@$(VECHO) INSTALL32 $(LIBDIR32)
	$(INSTALL) -d $(DESTDIR)$(LIBDIR32)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj32/%) $(DESTDIR)$(LIBDIR32)
	$(INSTALL) -d $(DESTDIR)$(SBINDIR)
	for x in $(SBINOBJS); do $(INSTALL) obj32/$$x $(DESTDIR)$(SBINDIR)/$$x; done

obj64/install:
	@$(VECHO) INSTALL64 $(LIBDIR64)
	$(INSTALL) -d $(DESTDIR)$(LIBDIR64)
	$(INSTALL) $(INSTALL_OBJ_LIBS:%=obj64/%) $(DESTDIR)$(LIBDIR64)
	$(INSTALL) -d $(DESTDIR)$(SBINDIR)
	for x in $(SBINOBJS); do $(INSTALL) obj64/$$x $(DESTDIR)$(SBINDIR)/$$x; done

objscript.%: %
	@$(VECHO) OBJSCRIPT $*
	sed "s!### SET DEFAULT LDSCRIPT PATH HERE ###!HUGETLB_LDSCRIPT_PATH=$(LDSCRIPTDIR)!" < $< > $@

install: all $(OBJDIRS:%=%/install) $(INSTALL_OBJSCRIPT:%=objscript.%)
	@$(VECHO) INSTALL
	$(INSTALL) -d $(DESTDIR)$(LDSCRIPTDIR)
	$(INSTALL) -m 644 $(INSTALL_LDSCRIPTS:%=ldscripts/%) $(DESTDIR)$(LDSCRIPTDIR)
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	for x in $(INSTALL_OBJSCRIPT); do \
		$(INSTALL) -m 755 objscript.$$x $(DESTDIR)$(BINDIR)/$$x; done
	cd $(DESTDIR)$(BINDIR) && ln -sf ld.hugetlbfs ld

install-docs:
	$(INSTALL) -d $(DESTDIR)$(DOCDIR)
	for x in $(EXTRA_DIST); do $(INSTALL) -m 755 $$x $(DESTDIR)$(DOCDIR)/$$x; done

install-tests: install	# Force make to install the library first
	${MAKE} -C tests install DESTDIR=$(DESTDIR) OBJDIRS="$(OBJDIRS)" LIB32=$(LIB32) LIB64=$(LIB64)
