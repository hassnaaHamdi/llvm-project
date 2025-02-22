# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64 %s -o %t.o

# RUN: ld.lld --no-relax %t.o -o %t
# RUN: llvm-objdump --no-print-imm-hex -d --no-show-raw-insn %t | FileCheck %s --check-prefix=PDE
# RUN: llvm-readobj -r %t | FileCheck %s --check-prefix=PDE-RELOC

# RUN: ld.lld -pie --no-relax %t.o -o %t
# RUN: ld.lld -pie --no-relax --apply-dynamic-relocs %t.o -o %t.apply
# RUN: llvm-objdump --no-print-imm-hex -d --no-show-raw-insn %t | FileCheck %s --check-prefix=PIE
# RUN: llvm-readobj -r -x .got.plt %t | FileCheck %s --check-prefixes=PIE-RELOC,NO-APPLY
# RUN: llvm-readobj -r -x .got.plt %t.apply | FileCheck %s --check-prefixes=PIE-RELOC,APPLY

## When compiling with -fno-PIE or -fPIE, if the ifunc is in the same
## translation unit as the address taker, the compiler knows that ifunc is not
## defined in a shared library so it can use a non GOT generating relative reference.
.text
.globl myfunc
.type myfunc,@gnu_indirect_function
myfunc:
.globl myfunc_resolver
.type myfunc_resolver,@function
myfunc_resolver:
 ret

.text
.globl main
.type main,@function
main:
 adrp x8, myfunc
 add  x8, x8, :lo12: myfunc
 ret

## The address of myfunc is the address of the PLT entry for myfunc.
# PDE:      <myfunc_resolver>:
# PDE-NEXT:   210170:   ret
# PDE:      <main>:
# PDE-NEXT:   210174:   adrp    x8, 0x210000
# PDE-NEXT:   210178:   add     x8, x8, #384
# PDE-NEXT:   21017c:   ret
# PDE-EMPTY:
# PDE-NEXT: Disassembly of section .iplt:
# PDE-EMPTY:
# PDE-NEXT: <myfunc>:
## page(.got.plt) - page(0x210010) = 65536
# PDE-NEXT:   210180: adrp    x16, 0x220000
# PDE-NEXT:   210184: ldr     x17, [x16, #400]
# PDE-NEXT:   210188: add     x16, x16, #400
# PDE-NEXT:   21018c: br      x17

## The adrp to myfunc should generate a PLT entry and a GOT entry with an
## irelative relocation.
# PDE-RELOC:      .rela.dyn {
# PDE-RELOC-NEXT:   0x220190 R_AARCH64_IRELATIVE - 0x210170
# PDE-RELOC-NEXT: }

# PIE:      <myfunc_resolver>:
# PIE-NEXT:    10260: ret
# PIE:      <main>:
# PIE-NEXT:    10264: adrp    x8, 0x10000
# PIE-NEXT:    10268: add     x8, x8, #624
# PIE-NEXT:    1026c: ret
# PIE-EMPTY:
# PIE-NEXT: Disassembly of section .iplt:
# PIE-EMPTY:
# PIE-NEXT: <myfunc>:
# PIE-NEXT:    10270: adrp    x16, 0x30000
# PIE-NEXT:           ldr     x17, [x16, #832]
# PIE-NEXT:           add     x16, x16, #832
# PIE-NEXT:           br      x17

# PIE-RELOC:      .rela.dyn {
# PIE-RELOC-NEXT:   0x30340 R_AARCH64_IRELATIVE - 0x10260
# PIE-RELOC-NEXT: }
# PIE-RELOC:      Hex dump of section '.got.plt':
# NO-APPLY:       0x00030340 00000000 00000000
# APPLY:          0x00030340 60020100 00000000
# PIE-RELOC-EMPTY:
