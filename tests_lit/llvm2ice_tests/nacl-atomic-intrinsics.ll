; This tests each of the supported NaCl atomic instructions for every
; size allowed.

; RUN: %llvm2ice -O2 --verbose none %s | FileCheck %s
; RUN: %llvm2ice -O2 --verbose none %s | FileCheck %s --check-prefix=CHECKO2REM
; RUN: %llvm2ice -Om1 --verbose none %s | FileCheck %s
; RUN: %llvm2ice -O2 --verbose none %s | llvm-mc -x86-asm-syntax=intel
; RUN: %llvm2ice -Om1 --verbose none %s | llvm-mc -x86-asm-syntax=intel
; RUN: %llvm2ice --verbose none %s | FileCheck --check-prefix=ERRORS %s
; RUN: %llvm2iceinsts %s | %szdiff %s | FileCheck --check-prefix=DUMP %s
; RUN: %llvm2iceinsts --pnacl %s | %szdiff %s \
; RUN:                           | FileCheck --check-prefix=DUMP %s

declare i8 @llvm.nacl.atomic.load.i8(i8*, i32)
declare i16 @llvm.nacl.atomic.load.i16(i16*, i32)
declare i32 @llvm.nacl.atomic.load.i32(i32*, i32)
declare i64 @llvm.nacl.atomic.load.i64(i64*, i32)
declare void @llvm.nacl.atomic.store.i8(i8, i8*, i32)
declare void @llvm.nacl.atomic.store.i16(i16, i16*, i32)
declare void @llvm.nacl.atomic.store.i32(i32, i32*, i32)
declare void @llvm.nacl.atomic.store.i64(i64, i64*, i32)
declare i8 @llvm.nacl.atomic.rmw.i8(i32, i8*, i8, i32)
declare i16 @llvm.nacl.atomic.rmw.i16(i32, i16*, i16, i32)
declare i32 @llvm.nacl.atomic.rmw.i32(i32, i32*, i32, i32)
declare i64 @llvm.nacl.atomic.rmw.i64(i32, i64*, i64, i32)
declare i8 @llvm.nacl.atomic.cmpxchg.i8(i8*, i8, i8, i32, i32)
declare i16 @llvm.nacl.atomic.cmpxchg.i16(i16*, i16, i16, i32, i32)
declare i32 @llvm.nacl.atomic.cmpxchg.i32(i32*, i32, i32, i32, i32)
declare i64 @llvm.nacl.atomic.cmpxchg.i64(i64*, i64, i64, i32, i32)
declare void @llvm.nacl.atomic.fence(i32)
declare void @llvm.nacl.atomic.fence.all()
declare i1 @llvm.nacl.atomic.is.lock.free(i32, i8*)

; NOTE: The LLC equivalent for 16-bit atomic operations are expanded
; as 32-bit operations. For Subzero, assume that real 16-bit operations
; will be usable (the validator will be fixed):
; https://code.google.com/p/nativeclient/issues/detail?id=2981

;;; Load

; x86 guarantees load/store to be atomic if naturally aligned.
; The PNaCl IR requires all atomic accesses to be naturally aligned.

define i32 @test_atomic_load_8(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i8*
  ; parameter value "6" is for the sequential consistency memory order.
  %i = call i8 @llvm.nacl.atomic.load.i8(i8* %ptr, i32 6)
  %r = zext i8 %i to i32
  ret i32 %r
}
; CHECK-LABEL: test_atomic_load_8
; CHECK: mov {{.*}}, dword
; CHECK: mov {{.*}}, byte

define i32 @test_atomic_load_16(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i16*
  %i = call i16 @llvm.nacl.atomic.load.i16(i16* %ptr, i32 6)
  %r = zext i16 %i to i32
  ret i32 %r
}
; CHECK-LABEL: test_atomic_load_16
; CHECK: mov {{.*}}, dword
; CHECK: mov {{.*}}, word

define i32 @test_atomic_load_32(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %r = call i32 @llvm.nacl.atomic.load.i32(i32* %ptr, i32 6)
  ret i32 %r
}
; CHECK-LABEL: test_atomic_load_32
; CHECK: mov {{.*}}, dword
; CHECK: mov {{.*}}, dword

define i64 @test_atomic_load_64(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %r = call i64 @llvm.nacl.atomic.load.i64(i64* %ptr, i32 6)
  ret i64 %r
}
; CHECK-LABEL: test_atomic_load_64
; CHECK: movq x{{.*}}, qword
; CHECK: movq qword {{.*}}, x{{.*}}

