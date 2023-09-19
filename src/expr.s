* expr.s
* Itagaki Fumihiko 03-Nov-90  Create.

.include doscall.h
.include ../src/fish.h

*  PRIMARY
*     <word>
*     <decimal>
*     0<octal>
*     0x<hexa-decimal>
*     -w <name>
*     -e <name>
*     -z <name>
*     -f <name>
*     -d <name>
*     -c <name>
*     -b <name>
*     -a <name>
*     -h <name>
*     -s <name>
*     -v <name>
*     -t <handle>
*     sizeof <filename>
*     timeof <filename>
*     freeof <drive>:
*     { <command> }
*     ( expression )
*
*  OPERATORS
*
*  結合方向
*     <-          + E     - E     ~ E     ! E
*     ->          E1 * E2     E1 / E2     E1 % E2
*     ->          E1 + E2     E1 - E2
*     ->          E1 << E2     E1 >> E2
*     ->          E1 <= E2     E1 >= E2     E1 < E2     E1 > E2
*     ->          E1 == E2     E1 != E2     E1 =~ E2    E1 !~ E2
*     ->          E1 & E2
*     ->          E1 ^ E2
*     ->          E1 | E2
*     ->          E1 && E2
*     ->          E1 || E2
*     <-          E1 ? E2 : E3
*     ->          E1 , E2
*

OP_COMMA	equ	1
OP_QUESTION	equ	2
OP_COLON	equ	3
OP_BOOLOR	equ	4
OP_BOOLAND	equ	5
OP_BITOR	equ	6
OP_BITXOR	equ	7
OP_BITAND	equ	8
OP_EQ		equ	9
OP_NE		equ	10
OP_MATCH	equ	11
OP_NMATCH	equ	12
OP_LT		equ	13
OP_GT		equ	14
OP_LE		equ	15
OP_GE		equ	16
OP_SHL		equ	17
OP_SHR		equ	18
OP_PLUS		equ	19
OP_MINUS	equ	20
OP_MUL		equ	21
OP_DIV		equ	22
OP_MOD		equ	23
OP_BITNOT	equ	24
OP_BOOLNOT	equ	25

E_SYNTAX	equ	1
E_BADNUM	equ	2
E_DIV0		equ	3

FILEMODE_READONLY	equ	%000001
FILEMODE_HIDDEN		equ	%000010
FILEMODE_SYSTEM		equ	%000100
FILEMODE_VOLUME		equ	%001000
FILEMODE_DIRECTORY	equ	%010000
FILEMODE_ARCHIVE	equ	%100000

term = -(((MAXWORDLEN+1)+1)>>1<<1)
term2 = -(((MAXWORDLEN*2+1)+1)>>1<<1)
itoabuf = -12

.xref isdigit
.xref toupper
.xref itoa
.xref strlen
.xref strcmp
.xref strpcmp
.xref strcpy
.xref for1str
.xref skip_space
.xref enputs1
.xref escape_quoted
.xref expand_a_word
.xref tfopen
.xref fclose
.xref isblkdev
.xref stat
.xref divsl
.xref mulsl
.xref drvchk
.xref fork
.xref command_error
.xref expression_syntax_error
.xref pre_perror
.xref too_long_word
.xref no_close_brace
.xref msg_ambiguous

.text

****************************************************************
* expression1 - 式を評価し，結果の文字列と数値を得る
*
* CALL
*      A0     式の単語並びの先頭アドレス
*      A1     式の値を格納するバッファのアドレス
*      D7.W   式の単語数
*
* RETURN
*      A0     残った単語並びの先頭アドレス
*      D0.L   エラーが無ければ 0．さもなくば 1
*      D1.L   式の値
*      D7.W   残った単語の数
*      CCR    TST.L D0
****************************************************************
.xdef expression1

expression1:
		movem.l	d2-d6/a2-a3,-(a7)
		st	d6
		bsr	expression0
		movem.l	(a7)+,d2-d6/a2-a3
		rts
