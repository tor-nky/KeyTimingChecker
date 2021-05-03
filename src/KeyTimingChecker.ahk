; Copyright 2021 Satoru NAKAYA
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;	  http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; **********************************************************************
;	キー入力の時間差を計測する
; **********************************************************************


; ----------------------------------------------------------------------
; 初期設定
; ----------------------------------------------------------------------

SetWorkingDir %A_ScriptDir%	; スクリプトの作業ディレクトリを変更
#SingleInstance force		; 既存のプロセスを終了して実行開始
#Persistent					; スクリプトを常駐状態にする
#NoEnv						; 変数名を解釈するとき、環境変数を無視する
SetBatchLines, -1			; 自動Sleepなし
ListLines, Off				; スクリプトの実行履歴を取らない
SetKeyDelay, 0, 0			; キーストローク間のディレイを変更
#MenuMaskKey vk07			; Win または Alt の押下解除時のイベントを隠蔽するためのキーを変更する
#UseHook					; ホットキーはすべてフックを使用する
;Process, Priority, , High	; プロセスの優先度を変更
;Thread, interrupt, 15, 6	; スレッド開始から15ミリ秒ないし1行以内の割り込みを、絶対禁止
;SetStoreCapslockMode, off	; Sendコマンド実行時にCapsLockの状態を自動的に変更しない

;SetFormat, Integer, H		; 数値演算の結果を、16進数の整数による文字列で表現する

; ----------------------------------------------------------------------
; グローバル変数
; ----------------------------------------------------------------------

; 入力バッファ
InBuf := []
InBufTime := []	; 入力の時間
InBufRead := 0	; 読み出し位置
InBufWrite := 0	; 書き込み位置
InBufRest := 15

SCArray := ["", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "{sc0D}", "", ""
	, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{sc1A}", "{sc1B}", "", "", "A", "S"
	, "D", "F", "G", "H", "J", "K", "L", "{sc27}", "{sc28}", "{sc29}", "", "{sc2B}", "Z", "X", "C", "V"
	, "B", "N", "M", ",", ".", "/", "", "", "", "Space", "CapsLock", "", "", "", "", ""
	, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""
	, "", "", "", "", "SysRq", "", "KC_NUBS", "", "", "(Mac)=", "", "", "(NEC),", "", "", ""
	, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""
	, "(JIS)ひらがな", "(Mac)英数", "(Mac)かな", "(JIS)_", "", "", "", "KC_LANG4"
	, "KC_LANG3", "(JIS)変換", "", "(JIS)無変換", "", "(JIS)￥", "(Mac),", ""]

; キーボードドライバを調べて KeyDriver に格納する
; 参考: https://ixsvr.dyndns.org/blog/764
RegRead, KeyDriver, HKEY_LOCAL_MACHINE, SYSTEM\CurrentControlSet\Services\i8042prt\Parameters, LayerDriver JPN


; ----------------------------------------------------------------------
; タイマー関数、設定
; ----------------------------------------------------------------------

; 参照: https://www.autohotkey.com/boards/viewtopic.php?t=4667
WinAPI_timeGetTime()	; http://msdn.microsoft.com/en-us/library/dd757629.aspx
{
	return DllCall("Winmm.dll\timeGetTime", "UInt")
}
WinAPI_timeBeginPeriod(uPeriod)	; http://msdn.microsoft.com/en-us/library/dd757624.aspx
{
	return DllCall("Winmm.dll\timeBeginPeriod", "UInt", uPeriod, "UInt")
}
WinAPI_timeEndPeriod(uPeriod)	; http://msdn.microsoft.com/en-us/library/dd757626.aspx
{
	return DllCall("Winmm.dll\timeEndPeriod", "UInt", uPeriod, "UInt")
}

; タイマーの精度を調整
WinAPI_timeBeginPeriod(1)