define i32 @test_atomic_load_32_with_arith(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %r = call i32 @llvm.nacl.atomic.load.i32(i32* %ptr, i32 6)
  %r2 = add i32 %r, 32
  ret i32 %r2
}
; CHECK-LABEL: test_atomic_load_32_with_arith
; CHECK: mov {{.*}}, dword
; The next instruction may be a separate load or folded into an add.

define i32 @test_atomic_load_32_ignored(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.load.i32(i32* %ptr, i32 6)
  ret i32 0
}
; CHECK-LABEL: test_atomic_load_32_ignored
; CHECK: mov {{.*}}, dword
; CHECK: mov {{.*}}, dword

define i64 @test_atomic_load_64_ignored(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %ignored = call i64 @llvm.nacl.atomic.load.i64(i64* %ptr, i32 6)
  ret i64 0
}
; CHECK-LABEL: test_atomic_load_64_ignored
; CHECK: movq x{{.*}}, qword
; CHECK: movq qword {{.*}}, x{{.*}}

;;; Store

define void @test_atomic_store_8(i32 %iptr, i32 %v) {
entry:
  %truncv = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  call void @llvm.nacl.atomic.store.i8(i8 %truncv, i8* %ptr, i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_store_8
; CHECK: mov byte
; CHECK: mfence

define void @test_atomic_store_16(i32 %iptr, i32 %v) {
entry:
  %truncv = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  call void @llvm.nacl.atomic.store.i16(i16 %truncv, i16* %ptr, i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_store_16
; CHECK: mov word
; CHECK: mfence

define void @test_atomic_store_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  call void @llvm.nacl.atomic.store.i32(i32 %v, i32* %ptr, i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_store_32
; CHECK: mov dword
; CHECK: mfence

define void @test_atomic_store_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  call void @llvm.nacl.atomic.store.i64(i64 %v, i64* %ptr, i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_store_64
; CHECK: movq x{{.*}}, qword
; CHECK: movq qword {{.*}}, x{{.*}}
; CHECK: mfence

define void @test_atomic_store_64_const(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  call void @llvm.nacl.atomic.store.i64(i64 12345678901234, i64* %ptr, i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_store_64_const
; CHECK: mov {{.*}}, 1942892530
; CHECK: mov {{.*}}, 2874
; CHECK: movq x{{.*}}, qword
; CHECK: movq qword {{.*}}, x{{.*}}
; CHECK: mfence


;;; RMW

;; add

define i32 @test_atomic_rmw_add_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  ; "1" is an atomic add, and "6" is sequential consistency.
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 1, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_add_8
; CHECK: lock xadd byte {{.*}}, [[REG:.*]]
; CHECK: mov {{.*}}, [[REG]]

define i32 @test_atomic_rmw_add_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 1, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_add_16
; CHECK: lock xadd word {{.*}}, [[REG:.*]]
; CHECK: mov {{.*}}, [[REG]]

define i32 @test_atomic_rmw_add_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 1, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_add_32
; CHECK: lock xadd dword {{.*}}, [[REG:.*]]
; CHECK: mov {{.*}}, [[REG]]

define i64 @test_atomic_rmw_add_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 1, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_add_64
; CHECK: push ebx
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; RHS of add cannot be any of the e[abcd]x regs because they are
; clobbered in the loop, and the RHS needs to be remain live.
; CHECK: add ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: adc ecx, {{.*e.[^x]}}
; Ptr cannot be eax, ebx, ecx, or edx (used up for the expected and desired).
; It can be esi, edi, or ebp though, for example (so we need to be careful
; about rejecting eb* and ed*.)
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]

; Test with some more register pressure. When we have an alloca, ebp is
; used to manage the stack frame, so it cannot be used as a register either.
declare void @use_ptr(i32 %iptr)

define i64 @test_atomic_rmw_add_64_alloca(i32 %iptr, i64 %v) {
entry:
  %alloca_ptr = alloca i8, i32 16, align 16
  %ptr = inttoptr i32 %iptr to i64*
  %old = call i64 @llvm.nacl.atomic.rmw.i64(i32 1, i64* %ptr, i64 %v, i32 6)
  store i8 0, i8* %alloca_ptr, align 1
  store i8 1, i8* %alloca_ptr, align 1
  store i8 2, i8* %alloca_ptr, align 1
  store i8 3, i8* %alloca_ptr, align 1
  %__5 = ptrtoint i8* %alloca_ptr to i32
  call void @use_ptr(i32 %__5)
  ret i64 %old
}
; CHECK-LABEL: test_atomic_rmw_add_64_alloca
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; Ptr cannot be eax, ebx, ecx, or edx (used up for the expected and desired).
; It also cannot be ebp since we use that for alloca. Also make sure it's
; not esp, since that's the stack pointer and mucking with it will break
; the later use_ptr function call.
; That pretty much leaves esi, or edi as the only viable registers.
; CHECK: lock cmpxchg8b qword ptr [e{{[ds]}}i]
; CHECK: call use_ptr

define i32 @test_atomic_rmw_add_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 1, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; Technically this could use "lock add" instead of "lock xadd", if liveness
; tells us that the destination variable is dead.
; CHECK-LABEL: test_atomic_rmw_add_32_ignored
; CHECK: lock xadd dword {{.*}}, [[REG:.*]]

; Atomic RMW 64 needs to be expanded into its own loop.
; Make sure that works w/ non-trivial function bodies.
define i64 @test_atomic_rmw_add_64_loop(i32 %iptr, i64 %v) {
entry:
  %x = icmp ult i64 %v, 100
  br i1 %x, label %err, label %loop

loop:
  %v_next = phi i64 [ %v, %entry ], [ %next, %loop ]
  %ptr = inttoptr i32 %iptr to i64*
  %next = call i64 @llvm.nacl.atomic.rmw.i64(i32 1, i64* %ptr, i64 %v_next, i32 6)
  %success = icmp eq i64 %next, 100
  br i1 %success, label %done, label %loop

done:
  ret i64 %next

err:
  ret i64 0
}
; CHECK-LABEL: test_atomic_rmw_add_64_loop
; CHECK: push ebx
; CHECK-LABEL: .Ltest_atomic_rmw_add_64_loop{{.*}}loop
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; CHECK: add ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: adc ecx, {{.*e.[^x]}}
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]
; CHECK-LABEL: .Ltest_atomic_rmw_add_64_loop{{.*}}done

;; sub

define i32 @test_atomic_rmw_sub_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 2, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_sub_8
; CHECK: neg [[REG:.*]]
; CHECK: lock xadd byte {{.*}}, [[REG]]
; CHECK: mov {{.*}}, [[REG]]

define i32 @test_atomic_rmw_sub_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 2, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_sub_16
; CHECK: neg [[REG:.*]]
; CHECK: lock xadd word {{.*}}, [[REG]]
; CHECK: mov {{.*}}, [[REG]]

define i32 @test_atomic_rmw_sub_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 2, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_sub_32
; CHECK: neg [[REG:.*]]
; CHECK: lock xadd dword {{.*}}, [[REG]]
; CHECK: mov {{.*}}, [[REG]]

define i64 @test_atomic_rmw_sub_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 2, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_sub_64
; CHECK: push ebx
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; CHECK: sub ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: sbb ecx, {{.*e.[^x]}}
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]


define i32 @test_atomic_rmw_sub_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 2, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; Could use "lock sub" instead of "neg; lock xadd"
; CHECK-LABEL: test_atomic_rmw_sub_32_ignored
; CHECK: neg [[REG:.*]]
; CHECK: lock xadd dword {{.*}}, [[REG]]

;; or

define i32 @test_atomic_rmw_or_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 3, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_or_8
; CHECK: mov al, byte ptr
; CHECK: .L[[LABEL:.*]]:
; Dest cannot be eax here, because eax is used for the old value. Also want
; to make sure that cmpxchg's source is the same register.
; CHECK: or [[REG:[^a].]]
; CHECK: lock cmpxchg byte ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_or_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 3, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_or_16
; CHECK: mov ax, word ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: or [[REG:[^a].]]
; CHECK: lock cmpxchg word ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_or_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 3, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_or_32
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: or [[REG:e[^a].]]
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

define i64 @test_atomic_rmw_or_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 3, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_or_64
; CHECK: push ebx
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; CHECK: or ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: or ecx, {{.*e.[^x]}}
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_or_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 3, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; CHECK-LABEL: test_atomic_rmw_or_32_ignored
; Could just "lock or", if we inspect the liveness information first.
; Would also need a way to introduce "lock"'edness to binary
; operators without introducing overhead on the more common binary ops.
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: or [[REG:e[^a].]]
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

;; and

define i32 @test_atomic_rmw_and_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 4, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_and_8
; CHECK: mov al, byte ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: and [[REG:[^a].]]
; CHECK: lock cmpxchg byte ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_and_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 4, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_and_16
; CHECK: mov ax, word ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: and
; CHECK: lock cmpxchg word ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_and_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 4, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_and_32
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: and
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]

define i64 @test_atomic_rmw_and_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 4, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_and_64
; CHECK: push ebx
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; CHECK: and ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: and ecx, {{.*e.[^x]}}
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_and_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 4, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; CHECK-LABEL: test_atomic_rmw_and_32_ignored
; Could just "lock and"
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: and
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]

;; xor

define i32 @test_atomic_rmw_xor_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 5, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_xor_8
; CHECK: mov al, byte ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: xor [[REG:[^a].]]
; CHECK: lock cmpxchg byte ptr [e{{[^a].}}], [[REG]]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_xor_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 5, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_xor_16
; CHECK: mov ax, word ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: xor
; CHECK: lock cmpxchg word ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]


define i32 @test_atomic_rmw_xor_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 5, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_xor_32
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: xor
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]

define i64 @test_atomic_rmw_xor_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 5, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_xor_64
; CHECK: push ebx
; CHECK: mov eax, dword ptr [{{.*}}]
; CHECK: mov edx, dword ptr [{{.*}}+4]
; CHECK: .L[[LABEL:.*]]:
; CHECK: mov ebx, eax
; CHECK: or ebx, {{.*e.[^x]}}
; CHECK: mov ecx, edx
; CHECK: or ecx, {{.*e.[^x]}}
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_xor_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 5, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; CHECK-LABEL: test_atomic_rmw_xor_32_ignored
; CHECK: mov eax, dword ptr
; CHECK: .L[[LABEL:.*]]:
; CHECK: xor
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}]
; CHECK: jne .L[[LABEL]]

