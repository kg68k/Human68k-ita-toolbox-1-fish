* getline.s
* Itagaki Fumihiko 29-Jul-90  Create.

.include doscall.h
.include chrcode.h
.include limits.h
.include ../src/fish.h
.include ../src/source.h
.include ../src/history.h

.xref iscntrl
.xref isdigit
.xref issjis
.xref isspace
.xref tolower
.xref toupper
.xref atou
.xref utoa
.xref strbot
.xref strchr
.xref strcpy
.xref strlen
.xref memcmp
.xref memxcmp
.xref memmovi
.xref memmovd
.xref rotate
.xref skip_space
.xref for1str
.xref fornstrs
.xref sort_wordlist
.xref close_source
.xref putc
.xref cputc
.xref puts
.xref put_newline
.xref printfi
.xref printfs
.xref builtin_dir_match
.xref isttyin
.xref fgets
.xref fclose
.xref open_passwd
.xref expand_tilde
.xref includes_dos_wildcard
.xref test_pathname
.xref find_shellvar
.xref common_spell
.xref getcwdx
.xref search_up_history
.xref search_down_history
.xref is_histchar_canceller
.xref divul
.xref drvchkp
.xref manage_interrupt_signal
.xref too_long_line
.xref command_table
.xref word_prompt
.xref word_prompt2
.xref dos_allfile
.xref congetbuf
.xref tmpargs

.xref history_top
.xref history_bot
.xref current_eventno
.xref current_source
.xref switch_status
.xref if_status
.xref loop_status
.xref histchar1
.xref flag_usegets
.xref flag_cifilec
.xref flag_nobeep
.xref last_congetbuf
.xref keymap
.xref keymacromap
.xref linecutbuf

auto_word = (((MAXWORDLEN+1)+1)>>1<<1)
auto_dirbuf = (((53)+1)>>1<<1)

.text

*****************************************************************
* getline
*
* CALL
*      A0     入力バッファの先頭
*      D1.W   入力最大バイト数（32767以下．最後のNUL分は勘定しない）
*      D2.B   1 ならばコメントを削除する
*      A1     プロンプト出力ルーチンのエントリ・アドレス
*      A2     物理行入力ルーチンのエントリ・アドレス
*      D7.L   (A2) への引数 D0.L
*
* RETURN
*      D0.L   0:入力有り，-1:EOF，1:入力エラー
*      D1.W   残り入力可能バイト数（最後のNUL分は勘定しない）
*      CCR    TST.L D0
*****************************************************************
.xdef getline

getline:
		movem.l	d3-d6/a0-a4,-(a7)
		moveq	#0,d3				*  D3.B : 全体クオート・フラグ
getline_more:
		**
		**  １物理行を入力する
		**
		movea.l	a0,a4
		move.l	d7,d0
		jsr	(a2)
		bne	getline_return

		cmpa.l	a4,a0				*  入力された文字数が0ならば
		beq	getline_done			*  終わり

		suba.l	a1,a1
****************
		move.b	d3,d5				*  行の先頭でのクオート・フラグを保存
		**
		**  行継続をチェックする
		**
		movea.l	a4,a3
getline_cont_check_loop:
		cmpa.l	a0,a3
		beq	getline_not_cont

		move.b	(a3)+,d0
		bsr	issjis
		beq	getline_cont_check_sjis

		cmp.b	#'"',d0
		beq	getline_cont_check_quote

		cmp.b	#"'",d0
		beq	getline_cont_check_quote

		cmp.b	#'\',d0
		bne	getline_cont_check_loop

		cmpa.l	a0,a3
		beq	getline_cont_check_done		*  D0.B is always '\' here.

		move.b	(a3),d0
		bsr	issjis
		beq	getline_cont_check_loop
getline_cont_check_skip:
		addq.l	#1,a3
		bra	getline_cont_check_loop

getline_cont_check_quote:
		tst.b	d3
		bne	getline_cont_check_loop

		eor.b	d0,d3
		bra	getline_cont_check_loop

getline_cont_check_sjis:
		cmpa.l	a0,a3
		bne	getline_cont_check_skip
getline_not_cont:
		moveq	#0,d0
getline_cont_check_done:
		move.b	d0,d6				*  D6.B : 行継続フラグ
		beq	getline_process_comment

		move.b	#' ',-1(a0)
		tst.b	d3
		beq	getline_process_comment

		move.b	#CR,-1(a0)
		subq.w	#1,d1
		bcs	getline_over

		move.b	#LF,(a0)+
****************
getline_process_comment:
		tst.b	d2
		beq	getline_comment_cut_done
		**
		**  コメントを探す
		**
		moveq	#0,d4				*  D4.L : {}レベル
find_comment_loop:
		move.b	(a4)+,d0
		beq	find_comment_break

		bsr	issjis
		beq	find_comment_skip_one

		tst.l	d4
		beq	find_comment_0

		cmp.b	#'}',d0
		bne	find_comment_0

		subq.l	#1,d4
find_comment_0:
		tst.b	d5
		beq	find_comment_1

		cmp.b	d5,d0
		bne	find_comment_loop
find_comment_flip_quote:
		eor.b	d0,d5
		bra	find_comment_loop

find_comment_1:
		tst.l	d4
		bne	find_comment_2

		cmp.b	#'#',d0
		beq	find_comment_break
find_comment_2:
		cmp.b	#'\',d0
		beq	find_comment_ignore_next_char

		cmp.b	#'"',d0
		beq	find_comment_flip_quote

		cmp.b	#"'",d0
		beq	find_comment_flip_quote

		cmp.b	#'`',d0
		beq	find_comment_flip_quote

		cmp.b	#'$',d0
		beq	find_comment_special

		cmp.b	#'!',d0
		bne	find_comment_loop
find_comment_special:
		cmpi.b	#'{',(a4)
		bne	find_comment_ignore_next_char

		addq.l	#1,a4
		addq.l	#1,d4
		bra	find_comment_loop

find_comment_ignore_next_char:
		move.b	(a4)+,d0
		beq	find_comment_break

		bsr	issjis
		bne	find_comment_loop
find_comment_skip_one:
		move.b	(a4)+,d0
		bne	find_comment_loop
find_comment_break:
		**
		**  コメントを削除する
		**
		clr.b	-(a4)
		move.l	a0,d0
		sub.l	a4,d0
		add.w	d0,d1
		movea.l	a4,a0
getline_comment_cut_done:
		tst.b	d6
		bne	getline_more
getline_done:
		moveq	#0,d0
getline_return:
		movem.l	(a7)+,d3-d6/a0-a4
		rts

getline_over:
		moveq	#1,d0
		bra	getline_return
*****************************************************************
* getline_phigical
*
* CALL
*      A0     入力バッファの先頭
*      A1     プロンプト出力ルーチンのエントリ・アドレス
*      D0.W   入力ファイル・ハンドル
*      D1.W   入力最大バイト数（32767以下．最後のNUL分は勘定しない）
*
* RETURN
*      A0     入力文字数分進む
*      D0.L   0:入力有り，-1:EOF，1:入力エラー
*      D1.W   残り入力可能バイト数（最後のNUL分は勘定しない）
*      CCR    TST.L D0
*****************************************************************
.xdef getline_phigical

getline_phigical:
		tst.l	current_source(a5)
		beq	getline_phigical_stdin

		bsr	getline_phigical_script
		bra	getline_phigical_1

getline_phigical_stdin:
		bsr	getline_file
getline_phigical_1:
		beq	getline_phigical_return
		bpl	too_long_line
getline_phigical_return:
		rts
****************
getline_phigical_script:
		DOS	_KEYSNS				*  To allow interrupt
		movem.l	d2/a1-a2,-(a7)
		movea.l	current_source(a5),a1
		movea.l	a1,a2
		adda.l	SOURCE_SIZE(a1),a2
		movea.l	SOURCE_POINTER(a1),a1
		moveq	#0,d2
getline_phigical_script_loop:
		cmpa.l	a2,a1
		bhs	getline_phigical_script_eof

		move.b	(a1)+,d0
		cmp.b	#LF,d0
		beq	getline_phigical_script_lf

		cmp.b	#CR,d0
		bne	getline_phigical_script_dup1

		cmpa.l	a2,a1
		bhs	getline_phigical_script_eof

		cmpi.b	#LF,(a1)
		beq	getline_phigical_script_crlf
getline_phigical_script_dup1:
		subq.w	#1,d1
		bcs	getline_phigical_script_over

		move.b	d0,(a0)+
		bra	getline_phigical_script_loop

getline_phigical_script_over:
		addq.w	#1,d1
		moveq	#1,d2
		bra	getline_phigical_script_loop

getline_phigical_script_crlf:
		addq.l	#1,a1
getline_phigical_script_lf:
		clr.b	(a0)
		movea.l	current_source(a5),a2
		move.l	a1,SOURCE_POINTER(a2)
		addq.l	#1,SOURCE_LINENO(a2)
getline_phigical_script_return:
		move.l	d2,d0
		movem.l	(a7)+,d2/a1-a2
		rts

getline_phigical_script_eof:
		bsr	close_source
		moveq	#-1,d2
		bra	getline_phigical_script_return
*****************************************************************
.xdef getline_file

getline_file:
		movem.l	d0,-(a7)
		bsr	isttyin
		movem.l	(a7)+,d0
		bne	getline_console

		bra	fgets
*****************************************************************
getline_console:
		bsr	put_prompt
		tst.b	flag_usegets(a5)
		beq	getline_x