****************************************************************
* expression2 - 式を評価し，結果の数値を得る
*
* CALL
*      A0     式の単語並びの先頭アドレス
*      D7.W   式の単語数
*
* RETURN
*      A0     残った単語並びの先頭アドレス
*      D0.L   エラーが無ければ 0．さもなくば 1
*      D1.L   式の値
*      D7.W   残った単語の数
*      CCR    TST.L D0
****************************************************************
.xdef expression2

expression2:
		link	a6,#term
		movem.l	d2-d6/a1-a3,-(a7)
		lea	term(a6),a1
		st	d6
		bsr	expression0
		movem.l	(a7)+,d2-d6/a1-a3
		unlk	a6
		rts
****************************************************************
* check_expression - 式をチェックする．コマンドの実行やコマンド置換は行わない
*
* CALL
*      A0     式の単語並びの先頭アドレス
*      D7.W   式の単語数
*
* RETURN
*      A0     残った単語並びの先頭アドレス
*      D0.L   エラーが無ければ 0．さもなくば 1
*      D7.W   残った単語の数
*      CCR    TST.L D0
****************************************************************
.xdef check_expression

check_expression:
		link	a6,#term
		movem.l	d2-d6/a1-a3,-(a7)
		lea	term(a6),a1
		sf	d6
		bsr	expression0
		movem.l	(a7)+,d2-d6/a1-a3
		unlk	a6
		rts
****************************************************************
* expression0 - 式を評価し，結果の文字列と数値を得る
*
* CALL
*      A0     式の単語並びの先頭アドレス
*      A1     式の値を格納するバッファのアドレス
*      D6.B   コンディション
*      D7.W   式の単語数
*
* RETURN
*      A0     残った単語並びの先頭アドレス
*      D0.L   エラーが無ければ 0．さもなくば 1
*      D1.L   式の値
*      D7.W   残った単語の数
*      CCR    TST.L D0
*      D2-D6/A2-A3  破壊
****************************************************************
filebuf = -54
dfbuf = filebuf

expression0:
		link	a6,#dfbuf
		bsr	sub_expression
		bne	expression_done

		bsr	expr_atoi
		bne	expression_done

		bsr	expr_itoa
expression_done:
		unlk	a6
		rts
****************************************************************
* sub_expression - 式を評価する
*
* CALL
*      A0     式の単語並びの先頭アドレス
*      A1     式の値を格納するバッファのアドレス
*      D6.B   コンディション
*      D7.W   式の単語数
*
* RETURN
*      A0     残った単語並びの先頭アドレス
*      D0.L   エラーが無ければ 0．さもなくば 1
*      D7.W   残った単語の数
*      CCR    TST.L D0
*      D2-D6/A2-A3  破壊
****************************************************************
sub_expression:
		moveq	#0,d5
****************************************************************
comma:
		bsr	triterm
		bne	return
comma_loop:
		cmp.b	#OP_COMMA,d5
		bne	success

		lea	triterm(pc),a2
		bsr	dual_term
		bne	return

		tst.b	d6
		beq	comma_loop

		move.l	d2,d1
		bsr	expr_itoa
		bra	comma_loop
****************************************************************
triterm:
		bsr	bool_or
		bne	return

		cmp.b	#OP_QUESTION,d5
		bne	success

		bsr	expr_atoi		*  条件項を数値に変換する
		bne	return

		bsr	next_token		*  演算子 ? をスキップする
		tst.b	d6
		bne	triterm_select

		bsr	triterm_skip_term	*  第一項をスキップする
		bra	triterm_true_1

triterm_select:
		tst.l	d1			*  条件項は真か偽か
		beq	triterm_false
triterm_true:
		bsr	triterm			*  第一項を得る
		bne	return

		bsr	expr_atoi
triterm_true_1:
		bne	return

		bsr	triterm_skip_colon
		bne	return

		bra	triterm_skip_term	*  第二項をスキップする

triterm_false:
		bsr	triterm_skip_term	*  第一項をスキップする
		bne	return

		bsr	triterm_skip_colon
		bne	return

		bsr	triterm			*  第二項を得る
		bne	return

		bra	expr_atoi


triterm_skip_colon:
		cmp.b	#OP_COLON,d5
		bne	expression_syntax_error

		bsr	next_token		*  演算子 : をスキップする
		bra	success


