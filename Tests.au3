#include "Scheduler.au3"

_Assertions()

Func _Assertions()
    _AssertTimestampDurationFromMidnight()
    _AssertTimeConvertionToUserFriendlyString()
    _AssertMakeTimesheet()
EndFunc

Func _AssertTimestampDurationFromMidnight()
    Local Const $aDataTable[][3] = _
        [ _
            ['2:0:0',   7200000,  '2 hours'], _
            ['0:1:0',   60000,    '1 minute'], _
            ['0:0:30',  30000,    '30 seconds'], _
            ['0:0:0:1', 1,        '1 millisecond'], _
            ['1:0',     3600000,  '1 hour'], _
            ['3',       10800000, '3 hours'], _
            ['3:::1',   10800001, '3 hours and 1 millisecond'], _
            ['1:1:1:1', 3661001,  '1 hour, 1 minute, 1 second and 1 millisecond'], _
            ['0:2:5:0', 125000,   '2 minutes and 5 seconds'], _
            ['8:30:30', 30630000, '8 hours, 30 minutes and 30 seconds'] _
        ]

    ConsoleWrite('- - - - - - - - - - - - - - - - - -' & @CRLF)

    For $i = 0 To Ubound($aDataTable) - 1 Step 1
        Local $sStamp         = $aDataTable[$i][0]
        Local $sExpectedValue = $aDataTable[$i][1]
        Local $sTextToPrint   = $aDataTable[$i][2]
        Local $sActualValue   = _Scheduler_StampToTime($sStamp)

        If $sActualValue <> $sExpectedValue Then
            ConsoleWrite( _
                '[Failed] Timestamp duration of ' & $sTextToPrint & ' differs from the expected value. ' & _
                'Expected value "' & $sExpectedValue & '" ms, actual value "' & $sActualValue & ' ms". ' & _
                'Stamp "' & $sStamp & '". ' & _
                'Either the function under test behaves differently (is broken) or the data driven values have to be adjusted.' & @CRLF)

            ContinueLoop
        EndIf

        ConsoleWrite( _
            '[Passed] Timestamp duration of ' & $sTextToPrint & ' corresponds the expected value. ' & _
            'Expected value "' & $sExpectedValue & '" ms. Stamp "' & $sStamp & '".' & @CRLF)
    Next
EndFunc

Func _AssertTimeConvertionToUserFriendlyString()
    Local Const $aDataTable[][3] = _
        [ _
            ['2:0:0',      False, '2h 0s'], _
            ['0:1:0',      False, '1m 0s'], _
            ['0:0:30',     False, '30s'], _
            ['0:0:0:1',    False, '0s'], _
            ['0:1:0:2',    True,  '1m 0s 2ms'], _
            ['1:0',        False, '1h 0s'], _
            ['3',          False, '3h 0s'], _
            ['3:::1',      False, '3h 0s'], _
            ['3:::1',      True,  '3h 0s 1ms'], _
            ['1:1:1:1',    False, '1h 1m 1s'], _
            ['0:2:5:0',    False, '2m 5s'], _
            ['8:30:30',    False, '8h 30m 30s'], _
            ['8:30:30:1',  False, '8h 30m 30s'], _
            ['8:30:30:5',  False, '8h 30m 30s'], _
            ['8:30:30:1',  True,  '8h 30m 30s 1ms'], _
            ['8:9:29:426', True,  '8h 9m 29s 426ms'] _
        ]

    ConsoleWrite('- - - - - - - - - - - - - - - - - -' & @CRLF)

    For $i = 0 To Ubound($aDataTable) - 1 Step 1
        Local $sStamp         = $aDataTable[$i][0]
        Local $bIncludeMs     = $aDataTable[$i][1]
        Local $sExpectedValue = $aDataTable[$i][2]
        Local $sTime          = _Scheduler_StampToTime($sStamp)
        Local $sActualValue   = _Scheduler_TimeToString($sTime, $bIncludeMs)

        If $sActualValue <> $sExpectedValue Then
            ConsoleWrite( _
                '[Failed] User friendly timestamp string representation differs from the expected value. ' & _
                'Expected value "' & $sExpectedValue & '", actual value "' & $sActualValue & '". ' & _
                'Stamp "' & $sStamp & '". ' & _
                'Either the function under test behaves differently (is broken) or the data driven values have to be adjusted.' & @CRLF)

            ContinueLoop
        EndIf

        ConsoleWrite( _
            '[Passed] User friendly timestamp string representation corresponds the expected value. ' & _
            'Expected value "' & $sExpectedValue & '". Stamp "' & $sStamp & '".' & @CRLF)
    Next
EndFunc

Func _AssertMakeTimesheet()
    Local Const $aSubSchedule[] = _
        [ _
            '0', _
            '0:20:0:500', _
            '9:30', _
            '17:18:19' _
        ]

    Local Const $aSchedule[][2] = _
        [ _
            ['_CreateDatabaseBackup', '13:37'], _       ; "_CreateDatabaseBackup" is a made up example function
            ['_TriggerDeployment',    '16:20:09'], _    ; "_TriggerDeployment" is a made up example function
            ['_WriteLogFile',         $aSubSchedule] _  ; "_WriteLogFile" is a made up example function
        ]

    Local Const $aExpectedSchedule[][2] = _
        [ _
            ['_WriteLogFile',         '0'], _
            ['_WriteLogFile',         '1200500'], _
            ['_WriteLogFile',         '34200000'], _
            ['_CreateDatabaseBackup', '49020000'], _
            ['_TriggerDeployment',    '58809000'], _
            ['_WriteLogFile',         '62299000'] _
        ]

    Local Const $iExpectedCount = Ubound($aExpectedSchedule)

    ConsoleWrite('- - - - - - - - - - - - - - - - - -' & @CRLF)

    Local Const $aActualSchedule = _Scheduler_MakeTimesheet($aSchedule)
    Local Const $iActualCount    = @extended

    ; _ArrayDisplay($aActualSchedule)

    Local $iFailureCount = 0

    If $iActualCount <> $iExpectedCount Then
        ConsoleWrite( _
            '[Failed] The number of tasks by @extended differs from the expected count. ' & _
            'Expected count "' & $iExpectedCount & '", actual count "' & $iActualCount & '". ' & _
            'Either the function under test behaves differently (is broken) or the data driven values have to be adjusted.' & @CRLF)

        $iFailureCount += 1
    EndIf

    If _ArrayToString($aActualSchedule) <> _ArrayToString($aExpectedSchedule) Then
        ConsoleWrite( _
            '[Failed] Timesheet creation result differs from the expected schedule (array values). ' & _
            'Print _ArrayToString($aActualSchedule) and _ArrayToString($aExpectedSchedule) for comparison. ' & _
            'Either the function under test behaves differently (is broken) or the data driven values have to be adjusted.' & @CRLF)

        $iFailureCount += 1
    EndIf

    If $iFailureCount > 0 Then
        Return
    EndIf

    ConsoleWrite('[Passed] _AssertMakeTimesheet()' & @CRLF)
EndFunc
