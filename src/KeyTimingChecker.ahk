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
;		正確に測るため、出力は 1.05 秒後にまとめて
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
Thread, interrupt, 15, 5	; スレッド開始から15ミリ秒ないし5行以内の割り込みを、絶対禁止
;SetStoreCapslockMode, off	; Sendコマンド実行時にCapsLockの状態を自動的に変更しない

;SetFormat, Integer, H		; 数値演算の結果を、16進数の整数による文字列で表現する

#HotkeyInterval 200			; 指定時間(ミリ秒単位)の間に実行できる最大のホットキー数
#MaxHotkeysPerInterval 200	; 指定時間の間に実行できる最大のホットキー数

; ----------------------------------------------------------------------
; グローバル変数
; ----------------------------------------------------------------------

; 入力バッファ
changedKeys := []	; [String]型
changeCounter := []	; [Int64]型		入力の時間
; count				; Int64型
; nowKeyName		; String型
; clipSaved :=

; キーボードドライバを調べて keyDriver に格納する
; 参考: https://ixsvr.dyndns.org/blog/764
RegRead, keyDriver, HKEY_LOCAL_MACHINE, SYSTEM\CurrentControlSet\Services\i8042prt\Parameters, LayerDriver JPN
		; keyDriver: String型

	codeToStr := ["Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Ø", "-", "=", "BackSpace", "Tab"	; sc01-0F
		, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "Enter", "LCtrl", "A", "S"		; sc10-1F
		, "D", "F", "G", "H", "J", "K", "L", ";", "'", "`", "LShift", "＼", "Z", "X", "C", "V"			; sc20-2F
		, "B", "N", "M", ",", ".", "/", , "NumpadMult"													; sc30-37
		, "LAlt", "Space", "CapsLock", "F1", "F2", "F3", "F4", "F5"										; sc38-3F
		, "F6", "F7", "F8", "F9", "F10", "Pause", "ScrollLock"]											; sc40-46
			; String型
	If (GetKeyState("NumLock", "T"))
		codeToStr.Insert(0x47, "Numpad7", "Numpad8", "Numpad9", "NumpadSub"
			, "Numpad4", "Numpad5", "Numpad6", "NumpadAdd"
			, "Numpad1", "Numpad2", "Numpad3", "Numpad0", "NumpadDot")
	Else
		codeToStr.Insert(0x47, "NumpadHome", "NumpadUp", "NumpadPgUp", "NumpadSub"
			, "NumpadLeft", "NumpadClear", "NumpadRight", "NumpadAdd"
			, "NumpadEnd", "NumpadDown", "NumpadPgDn", "NumpadIns", "NumpadDel")
	codeToStr.Insert(0x54, "SysRq", , "KC_NUBS", "F11", "F12", "(Mac)=", , , "(NEC),")
	codeToStr.Insert(0x64, "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23")
	codeToStr.Insert(0x70, "(JIS)ひらがな", "(Mac)英数", "(Mac)かな", "(JIS)_", ,
		, "F24", "KC_LANG4", "KC_LANG3", "(JIS)変換", , "(JIS)無変換", , "(JIS)￥", "(Mac),")
	codeToStr.Insert(0x11C, "NumpadEnter", "RCtrl")
	codeToStr.Insert(0x135, "NumpadDiv", "RShift", "PrintScreen", "RAlt")
	codeToStr.Insert(0x145, "NumLock", , "Home", "Up", "PgUp", , "Left", , "Right", , "End"
		, "Down", "PgDn", "Insert", "Delete")
	codeToStr.Insert(0x15B, "LWin", "RWin", "AppsKey")
	If (keyDriver != "kbd101.dll")
	{
		codeToStr[0x0D] := "^"
		codeToStr[0x1A] := "@"
		codeToStr[0x1B] := "["
		codeToStr[0x28] := ":"
		codeToStr[0x29] := "半角/全角"
		codeToStr[0x2B] := "]"
		codeToStr[0x3A] := "英数"
	}

	codeToStr[0x216] := "(Mac)かな"
	codeToStr[0x21A] := "(Mac)英数"
	codeToStr.Insert(0x2A6, "Browser_Back", "Browser_Forward"
		, "Browser_Refresh", "Browser_Stop", "Browser_Search", "Browser_Favorites"
		, "Browser_Home", "Volume_Mute", "Volume_Down", "Volume_Up"
		, "Media_Next", "Media_Prev", "Media_Stop", "Media_Play_Pause"
		, "Launch_Mail", "Launch_Media", "Launch_App1", "Launch_App2")