;; exchange

define i32 @test_atomic_rmw_xchg_8(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i8
  %ptr = inttoptr i32 %iptr to i8*
  %a = call i8 @llvm.nacl.atomic.rmw.i8(i32 6, i8* %ptr, i8 %trunc, i32 6)
  %a_ext = zext i8 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_xchg_8
; CHECK: xchg byte ptr {{.*}}, [[REG:.*]]

define i32 @test_atomic_rmw_xchg_16(i32 %iptr, i32 %v) {
entry:
  %trunc = trunc i32 %v to i16
  %ptr = inttoptr i32 %iptr to i16*
  %a = call i16 @llvm.nacl.atomic.rmw.i16(i32 6, i16* %ptr, i16 %trunc, i32 6)
  %a_ext = zext i16 %a to i32
  ret i32 %a_ext
}
; CHECK-LABEL: test_atomic_rmw_xchg_16
; CHECK: xchg word ptr {{.*}}, [[REG:.*]]

define i32 @test_atomic_rmw_xchg_32(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %a = call i32 @llvm.nacl.atomic.rmw.i32(i32 6, i32* %ptr, i32 %v, i32 6)
  ret i32 %a
}
; CHECK-LABEL: test_atomic_rmw_xchg_32
; CHECK: xchg dword ptr {{.*}}, [[REG:.*]]

define i64 @test_atomic_rmw_xchg_64(i32 %iptr, i64 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %a = call i64 @llvm.nacl.atomic.rmw.i64(i32 6, i64* %ptr, i64 %v, i32 6)
  ret i64 %a
}
; CHECK-LABEL: test_atomic_rmw_xchg_64
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; CHECK: .L[[LABEL:.*]]:
; CHECK: lock cmpxchg8b qword ptr [{{e.[^x]}}]
; CHECK: jne .L[[LABEL]]

define i32 @test_atomic_rmw_xchg_32_ignored(i32 %iptr, i32 %v) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.rmw.i32(i32 6, i32* %ptr, i32 %v, i32 6)
  ret i32 %v
}
; In this case, ignoring the return value doesn't help. The xchg is
; used to do an atomic store.
; CHECK-LABEL: test_atomic_rmw_xchg_32_ignored
; CHECK: xchg dword ptr {{.*}}, [[REG:.*]]