triterm_skip_term:
		link	a6,#term
		movem.l	d1/d6/a1,-(a7)
		lea	term(a6),a1
		sf	d6
		bsr	triterm			*  項をスキップする
		bne	triterm_skip_term_return

		bsr	expr_atoi
triterm_skip_term_return:
		movem.l	(a7)+,d1/d6/a1
		unlk	a6
		rts
****************************************************************
bool_or:
		bsr	bool_and
		bne	return

		cmp.b	#OP_BOOLOR,d5
		bne	success

		move.w	d6,-(a7)
bool_or_loop:
		bsr	expr_atoi
		bne	bool_error

		tst.b	d6
		beq	bool_or_1

		move.l	d1,d2
		seq	d6
bool_or_1:
		cmp.b	#OP_BOOLOR,d5
		bne	bool_done

		bsr	next_token

		move.l	d2,-(a7)
		bsr	bool_and
		move.l	(a7)+,d2
		tst.l	d0
		bne	bool_error

		bra	bool_or_loop

bool_done:
		move.w	(a7)+,d6
		beq	success

		move.l	d2,d1
		bra	booltoa

bool_error:
		move.w	(a7)+,d6
		bra	expr_error
****************************************************************
bool_and:
		bsr	bit_or
		bne	return

		cmp.b	#OP_BOOLAND,d5
		bne	success

		move.w	d6,-(a7)
bool_and_loop:
		bsr	expr_atoi
		bne	bool_error

		tst.b	d6
		beq	bool_and_1

		move.l	d1,d2
		sne	d6
bool_and_1:
		cmp.b	#OP_BOOLAND,d5
		bne	bool_done

		bsr	next_token

		move.l	d2,-(a7)
		bsr	bit_or
		move.l	(a7)+,d2
		tst.l	d0
		bne	bool_error

		bra	bool_and_loop
****************************************************************
bit_or:
		bsr	bit_xor
		bne	return
bit_or_loop:
		cmp.b	#OP_BITOR,d5
		bne	success

		lea	bit_xor(pc),a2
		bsr	dual_term
		bne	return

		tst.b	d6
		beq	bit_or_loop

		or.l	d2,d1
		bsr	expr_itoa
		bra	bit_or_loop
****************************************************************
bit_xor:
		bsr	bit_and
		bne	return
bit_xor_loop:
		cmp.b	#OP_BITXOR,d5
		bne	success

		lea	bit_and(pc),a2
		bsr	dual_term
		bne	return

		tst.b	d6
		beq	bit_xor_loop

		eor.l	d2,d1
		bsr	expr_itoa
		bra	bit_xor_loop
****************************************************************
bit_and:
		bsr	compare_string
		bne	return
bit_and_loop:
		cmp.b	#OP_BITAND,d5
		bne	success

		lea	compare_string(pc),a2
		bsr	dual_term
		bne	return

		tst.b	d6
		beq	bit_and_loop

		and.l	d2,d1
		bsr	expr_itoa
		bra	bit_and_loop
****************************************************************
compare_string:
		bsr	compare_less_or_greater
		bne	return
compare_string_loop:
		lea	strcmp(pc),a2
		moveq	#0,d1
		cmp.b	#OP_EQ,d5
		beq	do_compare_string

		not.b	d1
		cmp.b	#OP_NE,d5
		beq	do_compare_string

		lea	strpcmp(pc),a2
		cmp.b	#OP_NMATCH,d5
		beq	do_compare_string

		not.b	d1
		cmp.b	#OP_MATCH,d5
		bne	success
do_compare_string:
		bsr	next_token
		tst.b	d6
		beq	do_compare_ignore

		link	a6,#term2
		lea	term(a6),a3
		exg	a1,a3
		movem.l	d1/a2-a3,-(a7)
		bsr	compare_less_or_greater
		movem.l	(a7)+,d1/a2-a3
		exg	a1,a3
		bne	compare_string_error1

		exg	a0,a1
		exg	a1,a3
		moveq	#0,d0
		jsr	(a2)
		exg	a1,a3
		exg	a0,a1
		unlk	a6
		tst.l	d0
		bmi	expr_error
		bne	do_compare_string_1

		not.b	d1