getline_standard_console:
		move.l	a1,-(a7)

		move.l	a0,-(a7)
		lea	congetbuf,a0
		move.l	a0,-(a7)
		move.b	#255,(a0)+

		lea	last_congetbuf(a5),a1
		move.b	(a1)+,(a0)+
		bsr	strcpy
		DOS	_GETS
		addq.l	#4,a7
		bsr	put_newline
		lea	congetbuf+1,a0
		tst.b	(a0)+
		beq	getline_console_done

		bsr	skip_space
		tst.b	(a0)
		beq	getline_console_done

		lea	congetbuf+1,a1
		lea	last_congetbuf(a5),a0
		move.b	(a1)+,(a0)+
		bsr	strcpy
getline_console_done:
		movea.l	(a7)+,a0

		lea	congetbuf+1,a1
		clr.w	d0
		move.b	(a1)+,d0
		sub.w	d0,d1
		bcs	getline_console_over

		bsr	memmovi
getline_console_ok:
		clr.b	(a0)
		moveq	#0,d0
getline_console_return:
		movea.l	(a7)+,a1
		rts

getline_console_over:
		moveq	#1,d0
		bra	getline_console_return

getline_console_eof:
		moveq	#-1,d0
		bra	getline_console_return
*****************************************************************

search_word = -32
put_prompt_ptr = search_word-4
macro_ptr = put_prompt_ptr-4
line_top = macro_ptr-4
x_histptr = line_top-4
input_handle = x_histptr-4
mark = input_handle-2
point = mark-2
nbytes = point-2
keymap_offset = nbytes-2
quote = keymap_offset-1
killing = quote-1
x_histflag = killing-1
pad = x_histflag-1				*  偶数バウンダリーに合わせる

getline_x:
		link	a6,#pad
		movem.l	d2-d7/a1-a3,-(a7)
		move.w	d0,input_handle(a6)
		move.l	a0,line_top(a6)
		move.l	a1,put_prompt_ptr(a6)
		clr.l	macro_ptr(a6)
		clr.w	nbytes(a6)
		clr.w	point(a6)
		move.w	#-1,mark(a6)
getline_x_0:
		sf	quote(a6)
getline_x_1:
		bsr	reset_history_ptr
getline_x_2:
		sf	killing(a6)
getline_x_3:
		clr.w	keymap_offset(a6)
getline_x_4:
		bsr	getline_x_getc
		bmi	getline_x_eof

		tst.b	quote(a6)
		bne	x_self_insert

		tst.b	d0
		bmi	x_self_insert

		moveq	#0,d2
		move.b	d0,d2
		add.w	keymap_offset(a6),d2
		lea	keymap(a5),a0
		moveq	#0,d3
		move.b	(a0,d2.l),d3
		lsl.l	#2,d3
		lea	key_function_jump_table,a0
		movea.l	(a0,d3.l),a0
		jmp	(a0)


getline_x_eof:
		moveq	#-1,d0
getline_x_return:
		movem.l	(a7)+,d2-d7/a1-a3
		unlk	a6
		rts
********************************
reset_history_ptr:
		movea.l	history_bot(a5),a0
		move.l	a0,x_histptr(a6)
		clr.b	x_histflag(a6)
		rts
********************************
*  self-insert
********************************
x_self_insert:
		move.b	d0,d4				*  D4.B : 第１バイト
		moveq	#1,d2				*  D2.W : 挿入するバイト数
		bsr	issjis
		sne	d3				*  D3.B : 「シフトJIS文字である」
		bne	x_self_insert_1

		bsr	getline_x_getc
		bmi	getline_x_eof

		move.b	d0,d5				*  D5.B : シフトJISの第２バイト
		moveq	#2,d2
x_self_insert_1:
		bsr	open_columns
		bcs	x_self_insert_over

		move.b	d4,(a0)
		tst.b	d3
		bne	x_self_insert_2

		move.b	d5,1(a0)
x_self_insert_2:
		bsr	post_insert_job
x_self_insert_done:
		bra	getline_x_0

x_self_insert_over:
		bsr	beep
		bra	x_self_insert_done
********************************
*  error
********************************
x_error:
		bsr	beep
		bra	getline_x_2
********************************
*  macro
********************************
x_macro:
		tst.l	macro_ptr(a6)
		bne	x_error				*  マクロでマクロは呼び出せないのだ

		lea	keymacromap(a5),a0
		lsl.l	#2,d2
		move.l	(a0,d2.l),macro_ptr(a6)
		bra	getline_x_2
********************************
*  prefix-1
********************************
x_prefix_1:
		move.w	#128,keymap_offset(a6)
		bra	getline_x_4
********************************
*  prefix-2
********************************
x_prefix_2:
		move.w	#256,keymap_offset(a6)
		bra	getline_x_4
********************************
*  abort
********************************
x_abort:
		bsr	cputc
		bsr	put_newline
		bra	manage_interrupt_signal
********************************
*  eof
********************************
********************************
*  cr
********************************
x_eof:
		bsr	iscntrl
		sne	d1
		bsr	cputc
		moveq	#2,d0
		tst.b	d1
		beq	x_eof_1

		moveq	#1,d0
x_eof_1:
		bsr	backward_cursor
		tst.w	nbytes(a6)
		beq	getline_x_eof

		move.w	point(a6),nbytes(a6)
x_accept_line:
		bsr	eol_newline
		movea.l	line_top(a6),a0
		move.w	nbytes(a6),d0
		lea	(a0,d0.w),a0
		clr.b	(a0)
		moveq	#0,d0
		bra	getline_x_return
********************************
*  quoted-insert
********************************
x_quoted_insert:
		st	quote(a6)
		bra	getline_x_2
********************************
*  redraw
********************************
********************************
*  clear-and-redraw
********************************
x_clear_and_redraw:
		lea	t_clear,a0
		bsr	puts
		bra	x_redraw_1

x_redraw:
		bsr	eol_newline
x_redraw_1:
		bsr	redraw_with_prompt
		bra	getline_x_2
********************************
*  set-mark
********************************
x_set_mark:
		move.w	point(a6),mark(a6)
		bra	getline_x_2
********************************
*  exchange-point-and-mark
********************************
x_exg_point_and_mark:
		move.w	mark(a6),d0
		bmi	x_error

		move.w	point(a6),mark(a6)
x_goto:
		move.w	point(a6),d2			*  D2.W : point
		move.w	d0,point(a6)
		movea.l	line_top(a6),a0
		lea	backward_cursor_x(pc),a1
		cmp.w	d0,d2
		bhi	x_exg_point_and_mark_2

		lea	forward_cursor_x(pc),a1
		exg	d0,d2
x_exg_point_and_mark_2:
		lea	(a0,d0.w),a0
		sub.w	d0,d2
		move.w	d2,d0
		jsr	(a1)
		bra	getline_x_2
********************************
*  search-character
********************************
x_search_character:
		bsr	getline_x_getletter
		bmi	getline_x_eof

		movea.l	line_top(a6),a0
		move.w	nbytes(a6),d2
		clr.b	(a0,d2.w)
		move.w	point(a6),d4
		cmp.w	d2,d4
		beq	x_search_char_1

		exg	d0,d4
		bsr	x_size_forward
		exg	d0,d4
		add.w	d2,d4
		lea	(a0,d4.w),a0
		bsr	strchr
		bne	x_search_char_ok
x_search_char_1:
		movea.l	line_top(a6),a0
		bsr	strchr
		beq	x_error
x_search_char_ok:
		move.l	a0,d0
		movea.l	line_top(a6),a0
		sub.l	a0,d0
		bra	x_goto
********************************
*  beginning-of-line
********************************
x_bol:
		movea.l	line_top(a6),a0
		move.w	point(a6),d0
		bsr	backward_cursor_x
		clr.w	point(a6)
		bra	getline_x_2
********************************
*  end-of-line
********************************
x_eol:
		bsr	move_cursor_to_eol
		move.w	nbytes(a6),point(a6)
		bra	getline_x_2
********************************
*  backward-char
********************************
x_backward_char:
		bsr	move_letter_backward
		bra	getline_x_2
********************************
*  forward-char
********************************
x_forward_char:
		bsr	move_letter_forward
		bra	getline_x_2
********************************
*  backward-word
********************************
x_backward_word:
		bsr	move_word_backward
		bra	getline_x_2
********************************
*  forward-word
********************************
x_forward_word:
		bsr	move_word_forward
		bra	getline_x_2
********************************
*  delete-backward-char
********************************
x_del_back_char:
		bsr	move_letter_backward
		move.w	point(a6),d4
xp_delete:
		bsr	delete_region
		bra	getline_x_1
********************************
*  delete-forward-char
********************************
x_del_for_char:
		move.w	point(a6),d4
		bsr	forward_letter
		move.w	d4,point(a6)
		bra	xp_delete
********************************
*  kill-backward-word
********************************
x_kill_back_word:
		bsr	backward_word
		move.w	point(a6),d4
		moveq	#3,d7
		bra	x_kill_region_backward_1
********************************
*  kill-forward-word
********************************
x_kill_for_word:
		move.w	point(a6),d4
		bsr	forward_word
		moveq	#1,d7
		bra	x_kill_or_copy_region_2
********************************
*  kill-to-bol
********************************
x_kill_bol:
		moveq	#0,d4
		bra	x_kill_eol_1