Run, Notepad.exe, , , pid	; メモ帳を起動
Sleep, 200
WinActivate, ahk_pid %pid%	；アクティブ化
Send, キー入力の時間差を計測します。他のウインドウでキーを押すと終了します。

; ----------------------------------------------------------------------
; メニュー表示
; ----------------------------------------------------------------------

exit	; 起動時はここまで実行

; ----------------------------------------------------------------------
; メニュー動作
; ----------------------------------------------------------------------


; ----------------------------------------------------------------------
; サブルーチン
; ----------------------------------------------------------------------


; ----------------------------------------------------------------------
; 関数
; ----------------------------------------------------------------------

Convert()
{
	global SCArray, KeyDriver, pid
		, InBuf, InBufRead, InBufTime, InBufRest
	static run := 0	; 多重起動防止フラグ
		, LastKeyTime := WinAPI_timeGetTime()
		, LastTerm := " "
;	local Str, Start, Term
;		, diff, number, temp

	if (run)
		return	; 多重起動防止で終了

	IfWinNotActive, ahk_pid %pid%
		ExitApp		; 起動したメモ帳以外への入力だったら終了

	; 入力バッファが空になるまで
	while (run := 15 - InBufRest)
	{
		; 入力バッファから読み出し
		Str := InBuf[InBufRead], KeyTime := InBufTime[InBufRead++], InBufRead &= 15, InBufRest++

		; キーの上げ下げを調べる
		StringRight, Term, Str, 3	; Term に入力末尾の2文字を入れる
		if (Term = " up")	; キーが離されたとき
		{
			Term := "↑"
			Str := SubStr(Str, 1, StrLen(Str) - 3)
			if (Term != LastTerm)
				Send, `n`t`t	; 上げ下げが変わったら改行、空白
			else
				Send, {Space}
		}
		else
		{
			Term := ""
			if (Term != LastTerm)
				Send, `n	; 上げ下げが変わったら改行
			else
				Send, {Space}
		}
		; 前回の入力からの時間を書き出し
		diff := KeyTime - LastKeyTime
		if (diff >= 0 && diff <= 1050)
			Send, % "(" . diff . "ms) "
		; 入力文字の書き出し
		if (Str = "sc29" && KeyDriver != "kbd101.dll")
			Str := "半角/全角"
		else if (Str = "sc3A" && KeyDriver != "kbd101.dll")
			Str := "英数"
		else if (Str = "LWin")		; LWin を半角のまま出力すると、なぜか Win+L が発動する
			Str := "ＬWin"
		else if (Str = "vk1A")
			Str := "(Mac)英数"
		else if (Str = "vk16")
			Str := "(Mac)かな"
		else
		{
			StringLeft, Start, Str, 2	; Start に入力先頭の2文字を入れる
			if (Start = "sc")
			{
				number := "0x" . SubStr(Str, 3, 2)
				temp := SCArray[number]
				if (temp != "")
					Str := temp
			}
		}

		Send, % Str . Term

		LastKeyTime := KeyTime	; 押した時間を保存
		LastTerm := Term		; キーの上げ下げを保存
	}

	return
}


; ----------------------------------------------------------------------
; ホットキー
; ----------------------------------------------------------------------
#MaxThreadsPerHotkey 2	; 1つのホットキー・ホットストリングに多重起動可能な
						; 最大のスレッド数を設定