; ----------------------------------------------------------------------
; 起動
; ----------------------------------------------------------------------

	Run, Notepad.exe, , , pid	; メモ帳を起動
	Sleep, 500
	WinActivate, ahk_pid %pid%	; アクティブ化
	If (A_IsCompiled)
	{
		; 実行ファイル化されたスクリプトの場合は終了
		Send, 実行ファイル化されているので終了します。
		ExitApp
	}
	clipSaved := ClipboardAll	; クリップボードの全内容を保存
	OnExit, ExitSub	; スクリプト終了時に実行させたいサブルーチンを指定
	Clipboard := "キー入力の時間差を計測します。他のウインドウでキーを押すと終了します。"
	Send, ^v

Exit	; 起動時はここまで実行

; ----------------------------------------------------------------------
; タイマー関数、設定
; ----------------------------------------------------------------------

; 参照: https://www.autohotkey.com/boards/viewtopic.php?t=36016
QPCInit() {	; () -> Int64
	DllCall("QueryPerformanceFrequency", "Int64P", freq)	; freq: Int64型
	Return freq
}
QPC() {		; () -> Double	ミリ秒単位
	static coefficient := 1000.0 / QPCInit()	; Double型
	DllCall("QueryPerformanceCounter", "Int64P", count)	; count: Int64型
	Return count * coefficient
}

; ----------------------------------------------------------------------
; サブルーチン
; ----------------------------------------------------------------------

; スクリプト終了時に実行
ExitSub:
	Clipboard := clipSaved	; クリップボードの内容を復元
	clipSaved :=			; 保存用変数に使ったメモリを解放
	ExitApp

OutputTimer:
	SetTimer, OutputTimer, Off
	If (changedKeys.Length())
		Output()
	Return

; ----------------------------------------------------------------------
; 関数
; ----------------------------------------------------------------------

