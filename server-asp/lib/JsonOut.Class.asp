<%
'==============================================================================
' lib/JsonOut.Class.asp  -  JSON 생성기 (순수 VBScript)
'------------------------------------------------------------------------------
' lib/Json.Class.asp 는 "읽기(파서)" 전용이다. 이 파일은 그 반대인 "쓰기" 담당이다.
' React 스택(/react)이 쓰는 /asp/api/*.asp 응답을 만든다.
'
' 왜 Dictionary 를 만들어 직렬화하지 않는가
'   VBScript 는 중첩 구조를 객체로 쌓으면 Set / IsObject 분기가 끝없이 늘어난다.
'   출력은 어차피 한 번 훑고 끝나므로, 쓰는 순간 바로 문자열로 흘려보내는 쪽이
'   코드가 짧고 실수가 적다.
'
' 쉼표 처리
'   "직전에 값을 하나 썼는가"(mComma) 플래그 하나로 충분하다.
'   컨테이너를 열면 False, 값을 쓰거나 컨테이너를 닫으면 True 가 된다.
'   중첩이 끝난 직후도 "값을 하나 쓴 상태"와 같으므로 스택이 필요 없다.
'
' 사용법
'   Dim o : Set o = New CJsonOut
'   o.ObjOpen ""                       루트 {
'       o.S  "title", "제목"
'       o.N  "count", 12
'       o.B  "isUse", True
'       o.D  "regDt", rs(0,0)          날짜 -> "2026-11-20 13:05:22" (없으면 null)
'       o.ArrOpen "items"
'           o.ObjOpen "" : o.S "name", "가" : o.ObjClose
'       o.ArrClose
'   o.ObjClose
'   Response.Write o.Text
'
'   이름을 빈 문자열("")로 주면 키 없이 값만 쓴다. 배열 원소에 쓴다.
'
' ※ 버퍼는 문자열 배열에 모았다가 Join 한다.
'   s = s & ... 로 이어붙이면 길이에 제곱으로 느려진다(수천 건 목록에서 체감된다).
'==============================================================================
Class CJsonOut

    Private mBuf, mN, mComma

    Private Sub Class_Initialize()
        Reset
    End Sub

    Public Sub Reset()
        ReDim mBuf(63)
        mN     = 0
        mComma = False
    End Sub

    Private Sub Push(ByVal s)
        If mN > UBound(mBuf) Then ReDim Preserve mBuf(mN * 2 + 1)
        mBuf(mN) = s
        mN = mN + 1
    End Sub

    '<Desc>지금까지 쓴 JSON 문자열</Desc>
    Public Property Get Text()
        Dim a
        If mN = 0 Then Text = "" : Exit Property
        a = mBuf
        ReDim Preserve a(mN - 1)
        Text = Join(a, "")
    End Property

    '--------------------------------------------------------------------------
    ' 내부 : 키 출력 + 쉼표 관리
    '--------------------------------------------------------------------------
    Private Sub Key(ByVal pName)
        If mComma Then Push ","
        If Len(pName & "") > 0 Then
            Push Esc(pName)
            Push ":"
        End If
        mComma = True
    End Sub

    '--------------------------------------------------------------------------
    ' 컨테이너
    '--------------------------------------------------------------------------
    Public Sub ObjOpen(ByVal pName)
        Key pName : Push "{" : mComma = False
    End Sub
    Public Sub ObjClose()
        Push "}" : mComma = True
    End Sub

    Public Sub ArrOpen(ByVal pName)
        Key pName : Push "[" : mComma = False
    End Sub
    Public Sub ArrClose()
        Push "]" : mComma = True
    End Sub

    '--------------------------------------------------------------------------
    ' 값
    '--------------------------------------------------------------------------

    '<Desc>문자열. NULL / Empty 는 "" 로 나간다</Desc>
    Public Sub S(ByVal pName, ByVal v)
        Key pName : Push Esc(v)
    End Sub

    '<Desc>숫자. 숫자가 아니면 0</Desc>
    Public Sub N(ByVal pName, ByVal v)
        Dim s
        If IsNull(v) Or IsEmpty(v) Then
            s = "0"
        ElseIf IsNumeric(v) Then
            ' 로캘에 따라 소수점이 쉼표로 찍히는 경우를 막는다
            s = Replace(CStr(v), ",", ".")
        Else
            s = "0"
        End If
        Key pName : Push s
    End Sub

    '<Desc>Boolean. BIT 컬럼(0/1)·"true" 문자열도 받는다</Desc>
    Public Sub B(ByVal pName, ByVal v)
        Dim t
        t = False
        If Not (IsNull(v) Or IsEmpty(v)) Then
            If VarType(v) = vbBoolean Then
                t = v
            Else
                t = (LCase(CStr(v)) = "true" Or CStr(v) = "1" Or CStr(v) = "-1")
            End If
        End If
        Key pName
        If t Then Push "true" Else Push "false"
    End Sub

    Public Sub Nul(ByVal pName)
        Key pName : Push "null"
    End Sub

    '<Desc>날짜/시각 -> "yyyy-MM-dd HH:mm:ss". 날짜가 아니면 null</Desc>
    Public Sub D(ByVal pName, ByVal v)
        If IsNull(v) Or IsEmpty(v) Then Nul pName : Exit Sub
        If Not IsDate(v) Then Nul pName : Exit Sub
        Dim d : d = CDate(v)
        S pName, Pad4(Year(d)) & "-" & Pad2(Month(d)) & "-" & Pad2(Day(d)) & " " & _
                 Pad2(Hour(d)) & ":" & Pad2(Minute(d)) & ":" & Pad2(Second(d))
    End Sub

    '<Desc>날짜만 -> "yyyy-MM-dd". 날짜가 아니면 null</Desc>
    Public Sub DOnly(ByVal pName, ByVal v)
        If IsNull(v) Or IsEmpty(v) Then Nul pName : Exit Sub
        If Not IsDate(v) Then Nul pName : Exit Sub
        Dim d : d = CDate(v)
        S pName, Pad4(Year(d)) & "-" & Pad2(Month(d)) & "-" & Pad2(Day(d))
    End Sub

    '<Desc>이미 JSON 인 조각을 그대로 끼워넣는다 (신뢰 가능한 값만)</Desc>
    Public Sub Raw(ByVal pName, ByVal pJson)
        Key pName : Push CStr(pJson & "")
    End Sub

    '--------------------------------------------------------------------------
    ' 문자열 -> JSON 리터럴 (감싸는 따옴표 포함)
    '--------------------------------------------------------------------------
    Public Function Esc(ByVal v)
        Dim s, i, c, n, out, cnt
        If IsNull(v) Or IsEmpty(v) Then s = "" Else s = CStr(v)

        ReDim out(Len(s) + 1)
        cnt = 0
        out(cnt) = """" : cnt = cnt + 1

        For i = 1 To Len(s)
            c = Mid(s, i, 1)
            n = AscW(c)
            If n < 0 Then n = n + 65536

            If c = """" Then
                out(cnt) = "\"""
            ElseIf c = "\" Then
                out(cnt) = "\\"
            ElseIf c = vbLf Then
                out(cnt) = "\n"
            ElseIf c = vbCr Then
                out(cnt) = "\r"
            ElseIf c = vbTab Then
                out(cnt) = "\t"
            ElseIf n < 32 Or n = 8232 Or n = 8233 Then
                ' U+2028 / U+2029 는 JSON 에선 합법이지만 JS 파서를 깨뜨린다
                out(cnt) = "\u" & Right("000" & Hex(n), 4)
            Else
                out(cnt) = c
            End If
            cnt = cnt + 1
        Next

        out(cnt) = """"
        ReDim Preserve out(cnt)
        Esc = Join(out, "")
    End Function

    Private Function Pad2(ByVal n)
        Pad2 = Right("0" & n, 2)
    End Function
    Private Function Pad4(ByVal n)
        Pad4 = Right("000" & n, 4)
    End Function

End Class
%>
