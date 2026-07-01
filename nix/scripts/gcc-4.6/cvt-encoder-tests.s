	.text
	cvtsi2sdq %rax, %xmm0
	cvtsi2sdq %r8, %xmm0
	cvtsi2sdq %rax, %xmm8
	cvtsi2sdq (%rdi), %xmm0
	cvtsi2sdq -8(%rbp), %xmm0
	cvtsi2sdq (%rdi,%rsi,8), %xmm0
	cvtsi2sdq 16(%rdi,%rsi,8), %xmm0
	cvtsi2sdq (%rsp), %xmm0
	cvtsi2sdq (%r12), %xmm0
	cvtsi2sdq (%r13), %xmm0
	cvtsi2ssq %rdi, %xmm0
	cvttsd2siq %xmm0, %rax
	cvttsd2siq %xmm8, %rax
	cvttsd2siq %xmm0, %r8
	cvttsd2siq (%rdi), %rax
	cvttss2siq %xmm0, %rax
