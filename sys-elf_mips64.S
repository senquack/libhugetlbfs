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
	daddiu  $sp, $sp, -16
	move    $v0, $a0        /* Syscall number is first arg */
	sd      $v0, 0($sp)     /* Store syscall number on stack (for restarts) */

	move    $a0, $a1        /* Move the next seven args up a register */
	move    $a1, $a2
	move    $a2, $a3
	move    $a3, $a4
	move    $a4, $a5
	move    $a5, $a6
	move    $a6, $a7

	ld      $v0, 0($sp)     /* For system call restarts */
	syscall

	daddiu  $sp, $sp, 16
	jr      $ra             /* Return to caller.  */

	.end    direct_syscall
	.size   direct_syscall,.-direct_syscall

#if defined(__linux__) && defined(__ELF__)
	.section .note.GNU-stack,"",%progbits
#endif