Output()	; () -> Double?
{
	global pid, changedKeys, changeCounter, codeToStr
	static coefficient := 1000.0 / QPCInit()	; Double型
	static lastKeyTime := QPC()		; Double型
;	local keyName, preKeyName, postKeyName, lastPostKeyName	; String型
;		, outputString										; String型
;		, keyTime, startTime								; Double型
;		, pressKeyCount, releaseKeyCount, repeatKeyCount, 	; Int型
;		, i, number, multiPress		; Int型
;		, pressingKeys				; [String]型

	; 起動したメモ帳以外へは出力しないで終了
	IfWinNotActive, ahk_pid %pid%
		ExitApp
	; 「保存しますか?」などの表示窓には出力しないで終了
	IfWinActive , ahk_class #32770
		ExitApp

	; 変数の初期化
	pressKeyCount := repeatKeyCount := releaseKeyCount := 0
	multiPress := 0
	pressingKeys := []
	outputString :=
	; 起動から、または前回表示からの経過時間表示が不要なら次の初期値は "" とする
	lastPostKeyName := " "

	; 一塊の入力の先頭の時間を保存
	startTime := changeCounter[1] * coefficient

	; 入力バッファが空になるまで
	While (changedKeys.Length())
	{
		; 入力バッファから読み出し
		keyName := changedKeys.RemoveAt(1), keyTime := changeCounter.RemoveAt(1) * coefficient

		; キーの上げ下げを調べる
		StringRight, postKeyName, keyName, 3	; postKeyName に入力末尾の3文字を入れる
		; キーが離されたとき
		If (postKeyName = " up")
		{
			StringTrimRight, keyName, keyName, 3
			releaseKeyCount++
			; ロールオーバー押し検出用 押しているキーを入れた配列から消す
			i := 1
			While (i <= pressingKeys.Length())
			{
				If (keyName = pressingKeys[i])
				{
					pressingKeys.RemoveAt(i)
					Break
				}
				i++
			}

			preKeyName := "", postKeyName := "↑"
			If (lastPostKeyName != postKeyName)
				outputString .= "`n`t`t"	; キーの上げ下げが変わったら改行と字下げ
			Else
				outputString .= " "
		}
		Else
		{
			; キーリピートでないキーを数える
			If (keyName != pressingKeys[pressingKeys.Length()])
			{
				pressKeyCount++
				preKeyName := "", postKeyName := "↓"
			}
			Else
			{
				repeatKeyCount++
				preKeyName := "<", postKeyName := ">"
			}
			; ロールオーバー押し検出 押しているキーを入れた配列と比べる
			i := 1
			While (i <= pressingKeys.Length())
			{
				If (keyName = pressingKeys[i])
					Break
				i++
			}
			If (i > pressingKeys.Length())
			{
				; 配列に追加
				pressingKeys.Push(keyName)
				; 同時押し数更新
				If (i > multiPress)
					multiPress := i
			}

			If (lastPostKeyName != "↓" && lastPostKeyName != ">")
				outputString .= "`n"	; キーの上げ下げが変わったら改行
			Else
				outputString .= " "
		}
		; 前回の入力からの時間を書き出し
		If (lastPostKeyName != "")
			outputString .= "(" . Round(keyTime - lastKeyTime, 1) . "ms) "

		; 入力文字の書き出し
		temp :=
		StringLeft, topKeyName, keyName, 2	; topKeyName に入力先頭の2文字を入れる
		number := (topKeyName = "sc" ? "0x" . SubStr(keyName, 3)
				 : topKeyName = "vk" ? "0x2" . SubStr(keyName, 3)
				 : 0)
		If (number)
			keyName := codeToStr[number]
		outputString .= preKeyName . keyName . postKeyName

		; 変数の更新
		lastKeyTime := keyTime	; 押した時間を保存
		lastPostKeyName := postKeyName		; キーの上げ下げを保存
	}

	; 一塊の入力時間合計を出力
	outputString .= "`n***** キー変化 " . pressKeyCount + repeatKeyCount + releaseKeyCount
		. " 回で " . Round(keyTime - startTime, 1) . " ms。`n`t("
		. pressKeyCount . " 個押し + " . repeatKeyCount . " 個キーリピート + " . releaseKeyCount . " 個離す)`n"
	If (multiPress > 1)
		outputString .= "`t同時押し 最高 " . multiPress . " キー。`n"
	outputString .= "`n"
	Clipboard := outputString
	Send, ^v

	Return
}

; ----------------------------------------------------------------------
; ホットキー
;		コメントの中で、:: がついていたら down と up のセットで入れ替え可能
; ※キーの調査には、ソフトウェア Keymill Ver.1.4 を使用しました。
;		http://kts.sakaiweb.com/keymill.html
; ※参考：https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
; ----------------------------------------------------------------------
#MaxThreadsPerHotkey 3	; 1つのホットキー・ホットストリングに多重起動可能な
						; 最大のスレッド数を設定