do_compare_string_1:
		bsr	booltoa
		bra	compare_string_loop

do_compare_ignore:
		bsr	compare_less_or_greater
		bra	compare_string_loop

compare_string_error1:
		unlk	a6
		rts
****************************************************************
compare_less_or_greater:
		bsr	shift
		bne	return
compare_less_or_greater_loop:
		moveq	#%01,d3
		cmp.b	#OP_LT,d5
		beq	do_compare_less_or_greater

		moveq	#%11,d3
		cmp.b	#OP_GT,d5
		beq	do_compare_less_or_greater

		moveq	#%00,d3
		cmp.b	#OP_LE,d5
		beq	do_compare_less_or_greater

		moveq	#%10,d3
		cmp.b	#OP_GE,d5
		bne	success
do_compare_less_or_greater:
		movem.l	d3,-(a7)
		lea	shift(pc),a2
		bsr	dual_term
		movem.l	(a7)+,d3
		bne	return

		tst.b	d6
		beq	compare_less_or_greater_loop

		cmp.l	d2,d1
		bgt	compare_greater_than
		blt	compare_less_than

		btst	#0,d3
		bra	compare_less_or_greater_2

compare_greater_than:
		bchg	#1,d3
compare_less_than:
		btst	#1,d3
compare_less_or_greater_2:
		bsr	eq1_ne0
		bra	compare_less_or_greater_loop
****************************************************************
shift:
		bsr	add_sub
		bne	return
shift_loop:
		cmp.b	#OP_SHL,d5
		beq	do_shift

		cmp.b	#OP_SHR,d5
		bne	success
do_shift:
		movem.l	d5,-(a7)
		lea	add_sub(pc),a2
		bsr	dual_term
		movem.l	(a7)+,d3
		bne	return

		tst.b	d6
		beq	shift_loop

		cmp.b	#OP_SHL,d3
		beq	do_shl

		asr.l	d2,d1
		bra	do_shift_1

do_shl:
		asl.l	d2,d1
do_shift_1:
		bsr	expr_itoa
		bra	shift_loop
****************************************************************
add_sub:
		bsr	mul_div
		bne	return
add_sub_loop:
		cmp.b	#OP_PLUS,d5
		beq	do_add_sub

		cmp.b	#OP_MINUS,d5
		bne	success
do_add_sub:
		movem.l	d5,-(a7)
		lea	mul_div(pc),a2
		bsr	dual_term
		movem.l	(a7)+,d3
		bne	return

		tst.b	d6
		beq	add_sub_loop

		cmp.b	#OP_PLUS,d3
		beq	do_add

		neg.l	d2
do_add:
		add.l	d2,d1
do_add_sub_1:
		bsr	expr_itoa
		bra	add_sub_loop
****************************************************************
mul_div:
		bsr	unary
		bne	return
mul_div_loop:
		cmp.b	#OP_MUL,d5
		beq	do_mul_div

		cmp.b	#OP_DIV,d5
		beq	do_mul_div

		cmp.b	#OP_MOD,d5
		bne	success
do_mul_div:
		movem.l	d5,-(a7)
		lea	unary(pc),a2
		bsr	dual_term
		movem.l	(a7)+,d3
		bne	return

		tst.b	d6
		beq	mul_div_loop

		move.l	d1,d0
		move.l	d2,d1
		cmp.b	#OP_MUL,d3
		beq	do_mul_div_mul

		tst.l	d1
		beq	div_mod_by_0

		bsr	divsl
		cmp.b	#OP_DIV,d3
		beq	do_mul_div_1
		bra	do_mul_div_2

do_mul_div_mul:
		bsr	mulsl
do_mul_div_1:
		move.l	d0,d1
do_mul_div_2:
		bsr	expr_itoa
		bra	mul_div_loop

div_mod_by_0:
		cmp.b	#OP_DIV,d3
		beq	divide_by_0
		bra	mod_by_0
****************************************************************
unary:
		movea.l	a0,a2
		move.w	d5,d3
		bra	unary_1

