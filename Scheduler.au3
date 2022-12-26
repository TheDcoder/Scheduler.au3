#comments-start

MIT License

Copyright (c) 2022 Damon Harris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

#comments-end

; #INDEX# =======================================================================================================================
; Title .........: Scheduler
; AutoIt Version : 3.3.16.1
; Description ...: A time-based task scheduler to run arbitrary tasks at set times in a day
; Author(s) .....: TheDcoder <TheDcoder@protonmail.com>
; Link ..........: https://github.com/TheDcoder/Scheduler.au3
; Forum .........: https://www.autoitscript.com/forum/topic/209375-scheduler-udf-run-tasks-according-to-a-schedule-in-a-day
; ===============================================================================================================================

#include-once
#include <Array.au3>
#include <WinAPIProc.au3>

Global Enum $geScheduler_EnumTask, $geScheduler_EnumTime
Global Const $geScheduler_MaxTime = 24 * 60 * 60 * 1000 ; 24 hours

Global $g__hScheduler_InterruptEvent = _WinAPI_CreateEvent(0, True, False)

; #FUNCTION# ====================================================================================================================
; Name ..........: _Scheduler_Run
; Description ...: Run the scheduler
; Syntax ........: _Scheduler_Run($aScheduleOrTimeSheet, $udfCallback[, $bSkipLateTasks = False])
; Parameters ....: $aScheduleOrTimeSheet- A schedule or timesheet.
;                  $udfCallback         - The callback function which will be called for each task.
;                  $bSkipLateTasks      - [optional] Skip tasks which are late? Default is False.
; Return values .: None, does not return until _Scheduler_Stop is called.
; Author ........: TheDcoder
; Remarks .......: This function is an event-loop, See _Scheduler_MakeTimesheet for the format of a schedule.
; Related .......: _Scheduler_Stop
; ===============================================================================================================================
Func _Scheduler_Run($aScheduleOrTimeSheet, $udfCallback, $bSkipLateTasks = False)
	Local $aSheet
	If UBound($aScheduleOrTimeSheet, 0) = 1 Then
		$aSheet = _Scheduler_MakeTimesheet($aScheduleOrTimeSheet)
	Else
		$aSheet = $aScheduleOrTimeSheet
	EndIf

	Local $iTime = _Scheduler_GetCurTime()
	Local $iSlot
	Local $iTotalSlots = UBound($aSheet)
	For $i = 0 To $iTotalSlots - 1
		If $aSheet[$i][$geScheduler_EnumTime] < $iTime Then ContinueLoop
		$iSlot = $i
		ExitLoop
	Next

	Local $iWait
	_WinAPI_ResetEvent($g__hScheduler_InterruptEvent)
	$iTime = _Scheduler_GetCurTime()
	While True
		$iWait = $aSheet[$iSlot][$geScheduler_EnumTime] - $iTime
		If $bSkipLateTasks And $iWait < 0 Then
			$iSlot += 1
			ContinueLoop
		EndIf
		__Scheduler_Run_Sleep($iWait)
		If @error Then ExitLoop

		Call($udfCallback, $aSheet[$iSlot][$geScheduler_EnumTask])
		$iSlot += 1

		If $iSlot >= $iTotalSlots Then
			; Wait for the next day and reset
			__Scheduler_Run_Sleep($geScheduler_MaxTime)
			$iSlot = 0
			$iTime = 0
		Else
			$iTime = _Scheduler_GetCurTime()
		EndIf
	WEnd
EndFunc

; #INTERNAL_USE_ONLY# ===========================================================================================================
; Name ..........: __Scheduler_Run_Sleep
; Description ...: Sleep for the given duration or until interrupted with _Scheduler_Stop
; Syntax ........: __Scheduler_Run_Sleep($iDuration)
; Parameters ....: $iDuration           - Sleep duration in milli-seconds.
; Return values .: @error is set to 1 if interrupted
; Author ........: TheDcoder
; Related .......: _Scheduler_Stop
; Example .......: __Scheduler_Run_Sleep(420)
; ===============================================================================================================================
Func __Scheduler_Run_Sleep($iDuration)
	Local $vRet = _WinAPI_WaitForSingleObject($g__hScheduler_InterruptEvent, $iDuration)
	Return SetError($vRet = $g__hScheduler_InterruptEvent ? 1 : 0)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Scheduler_Stop