********************************
*  kill-to-eol
********************************
x_kill_eol:
		move.w	nbytes(a6),d4
x_kill_eol_1:
		moveq	#1,d7
		bra	x_kill_or_copy_region_1
********************************
*  kill-region
********************************
********************************
*  copy-region
********************************
x_copy_region:
		moveq	#0,d7
		bra	x_kill_or_copy_region

x_kill_region:
		moveq	#1,d7
x_kill_or_copy_region:
		move.w	mark(a6),d0
		bmi	x_error

		move.w	d0,d4				*  D4.W : mark
x_kill_or_copy_region_1:
		move.w	point(a6),d2			*  D2.W : point
		cmp.w	d4,d2
		bhs	x_kill_region_backward

		exg	d2,d4
		bsr	compile_region
x_kill_or_copy_region_2:
		move.w	d4,point(a6)
x_kill_or_copy_region_3:
		move.b	d7,d0
		bsr	copy_region_to_buffer
		btst	#0,d7
		beq	x_kill_or_copy_region_done

		bsr	delete_region
x_kill_or_copy_region_done:
		bsr	reset_history_ptr
		bra	getline_x_3

x_kill_region_backward:
		bset	#1,d7
		bsr	compile_region
x_kill_region_backward_1:
		btst	#0,d7
		beq	x_kill_or_copy_region_3

		move.l	d3,d0
		bsr	backward_cursor
		bra	x_kill_or_copy_region_2

compile_region:
		movea.l	line_top(a6),a0
		lea	(a0,d4.w),a0
		sub.w	d4,d2
		move.w	d2,d0
		bsr	region_width
		move.l	d0,d3
		rts
********************************
*  yank
********************************
x_yank:
		lea	linecutbuf(a5),a0
		bsr	strlen
		move.l	d0,d2
		movea.l	a0,a1
		bsr	open_columns
		bcs	x_yank_over

		move.l	d2,d0
		move.l	a0,-(a7)
		bsr	memmovi
		movea.l	(a7)+,a0
		bsr	post_insert_job
x_yank_done:
		bra	getline_x_1

x_yank_over:
		bsr	beep
		bra	x_yank_done
********************************
*  upcase-char
********************************
x_upcase_char:
		lea	toupper(pc),a1
chcase_char:
		moveq	#1,d0
chcase:
		bsr	chcase_sub
		bra	getline_x_1

chcase_sub:
		move.w	point(a6),d4
		add.w	d0,d4
chcase_loop:
		move.w	point(a6),d3
		cmp.w	nbytes(a6),d3
		beq	chcase_done

		cmp.w	d4,d3
		bhs	chcase_done

		movea.l	line_top(a6),a0
		move.b	(a0,d3.w),d0
		jsr	(a1)
		cmp.b	(a0,d3.w),d0
		beq	chcase_char_not_changed

		move.b	d0,(a0,d3.w)
		bsr	putc
		bsr	forward_letter
		bra	chcase_loop

chcase_char_not_changed:
		bsr	move_letter_forward
		bra	chcase_loop

chcase_done:
		rts
********************************
*  downcase-char
********************************
x_downcase_char:
		lea	tolower(pc),a1
		bra	chcase_char
********************************
*  upcase-word
********************************
x_upcase_word:
		lea	toupper(pc),a1
chcase_word:
		move.w	point(a6),-(a7)
		bsr	forward_word
		move.w	(a7)+,point(a6)
		move.w	d2,d0
		bra	chcase
********************************
*  downcase-word
********************************
x_downcase_word:
		lea	tolower(pc),a1
		bra	chcase_word
********************************
*  upcase-region
********************************
x_upcase_region:
		lea	toupper(pc),a1
chcase_region:
		move.w	mark(a6),d0
		bmi	x_error

		move.w	point(a6),d2
		cmp.w	d0,d2
		bls	chcase_region_forward

		move.w	d0,point(a6)
		movea.l	line_top(a6),a0
		lea	(a0,d0.w),a0
		sub.w	d0,d2
		move.w	d2,d0
		bsr	backward_cursor_x
		move.w	d2,d0
		bra	chcase

chcase_region_forward:
		sub.w	d2,d0
		movem.l	d0/d2,-(a7)
		bsr	chcase_sub
		movem.l	(a7)+,d0/d2
		move.w	d2,point(a6)
		movea.l	line_top(a6),a0
		lea	(a0,d2.w),a0
		bsr	backward_cursor_x
		bra	getline_x_1
********************************
*  downcase-region
********************************
x_downcase_region:
		lea	tolower(pc),a1
		bra	chcase_region
********************************
*  transpose-chars
********************************
x_transpose_chars:
		move.w	point(a6),d0
		cmp.w	nbytes(a6),d0
		blo	x_transpose_chars_1

		bsr	move_letter_backward
x_transpose_chars_1:
		move.w	point(a6),d0
		beq	x_error

		bsr	x_size_forward
		move.w	d2,d4
		bsr	move_letter_backward
		bsr	transpose
		bra	getline_x_1
********************************
*  transpose-words
********************************
x_transpose_words:
		move.w	point(a6),d4
		bsr	move_word_forward
		bsr	move_word_backward
		move.w	point(a6),d0
		bne	x_transpose_word_ok

		move.w	d4,point(a6)
		move.w	d4,d0
		movea.l	line_top(a6),a0
		bsr	forward_cursor_x
		bra	x_error

x_transpose_word_ok:
		move.w	d2,d4				*  D4.W : 右の単語のバイト数
		bsr	move_word_backward
		move.w	d2,d5				*  D5.W : 左の単語＋スペースのバイト数
		move.l	d3,d6				*  D6.L : 左の単語＋スペースの文字幅
		move.w	point(a6),-(a7)
		bsr	forward_word			*  D2.W : 左の単語のバイト数
		move.w	(a7),point(a6)
		exg	d2,d5
		bsr	transpose
		sub.w	d2,point(a6)
		move.l	d6,d0
		bsr	backward_cursor
		move.w	d2,d4
		sub.w	d5,d4
		move.w	d5,d2
		bsr	transpose
		bra	getline_x_1
********************************
transpose:
		movea.l	line_top(a6),a0
		adda.w	point(a6),a0			*  正しい
		lea	(a0,d2.w),a1
		lea	(a1,d4.w),a2
		bsr	rotate
		move.w	d2,d0
		add.w	d4,d0
		bsr	write_chars
		move.w	mark(a6),d3
		bmi	transpose_done

		sub.w	point(a6),d3
		blo	transpose_done

		sub.w	d2,d3
		blo	transpose_mark_forward

		sub.w	d4,d3
		bhs	transpose_done

		sub.w	d2,mark(a6)
		bra	transpose_done

transpose_mark_forward:
		add.w	d4,mark(a6)
transpose_done:
		add.w	d0,point(a6)
		rts
********************************
*  up-history
********************************
x_up_history:
		movea.l	line_top(a6),a0
		moveq	#0,d0
		move.w	point(a6),d0

		movea.l	x_histptr(a6),a1
		btst.b	#0,x_histflag(a6)
		beq	x_up_history_1

		cmpa.l	#0,a1
		beq	x_up_history_2

		movea.l	HIST_PREV(a1),a1
x_up_history_1:
		moveq	#0,d2
		bsr	search_up_history
		bne	history_found
x_up_history_2:
		btst.b	#1,x_histflag(a6)
		beq	search_history_fail

		movea.l	history_bot(a5),a1
		moveq	#0,d2
		bsr	search_up_history
search_history_done:
		bne	history_found
search_history_fail:
		bset.b	#1,x_histflag(a6)
		bra	x_error

history_found:
		move.l	a1,x_histptr(a6)
		move.b	#1,x_histflag(a6)

		bsr	delete_line
		move.w	#-1,mark(a6)

		movea.l	line_top(a6),a0
		move.w	HIST_NWORDS(a1),d2		*  D2.W : このイベントの単語数
		subq.w	#1,d2
		bcs	copy_history_done

		lea	HIST_BODY(a1),a1		*  A1 : 履歴の単語並びの先頭
		bra	copy_history_start

copy_history_loop:
		subq.w	#1,d1
		bcs	copy_history_over

		move.b	#' ',(a0)+
		addq.w	#1,nbytes(a6)
copy_history_start:
copy_history_dup_word_loop:
		moveq	#0,d0
		move.b	(a1)+,d0
		beq	copy_history_continue

		bsr	issjis
		bne	copy_history_word_1

		lsl.w	#8,d0
		move.b	(a1)+,d0
		beq	copy_history_continue
copy_history_word_1:
		cmp.w	histchar1(a5),d0
		bne	copy_history_not_histchar

		move.b	(a1),d0
		bsr	is_histchar_canceller
		beq	copy_history_dup_histchar

		subq.w	#1,d1
		bcs	copy_history_over

		move.b	#'\',(a0)+
		addq.w	#1,nbytes(a6)
copy_history_dup_histchar:
		move.w	histchar1(a5),d0
		bra	copy_history_dup_1

copy_history_not_histchar:
		cmp.w	#'\',d0
		beq	copy_history_dup_escape
copy_history_dup_1:
		cmp.w	#$100,d0
		blo	copy_history_dup_1_1
copy_history_dup_1_2:
		subq.w	#1,d1
		bcs	copy_history_over

		move.w	d0,-(a7)
		lsr.w	#8,d0
		move.b	d0,(a0)+
		move.w	(a7)+,d0
		addq.w	#1,nbytes(a6)