unary_2:
		bsr	next_token
unary_1:
		bsr	operator
		cmp.b	#OP_PLUS,d5
		beq	unary_2

		cmp.b	#OP_MINUS,d5
		beq	unary_2

		cmp.b	#OP_BITNOT,d5
		beq	unary_2

		cmp.b	#OP_BOOLNOT,d5
		beq	unary_2

		move.w	d3,d5
		movem.l	a0/a2,-(a7)
		bsr	primary
		movea.l	a0,a3
		movem.l	(a7)+,a0/a2
		exg	a0,a3
		bne	return

		cmpa.l	a2,a3
		beq	unary_return

		bsr	expr_atoi
		bne	return
unary_more:
		moveq	#0,d0
		cmpa.l	a2,a3
		beq	unary_done
unary_backup:
		subq.l	#1,a3
		cmpa.l	a2,a3
		beq	unary_backup_done

		tst.b	-1(a3)
		bne	unary_backup
unary_backup_done:
		exg	a0,a3
		move.w	d7,-(a7)
		moveq	#1,d7
		bsr	operator
		move.w	(a7)+,d7
		exg	a0,a3
		cmp.b	#OP_PLUS,d5
		beq	unary_more

		cmp.b	#OP_MINUS,d5
		beq	unary_minus

		cmp.b	#OP_BITNOT,d5
		beq	unary_bitnot
unary_boolnot:
		bsr	boolize
		eor.b	#1,d1
		bra	unary_more

unary_bitnot:
		not.l	d1
		bra	unary_more

unary_minus:
		neg.l	d1
		bra	unary_more

unary_done:
		bsr	expr_itoa
unary_return:
		bra	operator
****************************************************************
primary:
		subq.w	#1,d7
		bcs	expression_syntax_error

		move.b	(a0),d0
**
**  ( expression ) ?
**
		cmp.b	#'(',d0
		bne	primary_not_expression

		tst.b	1(a0)
		bne	primary_not_expression
		*{
			addq.l	#2,a0
			bsr	sub_expression
			bne	return

			subq.w	#1,d7
			bcs	expression_syntax_error

			cmpi.b	#')',(a0)+
			bne	expression_syntax_error

			tst.b	(a0)+
			bne	expression_syntax_error

			bra	success
		*}

primary_not_expression:
**
**  { command } ?
**
		cmp.b	#'{',d0
		bne	primary_not_command

		tst.b	1(a0)
		bne	primary_not_command
		*{
			addq.l	#2,a0
			movea.l	a0,a2
			moveq	#0,d0
primary_command_count_loop:
			tst.w	d7
			beq	no_close_brace

			cmpi.b	#'}',(a2)
			bne	primary_command_count_continue

			tst.b	1(a2)
			beq	primary_command_count_break
primary_command_count_continue:
			exg	a0,a2
			bsr	next_token
			exg	a0,a2
			addq.w	#1,d0
			bra	primary_command_count_loop

primary_command_count_break:
			moveq	#1,d1
			move.b	d6,d2
			not.b	d2
			jsr	fork
			tst.l	d0
			bsr	eq1_ne0
			movea.l	a2,a0
			bsr	next_token
			bra	success
		*}

