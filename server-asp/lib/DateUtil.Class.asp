<%
'==============================================================================
' lib/DateUtil.Class.asp  -  날짜 유틸리티
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / _Gcommon/Lib/DateUtil.Class.asp
' 사용 : DateUtil.Fmt(reg_dt, "ymdhi")  /  DateUtil.TimeAgo(reg_dt)
'==============================================================================
Class CDateUtil

    Private Function P2(ByVal n)
        P2 = Right("0" & CStr(n), 2)
    End Function

    '<Desc>날짜 포맷</Desc>
    '<Param name="fmt">ymd | ymdhi | ymdhis | ym | md | dot | hi | iso</Param>
    '<Desc>매개변수 이름을 pFmt 로 둔 이유 : VBScript 는 함수명과 같은 이름의</Desc>
    '<Desc>매개변수를 허용하지 않는다 (오류 800a0411 "다시 정의된 이름")</Desc>
    Public Function Fmt(ByVal v, ByVal pFmt)
        Dim d
        Fmt = ""
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If CStr(v) = "" Then Exit Function
        If Not IsDate(v) Then Fmt = CStr(v) : Exit Function
        d = CDate(v)

        Select Case LCase(pFmt)
            Case "ymd"    : Fmt = Year(d) & "-" & P2(Month(d)) & "-" & P2(Day(d))
            Case "ymdhi"  : Fmt = Year(d) & "-" & P2(Month(d)) & "-" & P2(Day(d)) & " " & P2(Hour(d)) & ":" & P2(Minute(d))
            Case "ymdhis" : Fmt = Year(d) & "-" & P2(Month(d)) & "-" & P2(Day(d)) & " " & P2(Hour(d)) & ":" & P2(Minute(d)) & ":" & P2(Second(d))
            Case "ym"     : Fmt = Year(d) & "." & P2(Month(d))
            Case "md"     : Fmt = P2(Month(d)) & "-" & P2(Day(d))
            Case "dot"    : Fmt = Year(d) & "." & P2(Month(d)) & "." & P2(Day(d))
            Case "hi"     : Fmt = P2(Hour(d)) & ":" & P2(Minute(d))
            Case "iso"    : Fmt = Year(d) & "-" & P2(Month(d)) & "-" & P2(Day(d)) & "T" & P2(Hour(d)) & ":" & P2(Minute(d)) & ":" & P2(Second(d))
            Case Else     : Fmt = Year(d) & "-" & P2(Month(d)) & "-" & P2(Day(d))
        End Select
    End Function

    '<Desc>게시판 목록용 : 오늘 글이면 시:분, 아니면 날짜</Desc>
    Public Function ListDate(ByVal v)
        Dim d
        ListDate = ""
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If Not IsDate(v) Then Exit Function
        d = CDate(v)
        If DateDiff("d", d, Now()) = 0 Then
            ListDate = P2(Hour(d)) & ":" & P2(Minute(d))
        Else
            ListDate = Fmt(d, "ymd")
        End If
    End Function

    '<Desc>"3분 전" 형태</Desc>
    Public Function TimeAgo(ByVal v)
        Dim d, s
        TimeAgo = ""
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If Not IsDate(v) Then Exit Function
        d = CDate(v)
        s = DateDiff("s", d, Now())
        If s < 0 Then s = 0

        If s < 60 Then
            TimeAgo = "방금 전"
        ElseIf s < 3600 Then
            TimeAgo = Int(s / 60) & "분 전"
        ElseIf s < 86400 Then
            TimeAgo = Int(s / 3600) & "시간 전"
        ElseIf s < 2592000 Then
            TimeAgo = Int(s / 86400) & "일 전"
        Else
            TimeAgo = Fmt(d, "ymd")
        End If
    End Function

    '<Desc>경력 기간 표기 : 2021.03 ~ 현재</Desc>
    Public Function Period(ByVal dtStart, ByVal dtEnd, ByVal isOngoing)
        Dim s, on_
        s = ""
        If IsDate(dtStart) Then s = Fmt(dtStart, "ym")
        s = s & " ~ "

        on_ = False
        If Not (IsNull(isOngoing) Or IsEmpty(isOngoing)) Then
            If VarType(isOngoing) = vbBoolean Then
                on_ = isOngoing
            ElseIf IsNumeric(isOngoing) Then
                on_ = (CLng(isOngoing) <> 0)
            End If
        End If

        If on_ Then
            s = s & "현재"
        ElseIf IsDate(dtEnd) Then
            s = s & Fmt(dtEnd, "ym")
        End If
        Period = Trim(s)
    End Function

    '<Desc>신규글 표시 여부 (N시간 이내)</Desc>
    Public Function IsNew(ByVal v, ByVal hours)
        IsNew = False
        If Not IsDate(v) Then Exit Function
        IsNew = (DateDiff("h", CDate(v), Now()) < hours)
    End Function

    '<Desc>yyyyMM (업로드 폴더 분할용)</Desc>
    Public Function YearMonth()
        YearMonth = Year(Now()) & P2(Month(Now()))
    End Function

End Class

Dim DateUtil
Set DateUtil = New CDateUtil
%>