copy_history_dup_1_1:
		subq.w	#1,d1
		bcs	copy_history_over

		move.b	d0,(a0)+
		addq.w	#1,nbytes(a6)
		bra	copy_history_dup_word_loop

copy_history_dup_escape:
		subq.w	#1,d1
		bcs	copy_history_over

		move.b	d0,(a0)+
		addq.w	#1,nbytes(a6)

		move.b	(a1)+,d0
		beq	copy_history_continue

		bsr	issjis
		bne	copy_history_dup_1_1

		lsl.w	#8,d0
		move.b	(a1)+,d0
		bne	copy_history_dup_1_2
copy_history_continue:
		dbra	d2,copy_history_loop
copy_history_done:
		move.w	nbytes(a6),point(a6)
		cmp.w	point(a6),d3
		bhi	copy_history_draw

		move.w	d3,point(a6)
copy_history_draw:
		bsr	redraw
		bra	getline_x_2

copy_history_over:
		addq.w	#1,d1
		bsr	beep
		bra	copy_history_done
********************************
*  down-history
********************************
x_down_history:
		movea.l	line_top(a6),a0
		moveq	#0,d0
		move.w	point(a6),d0

		movea.l	x_histptr(a6),a1
		btst.b	#0,x_histflag(a6)
		beq	x_down_history_1

		cmpa.l	#0,a1
		beq	x_down_history_2

		movea.l	HIST_NEXT(a1),a1
x_down_history_1:
		moveq	#0,d2
		bsr	search_down_history
		bne	history_found
x_down_history_2:
		btst.b	#1,x_histflag(a6)
		beq	search_history_fail

		movea.l	history_top(a5),a1
		moveq	#0,d2
		bsr	search_down_history
		bra	search_history_done
********************************
*  list
********************************
x_list:
		st	d7
		bra	x_filec_or_list
********************************
*  complete
********************************
x_complete:
		sf	d7

filec_dir_buf = -auto_dirbuf
filec_pattern = filec_dir_buf-auto_word
filec_pattern2 = filec_pattern-auto_word
filec_pattern_length = filec_pattern2-4
filec_fignore = filec_pattern_length-4
filec_buffer_free = filec_fignore-2
filec_maxlen = filec_buffer_free-2
filec_numentry = filec_maxlen-2
filec_listflag = filec_numentry-1
filec_condition = filec_listflag-1
filec_pad = filec_condition-0

x_filec_or_list:
		link	a4,#filec_pad
		move.b	d7,filec_listflag(a4)
		*
		*  対象の単語を取り出す
		*
		move.w	point(a6),d6
		movea.l	line_top(a6),a2
filec_find_word_remember:
		movea.l	a2,a1
filec_find_word_loop:
		subq.w	#1,d6
		bcs	filec_find_word_done

		moveq	#0,d0
		move.b	(a2)+,d0
		beq	filec_find_word_remember

		bsr	issjis
		beq	filec_find_word_sjis

		lea	filec_separators,a0
		bsr	strchr
		bne	filec_find_word_remember

		bra	filec_find_word_loop

filec_find_word_sjis:
		subq.w	#1,d6
		bcs	filec_find_word_done

		addq.l	#1,a2
		bra	filec_find_word_loop

filec_find_word_done:
		moveq	#0,d0
		move.w	point(a6),d0
		add.l	line_top(a6),d0
		sub.l	a1,d0
		cmp.l	#MAXWORDLEN,d0
		bhi	filec_fail

		lea	filec_pattern(a4),a0
		bsr	memmovi
		clr.b	(a0)

		clr.w	filec_numentry(a4)
filec_correct:
		moveq	#0,d0
		tst.b	filec_listflag(a4)
		bne	filec_no_fignore

		sf	filec_condition(a4)
		lea	word_fignore,a0
		bsr	find_shellvar
filec_no_fignore:
		move.l	d0,filec_fignore(a4)
		*
		*  ユーザ名か？ ファイル名か？
		*
		lea	filec_pattern(a4),a0
		bsr	builtin_dir_match
		beq	filec_not_builtin

		cmpi.b	#'/',(a0,d0.l)
		bne	filec_not_builtin
*****************
		*
		*  組み込みコマンドを検索する
		*
		*       A0   : 検索パターンを格納したバッファのアドレス
		*       D0.L : 仮想ディレクトリ部の長さ-1
		*
		lea	1(a0,d0.l),a1			*  A1   : 検索パターンの先頭アドレス
		movea.l	a1,a0
		bsr	strlen
		move.l	d0,filec_pattern_length(a4)
		lea	command_table,a0
		bsr	filec_reset
filec_builtin_loop:
		tst.b	(a0)
		beq	filec_find_done

		move.l	filec_pattern_length(a4),d0
		bsr	memcmp
		bne	filec_builtin_next

		bsr	filec_enter
		bcs	filec_fail
filec_builtin_next:
		lea	14(a0),a0
		bra	filec_builtin_loop
****************
filec_not_builtin:
		cmpi.b	#'~',(a0)
		bne	filec_file

		moveq	#'/',d0
		bsr	strchr
		beq	filec_username
****************
filec_file:
		*
		*  ファイルを検索する
		*
		*
		*       ~を展開…
		*
		lea	filec_pattern(a4),a0
		lea	filec_pattern2(a4),a1
		moveq	#0,d2
		move.l	d1,-(a7)
		move.w	#MAXWORDLEN+1,d1
		bsr	expand_tilde
		move.l	(a7)+,d1
		tst.l	d0
		bmi	filec_find_done
		*
		*       ファイル名を検索する
		*
		lea	filec_pattern2(a4),a0
		bsr	includes_dos_wildcard		*  Human68k のワイルドカードを含んで
		bne	filec_find_done			*  いるならば無効

		moveq	#'\',d0				*  \ を
		bsr	strchr				*  含んで
		bne	filec_find_done			*  いるならば無効

		lea	filec_pattern2(a4),a0
		movem.l	d1,-(a7)
		bsr	test_pathname			*  D0-D3/A1-A3
		movem.l	(a7)+,d1
		bhi	filec_find_done

		bsr	test_directory
		bne	filec_find_done

		movea.l	a2,a1				*  A1   : 比較する名前
		move.l	d2,filec_pattern_length(a4)
		add.l	d3,filec_pattern_length(a4)
		bsr	filec_reset

		bsr	strbot
		tst.l	d3
		bne	filec_file_5

		cmp.l	#MAXFILE,d2
		bhs	filec_file_4

		move.b	#'*',(a0)+
filec_file_4:
		tst.l	d3
		bne	filec_file_5

		move.b	#'.',(a0)+
filec_file_5:
		cmp.l	#MAXEXT,d3
		bhs	filec_file_6

		move.b	#'*',(a0)+
filec_file_6:
		clr.b	(a0)
		move.w	#$37,-(a7)			*  ボリューム・ラベル以外の全てを検索
		pea	filec_pattern2(a4)
		pea	filec_dir_buf(a4)
		DOS	_FILES
		lea	10(a7),a7
filec_file_loop:
		tst.l	d0
		bmi	filec_find_done

		lea	filec_dir_buf+30(a4),a0
		cmpi.b	#'.',(a0)
		beq	filec_file_next

		movem.l	d1,-(a7)
		move.b	flag_cifilec(a5),d1
		move.l	filec_pattern_length(a4),d0
		bsr	memxcmp
		movem.l	(a7)+,d1
		bne	filec_file_next

		bsr	filec_enter
		bcs	filec_fail

		tst.b	filec_listflag(a4)
		beq	filec_file_next

		btst.b	#4,filec_dir_buf+21(a4)
		beq	filec_file_next

		subq.w	#1,filec_buffer_free(a4)
		bcs	filec_fail

		move.b	#'/',-1(a3)
		clr.b	(a3)+
filec_file_next:
		pea	filec_dir_buf(a4)
		DOS	_NFILES
		addq.l	#4,a7
		bra	filec_file_loop
****************
filec_username:
		*
		*  ユーザ名を検索する
		*
		*       A1   : 検索パターンの先頭アドレス
		*
		bsr	open_passwd
		bmi	filec_find_done

		move.w	d0,d2				*  D2.W : passwd ファイル・ハンドル

		lea	filec_pattern+1(a4),a0
		bsr	strlen
		move.l	d0,filec_pattern_length(a4)
		bsr	filec_reset
filec_username_loop:
		lea	congetbuf+2,a0
		move.w	d2,d0
		move.w	d1,-(a7)
		move.w	#255,d1
		bsr	fgets
		move.w	(a7)+,d1
		tst.l	d0
		bmi	filec_username_done
		bne	filec_username_loop

		lea	congetbuf+2,a0
		moveq	#';',d0
		bsr	strchr
		clr.b	(a0)
		lea	congetbuf+2,a0
		lea	filec_pattern+1(a4),a1
		move.l	filec_pattern_length(a4),d0
		bsr	memcmp
		bne	filec_username_loop

		bsr	filec_enter
		bcc	filec_username_loop
filec_username_done:
		move.l	d0,-(a7)
		move.w	d2,d0
		bsr	fclose
		move.l	(a7)+,d0
		bpl	filec_fail