; Description ...: Interrupt the running schedule
; Syntax ........: _Scheduler_Stop()
; Parameters ....: None
; Return values .: None
; Author ........: TheDcoder
; Related .......: _Scheduler_Run and __Scheduler_Run_Sleep
; Example .......: If $bFatalError Or $bShitHitTheFan Then _Scheduler_Stop()
; ===============================================================================================================================
Func _Scheduler_Stop()
	_WinAPI_SetEvent($g__hScheduler_InterruptEvent)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Scheduler_MakeTimesheet
; Description ...: Make a timesheet from a schedule
; Syntax ........: _Scheduler_MakeTimesheet($aOrigSchedule)
; Parameters ....: $aOrigSchedule       - The schedule, see remarks.
; Return values .: The timesheet and @extended is set to number of tasks in a day
; Author ........: TheDcoder
; Remarks .......: A schedule is nothing but a 2D array with 2 columns:
;                  1. $geScheduler_EnumTask - The task, can be any value, this value is supplied to the callback function
;                  2. $geScheduler_EnumTime - A timestamp (see _Scheduler_StampToTime for format) or an array of timestamps
;
;                  Example:
;                  Local $aSchedule[3][2] ; A schedule with 3 tasks
;
;                  $aSchedule[0][$geScheduler_EnumTask] = "foo" ; Use a string to identify the task
;                  $aSchedule[0][$geScheduler_EnumTime] = '13:37' ; Run at 1:37 PM
;
;                  $aSchedule[1][$geScheduler_EnumTask] = "bar"
;                  $aSchedule[1][$geScheduler_EnumTime] = '16:20:09' ; Run at 4:20 PM after 9 seconds have elapsed
;
;                  $aSchedule[2][$geScheduler_EnumTask] = "baz"
;                  Local $aBazSubSchedule[3] ; This task has a mini sub-schedule, so it can run multiple times in a day!
;                  $aBazSubSchedule[0] = '0' ; Mid-night (start of the day)
;                  $aBazSubSchedule[1] = '9:30' ; 9:30 AM
;                  $aBazSubSchedule[2] = '17:18:19' ; 5:18 PM + 19 seconds
;                  $aSchedule[2][$geScheduler_EnumTime] = $aBazSubSchedule ; Run 3 times a day at given times
;
; Related .......: _Scheduler_Run will automatically call this function if you supply a schedule
; ===============================================================================================================================
Func _Scheduler_MakeTimesheet($aOrigSchedule)
	Local $iTaskCount = 0
	For $i = 0 To UBound($aOrigSchedule) - 1
		If IsArray($aOrigSchedule[$i]) Then
			Local $aSubSchedule = $aOrigSchedule[$i]
			For $j = 0 To UBound($aSubSchedule) - 1
				$iTaskCount += 1
				Local $sOrigStamp = $aSubSchedule[$j]
				$aSubSchedule[$j] = _Scheduler_StampToTime($aSubSchedule[$j])
			Next
			$aOrigSchedule[$i] = $aSubSchedule
		Else
			$iTaskCount += 1
			$aOrigSchedule[$i] = _Scheduler_StampToTime($aOrigSchedule[$i])
		EndIf
	Next

	; Transform the schedule
	Local $aSchedule[$iTaskCount][2]
	Local $iCurTask = 0
	For $i = 0 To UBound($aOrigSchedule) - 1
		If IsArray($aOrigSchedule[$i]) Then
			Local $aOrigSubSchedule = $aOrigSchedule[$i]
			For $j = 0 To UBound($aOrigSubSchedule) - 1
				$aSchedule[$iCurTask][$geScheduler_EnumTask] = $i
				$aSchedule[$iCurTask][$geScheduler_EnumTime] = $aOrigSubSchedule[$j]
				$iCurTask += 1
			Next
		Else
			$aSchedule[$iCurTask][$geScheduler_EnumTask] = $i
			$aSchedule[$iCurTask][$geScheduler_EnumTime] = $aOrigSchedule[$i]
			$iCurTask += 1
		EndIf
	Next

	Local $aSheet[$iTaskCount][2]
	Local $iTime = 0
	Local $iLowest, $iLowestDiff, $iDiff
	For $i = 0 To $iTaskCount - 1
		$iLowest = -1
		$iLowestDiff = -1
		For $j = 0 To UBound($aSchedule) - 1
			If $aSchedule[$j][$geScheduler_EnumTask] = Null Then ContinueLoop
			$iDiff = $aSchedule[$j][$geScheduler_EnumTime] - $iTime
			If $iDiff <= $iLowestDiff Or $iLowestDiff = -1 Then
				$iLowest = $j
				$iLowestDiff = $iDiff
			EndIf
		Next
		$aSheet[$i][$geScheduler_EnumTask] = $iLowest
		$aSheet[$i][$geScheduler_EnumTime] = $aSchedule[$iLowest][$geScheduler_EnumTime]
		$iTime = $iLowestDiff
		$aSchedule[$iLowest][$geScheduler_EnumTask] = Null
	Next

	Return SetExtended($iTaskCount, $aSheet)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Scheduler_StampToTime