;;;; Cmpxchg

define i32 @test_atomic_cmpxchg_8(i32 %iptr, i32 %expected, i32 %desired) {
entry:
  %trunc_exp = trunc i32 %expected to i8
  %trunc_des = trunc i32 %desired to i8
  %ptr = inttoptr i32 %iptr to i8*
  %old = call i8 @llvm.nacl.atomic.cmpxchg.i8(i8* %ptr, i8 %trunc_exp,
                                              i8 %trunc_des, i32 6, i32 6)
  %old_ext = zext i8 %old to i32
  ret i32 %old_ext
}
; CHECK-LABEL: test_atomic_cmpxchg_8
; CHECK: mov al, {{.*}}
; Need to check that eax isn't used as the address register or the desired.
; since it is already used as the *expected* register.
; CHECK: lock cmpxchg byte ptr [e{{[^a].}}], {{[^a]}}

define i32 @test_atomic_cmpxchg_16(i32 %iptr, i32 %expected, i32 %desired) {
entry:
  %trunc_exp = trunc i32 %expected to i16
  %trunc_des = trunc i32 %desired to i16
  %ptr = inttoptr i32 %iptr to i16*
  %old = call i16 @llvm.nacl.atomic.cmpxchg.i16(i16* %ptr, i16 %trunc_exp,
                                               i16 %trunc_des, i32 6, i32 6)
  %old_ext = zext i16 %old to i32
  ret i32 %old_ext
}
; CHECK-LABEL: test_atomic_cmpxchg_16
; CHECK: mov ax, {{.*}}
; CHECK: lock cmpxchg word ptr [e{{[^a].}}], {{[^a]}}