primary_not_command:
**
**  -l name ?
**
		cmp.b	#'-',d0
		bne	primary_not_file_examination

		tst.b	2(a0)
		bne	primary_not_file_examination

		move.b	1(a0),d0
		cmp.b	#'z',d0				*  -z : csh
		beq	primary_file_zero

		cmp.b	#'t',d0
		beq	primary_isatty

		sf	d3
		cmp.b	#'b',d0
		beq	primary_devicetype

		st	d3
		cmp.b	#'c',d0
		beq	primary_devicetype

		sf	d3
		moveq	#FILEMODE_DIRECTORY,d2
		cmp.b	#'d',d0				*  -d : csh
		beq	primary_file_mode

		moveq	#FILEMODE_ARCHIVE,d2
		cmp.b	#'a',d0				*  -a : fish
		beq	primary_file_mode

		moveq	#FILEMODE_HIDDEN,d2
		cmp.b	#'h',d0				*  -h : fish
		beq	primary_file_mode

		moveq	#FILEMODE_SYSTEM,d2
		cmp.b	#'s',d0				*  -s : fish
		beq	primary_file_mode

		moveq	#FILEMODE_VOLUME,d2
		cmp.b	#'v',d0				*  -v : fish
		beq	primary_file_mode

		st	d3
		moveq	#FILEMODE_READONLY,d2
		cmp.b	#'w',d0				*  -w : csh
		beq	primary_file_mode

		moveq	#FILEMODE_SYSTEM+FILEMODE_VOLUME+FILEMODE_DIRECTORY,d2
		cmp.b	#'f',d0				*  -f : csh
		beq	primary_file_mode

		moveq	#0,d2
		cmp.b	#'e',d0				*  -e : csh
		bne	primary_not_file_examination
		* {
primary_file_mode:
			bsr	stat_operand
			bpl	return

			moveq	#0,d1
			move.b	filebuf+21(a6),d1
			and.b	d2,d1
switchable_booltoa:
			tst.b	d3
			beq	booltoa

			tst.b	d1
			bra	eq1_ne0

primary_file_zero:
			bsr	stat_operand
			bpl	return

			tst.l	filebuf+26(a6)
			bra	eq1_ne0

primary_devicetype:
			bsr	next_token__expand
			bne	expr_error

			tst.b	d6
			beq	store_0

			exg	a0,a1
			moveq	#2,d0
			bsr	tfopen
			exg	a0,a1
			move.l	d0,d2
			bmi	store_0

			moveq	#0,d1
			bsr	isblkdev
			seq	d1
			move.w	d2,d0
			bsr	fclose
			bra	switchable_booltoa

primary_isatty:
			bsr	next_token__expand
			bne	expr_error

			bsr	expr_atoi
			bne	expr_error

			tst.b	d6
			beq	store_0

			cmp.l	#$ffff,d1
			bhi	store_0

			move.w	d1,-(a7)
			clr.w	-(a7)
			DOS	_IOCTRL
			addq.l	#4,a7
			move.l	d0,d1
			bmi	store_0

			btst	#7,d1
			beq	store_0			*  Not a character device.

			and.l	#3,d1			*  ttyin or ttyout
			bra	booltoa
		*}

primary_not_file_examination:
**
**  sizeof file ?
**
		move.l	a1,-(a7)
		lea	token_sizeof,a1
		bsr	strcmp
		movea.l	(a7)+,a1
		bne	primary_not_sizeof
		*{
			bsr	stat_operand
			bpl	return

			move.l	filebuf+26(a6),d1
			bra	expr_itoa
		*}

primary_not_sizeof:
**
**  timeof file ?
**
		move.l	a1,-(a7)
		lea	token_timeof,a1
		bsr	strcmp
		movea.l	(a7)+,a1
		bne	primary_not_timeof
		*{
			bsr	stat_operand
			bpl	return

			move.w	filebuf+24(a6),d1
			swap	d1
			move.w	filebuf+22(a6),d1
			bra	expr_itoa
		*}

primary_not_timeof:
**
**  freeof drive: ?
**
		move.l	a1,-(a7)
		lea	token_freeof,a1
		bsr	strcmp
		movea.l	(a7)+,a1
		bne	primary_not_freeof
		*{
			bsr	next_token__expand
			bne	expr_error

			tst.b	d6
			beq	store_0

			move.b	(a1),d0
			beq	expression_syntax_error

			cmpi.b	#':',1(a1)
			bne	expression_syntax_error

			tst.b	2(a1)
			bne	expression_syntax_error

			cmp.b	#'@',d0
			bne	primary_freeof_1

			DOS	_CURDRV
			add.b	#'A',d0
primary_freeof_1:
			move.b	d0,d1
			bsr	drvchk
			bne	store_0

			moveq	#0,d0
			move.b	d1,d0
			bsr	toupper
			sub.b	#'@',d0
			pea	dfbuf(a6)
			move.w	d0,-(a7)
			DOS	_DSKFRE
			addq.l	#6,a7
			move.l	d0,d1
			bmi	store_0

			bra	expr_itoa
		*}

