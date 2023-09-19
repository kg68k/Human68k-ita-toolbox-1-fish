*************************************************
*						*
*   malloc Ext version				*
*   Copyright 1991 by �d����(T.Kawamoto)	*
*						*
*************************************************
*						*
*   file name : defines.inc			*
*   author    : T.Kawamoto			*
*   date      : 91/9/22				*
*   functions : offset definitions		*
*   history   : 91/9/16	now coding		*
*             : 91/9/21	debugging has finished	*
*						*
*************************************************
*
*  offset definitions
*
		.offset	0
*
pool_head:			* �e pool �̐擪
next_pool_offset:		* ���� pool �ւ̃I�t�Z�b�g
		ds.w	1	* �K�� 2 �̔{���ł���
				* 0 �Ȃ�I����\�킷 dummy pool
				* 2 �� broken pool�A���݂͈�ؐ������Ȃ�
pool_buffer_head:		* 4 �ȏ�� used pool �� free pool
				*   ���̋�ʂ͕ʂ̃`�F�C���� free �������q��
				*   ���̃��X�g�ɂȂ���� used �� pool_buffer_head
				*   ���� next_pool_offset - 2 bytes �g�p��
next_free_offset:		* free �� next_free_offset �Ń`�F�C������
		ds.w	1	* �K�� 2 �̔{���ł���
				* 0 �Ȃ玟�� free pool ��������������
free_pool_buffer_head:
*
		.offset	0
*
lake_head:			* �e lake �̐擪
lake_size:			* lake �̃T�C�Y
		ds.l	1	*
next_lake_ptr:			* ���� lake �ւ̃|�C���^
		ds.l	1	* 0 �Ȃ玟�� lake �͖���
head_pool:			* next_free_offset ���i�[����ׂ� free pool
		ds.b	free_pool_buffer_head
				* next_pool_offset �ɂ͒��x free_pool_buffer_head ��
				* next_free_offset �ɂ� free pool ��
				* �̃I�t�Z�b�g������
lake_buffer_head:		* ����������ۂ� pool �̃`�F�C��������
				* ��ԍŌ�ɂ� dummy pool ������
*
		.text
*
		.globl	lake_top
*
		.globl	print_string,print_long,print_word
		.globl	print_byte,print_nible,putchar
		.globl	dumpout_memory_reg_saved
		.globl	dumpout_memory
*
debug		macro	message,value
		local	next,label,CRLF
		movem.l	d0/a0,-(sp)
		lea	label,a0
		bsr	print_string
		movem.l	(sp)+,d0/a0
		movem.l	d0/a0,-(sp)
		move.l	value,d0
		bsr	print_long
		lea	CRLF,a0
		bsr	print_string
		movem.l	(sp)+,d0/a0
		bra	next
label:
		dc.b	message
CRLF:
		dc.b	$0d,$0a,0
		even
next:
		endm
*