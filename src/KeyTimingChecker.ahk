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

SetWorkingDir %A_ScriptDir%	; スクリプトの作業ディレクトリを変更
#SingleInstance force		; 既存のプロセスを終了して実行開始
#NoEnv						; 変数名を解釈するとき、環境変数を無視する
SetBatchLines, -1			; 自動Sleepなし
ListLines, Off				; スクリプトの実行履歴を取らない
SetKeyDelay, 0, 0			; キーストローク間のディレイを変更
#MenuMaskKey vk07			; Win または Alt の押下解除時のイベントを隠蔽するためのキーを変更する
#UseHook					; ホットキーはすべてフックを使用する
; Process, Priority, , High	; プロセスの優先度を変更
;Thread, interrupt, 15, 6	; スレッド開始から15ミリ秒ないし1行以内の割り込みを、絶対禁止
SetStoreCapslockMode, off	; Sendコマンド実行時にCapsLockの状態を自動的に変更しない

;SetFormat, Integer, H		; 数値演算の結果を、16進数の整数による文字列で表現する

; 入力バッファ
InBuf := []
InBufTime := []	; 入力の時間
InBufRead := 0	; 読み出し位置
InBufWrite := 0	; 書き込み位置
InBufRest := 15

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


; ----------------------------------------------------------------------
; 関数
; ----------------------------------------------------------------------

Convert()
{
	global KanaMode
		, InBuf, InBufRead, InBufTime, InBufRest
	static run := 0	; 多重起動防止フラグ
		, LastKeyTime := 0
;	local Str1, Str2
;		, diff
;		, Term		; 入力の末端2文字

	if (run)
		return	; 多重起動防止で終了

	; 入力バッファが空になるまで
	while (run := 15 - InBufRest)
	{
		; 入力バッファから読み出し
		Str1 := InBuf[InBufRead], KeyTime := InBufTime[InBufRead++], InBufRead &= 15, InBufRest++

		; 前回の入力から1.05秒以内なら、時間を書き出し
		diff := KeyTime - LastKeyTime
		if diff <= 1050
			Send, % "(" . diff . "ms) "

		; 入力文字の書き出し
		Str2 := SubStr(Str1, 1, 4)
		if (Str2 == "sc39")
			Str2 := "SPC"
		else
			Str2 := "{" . Str2 . "}"
		StringRight, Term, Str1, 2	; Term に入力末尾の2文字を入れる
		if (Term == "up")	; キーが離されたとき
			Str2 .= "↑ "
		else
			Str2 .= " "

		Send, % Str2

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

#If (KeyDriver == "kbd101.dll")	; 設定がUSキーボードの場合
sc29::	; (JIS)半角/全角	(US)`
#If

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
sc27::	; ;
sc28::	; (JIS):	(US)'
sc2B::	; (JIS)]	(US)＼
sc2C::	; Z
sc2D::	; X
sc2E::	; C
sc2F::	; V
sc30::	; B
sc31::	; N
sc32::	; M
sc33::	; ,
sc34::	; .
sc35::	; /
sc73::	; (JIS)_
sc39::	; Space
	; 入力バッファへ保存
	; キーを押す方はいっぱいまで使わない
	InBuf[InBufWrite] := A_ThisHotkey, InBufTime[InBufWrite] := WinAPI_timeGetTime()
		, InBufWrite := (InBufRest > 6) ? ++InBufWrite & 15 : InBufWrite
		, (InBufRest > 6) ? InBufRest-- :
	Convert()	; 変換ルーチン
	return

; キー押上げ

#If (KeyDriver == "kbd101.dll")	; 設定がUSキーボードの場合
sc29 up::	; (JIS)半角/全角	(US)`
#If

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
	; 入力バッファへ保存
	InBuf[InBufWrite] := A_ThisHotkey, InBufTime[InBufWrite] := WinAPI_timeGetTime()
		, InBufWrite := InBufRest ? ++InBufWrite & 15 : InBufWrite
		, InBufRest ? InBufRest-- :
	Convert()	; 変換ルーチン
	return

#MaxThreadsPerHotkey 1	; 元に戻す

; 終了
Esc::
	Send, 終了.
	ExitApp
