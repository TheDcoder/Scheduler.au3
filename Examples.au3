#include "Scheduler.au3"

_Examples()

Func _Examples()
    _PrintCurrentTimeOfTheDayElapsedSinceMidnight()
    _UnrefactoredExamples()
EndFunc

Func _PrintCurrentTimeOfTheDayElapsedSinceMidnight()
    ConsoleWrite('- - - - - - - - - - - - - - - - - -' & @CRLF)
    ConsoleWrite('"' & _Scheduler_GetCurTime() & '" ms elapsed since midnight.' & @CRLF)
EndFunc

Func _UnrefactoredExamples()
    ; TODO: Refactor and extent the examples below and further ones.

    While True
        Local $sInput = InputBox("Stamp Test", 'Enter Stamp like format "0:0:10" (for 0 hours, 0 minutes and 10 seconds from now)')
        If @error Then ExitLoop
        MsgBox(0, "Stamp Test", _Scheduler_StampToTime($sInput))
    WEnd

    Exit

    While True
        Local $sInput = InputBox("Timesheet Multi Test", "Enter timings")
        If @error Then ExitLoop
        Local $aSchedule = StringSplit($sInput, ',', 2)
        For $i = 0 To UBound($aSchedule) - 1
            If StringLeft($aSchedule[$i], 1) <> '[' Then ContinueLoop
            $aSchedule[$i] = StringMid($aSchedule[$i], 2, StringLen($aSchedule[$i]) - 2)
            $aSchedule[$i] = StringSplit($aSchedule[$i], ';', 2)
        Next
        Local $aSheet = _Scheduler_MakeTimesheet($aSchedule)
        _ArrayDisplay($aSheet, "Timesheet Multi Test")
    WEnd

    Local $iTimeNow = _Scheduler_GetCurTime()
    Local $aSheet[3][2]
    $aSheet[0][$geScheduler_EnumTime] = $iTimeNow + _Scheduler_StampToTime('0:0:10')
    $aSheet[1][$geScheduler_EnumTime] = $iTimeNow + _Scheduler_StampToTime('0:10')
    $aSheet[2][$geScheduler_EnumTime] = $iTimeNow + _Scheduler_StampToTime('0:22')
    ExampleCallback()
    _Scheduler_Run($aSheet, ExampleCallback)
EndFunc

Func ExampleCallback()
    ConsoleWrite(StringFormat('> Time is now %02i:%02i:%02i', @HOUR, @MIN, @SEC) & @CRLF)
EndFunc