****************
filec_find_done:
		tst.b	filec_listflag(a4)
		bne	filec_list			*  リスト表示へ

		tst.w	filec_numentry(a4)
		beq	filec_fail
		*
		*  最初の曖昧でない部分を確定する
		*
		lea	tmpargs,a0
		move.w	filec_numentry(a4),d0
		move.b	flag_cifilec(a5),d2
		move.l	d1,-(a7)
		move.l	filec_pattern_length(a4),d1
		bsr	common_spell
		move.l	(a7)+,d1
		*
		*  完成部分を挿入する
		*
		movea.l	a0,a1
		adda.l	filec_pattern_length(a4),a1
		move.l	d0,d2
		bsr	open_columns
		bcs	filec_file_over

		move.l	d2,d0
		move.l	a0,-(a7)
		bsr	memmovi
		movea.l	(a7)+,a0
		bsr	post_insert_job
		subq.w	#1,filec_numentry(a4)
		beq	filec_done
filec_fail:
filec_file_over:
		bsr	beep
filec_done:
		unlk	a4
		bra	getline_x_1
****************
filec_list:
		*
		*  リスト表示
		*
		move.w	filec_numentry(a4),d6
		beq	filec_list_done

		lea	tmpargs,a0
		move.w	d6,d0
		bsr	sort_wordlist
		addq.w	#2,filec_maxlen(a4)
		*
		*  79(行の桁数-1)を1項目の桁数で割って、1行あたりの項目数を暫定する
		*
		moveq	#1,d2
		move.w	filec_maxlen(a4),d0
		moveq	#79,d3
		cmp.w	d0,d3
		blo	filec_list_width_ok

		move.l	d3,d2
		divu	d0,d2				*  D2.W : 79 / 桁数 = 1行の項目数(暫定)
filec_list_width_ok:
		*
		*  何行になるかを求める
		*
		moveq	#0,d3
		move.w	d6,d3
		divu	d2,d3				*  D3.W : エントリ数 / 1行の項目数 = 行数
		swap	d3
		move.w	d3,d4
		swap	d3
		*
		*  余りがなければＯＫ
		*
		tst.w	d4
		beq	filec_list_height_ok
		*
		*  余りがある --- 行数はさらに1行多い
		*
		addq.w	#1,d3
		*
		*  1行多くなったので、1行の項目数を計算し直す
		*
		moveq	#0,d2
		move.w	d6,d2
		divu	d3,d2
		swap	d2
		move.w	d2,d4
		swap	d2
		tst.w	d4
		beq	filec_list_height_ok
		*
		*  余りがある --- 1行の項目数はさらに1項目多い
		*                 余り(D4.W)は1項目多い行数である
		*
		addq.w	#1,d2
filec_list_height_ok:
		lea	tmpargs,a0
		movea.l	a0,a1				*  A1:最初の行の先頭項目
		bsr	move_cursor_to_eol
filec_list_loop1:
		bsr	put_newline
		movea.l	a1,a0
		bsr	for1str
		exg	a0,a1				*  A0:この行の先頭項目  A1:次行の先頭項目
		move.w	d2,d5
filec_list_loop2:
		movem.l	d1-d3/a1,-(a7)
		moveq	#0,d1
		move.w	filec_maxlen(a4),d1
		moveq	#1,d2
		moveq	#' ',d3
		lea	putc(pc),a1
		bsr	printfs
		movem.l	(a7)+,d1-d3/a1

		subq.w	#1,d6
		beq	filec_list_done

		subq.w	#1,d5
		beq	filec_list_loop2_break

		move.w	d3,d0
		bsr	fornstrs
		bra	filec_list_loop2

filec_list_loop2_break:
		tst.w	d4
		beq	filec_list_loop1

		subq.w	#1,d4
		bne	filec_list_loop1

		subq.w	#1,d2
		bra	filec_list_loop1

filec_list_done:
		unlk	a4
		bsr	put_newline
		bra	x_redraw_1
****************
filec_reset:
		clr.w	filec_numentry(a4)
		clr.w	filec_maxlen(a4)
		lea	tmpargs,a3
		move.w	#MAXWORDLISTSIZE,filec_buffer_free(a4)
		rts
****************
filec_enter:
		movem.l	d1-d4/a0-a2,-(a7)
		bsr	strlen
		cmp.l	#MAXWORDLEN,d0
		bhi	filec_enter_error

		move.l	d0,d2				*  D2 : 単語の長さ
		movea.l	a0,a2				*  A2 : 単語の先頭アドレス
		*
		*  fignore に含まれているかどうかを調べる
		*
		tst.l	filec_fignore(a4)
		beq	filec_add_entry

		movea.l	filec_fignore(a4),a0
		addq.l	#2,a0
		move.w	(a0)+,d4			*  D4.W : fignore の要素数
		bra	check_fignore_continue

check_fignore_loop:
		bsr	strlen
		move.l	d0,d3				*  D3.L : $fignore[i] の長さ
		move.l	d2,d0				*  単語の長さ(D2)は
		sub.l	d3,d0				*  $fignore[i] の長さ(D3)より
		blo	check_fignore_continue		*  短い

		lea	(a2,d0.l),a1
		move.l	d3,d0
		move.b	flag_cifilec(a5),d1
		bsr	memxcmp				*  ケツが一致するか？
		beq	ignore_or_keep
check_fignore_continue:
		bsr	for1str
		dbra	d4,check_fignore_loop
not_ignore:
		tst.b	filec_condition(a4)
		bne	filec_add_entry

		bsr	filec_reset
		st	filec_condition(a4)
		bra	filec_add_entry

ignore_or_keep:
		tst.b	filec_condition(a4)
		bne	filec_entry_return		*  C=0
filec_add_entry:
		*
		*  登録する
		*
		cmp.w	filec_maxlen(a4),d2
		bls	filec_entry_1

		move.w	d2,filec_maxlen(a4)
filec_entry_1:
		addq.w	#1,filec_numentry(a4)
		bcs	filec_entry_return

		sub.w	d2,filec_buffer_free(a4)
		bcs	filec_entry_return

		movea.l	a2,a1
		movea.l	a3,a0
		move.l	d2,d0
		bsr	memmovi
		movea.l	a0,a3
		subq.w	#1,filec_buffer_free(a4)
		bcs	filec_entry_return

		clr.b	(a3)+
filec_entry_return:
		movem.l	(a7)+,d1-d4/a0-a2
		rts

filec_enter_error:
		moveq	#0,d0
		subq.w	#1,d0
		bra	filec_entry_return
*****************************************************************
getline_x_getletter:
		bsr	getline_x_getc
		bmi	getline_x_getletter_return

		bsr	issjis
		bne	getline_x_getletter_1

		move.b	d0,d2
		lsl.w	#8,d2
		bsr	getline_x_getc
		bmi	getline_x_getletter_return

		or.w	d2,d0
getline_x_getletter_1:
		cmp.l	d0,d0
getline_x_getletter_return:
		rts
*****************************************************************
getline_x_getc:
		tst.l	macro_ptr(a6)
		beq	getline_x_getc_tty

		move.l	a0,-(a7)
		movea.l	macro_ptr(a6),a0
		moveq	#0,d0
		move.b	(a0)+,d0
		move.l	a0,macro_ptr(a6)
		movea.l	(a7)+,a0
		tst.l	d0
		bne	getline_x_getc_return

		clr.l	macro_ptr(a6)
getline_x_getc_tty:
		move.w	input_handle(a6),-(a7)
		DOS	_FGETC
		addq.l	#2,a7
		tst.l	d0
getline_x_getc_return:
		rts
*****************************************************************
x_size_forward:
		movem.l	d0/a0,-(a7)
		movea.l	line_top(a6),a0
		move.b	(a0,d0.w),d0
		moveq	#1,d2
		moveq	#4,d3
		cmp.b	#HT,d0
		beq	x_size_forward_return

		moveq	#2,d3
		bsr	iscntrl
		beq	x_size_forward_return

		moveq	#1,d3
		bsr	issjis
		bne	x_size_forward_return

		moveq	#2,d2
		cmp.b	#$80,d0
		beq	x_size_forward_return

		cmp.b	#$f0,d0
		bhs	x_size_forward_return

		moveq	#2,d3
x_size_forward_return:
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
x_size_backward:
		movem.l	d0-d1/a0,-(a7)
		move.w	d0,d1
		movea.l	line_top(a6),a0
		lea	(a0,d1.w),a0
		move.b	-1(a0),d0
		moveq	#1,d2
		moveq	#4,d3
		cmp.b	#HT,d0
		beq	x_size_backward_return

		moveq	#2,d3
		bsr	iscntrl
		beq	x_size_backward_return

		moveq	#1,d3
		cmp.w	#2,d1
		blo	x_size_backward_return

		move.b	-2(a0),d0
		bsr	issjis
		bne	x_size_backward_return

		move.w	d1,d0
		subq.w	#1,d0
		bsr	getline_isnsjisp
		beq	x_size_backward_return

		moveq	#2,d2
		cmp.b	#$80,d0
		beq	x_size_backward_return

		cmp.b	#$f0,d0
		bhs	x_size_backward_return

		moveq	#2,d3
x_size_backward_return:
		movem.l	(a7)+,d0-d1/a0
		rts
****************
getline_isnsjisp:
		movem.l	d1/a0,-(a7)
		movea.l	line_top(a6),a0
		move.w	d0,d1
getline_isnsjisp_loop:
		move.b	(a0)+,d0
		bsr	issjis
		bne	getline_isnsjisp_continue

		subq.w	#1,d1
		beq	getline_isnsjisp_break

		addq.l	#1,a0