; キー入力部
sc01::		; Esc::		Escape::	vk1B::
sc02::		; 1::		vk31::
sc03::		; 2::		vk32::
sc04::		; 3::		vk33::
sc05::		; 4::		vk34::
sc06::		; 5::		vk35::
sc07::		; 6::		vk36::
sc08::		; 7::		vk37::
sc09::		; 8::		vk38::
sc0A::		; 9::		vk39::
sc0B::		; 0::		vk30::
sc0C::		; -::		vkBD::
sc0D::	; ※ (JIS)^	(US)=
sc0E::		; BackSpace::	BS::	vk08::
sc0F::		; Tab::		vk09::
sc10::		; Q::		vk51::
sc11::		; W::		vk57::
sc12::		; E::		vk45::
sc13::		; R::		vk52::
sc14::		; T::		vk54::
sc15::		; Y::		vk59::
sc16::		; U::		vk55::
sc17::		; I::		vk49::
sc18::		; O::		vk4F::
sc19::		; P::		vk50::
sc1A::	; ※ (JIS)@	(US)[
sc1B::	; ※ (JIS)[	(US)]
sc1C::		; Enter::
sc1D::		; LCtrl::	vkA2::
sc1E::		; A::		vk41::
sc1F::		; S::		vk53::
sc20::		; D::		vk44::
sc21::		; F::		vk46::
sc22::		; G::		vk47::
sc23::		; H::		vk48::
sc24::		; J::		vk4A::
sc25::		; K::		vk4B::
sc26::		; L::		vk4C::
sc27::		; `;::
sc28::	; ※ (JIS):	(US)'
sc29::	; ※ (JIS)半角/全角	(US)`
sc2A::		; LShift::	vkA0::
sc2B::	; ※ (JIS)]	(US)＼
sc2C::		; Z::		vk5A::
sc2D::		; X::		vk58::
sc2E::		; C::		vk43::
sc2F::		; V::		vk56::
sc30::		; B::		vk42::
sc31::		; N::		vk4E::
sc32::		; M::		vk4D::
sc33::	; ※ ,			vkBC::
sc34::		; .::		vkBE::
sc35::		; /::		vkBF::
sc37::		; NumpadMult::	vk6A::
sc38::		; LAlt::	vkA4::
sc39::		; Space::	vk20::
sc3A::	; ※ (JIS)英数	(US)CapsLock
sc3B::		; F1::		vk70::
sc3C::		; F2::		vk71::
sc3D::		; F3::		vk72::
sc3E::		; F4::		vk73::
sc3F::		; F5::		vk74::
sc40::		; F6::		vk75::
sc41::		; F7::		vk76::
sc42::		; F8::		vk77::
sc43::		; F9::		vk78::
sc44::		; F10::		vk79::
sc45::		; Pause::	vk13::
sc46::		; ScrollLock::
sc47::		; Numpad7::		vk67::
			; NumpadHome::	vk24::
sc48::		; Numpad8::		vk68::
			; NumpadUp::	vk26::
sc49::		; Numpad9::		vk69::
			; NumpadPgUp::	vk21::
sc4A::		; NumpadSub::	vk6D::
sc4B::		; Numpad4::		vk64::
			; NumpadLeft::	vk25::
sc4C::		; Numpad5::		vk65::
			; NumpadClear::	vk0C::
sc4D::		; Numpad6::		vk66::
			; NumpadRight::	vk27::
sc4E::		; NumpadAdd::	vk6B::
sc4F::		; Numpad1::		vk61::
			; NumpadEnd::	vk23::
sc50::		; Numpad2::		vk62::
			; NumpadDown::	vk28::
sc51::		; Numpad3::		vk63::
			; NumpadPgDn::	vk22::
sc52::		; Numpad0::		vk60::
			; NumpadIns::	vk2D::
sc53::		; NumpadDot::	vk6E::
			; NumpadDel::	vk2E::
sc54::	; ※ SysRq	＝ Alt+PrintScreen
sc56::	; ※ KC_NUBS
sc57::		; F11::		vk7A::
sc58::		; F12::		vk7B::
sc59::	; ※ (Mac)=
sc5C::	; ※ (NEC),
sc64::		; F13::		vk7C::
sc65::		; F14::		vk7D::
sc66::		; F15::		vk7E::
sc67::		; F16::		vk7F::
sc68::		; F17::		vk80::
sc69::		; F18::		vk81::
sc6A::		; F19::		vk82::
sc6B::		; F20::		vk83::
sc6C::		; F21::		vk84::
sc6D::		; F22::		vk85::
sc6E::		; F23::		vk86::
sc70::	; ※ (JIS)ひらがな
sc73::	; ※ (JIS)_
sc76::		; F24::		vk87::
sc77::	; ※ KC_LANG4
sc78::	; ※ KC_LANG3
sc79::	; ※ (JIS)変換
sc7B::	; ※ (JIS)無変換
sc7D::	; ※ (JIS)￥
sc7E::	; ※ (Mac),
sc11C::		; NumpadEnter::
sc11D::		; RCtrl::		vkA3::
sc135::		; NumpadDiv::	vk6F::
sc136::		; RShift::		vkA1::
sc137::		; PrintScreen::	vk2C::
sc138::		; RAlt::		vkA5::
sc145::		; NumLock::		vk90::
sc147::		; Home::
sc148::		; Up::
sc149::		; PgUp::
sc14B::		; Left::
sc14D::		; Right::
sc14F::		; End::
sc150::		; Down::
sc151::		; PgDn::
sc152::		; Insert::		Ins::
sc153::		; Delete::		Del::
sc15B::		; LWin::		vk5B::
sc15C::		; RWin::		vk5C::
sc15D::		; AppsKey::		vk5D::