; Description ...: Convert a timestamp to an integer for use in timesheets
; Syntax ........: _Scheduler_StampToTime($sStamp)
; Parameters ....: $sStamp              - The timestamp, see remarks.
; Return values .: An integer which represents the timestamp as the duration from the start of the day (mid-night) in milli-seconds
; Author ........: TheDcoder
; Remarks .......: The format of the timestamp is simple, it is a string with numbers delimited with `:`.
;                  A timestamp can have 4 components (all are optional):
;                  1. Hours
;                  2. Minutes
;                  3. Seconds
;                  4. Milli-seconds
;
;                  Padding of numbers with 0 is optionally allowed since the `Number` function is used for conversion to integer
; Related .......: _Scheduler_MakeTimesheet
; ===============================================================================================================================
Func _Scheduler_StampToTime($sStamp)
	Local $aStamp = StringSplit($sStamp, ':')
	Local $iTime = 0, $iMultiplier
	For $i = 1 To $aStamp[0]
		If $i = 1 Then
			; Hour
			$iMultiplier = 60 * 60 * 1000
		ElseIf $i = 2 Then
			; Minute
			$iMultiplier = 60 * 1000
		ElseIf $i = 3 Then
			; Second
			$iMultiplier = 1000
		ElseIf $i = 4 Then
			; Milli-Second
			$iMultiplier = 1
		Else
			; Invalid
			$iMultiplier = 0
		EndIf
		$iTime += Number($aStamp[$i]) * $iMultiplier
	Next
	Return $iTime
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Scheduler_GetCurTime
; Description ...: Get the current time of day
; Syntax ........: _Scheduler_GetCurTime()
; Parameters ....: None
; Return values .: The number of milli-seconds elasped since mid-night
; Author ........: TheDcoder
; Remarks .......: This is mostly used internally but you can use this to make your own dynamic timesheets manually
; Example .......: $aSheet[0][$geScheduler_EnumTime] = _Scheduler_GetCurTime() + _Scheduler_StampToTime('0:0:10') ; 10 seconds from now
; ===============================================================================================================================
Func _Scheduler_GetCurTime()
	Local $iTime = 0
	$iTime += @HOUR * 60 * 60 * 1000
	$iTime += @MIN * 60 * 1000
	$iTime += @SEC * 1000
	$iTime += @MSEC
	Return $iTime
EndFunc