getline_isnsjisp_continue:
		subq.w	#1,d1
		bne	getline_isnsjisp_loop

		moveq	#0,d0
getline_isnsjisp_break:
		movem.l	(a7)+,d1/a0
		tst.b	d0
		rts
*****************************************************************
region_width:
		movem.l	d1-d3/a0,-(a7)
		moveq	#0,d2
		move.w	d0,d1
		beq	region_width_return
region_width_loop:
		move.b	(a0)+,d0
		subq.w	#1,d1
		moveq	#4,d3
		cmp.b	#HT,d0
		beq	region_width_1

		moveq	#2,d3
		bsr	iscntrl
		beq	region_width_1

		moveq	#1,d3
		bsr	issjis
		bne	region_width_1

		cmp.b	#$80,d0
		beq	region_width_2

		cmp.b	#$f0,d0
		bhs	region_width_2

		moveq	#2,d3
region_width_2:
		tst.w	d1
		beq	region_width_1

		addq.l	#1,a0
		subq.w	#1,d1
region_width_1:
		add.l	d3,d2
		tst.w	d1
		bne	region_width_loop
region_width_return:
		move.l	d2,d0
		movem.l	(a7)+,d1-d3/a0
		rts
*****************************************************************
* backward_cursor_x - 指定のフィールドの幅だけカーソルを左に移動する
*
* CALL
*      A0     フィールドの先頭アドレス
*      D0.W   フィールドの長さ（バイト）
*
* RETURN
*      D0.L   フィールドの幅
*****************************************************************
*****************************************************************
* backward_cursor - カーソルを左に移動する
*
* CALL
*      D0.L   移動幅
*
* RETURN
*      none
*****************************************************************
backward_cursor_x:
		bsr	region_width
backward_cursor:
		move.l	a0,-(a7)
		lea	t_bs,a0
		bsr	puts_ntimes
		movea.l	(a7)+,a0
		rts
*****************************************************************
* forward_cursor_x - 指定のフィールドの幅だけカーソルを右に移動する
*
* CALL
*      A0     フィールドの先頭アドレス
*      D0.W   フィールドの長さ（バイト）
*
* RETURN
*      D0.L   フィールドの幅
*****************************************************************
*****************************************************************
* forward_cursor - カーソルを右に移動する
*
* CALL
*      D0.L   移動幅
*
* RETURN
*      none
*****************************************************************
forward_cursor_x:
		bsr	region_width
forward_cursor:
		move.l	a0,-(a7)
		lea	t_fs,a0
		bsr	puts_ntimes
		movea.l	(a7)+,a0
		rts
*****************************************************************
* backward_letter - ポインタを1文字戻す．カーソルは移動しない
*
* CALL
*      none
*
* RETURN
*      D0.L   破壊
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
backward_letter:
		moveq	#0,d2
		moveq	#0,d3
		move.w	point(a6),d0
		beq	backward_letter_done

		bsr	x_size_backward
		sub.w	d2,point(a6)
backward_letter_done:
		rts
*****************************************************************
* forward_letter - ポインタを1文字進める．カーソルは移動しない
*
* CALL
*      none
*
* RETURN
*      D0.L   破壊
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
forward_letter:
		moveq	#0,d2
		moveq	#0,d3
		move.w	point(a6),d0
		cmp.w	nbytes(a6),d0
		beq	forward_letter_done

		bsr	x_size_forward
		add.w	d2,point(a6)
forward_letter_done:
		rts
*****************************************************************
* backward_word - ポインタを1語戻す．カーソルは移動しない
*
* CALL
*      none
*
* RETURN
*      D0.L   破壊
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
backward_word:
		movem.l	d0/d4-d6/a0,-(a7)
		moveq	#0,d4
		moveq	#0,d5
backward_word_1:
		tst.w	point(a6)
		beq	backward_word_done

		bsr	backward_letter
		add.w	d2,d4
		add.l	d3,d5

		bsr	is_point_space
		beq	backward_word_1

		bsr	is_special_character
		move.b	(a0),d6
backward_word_3:
		tst.w	point(a6)
		beq	backward_word_done

		bsr	backward_letter
		add.w	d2,d4
		add.l	d3,d5

		bsr	is_point_space
		beq	backward_word_5

		tst.b	d6
		beq	backward_word_4

		cmp.b	d6,d0
		beq	backward_word_3
		bra	backward_word_5

backward_word_4:
		bsr	is_special_character
		beq	backward_word_3
backward_word_5:
		bsr	forward_letter
		sub.w	d2,d4
		sub.l	d3,d5
backward_word_done:
		move.w	d4,d2
		move.l	d5,d3
		movem.l	(a7)+,d0/d4-d6/a0
		rts
*****************************************************************
* forward_word - ポインタを1語進める．カーソルは移動しない
*
* CALL
*      none
*
* RETURN
*      D0.L   破壊
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
forward_word:
		movem.l	d0/d4-d6/a0,-(a7)
		moveq	#0,d4
		moveq	#0,d5
forward_word_1:
		move.w	point(a6),d0
		cmp.w	nbytes(a6),d0
		beq	forward_word_done

		bsr	is_dot_space
		bne	forward_word_2

		bsr	forward_letter
		add.w	d2,d4
		add.l	d3,d5
		bra	forward_word_1

forward_word_2:
		bsr	is_special_character
		move.b	(a0),d6
forward_word_3:
		bsr	forward_letter
		add.w	d2,d4
		add.l	d3,d5
		move.w	point(a6),d0
		cmp.w	nbytes(a6),d0
		beq	forward_word_done

		bsr	is_dot_space
		beq	forward_word_done

		tst.b	d6
		beq	forward_word_4

		cmp.b	d6,d0
		beq	forward_word_3
		bra	forward_word_done

forward_word_4:
		bsr	is_special_character
		beq	forward_word_3
forward_word_done:
		move.w	d4,d2
		move.l	d5,d3
		movem.l	(a7)+,d0/d4-d6/a0
		rts
*****************************************************************
is_point_space:
		move.w	point(a6),d0
is_dot_space:
		movea.l	line_top(a6),a0
		move.b	(a0,d0.w),d0
		bra	isspace
*****************************************************************
is_special_character:
		and.w	#$ff,d0
		lea	x_special_characters,a0
		bra	strchr
*****************************************************************
* move_letter_backward - ポインタを1文字戻し、カーソルも左に移動する
* move_word_backward - ポインタを1語戻し、カーソルも左に移動する
*
* CALL
*      none
*
* RETURN
*      D0.L   カーソル移動幅
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
move_letter_backward:
		bsr	backward_letter
		bra	backward_cursor_d3

move_word_backward:
		bsr	backward_word
backward_cursor_d3:
		move.l	d3,d0
		bra	backward_cursor
*****************************************************************
* move_letter_forward - ポインタを1文字進め、カーソルも右に移動する
* move_word_forward - ポインタを1語進め、カーソルも右に移動する
*
* CALL
*      none
*
* RETURN
*      D0.L   カーソル移動幅
*      D2.W   移動バイト数
*      D3.L   カーソル移動幅
*****************************************************************
move_letter_forward:
		bsr	forward_letter
		bra	forward_cursor_d3

move_word_forward:
		bsr	forward_word
forward_cursor_d3:
		move.l	d3,d0
		bra	forward_cursor
*****************************************************************
move_cursor_to_eol:
		movem.l	d0/a0,-(a7)
		movea.l	line_top(a6),a0
		adda.w	point(a6),a0			*  正しい
		move.w	nbytes(a6),d0
		sub.w	point(a6),d0
		bsr	forward_cursor_x
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
erase_line:
		movem.l	d0/a0-a1,-(a7)
		movea.l	line_top(a6),a0
		move.w	point(a6),d0
		lea	(a0,d0.w),a1			*  A1 : カーソル位置
		bsr	backward_cursor_x
		move.l	d0,-(a7)			*  行の先頭からカーソル位置までの幅
		movea.l	a1,a0
		move.w	nbytes(a6),d0
		sub.w	point(a6),d0
		bsr	region_width			*  カーソル位置から行末までの幅
		add.l	(a7)+,d0			*  D0.L : 行全体の幅
		bsr	put_spaces
		bsr	backward_cursor
		movem.l	(a7)+,d0/a0-a1
		rts
*****************************************************************
delete_line:
		bsr	erase_line
		add.w	nbytes(a6),d1
		clr.w	nbytes(a6)
		clr.w	point(a6)
		clr.w	mark(a6)
		rts
*****************************************************************
* open_columns
*
* CALL
*      D2.W   挿入バイト数
*****************************************************************
open_columns:
		cmp.w	d2,d1
		blo	open_columns_return

		sub.w	d2,d1
		movem.l	d0/a1,-(a7)
		movea.l	line_top(a6),a0
		moveq	#0,d0
		move.w	nbytes(a6),d0
		adda.l	d0,a0				*  A0 : 行末
		sub.w	point(a6),d0			*  D0.W : カーソル以降のバイト数
		movea.l	a0,a1
		lea	(a0,d2.w),a0
		bsr	memmovd
		movem.l	(a7)+,d0/a1
		suba.w	d2,a0				*  正しい
		cmp.w	d0,d0
open_columns_return:
		rts
