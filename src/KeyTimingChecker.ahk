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
SetKeyDelay, -1, -1			; キーストローク間のディレイを変更
#MenuMaskKey vk07			; Win または Alt の押下解除時のイベントを隠蔽するためのキーを変更する
#UseHook					; ホットキーはすべてフックを使用する
;Process, Priority, , High	; プロセスの優先度を変更
Thread, interrupt, 15, 6	; スレッド開始から15ミリ秒ないし6行以内の割り込みを、絶対禁止
;SetStoreCapslockMode, off	; Sendコマンド実行時にCapsLockの状態を自動的に変更しない

;SetFormat, Integer, H		; 数値演算の結果を、16進数の整数による文字列で表現する

#HotkeyInterval 200			; 指定時間(ミリ秒単位)の間に実行できる最大のホットキー数
#MaxHotkeysPerInterval 200	; 指定時間の間に実行できる最大のホットキー数

; ----------------------------------------------------------------------
; グローバル変数
; ----------------------------------------------------------------------

; 入力バッファ
InBufsKey := []
InBufsTime := []	; 入力の時間

SCArray := ["Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Ø", "-", "{sc0D}", "BackSpace", "Tab"
	, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "{sc1A}", "{sc1B}", "", "", "A", "S"
	, "D", "F", "G", "H", "J", "K", "L", "{sc27}", "{sc28}", "{sc29}", "LShift", "{sc2B}", "Z", "X", "C", "V"
	, "B", "N", "M", ",", ".", "/", "", "", "", "Space", "CapsLock", "F1", "F2", "F3", "F4", "F5"
	, "F6", "F7", "F8", "F9", "F10", "Pause", "ScrollLock", "", "", "", "", "", "", "", "", ""
	, "", "", "", "", "SysRq", "", "KC_NUBS", "F11", "F12", "(Mac)=", "", "", "(NEC),", "", "", ""
	, "", "", "", "", "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", ""
	, "(JIS)ひらがな", "(Mac)英数", "(Mac)かな", "(JIS)_", "", "", "F24", "KC_LANG4"
	, "KC_LANG3", "(JIS)変換", "", "(JIS)無変換", "", "(JIS)￥", "(Mac),", ""]

LastKeyTime := QPC()
LastTerm := " "

; キーボードドライバを調べて KeyDriver に格納する
; 参考: https://ixsvr.dyndns.org/blog/764
RegRead, KeyDriver, HKEY_LOCAL_MACHINE, SYSTEM\CurrentControlSet\Services\i8042prt\Parameters, LayerDriver JPN

; ----------------------------------------------------------------------
; 起動
; ----------------------------------------------------------------------

Run, Notepad.exe, , , pid	; メモ帳を起動
Sleep, 500
WinActivate, ahk_pid %pid%	; アクティブ化
Send, キー入力の時間差を計測します。他のウインドウでキーを押すと終了します。

exit	; 起動時はここまで実行

; ----------------------------------------------------------------------
; タイマー関数、設定
; ----------------------------------------------------------------------

; 参照: https://www.autohotkey.com/boards/viewtopic.php?t=36016
QPCInit() {
	DllCall("QueryPerformanceFrequency", "Int64P", Freq)
	return Freq
}
QPC() {	; ミリ秒単位
	static Coefficient := 1000.0 / QPCInit()
	DllCall("QueryPerformanceCounter", "Int64P", Count)
	Return Count * Coefficient
}

; ----------------------------------------------------------------------
; サブルーチン
; ----------------------------------------------------------------------

SendTimer:
;	local Str, KeyTime, Term, diff, number, temp, BeginKeyTime

	BeginKeyTime := InBufsTime[1]	; 一塊の入力の先頭の時間を保存

	; 入力バッファが空になるまで
	while (ConvRest := InBufsKey.Length())
	{
		IfWinNotActive, ahk_pid %pid%
			ExitApp		; 起動したメモ帳以外へは出力しないで終了

		; 入力バッファから読み出し
		Str := InBufsKey.RemoveAt(1), KeyTime := InBufsTime.RemoveAt(1)

		; キーの上げ下げを調べる
		StringRight, Term, Str, 3	; Term に入力末尾の2文字を入れる
		if (Term = " up")	; キーが離されたとき
		{
			Term := "↑"
			Str := SubStr(Str, 1, StrLen(Str) - 3)
			if (Term != LastTerm)
				Send, % "{Enter}{Tab}{Tab}"
			else
				Send, % "{Space}"
		}
		else
		{
			Term := ""
			if (Term != LastTerm)
				Send, % "{Enter}"	; キーの上げ下げが変わったら改行
			else
				Send, % "{Space}"
		}
		; 前回の入力からの時間を書き出し
		diff := round(KeyTime - LastKeyTime, 1)
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
			if (SubStr(Str, 1, 2) = "sc")
			{
				number := "0x" . SubStr(Str, 3, 2)
				temp := SCArray[number]
				if (temp != "")
					Str := temp
			}
		}

		; 1文字ごとに間隔を置いて出力
		Send, % Str . Term

		LastKeyTime := KeyTime	; 押した時間を保存
		LastTerm := Term		; キーの上げ下げを保存
	}

	; 一塊の入力時間合計を出力
	Send, % "{Enter}" . "***** " . round(LastKeyTime - BeginKeyTime, 1) . "ms{Enter 2}"

	return