primary_not_freeof:
**
**  strlen string ?
**
		move.l	a1,-(a7)
		lea	token_strlen,a1
		bsr	strcmp
		movea.l	(a7)+,a1
		bne	primary_not_strlen
		*{
			bsr	next_token__expand
			bne	expr_error

			tst.b	d6
			beq	store_0

			exg	a0,a1
			bsr	strlen
			exg	a0,a1
			move.l	d0,d1
			bra	expr_itoa
		*}

primary_not_strlen:
**
**  normal primary word
**
		cmp.b	#OP_MATCH,d5
		beq	primary_pattern

		cmp.b	#OP_NMATCH,d5
		bne	expr_expand_a_word
primary_pattern:
		bsr	escape_quoted
		bra	expr_expand_ok
****************************************************************
next_token__expand:
		bsr	next_token
		bcs	expression_syntax_error
expr_expand_a_word:
		move.l	#MAXWORDLEN,d1
		bsr	expand_a_word
		bpl	expr_expand_ok

		cmp.l	#-1,d0
		beq	expr_ambiguous

		cmp.l	#-2,d0
		beq	too_long_word

		cmp.l	#-3,d0
		beq	too_long_word

		cmp.l	#-4,d0
		beq	expr_error

		clr.b	(a1)
expr_expand_ok:
		bsr	for1str
		bra	success

expr_ambiguous:
		bsr	pre_perror
		lea	msg_ambiguous,a0
		bra	enputs1
****************************************************************
stat_operand:
		bsr	next_token__expand
		bne	expr_error

		tst.b	d6
		beq	store_0

		movem.l	a0-a1,-(a7)
		movea.l	a1,a0
		lea	filebuf(a6),a1
		bsr	stat
		movem.l	(a7)+,a0-a1
		bmi	store_0

		moveq	#-1,d0
		rts
****************************************************************
operator:
		move.l	a1,-(a7)
		tst.w	d7
		beq	no_operator

		lea	operator_table,a1
		moveq	#1,d5
operator_loop:
		tst.b	(a1)
		beq	no_operator

		bsr	strcmp
		beq	operator_return

		addq.b	#1,d5
		addq.l	#3,a1
		bra	operator_loop

no_operator:
		moveq	#0,d5
operator_return:
		movea.l	(a7)+,a1
		bra	success
****************************************************************
next_token:
		bsr	for1str
		subq.w	#1,d7
		rts
****************************************************************
* dual_term
*
* CALL
*      A0     式の単語並び（右項）
*      A1     左項
*      A2     項を得るサブルーチンのエントリ・アドレス
*
* RETURN
*      A0     進む
*      A1     保存
*      D0.L   エラー
*      D1.L   左項の値
*      D2.L   右項の値
*      D6.L   次の演算子のコード
*      CCR    TST.L D0
*      その他は破壊
****************************************************************
dual_term:
		bsr	expr_atoi		* 左項を数値に変換する
		bne	return

		bsr	next_token		* 演算子をスキップする

		movem.l	d1/a1,-(a7)
		link	a6,#term
		lea	term(a6),a1
		jsr	(a2)			* 右項を得る
		bne	dual_term_2

		bsr	expr_atoi		* 右項を数値に変換する
		bne	dual_term_2

		move.l	d1,d2
		moveq	#0,d0
dual_term_2:
		unlk	a6
		movem.l	(a7)+,d1/a1
		rts
****************************************************************
* expr_atoi
*
* CALL
*      A1     単語
*
* RETURN
*      D0.L   エラー
*      D1.L   単語の値
*      CCR    TST.L D0
****************************************************************
.xdef expr_atoi

expr_atoi:
		movem.l	d2/a2,-(a7)
		movea.l	a1,a2
		move.b	(a2)+,d0
		cmpi.b	#'+',d0
		beq	expr_atoi_plus

		cmpi.b	#'-',d0
		beq	expr_atoi_minus

		subq.l	#1,a2
expr_atoi_plus:
		bsr	expr_atou
expr_atoi_return:
		movem.l	(a7)+,d2/a2
		tst.l	d0
		rts