*****************************************************************
* post_insert_job
*
* CALL
*      D2.W   挿入バイト数
*****************************************************************
post_insert_job:
		movem.l	d0/a0,-(a7)
		move.w	d2,d0
		bsr	write_chars
		lea	(a0,d2.w),a0
		move.w	nbytes(a6),d0
		sub.w	point(a6),d0
		bsr	write_chars
		bsr	backward_cursor_x
		move.w	mark(a6),d0
		bmi	post_insert_1

		cmp.w	point(a6),d0
		blo	post_insert_1

		add.w	d2,mark(a6)
post_insert_1:
		add.w	d2,nbytes(a6)
		add.w	d2,point(a6)
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
* copy_region_to_buffer
*
* CALL
*      D0.B     bit0 : 非0ならば失敗したときに尋ねる
*               bit1 : 0:後ろに追加, 1:先頭に追加
*      D2.W     コピーする領域の長さ（バイト数）
*      D4.W     コピーする領域の先頭オフセット
*
* RETURN
*      D0.L     成功したなら 0，失敗したなら 1
*      CCR      TST.L D0
*****************************************************************
copy_region_to_buffer:
		movem.l	d1/d3/a0-a1,-(a7)
		move.b	d0,d1
		lea	linecutbuf(a5),a0
		tst.b	killing(a6)
		bne	copy_region_to_buffer_1

		clr.b	(a0)
copy_region_to_buffer_1:
		bsr	strlen
		move.l	d0,d3
		add.w	d2,d0
		cmp.w	#MAXLINELEN,d0
		bhi	cannot_copy_region_to_buffer

		clr.b	(a0,d0.w)
		btst	#1,d1
		bne	copy_region_to_buffer_2

		bsr	strbot
		bra	copy_region_to_buffer_3

copy_region_to_buffer_2:
		lea	(a0,d0.w),a0
		movea.l	a0,a1
		suba.w	d2,a1				*  正しい
		move.l	d3,d0
		bsr	memmovd
		lea	linecutbuf(a5),a0
copy_region_to_buffer_3:
		movea.l	line_top(a6),a1
		lea	(a1,d4.w),a1
		moveq	#0,d0
		move.w	d2,d0
		bsr	memmovi
		st	killing(a6)
copy_region_to_buffer_success:
		moveq	#0,d0
copy_region_to_buffer_return:
		movem.l	(a7)+,d1/d3/a0-a1
		rts

cannot_copy_region_to_buffer:
		bsr	beep
		moveq	#1,d0
		bra	copy_region_to_buffer_return
*****************************************************************
* delete_region
*
* CALL
*      D2.W     削除する領域の長さ（バイト数）
*      D3.L     削除する領域の幅
*      D4.W     削除する領域の先頭オフセット
*
* RETURN
*      none.
*****************************************************************
delete_region:
		movem.l	d0/a0-a1,-(a7)
		tst.w	d2
		beq	delete_region_done

		movea.l	line_top(a6),a0
		lea	(a0,d4.w),a0
		lea	(a0,d2.w),a1
		moveq	#0,d0
		move.w	nbytes(a6),d0
		sub.w	d4,d0
		sub.w	d2,d0
		move.l	a0,-(a7)
		bsr	memmovi
		movea.l	(a7)+,a0
		bsr	write_chars
		bsr	region_width
		exg	d0,d3
		bsr	put_spaces
		exg	d0,d3
		add.l	d3,d0
		bsr	backward_cursor

		sub.w	d2,nbytes(a6)
		add.w	d2,d1
		move.w	mark(a6),d0
		bmi	delete_region_done

		sub.w	d4,d0
		blo	delete_region_done

		cmp.w	d2,d0
		blo	delete_region_mark_missed

		sub.w	d2,mark(a6)
		bra	delete_region_done

delete_region_mark_missed:
		move.w	d4,mark(a6)
delete_region_done:
		movem.l	(a7)+,d0/a0-a1
		rts
*****************************************************************
redraw_with_prompt:
		move.l	a1,-(a7)
		movea.l	put_prompt_ptr(a6),a1
		bsr	put_prompt
		movea.l	(a7)+,a1
redraw:
		movem.l	d0/d2/a0,-(a7)
		movea.l	line_top(a6),a0
		move.w	nbytes(a6),d0
		bsr	write_chars
		move.w	point(a6),d2
		lea	(a0,d2.w),a0
		move.w	nbytes(a6),d0
		sub.w	d2,d0
		bsr	backward_cursor_x
		movem.l	(a7)+,d0/d2/a0
		rts
*****************************************************************
puts_ntimes:
		move.l	d0,-(a7)
		beq	puts_nitems_done
puts_ntimes_loop:
		bsr	puts
		subq.l	#1,d0
		bne	puts_ntimes_loop
puts_nitems_done:
		move.l	(a7)+,d0
		rts
*****************************************************************
put_spaces:
		movem.l	d0-d1,-(a7)
		move.l	d0,d1
		beq	put_spaces_done

		moveq	#' ',d0
put_spaces_loop:
		bsr	putc
		subq.l	#1,d1
		bne	put_spaces_loop
put_spaces_done:
		movem.l	(a7)+,d0-d1
		rts
*****************************************************************
write_chars:
		movem.l	d0-d1/a0,-(a7)
		move.w	d0,d1
		bra	write_chars_continue

write_chars_loop:
		move.b	(a0)+,d0
		cmp.b	#HT,d0
		beq	write_chars_tab

		bsr	cputc
		bra	write_chars_continue

write_chars_tab:
		moveq	#4,d0
		bsr	put_spaces
write_chars_continue:
		dbra	d1,write_chars_loop

		movem.l	(a7)+,d0-d1/a0
		rts
*****************************************************************
eol_newline:
		bsr	move_cursor_to_eol
		bra	put_newline
*****************************************************************
beep:
		tst.b	flag_nobeep(a5)
		bne	beep_done

		move.l	a0,-(a7)
		lea	t_bell,a0
		bsr	puts
		movea.l	(a7)+,a0
beep_done:
		rts
*****************************************************************
put_prompt:
		cmpa.l	#0,a1
		beq	put_prompt_done

		jsr	(a1)
put_prompt_done:
		rts
*****************************************************************
*  $prompt の制御文字
*
*	%!	履歴番号
*	%p	カレント・ディレクトリ（~略記）
*	%l	カレント・ディレクトリ（フル・パス）
*	%y	年（最小フィールド幅が4未満ならば、年の下2桁）
*	%m	月
*	%a	月の英語名の略記（3桁）
*	%d	日
*	%h	曜日の英語名の略記（3桁）
*	%s	日本語での曜日（2桁）
*	%H	時
*	%M	分
*	%S	秒
*	%n	改行
*	%%	文字 '%'
*****************************************************************
.xdef put_prompt_1

put_prompt_1:
		movem.l	d0-d3/a0-a1,-(a7)
		lea	word_prompt2,a0
		tst.b	switch_status(a5)
		bne	put_prompt_2

		tst.b	if_status(a5)
		bne	put_prompt_2

		tst.b	loop_status(a5)
		bmi	put_prompt_2

		lea	word_prompt,a0
put_prompt_2:
		bsr	find_shellvar
		beq	prompt_done

		addq.l	#2,a0
		tst.w	(a0)+
		beq	prompt_done

		bsr	for1str
		movea.l	a0,a1
prompt_loop:
		move.b	(a1)+,d0
		beq	prompt_done

		cmp.b	#'%',d0
		bne	prompt_normal_letter

		tst.b	(a1)
		beq	prompt_normal_char

		moveq	#1,d1				*  D1.L : format - 少くとも 1文字を出力
		moveq	#0,d2				*  D2.L : flags - 右詰め，上限無し
		moveq	#' ',d3				*  D3.B : pad character - ' '

		move.b	(a1)+,d0
		cmp.b	#'-',d0
		bne	prompt_no_minus

		bset	#0,d2				*  左詰め
		move.b	(a1)+,d0
		beq	prompt_done
prompt_no_minus:
		cmp.b	#'0',d0
		bne	prompt_no_0

		move.b	d0,d3
		move.b	(a1)+,d0
		beq	prompt_done
prompt_no_0:
		bsr	isdigit
		bne	prompt_no_format

		lea	-1(a1),a0
		bsr	atou				*  ［オーバーフローは面倒だから無視！］
		movea.l	a0,a1
		move.b	(a1)+,d0
		beq	prompt_done
prompt_no_format:
		cmp.b	#'%',d0
		beq	prompt_normal_char

		cmp.b	#'!',d0
		beq	prompt_eventno

		cmp.b	#'p',d0
		beq	prompt_cwd

		cmp.b	#'l',d0
		beq	prompt_cwd_l

		cmp.b	#'y',d0
		beq	prompt_year

		cmp.b	#'m',d0
		beq	prompt_month_of_year

		cmp.b	#'a',d0
		beq	prompt_abbrev_month

		cmp.b	#'d',d0
		beq	prompt_day_of_month

		cmp.b	#'h',d0
		beq	prompt_english_day_of_week

		cmp.b	#'s',d0
		beq	prompt_japanese_day_of_week

		cmp.b	#'H',d0
		beq	prompt_hour

		cmp.b	#'M',d0
		beq	prompt_minute

		cmp.b	#'S',d0
		beq	prompt_second

		cmp.b	#'n',d0
		beq	prompt_newline

		moveq	#'%',d0
		bsr	putc
		move.b	-1(a1),d0
prompt_normal_letter:
		bsr	issjis
		bne	prompt_normal_char

		bsr	putc
		move.b	(a1)+,d0
		beq	prompt_done
prompt_normal_char:
		bsr	putc
		bra	prompt_loop