; ----------------------------------------------------------------------
; ホットキー
;		コメントの中で、:: がついていたら down と up のセットで入れ替え可能
; ※キーの調査には、ソフトウェア Keymill Ver.1.4 を使用しました。
;		http://kts.sakaiweb.com/keymill.html
; ※参考：https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
; ----------------------------------------------------------------------
; キー入力部
sc29::	; (JIS)半角/全角	(US)`
sc02::		; 1::	vk31::
sc03::		; 2::	vk32::
sc04::		; 3::	vk33::
sc05::		; 4::	vk34::
sc06::		; 5::	vk35::
sc07::		; 6::	vk36::
sc08::		; 7::	vk37::
sc09::		; 8::	vk38::
sc0A::		; 9::	vk39::
sc0B::		; 0::	vk30::
sc0C::		; -::	vkBD::
sc0D::	; (JIS)^	(US)=
sc7D::	; (JIS)￥
sc10::		; Q::	vk51::
sc11::		; W::	vk57::
sc12::		; E::	vk45::
sc13::		; R::	vk52::
sc14::		; T::	vk54::
sc15::		; Y::	vk59::
sc16::		; U::	vk55::
sc17::		; I::	vk49::
sc18::		; O::	vk4F::
sc19::		; P::	vk50::
sc1A::	; (JIS)@	(US)[
sc1B::	; (JIS)[	(US)]
sc56::	; KC_NUBS
sc1E::		; A::	vk41::
sc1F::		; S::	vk53::
sc20::		; D::	vk44::
sc21::		; F::	vk46::
sc22::		; G::	vk47::
sc23::		; H::	vk48::
sc24::		; J::	vk4A::
sc25::		; K::	vk4B::
sc26::		; L::	vk4C::
sc27::		; `;::
sc28::	; (JIS):	(US)'
sc2B::	; (JIS)]	(US)＼
sc2C::		; Z::	vk5A::
sc2D::		; X::	vk58::
sc2E::		; C::	vk43::
sc2F::		; V::	vk56::
sc30::		; B::	vk42::
sc31::		; N::	vk4E::
sc32::		; M::	vk4D::
sc33::	; ,			vkBC::
sc34::		; .::	vkBE::
sc35::		; /::	vkBF::
sc73::	; (JIS)_
sc39::		; Space::	vk20::

sc0F::			; Tab::		vk09::
Enter::
sc0E::			; BackSpace::	vk08::
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
sc79::		; (JIS)変換
sc7B::		; (JIS)無変換
sc70::		; (JIS)ひらがな
sc78::		; KC_LANG3
sc77::		; KC_LANG4
vk1A::		; (Mac)英数 downのみ
vk16::		; (Mac)かな downのみ
sc3B::			; F1::		vk70::
sc3C::			; F2::		vk71::
sc3D::			; F3::		vk72::
sc3E::			; F4::		vk73::
sc3F::			; F5::		vk74::
sc40::			; F6::		vk75::
sc41::			; F7::		vk76::
sc42::			; F8::		vk77::
sc43::			; F9::		vk78::
sc44::			; F10::		vk79::
sc57::			; F11::		vk7A::
sc58::			; F12::		vk7B::
sc64::			; F13::		vk7C::
sc65::			; F14::		vk7D::
sc66::			; F15::		vk7E::
sc67::			; F16::		vk7F::
sc68::			; F17::		vk80::
sc69::			; F18::		vk81::
sc6A::			; F19::		vk82::
sc6B::			; F20::		vk83::
sc6C::			; F21::		vk84::
sc6D::			; F22::		vk85::
sc6E::			; F23::		vk86::
sc76::			; F24::		vk87::
sc01::			; Esc::		vk1B::
AppsKey::		; vk5D::
PrintScreen::	; vk2C::
sc54::		; SysRq	※Alt+PrintScreen
sc45::			; Pause::	vk13::
;Break::	; 認識しない
;Sleep::	; 認識しない
;Help::		; 認識しない
CtrlBreak::	; ※Ctrl+Pause
sc3A::		; (JIS)英数	(US)CapsLock
sc46::			; ScrollLock::
NumLock::		; vk90::
LCtrl::			; vkA2::
RCtrl::			; vkA3::
LAlt::			; vkA4::
RAlt::			; vkA5::
sc2A::			; LShift::	vkA0::
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
sc59::		; (Mac)=
sc7E::		; (Mac),
sc5C::		; (NEC),
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


