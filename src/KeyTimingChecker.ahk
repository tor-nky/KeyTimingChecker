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

SCArray := ["Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "{sc0D}", "BackSpace", "Tab"
	, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{sc1A}", "{sc1B}", "", "Ctrl", "A", "S"
	, "D", "F", "G", "H", "J", "K", "L", "{sc27}", "{sc28}", "{sc29}", "LShift", "{sc2B}", "Z", "X", "C", "V"
	, "B", "N", "M", ",", ".", "/", "", "", "", "Space", "CapsLock", "F1", "F2", "F3", "F4", "F5"
	, "F6", "F7", "F8", "F9", "F10", "Pause", "ScrollLock", "", "", "", "", "", "", "", "", ""
	, "", "", "", "", "SysRq", "", "KC_NUBS", "F11", "F12", "(Mac)=", "", "", "(NEC),", "", "", ""
	, "", "", "", "", "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", ""
	, "(JIS)ひらがな", "(Mac)英数", "(Mac)かな", "(JIS)＼", "", "", "F24", "KC_LANG4"
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
Sleep, 100
WinActivate, ahk_pid %pid%	；アクティブ化
Send, キー入力の時間差を計測します。10秒間、何もキーを押さなければ終了します。`n
SetTimer, Timeout, 10000	; 10 秒間、何もキーを押さなければ終了

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

Timeout:	; 一定時間、キーを押さなければ終了
	IfWinActive, ahk_pid %pid%
		Send, 終了.	; 起動したメモ帳がアクティブだったら出力
	ExitApp

; ----------------------------------------------------------------------
; 関数
; ----------------------------------------------------------------------

Convert()
{
	global SCArray, KeyDriver, pid
		, InBuf, InBufRead, InBufTime, InBufRest
	static run := 0	; 多重起動防止フラグ
		, LastKeyTime := 0
;	local Str, Start, Term
;		, diff, number

	SetTimer, Timeout, 10000	; タイマー更新

	if (run)
		return	; 多重起動防止で終了

	IfWinNotActive, ahk_pid %pid%
		ExitApp		; 起動したメモ帳以外への入力だったら終了

	; 入力バッファが空になるまで
	while (run := 15 - InBufRest)
	{
		; 入力バッファから読み出し
		Str := InBuf[InBufRead], KeyTime := InBufTime[InBufRead++], InBufRead &= 15, InBufRest++

		; 前回の入力からの時間を書き出し
		diff := KeyTime - LastKeyTime
		if diff < 10000
			Send, % "<" . diff . "ms> "

		; 入力文字の書き出し
		StringRight, Term, Str, 2	; Term に入力末尾の2文字を入れる
		if (Term == "up")	; キーが離されたとき
		{
			Term := "↑ "
			Str := SubStr(Str, 1, StrLen(Str) - 3)
		}
		else
			Term := " "

		if (Str == "sc29" && KeyDriver != "kbd101.dll")
			Str := "半角/全角"
		else if (Str == "sc3A" && KeyDriver != "kbd101.dll")
			Str := "英数"
		else if (Str == "LWin")		; LWin を半角のまま出力すると、なぜか Win+L が発動する
			Str := "ＬWin"
		else if (Str == "vk1A")
			Str := "(Mac)英数"
		else if (Str == "vk16")
			Str := "(Mac)かな"
		else
		{
			StringLeft, Start, Str, 2	; Start に入力先頭の2文字を入れる
			if (Start = "sc")
			{
				number := "0x" . SubStr(Str, 3, 2)
				Str := SCArray[number & 0x7F]
			}
		}

		Send, % Str . Term

		LastKeyTime := KeyTime		; 押した時間を保存
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
sc7D::	; (JIS)\
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

Esc::			; または sc01::
BackSpace::		; または sc0E::
Tab::			; または sc0F::
Enter::
NumpadEnter::
LCtrl::			; vkA2::
RCtrl::			; vkA3::
LShift::		; または sc2A::
RShift::		; vkA1::
PrintScreen::	; vk2C::
NumpadMult::	; vk6A::
NumpadDiv::		; vk6F::
LAlt::			; vkA4::
RAlt::			; vkA5::
sc3A::	; (JIS)英数	(US)CapsLock
F1::			; または sc3B::
F2::			; または sc3C::
F3::			; または sc3D::
F4::			; または sc3E::
F5::			; または sc3F::
F6::			; または sc40::
F7::			; または sc41::
F8::			; または sc42::
F9::			; または sc43::
F10::			; または sc44::
Pause::			; または sc45::
NumLock::		; vk90::
sc46::	; ScrollLock
Home::
NumpadHome::
Numpad7::		; vk67::
Up::
NumpadUp::
Numpad8::		; vk68::
PgUp::
NumpadPgUp::
Numpad9::		; vk69::
NumpadSub::		; vk6D::
Left::
NumpadLeft::
Numpad4::		; vk64::
NumpadClear::
Numpad5::		; vk65::
Right::
NumpadRight::
Numpad6::		; vk66::
NumpadAdd::		; vk6B::
End::
NumpadEnd::
Numpad1::		; vk61::
Down::
NumpadDown::
Numpad2:		; vk62::
PgDn::
NumpadPgDn::
Numpad3::		; vk63::
Insert::
NumpadIns::
Numpad0::		; vk60::
Del::
NumpadDel::
NumpadDot::		; vk6E::
sc54::	; SysRq
sc56::	; non_us_backslash
F11::			; または sc57::
F12::			; または sc58::
sc59::	; (Mac)=
LWin::			; または vk5B::
RWin::			; または vk5C::
sc5C::	; (NEC),
AppsKey::
F13::			; または sc64::
F14::			; または sc65::
F15::			; または sc66::
F16::			; または sc67::
F17::			; または sc68::
F18::			; または sc69::
F19::			; または sc6A::
F20::			; または sc6B::
F21::			; または sc6C::
F22:: 			; または sc6D::
F23::			; または sc6E::
sc70::	; (JIS)ひらがな
F24::			; または sc76::
sc77::	; lang4
sc78::	; lang3
sc79::	; (JIS)変換
sc7B::	; (JIS)無変換
sc7E::	; (Mac),
vk1A::	; (Mac)英数 downのみ
vk16::	; (Mac)かな downのみ
;Break::	; 不可
;Sleep::	; 不可
;Help::	; 不可
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
sc7D up::	; (JIS)\
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
sc1E up::	; A
sc1F up::	; S
sc20 up::	; D
sc21 up::	; F
sc22 up::	; G
sc23 up::	; H
sc24 up::	; J
sc25 up::	; K
sc26 up::	; L
sc27 up::	; ;
sc28 up::	; (JIS):	(US)'
sc2B up::	; (JIS)]	(US)＼
sc2C up::	; Z
sc2D up::	; X
sc2E up::	; C
sc2F up::	; V
sc30 up::	; B
sc31 up::	; N
sc32 up::	; M
sc33 up::	; ,
sc34 up::	; .
sc35 up::	; /
sc73 up::	; (JIS)_
sc39 up::	; Space

Esc up::			; または sc01 up::
BackSpace up::		; または sc0E up::
Tab up::			; または sc0F up::
Enter up::
NumpadEnter up::
LCtrl up::			; vkA2 up::
RCtrl up::			; vkA3 up::
LShift up::			; または sc2A up::
RShift up::			; vkA1 up::
PrintScreen up::	; vk2C up::
NumpadMult up::		; vk6A up::
NumpadDiv up::		; vk6F up::
LAlt up::			; vkA4 up::
RAlt up::			; vkA5 up::
sc3A up::	; (JIS)英数	(US)CapsLock
F1 up::				; または sc3B up::
F2 up::				; または sc3C up::
F3 up::				; または sc3D up::
F4 up::				; または sc3E up::
F5 up::				; または sc3F up::
F6 up::				; または sc40 up::
F7 up::				; または sc41 up::
F8 up::				; または sc42 up::
F9 up::				; または sc43 up::
F10 up::			; または sc44 up::
Pause up::			; または sc45 up::
NumLock up::		; vk90 up::
sc46 up::	; ScrollLock
Home up::
NumpadHome up::
Numpad7 up::		; vk67 up::
Up up::
NumpadUp up::
Numpad8 up::		; vk68 up::
PgUp up::
NumpadPgUp up::
Numpad9 up::		; vk69 up::
NumpadSub up::		; vk6D up::
Left up::
NumpadLeft up::
Numpad4 up::		; vk64 up::
NumpadClear up::
Numpad5 up::		; vk65 up::
Right up::
NumpadRight up::
Numpad6 up::		; vk66 up::
NumpadAdd up::		; vk6B up::
End up::
NumpadEnd up::
Numpad1 up::		; vk61 up::
Down up::
NumpadDown up::
Numpad2 up::		; vk62 up::
PgDn up::
NumpadPgDn up::
Numpad3 up::		; vk63 up::
Insert up::
NumpadIns up::
Numpad0 up::		; vk60 up::
Del up::
NumpadDel up::
NumpadDot up::		; vk6E up::
sc54 up::	; SysRq
sc56 up::	; non_us_backslash
F11 up::			; または sc57 up::
F12 up::			; または sc58 up::
sc59 up::	; (Mac)=
LWin up::			; vk5B up::
RWin up::			; vk5C up::
sc5C up::	; (NEC),
AppsKey up::
F13 up::			; または sc64 up::
F14 up::			; または sc65 up::
F15 up::			; または sc66 up::
F16 up::			; または sc67 up::
F17 up::			; または sc68 up::
F18 up::			; または sc69 up::
F19 up::			; または sc6A up::
F20 up::			; または sc6B up::
F21 up::			; または sc6C up::
F22 up:: 			; または sc6D up::
F23 up::			; または sc6E up::
sc70 up::	; (JIS)ひらがな
sc71 up::	; (Mac)英数 upのみ
sc72 up::	; (Mac)かな upのみ
F24 up::			; または sc76 up::
sc77 up::	; lang4
sc78 up::	; lang3
sc79 up::	; (JIS)変換
sc7B up::	; (JIS)無変換
sc7E up::	; (Mac),
;Break up::	; 不可
;Sleep up::	; 不可
;Help up::	; 不可
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