prompt_done:
		movem.l	(a7)+,d0-d3/a0-a1
		rts
****************
*  %! : current event number of history
****************
prompt_eventno:
		move.l	current_eventno(a5),d0
prompt_digit:
		move.l	a1,-(a7)
		lea	utoa(pc),a0
		lea	putc(pc),a1
		bsr	printfi
		movea.l	(a7)+,a1
		bra	prompt_loop
****************
*  %p : abbrev current working directory
****************
prompt_cwd:
		st	d0
prompt_cwd_1:

cwdbuf = -(((MAXPATH+1)+1)>>1<<1)

		link	a6,#cwdbuf
		lea	cwdbuf(a6),a0
		bsr	getcwdx
		bsr	prompt_string
		unlk	a6
		bra	prompt_loop

prompt_string:
		move.l	a1,-(a7)
		lea	putc(pc),a1
		bsr	printfs
		movea.l	(a7)+,a1
		rts
****************
*  %l : long current working directory
****************
prompt_cwd_l:
		sf	d0
		bra	prompt_cwd_1
****************
*  %y : year
****************
prompt_year:
		DOS	_GETDATE
		lsr.l	#8,d0
		lsr.l	#1,d0
		and.l	#%1111111,d0
		add.l	#1980,d0
		cmp.l	#4,d1
		bhs	prompt_digit

		move.l	d1,-(a7)
		moveq	#100,d1
		bsr	divul
		move.l	d1,d0
		move.l	(a7)+,d1
		bra	prompt_digit
****************
*  %m : month of year
****************
prompt_month_of_year:
		DOS	_GETDATE
		lsr.l	#5,d0
		and.l	#%1111,d0
		bra	prompt_digit
****************
*  %a : abbrev month name
****************
prompt_abbrev_month:
		lea	month_word_table,a0
		DOS	_GETDATE
		lsr.l	#5,d0
		and.l	#%1111,d0
		subq.l	#1,d0
prompt_name_in_table:
		bsr	fornstrs
		bsr	prompt_string
		bra	prompt_loop
****************
*  %d : day of month
****************
prompt_day_of_month:
		DOS	_GETDATE
		and.l	#%11111,d0
		bra	prompt_digit
****************
*  %h : English day name of week
****************
prompt_english_day_of_week:
		lea	english_week,a0
prompt_day_of_week:
		DOS	_GETDATE
		swap	d0
		and.w	#%111,d0
		bra	prompt_name_in_table
****************
*  %s : Japanese day name of week
****************
prompt_japanese_day_of_week:
		lea	japanese_week,a0
		bra	prompt_day_of_week
****************
*  %H : hour
****************
prompt_hour:
		DOS	_GETTIM2
		lsr.l	#8,d0
		lsr.l	#8,d0
		and.l	#%11111,d0
		bra	prompt_digit
****************
*  %M : minute
****************
prompt_minute:
		DOS	_GETTIM2
		lsr.l	#8,d0
		and.l	#%111111,d0
		bra	prompt_digit
****************
*  %S : second
****************
prompt_second:
		DOS	_GETTIM2
		and.l	#%111111,d0
		bra	prompt_digit
****************
*  %n : newline
****************
prompt_newline:
		bsr	put_newline
		bra	prompt_loop
*****************************************************************
* test_directory - パス名のディレクトリが存在するかどうかを調べる
*
* CALL
*      A0     パス名
*
* RETURN
*      D0.L   存在するならば0
*      CCR    TST.L D0
*
* NOTE
*      / のみが許され、\ は許さない
*      flag_cifilec(B) が効く
****************************************************************
filebuf = -54
searchnamebuf = filebuf-(MAXPATH+1)
pad = searchnamebuf-(searchnamebuf.MOD.2)

test_directory:
		link	a6,#pad
		movem.l	d1-d2/a0-a3,-(a7)
		lea	searchnamebuf(a6),a2
		moveq	#0,d2
get_firstdir_restart:
		movea.l	a0,a3
		move.b	(a0)+,d0
		beq	get_firstdir_done

		cmp.b	#'/',d0
		beq	get_firstdir_root

		tst.w	d2
		bne	get_firstdir_done

		bsr	issjis
		beq	get_firstdir_done

		move.b	d0,d1
		move.b	(a0)+,d0
		beq	get_firstdir_done

		cmp.b	#':',d0
		bne	get_firstdir_done

		move.b	d1,(a2)+
		move.b	d0,(a2)+
		moveq	#1,d2
		bra	get_firstdir_restart

get_firstdir_root:
		move.b	d0,(a2)+
		movea.l	a0,a3
get_firstdir_done:
		clr.b	(a2)
		lea	searchnamebuf(a6),a0
		bsr	drvchkp				*  ドライブ名は有効か
		bmi	test_directory_return		*  無効 .. false
test_directory_loop:
		*
		*  A2 : 検索名バッファのケツ
		*  A3 : 現在着目しているエレメントの先頭
		*
		movea.l	a3,a0				*  現在着目しているエレメントの後ろに
		moveq	#'/',d0				*  / が
		bsr	strchr				*  あるか？
		beq	test_directory_true		*  無い .. true

		move.l	a0,d2
		sub.l	a3,d2				*  D2.L : エレメントの長さ
		move.w	#%010000,-(a7)			*  ディレクトリのみを検索
		pea	searchnamebuf(a6)
		pea	filebuf(a6)
		movea.l	a2,a0
		lea	dos_allfile,a1
		bsr	strcpy
		DOS	_FILES
		lea	10(a7),a7
test_directory_find_loop:
		tst.l	d0
		bmi	test_directory_return		*  エントリが無い .. false

		lea	filebuf+30(a6),a0
		movea.l	a3,a1
		move.l	d2,d0
		move.b	flag_cifilec(a5),d1
		bsr	memxcmp
		beq	test_directory_found

		pea	filebuf(a6)
		DOS	_NFILES
		addq.l	#4,a7
		bra	test_directory_find_loop

test_directory_found:
		move.l	d2,d0
		addq.l	#1,d0
		exg	a1,a3
		exg	a0,a2
		bsr	memmovi
		exg	a0,a2
		exg	a1,a3
		clr.b	(a2)
		bra	test_directory_loop

test_directory_true:
		moveq	#0,d0
test_directory_return:
		movem.l	(a7)+,d1-d2/a0-a3
		unlk	a6
		tst.l	d0
		rts
*****************************************************************
.data

.xdef word_separators

.even
key_function_jump_table:
		dc.l	x_self_insert
		dc.l	x_error
		dc.l	x_macro
		dc.l	x_prefix_1
		dc.l	x_prefix_2
		dc.l	x_abort
		dc.l	x_eof
		dc.l	x_accept_line
		dc.l	x_quoted_insert
		dc.l	x_redraw
		dc.l	x_clear_and_redraw
		dc.l	x_set_mark
		dc.l	x_exg_point_and_mark
		dc.l	x_search_character
		dc.l	x_bol
		dc.l	x_eol
		dc.l	x_backward_char
		dc.l	x_forward_char
		dc.l	x_backward_word
		dc.l	x_forward_word
		dc.l	x_del_back_char
		dc.l	x_del_for_char
		dc.l	x_kill_back_word
		dc.l	x_kill_for_word
		dc.l	x_kill_bol
		dc.l	x_kill_eol
		dc.l	x_kill_region
		dc.l	x_copy_region
		dc.l	x_yank
		dc.l	x_upcase_char
		dc.l	x_downcase_char
		dc.l	x_upcase_word
		dc.l	x_downcase_word
		dc.l	x_upcase_region
		dc.l	x_downcase_region
		dc.l	x_transpose_chars
		dc.l	x_transpose_words
		dc.l	x_up_history
		dc.l	x_down_history
		dc.l	x_complete
		dc.l	x_list

word_fignore:		dc.b	'fignore',0

filec_separators:	dc.b	'"',"'",'`^'
word_separators:	dc.b	' ',HT,LF,VT,FS,CR
x_special_characters:	dc.b	';&|<>()',0

month_word_table:
		dc.b	'Jan',0
		dc.b	'Feb',0
		dc.b	'Mar',0
		dc.b	'Apr',0
		dc.b	'May',0
		dc.b	'Jun',0
		dc.b	'Jul',0
		dc.b	'Aug',0
		dc.b	'Sep',0
		dc.b	'Oct',0
		dc.b	'Nov',0
		dc.b	'Dec',0
		dc.b	'???',0
		dc.b	'???',0
		dc.b	'???',0

english_week:
		dc.b	'Sun',0
		dc.b	'Mon',0
		dc.b	'Tue',0
		dc.b	'Wed',0
		dc.b	'Thu',0
		dc.b	'Fri',0
		dc.b	'Sat',0
		dc.b	'???',0

japanese_week:
		dc.b	'日',0
		dc.b	'月',0
		dc.b	'火',0
		dc.b	'水',0
		dc.b	'木',0
		dc.b	'金',0
		dc.b	'土',0
		dc.b	'？',0

t_bs:		dc.b	BS,0			*  ［termcap］
t_fs:		dc.b	FS,0			*  ［termcap］
t_clear:	dc.b	ESC,'[2J',0		*  ［termcap］
t_bell:		dc.b	BL,0			*  ［termcap］

.if 0
msg_reverse_i_search:	dc.b	'reverse-'
msg_i_search:		dc.b	'i-search: ',0
msg_i_search_colon:	dc.b	' : ',0
.endif

.end