define i32 @test_atomic_cmpxchg_32(i32 %iptr, i32 %expected, i32 %desired) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %old = call i32 @llvm.nacl.atomic.cmpxchg.i32(i32* %ptr, i32 %expected,
                                               i32 %desired, i32 6, i32 6)
  ret i32 %old
}
; CHECK-LABEL: test_atomic_cmpxchg_32
; CHECK: mov eax, {{.*}}
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}], e{{[^a]}}

define i64 @test_atomic_cmpxchg_64(i32 %iptr, i64 %expected, i64 %desired) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %old = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %ptr, i64 %expected,
                                               i64 %desired, i32 6, i32 6)
  ret i64 %old
}
; CHECK-LABEL: test_atomic_cmpxchg_64
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; edx and eax are already the return registers, so they don't actually
; need to be reshuffled via movs. The next test stores the result
; somewhere, so in that case they do need to be mov'ed.

; Test a case where %old really does need to be copied out of edx:eax.
define void @test_atomic_cmpxchg_64_store(i32 %ret_iptr, i32 %iptr, i64 %expected, i64 %desired) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %old = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %ptr, i64 %expected,
                                                i64 %desired, i32 6, i32 6)
  %__6 = inttoptr i32 %ret_iptr to i64*
  store i64 %old, i64* %__6, align 1
  ret void
}
; CHECK-LABEL: test_atomic_cmpxchg_64_store
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]
; CHECK: mov {{.*}}, edx
; CHECK: mov {{.*}}, eax

; Test with some more register pressure. When we have an alloca, ebp is
; used to manage the stack frame, so it cannot be used as a register either.
define i64 @test_atomic_cmpxchg_64_alloca(i32 %iptr, i64 %expected, i64 %desired) {
entry:
  %alloca_ptr = alloca i8, i32 16, align 16
  %ptr = inttoptr i32 %iptr to i64*
  %old = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %ptr, i64 %expected,
                                                i64 %desired, i32 6, i32 6)
  store i8 0, i8* %alloca_ptr, align 1
  store i8 1, i8* %alloca_ptr, align 1
  store i8 2, i8* %alloca_ptr, align 1
  store i8 3, i8* %alloca_ptr, align 1
  %__6 = ptrtoint i8* %alloca_ptr to i32
  call void @use_ptr(i32 %__6)
  ret i64 %old
}
; CHECK-LABEL: test_atomic_cmpxchg_64_alloca
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; Ptr cannot be eax, ebx, ecx, or edx (used up for the expected and desired).
; It also cannot be ebp since we use that for alloca. Also make sure it's
; not esp, since that's the stack pointer and mucking with it will break
; the later use_ptr function call.
; That pretty much leaves esi, or edi as the only viable registers.
; CHECK: lock cmpxchg8b qword ptr [e{{[ds]}}i]
; CHECK: call use_ptr

define i32 @test_atomic_cmpxchg_32_ignored(i32 %iptr, i32 %expected, i32 %desired) {
entry:
  %ptr = inttoptr i32 %iptr to i32*
  %ignored = call i32 @llvm.nacl.atomic.cmpxchg.i32(i32* %ptr, i32 %expected,
                                                    i32 %desired, i32 6, i32 6)
  ret i32 0
}
; CHECK-LABEL: test_atomic_cmpxchg_32_ignored
; CHECK: mov eax, {{.*}}
; CHECK: lock cmpxchg dword ptr [e{{[^a].}}]

