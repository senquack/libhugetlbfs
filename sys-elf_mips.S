/*
 * libhugetlbfs - Easy use of Linux hugepages
 * Copyright (C) 2019 Daniel Silsby
 *
 * Based on code from the GNU C Library, Copyright Free Software Foundation, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

	.text
	.globl  direct_syscall
	.type   direct_syscall,%function
	.ent    direct_syscall
direct_syscall:
	move    $v0, $a0        /* Syscall number is first arg */

	move    $a0, $a1        /* Move the next 3 args up a register */
	move    $a1, $a2
	move    $a2, $a3

	/* Load the remaining possible args (up to 7 total) from the stack */
	lw      $a3, 4*4($sp)
	lw      $t0, 5*4($sp)
	lw      $t1, 6*4($sp)
	lw      $t2, 7*4($sp)

	addiu   $sp, $sp, -32
	sw      $v0, 7*4($sp)   /* Store syscall number on stack (for restarts) */

	sw      $t0, 4*4($sp)   /* Last 3 syscall args are passed on stack */
	sw      $t1, 5*4($sp)
	sw      $t2, 6*4($sp)

	lw      $v0, 7*4($sp)   /* For system call restarts */
	syscall

	addiu   $sp, $sp, 32
	jr      $ra             /* Return to caller */

	.end    direct_syscall
	.size   direct_syscall,.-direct_syscall

#if defined(__linux__) && defined(__ELF__)
	.section .note.GNU-stack,"",%progbits
#endif
