* setvar.s
* Itagaki Fumihiko 26-Sep-90  Create.

.xref strlen
.xref strmove
.xref memmove_inc
.xref memmove_dec
.xref wordlistlen
.xref find_var

.text

****************************************************************
* set_var - �ϐ����`����
*
* CALL
*      A0     �ϐ��̈�̐擪�A�h���X
*      A1     �ϐ����̐擪�A�h���X
*      A2     �l�̌���т̐擪�A�h���X
*      D0.W   �l�̌ꐔ
*
* RETURN
*      D0.L   0:����  1:�̈悪����Ȃ�
*      CCR    TST.L D0
*
* NOTE
*      �Z�b�g����l�̌���т̃A�h���X���ϐ��̌��݂̒l��
*      �ꕔ�ʂł���Ƃ��ɂ��A���������삷��B
****************************************************************
.xdef set_var

set_var:
		movem.l	d1-d7/a0-a1/a3-a4,-(a7)
		movea.l	a0,a3			* A3 : �ϐ��̈�̐擪�A�h���X
		move.w	d0,d1			* D1.W : �l�̌ꐔ
		movea.l	a2,a0			* A0 = �l
		bsr	wordlistlen
		move.l	d0,d2			* D2.L = ����т̃o�C�g��
		movea.l	a1,a0			* A0 = �ϐ���
		bsr	strlen
		addq.l	#1,d0
		add.l	d2,d0
		bsr	calc_var_size
		move.l	d0,d3			* D3.L = �ϐ��ɕK�v�ȃo�C�g��

		movea.l	a3,a4
		adda.l	4(a3),a4		* A4 = �ϐ��̈�̌��݂̏I�[�A�h���X

		move.l	(a3),d4
		sub.l	4(a3),d4
		subq.l	#2,d4			* D4.L = ���݂̕ϐ��̈�̗]�T

		movea.l	a3,a0
		bsr	find_var
		move.l	d0,d5
		beq	do_insert

		moveq	#0,d5
		move.w	(a0),d5
do_insert:
		move.l	a0,d0
		add.l	d5,d0			* D0 = A0 + D5 ... ���̕ϐ��̃A�h���X
		move.l	a4,d6
		sub.l	d0,d6			* D6 = A4 - D0 ... ���̕ϐ��̐擪����I�[�܂ł̃o�C�g��
		move.l	d5,d7
		sub.l	d3,d7			* D7 = D5 - D3 ... �����o�C�g��
		beq	do_put
		bmi	reset_expand

		* �o�C�g������

		bsr	put
		suba.l	d7,a4			* A4 = �Đݒ��̏I�[�A�h���X
		movea.l	d0,a1
		movea.l	d0,a0
		suba.l	d7,a0
		move.l	d6,d0
		bsr	memmove_inc
		bra	insert_done

reset_expand:
		* �o�C�g������

		add.l	d5,d4
		sub.l	d3,d4			* D4.L = �Đݒ��̗]�T
		blo	nospace

		movem.l	a0-a1,-(a7)
		movea.l	a4,a1
		suba.l	d7,a4			* A4 = �Đݒ��̏I�[�A�h���X
		movea.l	a4,a0
		move.l	d6,d0
		bsr	memmove_dec
		movem.l	(a7)+,a0-a1
do_put:
		bsr	put
insert_done:
		move.w	d3,-2(a0,d3.w)		* ���̕ϐ�����߂�o�C�g��
		clr.w	(a4)			* �ϐ��Q�̏I�[
		suba.l	a3,a4
		move.l	a4,4(a3)		* �ϐ��Q�̏I�[�A�h���X�̐擪����̃I�t�Z�b�g
		moveq	#0,d0			* return 0 : ����
set_var_return:
		movem.l	(a7)+,d1-d7/a0-a1/a3-a4
		rts

nospace:
		moveq	#1,d0
		bra	set_var_return
****************************************************************
put:
		movem.l	d0/a0-a1,-(a7)
		move.w	d3,(a0)+		* ���̕ϐ�����߂�o�C�g��
		move.w	d1,(a0)+		* ���̕ϐ��̌ꐔ
		bsr	strmove			* �ϐ���
		movea.l	a2,a1
		move.l	d2,d0
		bsr	memmove_inc		* �����
		movem.l	(a7)+,d0/a0-a1
		rts
****************************************************************
.xdef calc_var_size

calc_var_size:
		btst	#0,d0
		beq	calc_var_size_1

		addq.l	#1,d0
calc_var_size_1:
		addq.l	#6,d0
		rts
****************************************************************

.end