define i64 @test_atomic_cmpxchg_64_ignored(i32 %iptr, i64 %expected, i64 %desired) {
entry:
  %ptr = inttoptr i32 %iptr to i64*
  %ignored = call i64 @llvm.nacl.atomic.cmpxchg.i64(i64* %ptr, i64 %expected,
                                                    i64 %desired, i32 6, i32 6)
  ret i64 0
}
; CHECK-LABEL: test_atomic_cmpxchg_64_ignored
; CHECK: push ebx
; CHECK-DAG: mov edx
; CHECK-DAG: mov eax
; CHECK-DAG: mov ecx
; CHECK-DAG: mov ebx
; CHECK: lock cmpxchg8b qword ptr [e{{.[^x]}}]

define i32 @test_atomic_cmpxchg_32_loop(i32 %iptr, i32 %expected, i32 %desired) {
entry:
  br label %loop

loop:
  %cmp = phi i32 [ %expected, %entry ], [ %old, %loop ]
  %ptr = inttoptr i32 %iptr to i32*
  %old = call i32 @llvm.nacl.atomic.cmpxchg.i32(i32* %ptr, i32 %cmp,
                                                i32 %desired, i32 6, i32 6)
  %success = icmp eq i32 %cmp, %old
  br i1 %success, label %done, label %loop

done:
  ret i32 %old
}
; CHECK-LABEL: test_atomic_cmpxchg_32_loop

;;;; Fence and is-lock-free.

define void @test_atomic_fence() {
entry:
  call void @llvm.nacl.atomic.fence(i32 6)
  ret void
}
; CHECK-LABEL: test_atomic_fence
; CHECK: mfence

define void @test_atomic_fence_all() {
entry:
  call void @llvm.nacl.atomic.fence.all()
  ret void
}
; CHECK-LABEL: test_atomic_fence_all
; CHECK: mfence

define i32 @test_atomic_is_lock_free(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i8*
  %i = call i1 @llvm.nacl.atomic.is.lock.free(i32 4, i8* %ptr)
  %r = zext i1 %i to i32
  ret i32 %r
}
; CHECK-LABEL: test_atomic_is_lock_free
; CHECK: mov {{.*}}, 1

define i32 @test_not_lock_free(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i8*
  %i = call i1 @llvm.nacl.atomic.is.lock.free(i32 7, i8* %ptr)
  %r = zext i1 %i to i32
  ret i32 %r
}
; CHECK-LABEL: test_not_lock_free
; CHECK: mov {{.*}}, 0

define i32 @test_atomic_is_lock_free_ignored(i32 %iptr) {
entry:
  %ptr = inttoptr i32 %iptr to i8*
  %ignored = call i1 @llvm.nacl.atomic.is.lock.free(i32 4, i8* %ptr)
  ret i32 0
}
; CHECK-LABEL: test_atomic_is_lock_free_ignored
; CHECK: mov {{.*}}, 0
; This can get optimized out, because it's side-effect-free.
; CHECKO2REM-LABEL: test_atomic_is_lock_free_ignored
; CHECKO2REM-NOT: mov {{.*}}, 1
; CHECKO2REM: mov {{.*}}, 0

; TODO(jvoung): at some point we can take advantage of the
; fact that nacl.atomic.is.lock.free will resolve to a constant
; (which adds DCE opportunities). Once we optimize, the test expectations
; for this case should change.
define i32 @test_atomic_is_lock_free_can_dce(i32 %iptr, i32 %x, i32 %y) {
entry:
  %ptr = inttoptr i32 %iptr to i8*
  %i = call i1 @llvm.nacl.atomic.is.lock.free(i32 4, i8* %ptr)
  %i_ext = zext i1 %i to i32
  %cmp = icmp eq i32 %i_ext, 1
  br i1 %cmp, label %lock_free, label %not_lock_free
lock_free:
  ret i32 %i_ext

not_lock_free:
  %z = add i32 %x, %y
  ret i32 %z
}
; CHECK-LABEL: test_atomic_is_lock_free_can_dce
; CHECK: mov {{.*}}, 1
; CHECK: ret
; CHECK: add
; CHECK: ret

; ERRORS-NOT: ICE translation error
; DUMP-NOT: SZ