vk1A::	; ※ (Mac)英数 downのみ認識
vk16::	; ※ (Mac)かな downのみ認識
vkA6::		; Browser_Back::
vkA7::		; Browser_Forward::
vkA8::		; Browser_Refresh::
vkA9::		; Browser_Stop::
vkAA::		; Browser_Search::
vkAB::		; Browser_Favorites::
vkAC::		; Browser_Home::
vkAD::		; Volume_Mute::
vkAE::		; Volume_Down::
vkAF::		; Volume_Up::
vkB0::		; Media_Next::
vkB1::		; Media_Prev::
vkB2::		; Media_Stop::
vkB3::		; Media_Play_Pause::
vkB4::		; Launch_Mail::
vkB5::		; Launch_Media::
vkB6::		; Launch_App1::
vkB7::		; Launch_App2::

Break::		; ※ 認識しない
Sleep::		; ※ 認識しない
Help::		; ※ 認識しない
CtrlBreak::	; ※ Ctrl+Pause


; キー押上げ
sc01 up::		; Esc up::	Escape up::		vk1B up::
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
sc0D up::	; ※ (JIS)^	(US)=
sc0E up::		; BackSpace up::	BS up::		vk08 up::
sc0F up::		; Tab up::	vk09 up::
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
sc1A up::	; ※ (JIS)@	(US)[
sc1B up::	; ※ (JIS)[	(US)]
sc1C up::		; Enter up::
sc1D up::		; LCtrl up::	vkA2 up::
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
sc28 up::	; ※ (JIS):	(US)'
sc29 up::	; ※ (JIS)半角/全角	(US)`
sc2A up::		; LShift up::	vkA0 up::
sc2B up::	; ※ (JIS)]	(US)＼
sc2C up::		; Z up::	vk5A up::
sc2D up::		; X up::	vk58 up::
sc2E up::		; C up::	vk43 up::
sc2F up::		; V up::	vk56 up::
sc30 up::		; B up::	vk42 up::
sc31 up::		; N up::	vk4E up::
sc32 up::		; M up::	vk4D up::
sc33 up::	; ※ ,			vkBC up::
sc34 up::		; . up::	vkBE up::
sc35 up::		; / up::	vkBF up::
sc37 up::		; NumpadMult up::	vk6A up::
sc38 up::		; LAlt up::			vkA4 up::
sc39 up::		; Space up::		vk20 up::
sc3A up::	; ※ (JIS)英数	(US)CapsLock
sc3B up::		; F1 up::	vk70 up::
sc3C up::		; F2 up::	vk71 up::
sc3D up::		; F3 up::	vk72 up::
sc3E up::		; F4 up::	vk73 up::
sc3F up::		; F5 up::	vk74 up::
sc40 up::		; F6 up::	vk75 up::
sc41 up::		; F7 up::	vk76 up::
sc42 up::		; F8 up::	vk77 up::
sc43 up::		; F9 up::	vk78 up::
sc44 up::		; F10 up::	vk79 up::
sc45 up::		; Pause up::	vk13 up::
sc46 up::		; ScrollLock up::
sc47 up::		; Numpad7 up::		vk67 up::
				; NumpadHome up::	vk24 up::
sc48 up::		; Numpad8 up::		vk68 up::
				; NumpadUp up::		vk26 up::
sc49 up::		; Numpad9 up::		vk69 up::
				; NumpadPgUp up::	vk21 up::
sc4A up::		; NumpadSub up::	vk6D up::
sc4B up::		; Numpad4 up::		vk64 up::
				; NumpadLeft up::	vk25 up::
sc4C up::		; Numpad5 up::		vk65 up::
				; NumpadClear up::	vk0C up::
sc4D up::		; Numpad6 up::		vk66 up::
				; NumpadRight up::	vk27 up::
sc4E up::		; NumpadAdd up::	vk6B up::
sc4F up::		; Numpad1 up::		vk61 up::
				; NumpadEnd up::	vk23 up::
sc50 up::		; Numpad2 up::		vk62 up::
				; NumpadDown up::	vk28 up::
sc51 up::		; Numpad3 up::		vk63 up::
				; NumpadPgDn up::	vk22 up::
sc52 up::		; Numpad0 up::		vk60 up::
				; NumpadIns up::	vk2D up::
sc53 up::		; NumpadDot up::	vk6E up::
				; NumpadDel up::	vk2E up::
sc54 up::	; ※ SysRq	＝ Alt+PrintScreen
sc56 up::	; ※ KC_NUBS
sc57 up::		; F11 up::	vk7A up::
sc58 up::		; F12 up::	vk7B up::
sc59 up::	; ※ (Mac)=
sc5C up::	; ※ (NEC),
sc64 up::		; F13 up::	vk7C up::
sc65 up::		; F14 up::	vk7D up::
sc66 up::		; F15 up::	vk7E up::
sc67 up::		; F16 up::	vk7F up::
sc68 up::		; F17 up::	vk80 up::
sc69 up::		; F18 up::	vk81 up::
sc6A up::		; F19 up::	vk82 up::
sc6B up::		; F20 up::	vk83 up::
sc6C up::		; F21 up::	vk84 up::
sc6D up::		; F22 up::	vk85 up::
sc6E up::		; F23 up::	vk86 up::
sc70 up::	; ※ (JIS)ひらがな
sc71 up::	; ※ (Mac)英数 upのみ認識
sc72 up::	; ※ (Mac)かな upのみ認識
sc73 up::	; ※ (JIS)_
sc76 up::		; F24 up::	vk87 up::
sc77 up::	; ※ KC_LANG4
sc78 up::	; ※ KC_LANG3
sc79 up::	; ※ (JIS)変換
sc7B up::	; ※ (JIS)無変換
sc7D up::	; ※ (JIS)￥
sc7E up::	; ※ (Mac),
sc11C up::		; NumpadEnter up::
sc11D up::		; RCtrl up::		vkA3 up::
sc135 up::		; NumpadDiv up::	vk6F up::
sc136 up::		; RShift up::		vkA1 up::
sc137 up::		; PrintScreen up::	vk2C up::
sc138 up::		; RAlt up::			vkA5 up::
sc145 up::		; NumLock up::		vk90 up::
sc147 up::		; Home up::
sc148 up::		; Up up::
sc149 up::		; PgUp up::
sc14B up::		; Left up::
sc14D up::		; Right up::
sc14F up::		; End up::
sc150 up::		; Down up::
sc151 up::		; PgDn up::
sc152 up::		; Insert up::	Ins up::
sc153 up::		; Delete up::	Del up::
sc15B up::		; LWin up::		vk5B up::
sc15C up::		; RWin up::		vk5C up::
sc15D up::		; AppsKey up::	vk5D up::

vkA6 up::		; Browser_Back up::
vkA7 up::		; Browser_Forward up::
vkA8 up::		; Browser_Refresh up::
vkA9 up::		; Browser_Stop up::
vkAA up::		; Browser_Search up::
vkAB up::		; Browser_Favorites up::
vkAC up::		; Browser_Home up::
vkAD up::		; Volume_Mute up::
vkAE up::		; Volume_Down up::
vkAF up::		; Volume_Up up::
vkB0 up::		; Media_Next up::
vkB1 up::		; Media_Prev up::
vkB2 up::		; Media_Stop up::
vkB3 up::		; Media_Play_Pause up::
vkB4 up::		; Launch_Mail up::
vkB5 up::		; Launch_Media up::
vkB6 up::		; Launch_App1 up::
vkB7 up::		; Launch_App2 up::

Break up::		; ※ 認識しない
Sleep up::		; ※ 認識しない
Help up::		; ※ 認識しない
CtrlBreak up::	; ※ Ctrl+Pause
	; 入力バッファへ保存
	changedKeys.Push(nowKeyName := A_ThisHotkey)
	DllCall("QueryPerformanceCounter", "Int64P", count)
	changeCounter.Push(count)
	; キー変化なく1.05秒たったら表示
	SetTimer, OutputTimer, -1050
	Return

#MaxThreadsPerHotkey 1	; 元に戻す