; キー入力部(シフトなし)
sc29::	; (JIS)半角/全角	(US)`
sc02::	; 1
sc03::	; 2
sc04::	; 3
sc05::	; 4
sc06::	; 5
sc07::	; 6
sc08::	; 7
sc09::	; 8
sc0A::	; 9
sc0B::	; 0
sc0C::	; -
sc0D::	; (JIS)^	(US)=
sc7D::	; (JIS)￥
sc10::	; Q
sc11::	; W
sc12::	; E
sc13::	; R
sc14::	; T
sc15::	; Y
sc16::	; U
sc17::	; I
sc18::	; O
sc19::	; P
sc1A::	; (JIS)@	(US)[
sc1B::	; (JIS)[	(US)]
sc56::	; KC_NUBS
sc1E::	; A
sc1F::	; S
sc20::	; D
sc21::	; F
sc22::	; G
sc23::	; H
sc24::	; J
sc25::	; K
sc26::	; L
sc27::	; `;
sc28::	; (JIS):	(US)'
sc2B::	; (JIS)]	(US)＼
sc2C::	; Z
sc2D::	; X
sc2E::	; C
sc2F::	; V
sc30::	; B
sc31::	; N
sc32::	; M
sc33::	; `,
sc34::	; .
sc35::	; /
sc73::	; (JIS)_
sc39::	; Space

Tab::			; sc0F::	vk09::
Enter::
BackSpace::		; sc0E::	vk08::
Delete::
Insert::
Left::
Right::
Up::
Down::
Home::
End::
PgUp::
PgDn::
sc79::	; (JIS)変換
sc7B::	; (JIS)無変換
sc70::	; (JIS)ひらがな
sc78::	; KC_LANG3
sc77::	; KC_LANG4
vk1A::	; (Mac)英数 downのみ
vk16::	; (Mac)かな downのみ
F1::			; sc3B::	vk70::
F2::			; sc3C::	vk71::
F3::			; sc3D::	vk72::
F4::			; sc3E::	vk73::
F5::			; sc3F::	vk74::
F6::			; sc40::	vk75::
F7::			; sc41::	vk76::
F8::			; sc42::	vk77::
F9::			; sc43::	vk78::
F10::			; sc44::	vk79::
F11::			; sc57::	vk7A::
F12::			; sc58::	vk7B::
F13::			; sc64::	vk7C::
F14::			; sc65::	vk7D::
F15::			; sc66::	vk7E::
F16::			; sc67::	vk7F::
F17::			; sc68::	vk80::
F18::			; sc69::	vk81::
F19::			; sc6A::	vk82::
F20::			; sc6B::	vk83::
F21::			; sc6C::	vk84::
F22::			; sc6D::	vk85::
F23::			; sc6E::	vk86::
F24::			; sc76::	vk87::
Esc::			; sc01::	vk1B::
AppsKey::		; vk5D::
PrintScreen::	; vk2C::
sc54::	; SysRq
Pause::			; sc45::	vk13::
;Break::		; 認識しない
;Sleep::		; 認識しない
;Help::			; 認識しない
CtrlBreak::
sc3A::	; (JIS)英数	(US)CapsLock
ScrollLock::	; sc46::
NumLock::		; vk90::
LCtrl::			; vkA2::
RCtrl::			; vkA3::
LAlt::			; vkA4::
RAlt::			; vkA5::
LShift::		; sc2A::	vkA0::
RShift::		; vkA1::
LWin::			; vk5B::
RWin::			; vk5C::
Numpad0::		; vk60::
Numpad1::		; vk61::
Numpad2::		; vk62::
Numpad3::		; vk63::
Numpad4::		; vk64::
Numpad5::		; vk65::
Numpad6::		; vk66::
Numpad7::		; vk67::
Numpad8::		; vk68::
Numpad9::		; vk69::
NumpadDot::		; vk6E::
NumpadDel::		; vk2E::
NumpadIns::		; vk2D::
NumpadClear::	; vk0C::
NumpadUp::		; vk26::
NumpadDown::	; vk28::
NumpadLeft::	; vk25::
NumpadRight::	; vk27::
NumpadHome::	; vk24::
NumpadEnd::		; vk23::
NumpadPgUp::	; vk21::
NumpadPgDn::	; vk22::
NumpadDiv::		; vk6F::
NumpadMult::	; vk6A::
NumpadAdd::		; vk6B::
NumpadSub::		; vk6D::
NumpadEnter::
sc59::	; (Mac)=
sc7E::	; (Mac),
sc5C::	; (NEC),
Browser_Back::		; vkA6::
Browser_Forward::	; vkA7::
Browser_Refresh::	; vkA8::
Browser_Stop::		; vkA9::
Browser_Search::	; vkAA::
Browser_Favorites::	; vkAB::
Browser_Home::		; vkAC::
Volume_Mute::		; vkAD::
Volume_Down::		; vkAE::
Volume_Up::			; vkAF::
Media_Next::		; vkB0::
Media_Prev::		; vkB1::
Media_Stop::		; vkB2::
Media_Play_Pause::	; vkB3::
Launch_Mail::		; vkB4::
Launch_Media::		; vkB5::
Launch_App1::		; vkB6::
Launch_App2::		; vkB7::
	; 入力バッファへ保存
	; キーを押す方はいっぱいまで使わない
	InBuf[InBufWrite] := A_ThisHotkey, InBufTime[InBufWrite] := WinAPI_timeGetTime()
		, InBufWrite := (InBufRest > 6) ? ++InBufWrite & 15 : InBufWrite
		, (InBufRest > 6) ? InBufRest-- :
	Convert()	; 変換ルーチン
	return

; キー押上げ
sc29 up::	; (JIS)半角/全角	(US)`
sc02 up::	; 1
sc03 up::	; 2
sc04 up::	; 3
sc05 up::	; 4
sc06 up::	; 5
sc07 up::	; 6
sc08 up::	; 7
sc09 up::	; 8
sc0A up::	; 9
sc0B up::	; 0
sc0C up::	; -
sc0D up::	; (JIS)^	(US)=
sc7D up::	; (JIS)￥
sc10 up::	; Q
sc11 up::	; W
sc12 up::	; E
sc13 up::	; R
sc14 up::	; T
sc15 up::	; Y
sc16 up::	; U
sc17 up::	; I
sc18 up::	; O
sc19 up::	; P
sc1A up::	; (JIS)@	(US)[
sc1B up::	; (JIS)[	(US)]
sc56 up::	; KC_NUBS
sc1E up::	; A
sc1F up::	; S
sc20 up::	; D
sc21 up::	; F
sc22 up::	; G
sc23 up::	; H
sc24 up::	; J
sc25 up::	; K
sc26 up::	; L
sc27 up::	; `;
sc28 up::	; (JIS):	(US)'
sc2B up::	; (JIS)]	(US)＼
sc2C up::	; Z
sc2D up::	; X
sc2E up::	; C
sc2F up::	; V
sc30 up::	; B
sc31 up::	; N
sc32 up::	; M
sc33 up::	; `,
sc34 up::	; .
sc35 up::	; /
sc73 up::	; (JIS)_
sc39 up::	; Space

Tab up::			; sc0F up::	vk09 up::
Enter up::
BackSpace up::		; sc0E up::	vk08 up::
Delete up::
Insert up::
Left up::
Right up::
Up up::
Down up::
Home up::
End up::
PgUp up::
PgDn up::
sc79 up::	; (JIS)変換
sc7B up::	; (JIS)無変換
sc70 up::	; (JIS)ひらがな
sc78 up::	; KC_LANG3
sc77 up::	; KC_LANG4
sc71 up::	; (Mac)英数 upのみ
sc72 up::	; (Mac)かな upのみ
F1 up::				; sc3B up::	vk70 up::
F2 up::				; sc3C up::	vk71 up::
F3 up::				; sc3D up::	vk72 up::
F4 up::				; sc3E up::	vk73 up::
F5 up::				; sc3F up::	vk74 up::
F6 up::				; sc40 up::	vk75 up::
F7 up::				; sc41 up::	vk76 up::
F8 up::				; sc42 up::	vk77 up::
F9 up::				; sc43 up::	vk78 up::
F10 up::			; sc44 up::	vk79 up::
F11 up::			; sc57 up::	vk7A up::
F12 up::			; sc58 up::	vk7B up::
F13 up::			; sc64 up::	vk7C up::
F14 up::			; sc65 up::	vk7D up::
F15 up::			; sc66 up::	vk7E up::
F16 up::			; sc67 up::	vk7F up::
F17 up::			; sc68 up::	vk80 up::
F18 up::			; sc69 up::	vk81 up::
F19 up::			; sc6A up::	vk82 up::
F20 up::			; sc6B up::	vk83 up::
F21 up::			; sc6C up::	vk84 up::
F22 up::			; sc6D up::	vk85 up::
F23 up::			; sc6E up::	vk86 up::
F24 up::			; sc76 up::	vk87 up::
Esc up::			; sc01 up::	vk1B up::
AppsKey up::		; vk5D up::
PrintScreen up::	; vk2C up::
sc54 up::	; SysRq
Pause up::			; sc45 up::	vk13 up::
;Break up::			; 認識しない
;Sleep up::			; 認識しない
;Help up::			; 認識しない
CtrlBreak up::
sc3A up::	; (JIS)英数	(US)CapsLock
ScrollLock up::		; sc46 up::
NumLock up::		; vk90 up::
LCtrl up::			; vkA2 up::
RCtrl up::			; vkA3 up::
LAlt up::			; vkA4 up::
RAlt up::			; vkA5 up::
LShift up::			; sc2A up::	vkA0 up::
RShift up::			; vkA1 up::
LWin up::			; vk5B up::
RWin up::			; vk5C up::
Numpad0 up::		; vk60 up::
Numpad1 up::		; vk61 up::
Numpad2 up::		; vk62 up::
Numpad3 up::		; vk63 up::
Numpad4 up::		; vk64 up::
Numpad5 up::		; vk65 up::
Numpad6 up::		; vk66 up::
Numpad7 up::		; vk67 up::
Numpad8 up::		; vk68 up::
Numpad9 up::		; vk69 up::
NumpadDot up::		; vk6E up::
NumpadDel up::		; vk2E up::
NumpadIns up::		; vk2D up::
NumpadClear up::	; vk0C up::
NumpadUp up::		; vk26 up::
NumpadDown up::		; vk28 up::
NumpadLeft up::		; vk25 up::
NumpadRight up::	; vk27 up::
NumpadHome up::		; vk24 up::
NumpadEnd up::		; vk23 up::
NumpadPgUp up::		; vk21 up::
NumpadPgDn up::		; vk22 up::
NumpadDiv up::		; vk6F up::
NumpadMult up::		; vk6A up::
NumpadAdd up::		; vk6B up::
NumpadSub up::		; vk6D up::
NumpadEnter up::
sc59 up::	; (Mac)=
sc7E up::	; (Mac),
sc5C up::	; (NEC),
Browser_Back up::		; vkA6 up::
Browser_Forward up::	; vkA7 up::
Browser_Refresh up::	; vkA8 up::
Browser_Stop up::		; vkA9 up::
Browser_Search up::		; vkAA up::
Browser_Favorites up::	; vkAB up::
Browser_Home up::		; vkAC up::
Volume_Mute up::		; vkAD up::
Volume_Down up::		; vkAE up::
Volume_Up up::			; vkAF up::
Media_Next up::			; vkB0 up::
Media_Prev up::			; vkB1 up::
Media_Stop up::			; vkB2 up::
Media_Play_Pause up::	; vkB3 up::
Launch_Mail up::		; vkB4 up::
Launch_Media up::		; vkB5 up::
Launch_App1 up::		; vkB6 up::
Launch_App2 up::		; vkB7 up::
	; 入力バッファへ保存
	InBuf[InBufWrite] := A_ThisHotkey, InBufTime[InBufWrite] := WinAPI_timeGetTime()
		, InBufWrite := InBufRest ? ++InBufWrite & 15 : InBufWrite
		, InBufRest ? InBufRest-- :
	Convert()	; 変換ルーチン
	return

#MaxThreadsPerHotkey 1	; 元に戻す
