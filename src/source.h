.offset	0

SOURCE_PARENT:		ds.l	1
SOURCE_PARENT_STACKP:	ds.l	1
SOURCE_TOP:		ds.l	1
SOURCE_BOT:		ds.l	1
SOURCE_ONINTR_POINTER:	ds.l	1
SOURCE_ONINTR_LINENO:	ds.l	1
SOURCE_POINTER:		ds.l	1
SOURCE_LINENO:		ds.l	1
SOURCE_ARGV0_SIZE:	ds.w	1
SOURCE_PUSHARGV_SIZE:	ds.w	1
SOURCE_PUSHARGC:	ds.w	1
SOURCE_FLAGS:		ds.b	1
.even
SOURCE_WORDLIST:	ds.b	MAXWORDLISTSIZE+1
.even
SOURCE_STACK:		ds.b	STACKSIZE
.even
SOURCE_STACK_BOTTOM:

SOURCE_HEADER_SIZE	equ	SOURCE_STACK_BOTTOM

SOURCE_FLAGBIT_NOALIAS		equ	1
SOURCE_FLAGBIT_NOCOMMENT	equ	2