; キー押上げ
sc29 up::	; (JIS)半角/全角	(US)`
sc02 up::		; 1 up::	vk31 up::
sc03 up::		; 2 up::	vk32 up::
sc04 up::		; 3 up::	vk33 up::
sc05 up::		; 4 up::	vk34 up::
sc06 up::		; 5 up::	vk35 up::
sc07 up::		; 6 up::	vk36 up::
sc08 up::		; 7 up::	vk37 up::
sc09 up::		; 8 up::	vk38 up::
sc0A up::		; 9 up::	vk39 up::
sc0B up::		; 0 up::	vk30 up::
sc0C up::		; - up::	vkBD up::
sc0D up::	; (JIS)^	(US)=
sc7D up::	; (JIS)￥
sc10 up::		; Q up::	vk51 up::
sc11 up::		; W up::	vk57 up::
sc12 up::		; E up::	vk45 up::
sc13 up::		; R up::	vk52 up::
sc14 up::		; T up::	vk54 up::
sc15 up::		; Y up::	vk59 up::
sc16 up::		; U up::	vk55 up::
sc17 up::		; I up::	vk49 up::
sc18 up::		; O up::	vk4F up::
sc19 up::		; P up::	vk50 up::
sc1A up::	; (JIS)@	(US)[
sc1B up::	; (JIS)[	(US)]
sc56 up::	; KC_NUBS
sc1E up::		; A up::	vk41 up::
sc1F up::		; S up::	vk53 up::
sc20 up::		; D up::	vk44 up::
sc21 up::		; F up::	vk46 up::
sc22 up::		; G up::	vk47 up::
sc23 up::		; H up::	vk48 up::
sc24 up::		; J up::	vk4A up::
sc25 up::		; K up::	vk4B up::
sc26 up::		; L up::	vk4C up::
sc27 up::		; `; up::
sc28 up::	; (JIS):	(US)'
sc2B up::	; (JIS)]	(US)＼
sc2C up::		; Z up::	vk5A up::
sc2D up::		; X up::	vk58 up::
sc2E up::		; C up::	vk43 up::
sc2F up::		; V up::	vk56 up::
sc30 up::		; B up::	vk42 up::
sc31 up::		; N up::	vk4E up::
sc32 up::		; M up::	vk4D up::
sc33 up::	; ,				vkBC up::
sc34 up::		; . up::	vkBE up::
sc35 up::		; / up::	vkBF up::
sc73 up::	; (JIS)_
sc39 up::		; Space up::	vk20 up::

sc0F up::			; Tab up::	vk09 up::
Enter up::
sc0E up::			; BackSpace up::	; vk08 up::
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
sc79 up::		; (JIS)変換
sc7B up::		; (JIS)無変換
sc70 up::		; (JIS)ひらがな
sc78 up::		; KC_LANG3
sc77 up::		; KC_LANG4
sc71 up::		; (Mac)英数 upのみ
sc72 up::		; (Mac)かな upのみ
sc3B up::			; F1 up::	vk70 up::
sc3C up::			; F2 up::	vk71 up::
sc3D up::			; F3 up::	vk72 up::
sc3E up::			; F4 up::	vk73 up::
sc3F up::			; F5 up::	vk74 up::
sc40 up::			; F6 up::	vk75 up::
sc41 up::			; F7 up::	vk76 up::
sc42 up::			; F8 up::	vk77 up::
sc43 up::			; F9 up::	vk78 up::
sc44 up::			; F10 up::	vk79 up::
sc57 up::			; F11 up::	vk7A up::
sc58 up::			; F12 up::	vk7B up::
sc64 up::			; F13 up::	vk7C up::
sc65 up::			; F14 up::	vk7D up::
sc66 up::			; F15 up::	vk7E up::
sc67 up::			; F16 up::	vk7F up::
sc68 up::			; F17 up::	vk80 up::
sc69 up::			; F18 up::	vk81 up::
sc6A up::			; F19 up::	vk82 up::
sc6B up::			; F20 up::	vk83 up::
sc6C up::			; F21 up::	vk84 up::
sc6D up::			; F22 up::	vk85 up::
sc6E up::			; F23 up::	vk86 up::
sc76 up::			; F24 up::	vk87 up::
sc01 up::			; Esc up::	vk1B up::
AppsKey up::		; vk5D up::
PrintScreen up::	; vk2C up::
sc54 up::		; SysRq	※Alt+PrintScreen
sc45 up::			; Pause up::	vk13 up::
;Break up::		; 認識しない
;Sleep up::		; 認識しない
;Help up::		; 認識しない
CtrlBreak up::	; ※Ctrl+Pause
sc3A up::		; (JIS)英数	(US)CapsLock
sc46 up::			; ScrollLock up::
NumLock up::		; vk90 up::
LCtrl up::			; vkA2 up::
RCtrl up::			; vkA3 up::
LAlt up::			; vkA4 up::
RAlt up::			; vkA5 up::
sc2A up::			; LShift up::	vkA0 up::
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
sc59 up::		; (Mac)=
sc7E up::		; (Mac),
sc5C up::		; (NEC),
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
	InBufsKey.Push(A_ThisHotkey), InBufsTime.Push(QPC())
	IfWinNotActive, ahk_pid %pid%
		ExitApp					; 起動したメモ帳以外への入力だったら終了
	SetTimer, SendTimer, -1050	; キー変化なく1.05秒たったら表示
	return