****************
expr_atoi_minus:
		bsr	expr_atou
		neg.l	d1
		bra	expr_atoi_return
****************
expr_atou:
		moveq	#0,d0
		move.b	(a2)+,d0
		bsr	isdigit
		bne	expression_syntax_error

		moveq	#0,d1
		cmp.b	#'0',d0
		bne	expr_atou_decimal

		move.b	(a2)+,d0
		cmp.b	#'x',d0
		beq	expr_atou_hexa_decimal

		cmp.b	#'X',d0
		beq	expr_atou_hexa_decimal
expr_atou_octal:
		sub.b	#'0',d0
		blo	expr_atou_1

		cmp.b	#7,d0
		bhi	expr_atou_1

		lsl.l	#3,d1
		add.l	d0,d1
		move.b	(a2)+,d0
		bra	expr_atou_octal

expr_atou_decimal:
		sub.b	#'0',d0
		blo	expr_atou_1

		cmp.b	#9,d0
		bhi	expr_atou_1

		move.l	d1,d2
		swap	d2
		mulu	#10,d2
		swap	d2
		clr.w	d2
		mulu	#10,d1
		add.l	d2,d1
		add.l	d0,d1
		move.b	(a2)+,d0
		bra	expr_atou_decimal

expr_atou_hexa_decimal:
		move.b	(a2)+,d0
		sub.b	#'0',d0
		blo	expr_atou_1

		cmp.b	#9,d0
		blo	expr_atou_hexa_decimal_1

		add.b	#'0',d0
		bsr	toupper
		cmp.b	#'A',d0
		blo	expr_atou_1

		cmp.b	#'F',d0
		bhi	expr_atou_1

		sub.b	#'A'-10,d0
expr_atou_hexa_decimal_1:
		lsl.l	#4,d1
		add.l	d0,d1
		bra	expr_atou_hexa_decimal

expr_atou_1:
		tst.b	-(a2)
		bne	expression_syntax_error

		bra	success
****************************************************************
.xdef expr_itoa

expr_itoa:
		move.l	d1,d0
		exg	a0,a1
		bsr	itoa
		exg	a0,a1
		bra	success
****************************************************************
eq1_ne0:
		beq	store_1
		bra	store_0

booltoa:
		tst.l	d1
		beq	store_0
store_1:
		move.b	#'1',(a1)
		bra	boolstore_done

store_0:
		move.b	#'0',(a1)
boolstore_done:
		clr.b	1(a1)
success:
		moveq	#0,d0
return:
		rts
****************************************************************
boolize:
		tst.l	d1
		beq	boolize_done

		moveq	#1,d1
boolize_done:
		rts
****************************************************************
.xdef divide_by_0
.xdef mod_by_0

divide_by_0:
		lea	msg_divide_by_0,a0
		bra	command_error

mod_by_0:
		lea	msg_mod_by_0,a0
		bra	command_error

expr_error:
		moveq	#1,d0
		rts
****************************************************************
.data

operator_table:
		dc.b	',',0,0
		dc.b	'?',0,0
		dc.b	':',0,0
		dc.b	'||',0
		dc.b	'&&',0
		dc.b	'|',0,0
		dc.b	'^',0,0
		dc.b	'&',0,0
		dc.b	'==',0
		dc.b	'!=',0
		dc.b	'=~',0
		dc.b	'!~',0
		dc.b	'<',0,0
		dc.b	'>',0,0
		dc.b	'<=',0
		dc.b	'>=',0
		dc.b	'<<',0
		dc.b	'>>',0
		dc.b	'+',0,0
		dc.b	'-',0,0
		dc.b	'*',0,0
		dc.b	'/',0,0
		dc.b	'%',0,0
		dc.b	'~',0,0
		dc.b	'!',0,0
		dc.b	0

token_sizeof:	dc.b	'sizeof',0
token_timeof:	dc.b	'timeof',0
token_freeof:	dc.b	'freeof',0
token_strlen:	dc.b	'strlen',0

msg_divide_by_0:		dc.b	'0での除算があります',0
msg_mod_by_0:			dc.b	'0での剰余があります',0

.end
