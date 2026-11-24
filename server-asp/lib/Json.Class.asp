<%
'==============================================================================
' lib/Json.Class.asp  -  JSON 파서 (순수 VBScript)
'------------------------------------------------------------------------------
' 왜 직접 만드는가
'   VBScript 에는 JSON 파서가 없다. 흔히 쓰는 MSScriptControl(JScript eval) 은
'   32비트 전용이라 64비트 응용 프로그램 풀에는 등록되어 있지 않다.
'   앱풀을 32비트로 내리는 대가가 크므로 FileUpload 처럼 직접 구현한다.
'
' ★ API 설계 이유
'   VBScript 는 객체를 Set 없이 대입할 수 없다. 파싱 결과(Dictionary)를 함수
'   반환값으로 넘기면 호출자가 매번 IsObject 분기를 해야 하고, 실수하면
'   800a01c2 로 죽는다. 그래서 결과를 이 클래스가 내부에 들고 있고,
'   외부에는 "경로 문자열로 값만 꺼내는" 인터페이스만 노출한다.
'
' 사용법
'   If Not Json.Parse(txt) Then  ... Json.ErrMsg ...
'   Json.Str("data.items[0].name", "")     문자열
'   Json.Num("total", 0)                   숫자
'   Json.Bln("ok", False)                  Boolean
'   Json.Exists("error")                   존재 여부 (null 은 없음으로 본다)
'   Json.Count("items")                    배열 길이
'   Json.Enc("따옴표 "" 포함")               문자열 → JSON 리터럴(따옴표 포함)
'
'   응답을 두 개 동시에 다뤄야 하면  Dim j : Set j = New CJson  으로 따로 만든다.
'
' 표현 방식
'   object -> Scripting.Dictionary (CompareMode 0 = 대소문자 구분)
'   array  -> VBScript 배열 (0-based)
'   string -> String,  number -> Double,  true/false -> Boolean,  null -> Null
'==============================================================================
Class CJson

    Private mS, mPos, mLen, mErrMsg
    Private mRoot                              ' 파싱 결과 (객체일 수도, 값일 수도)
    Private mRootIsObj

    Private Sub Class_Initialize()
        mErrMsg     = ""
        mRootIsObj  = False
        mRoot       = Null
    End Sub

    Public Property Get ErrMsg()
        ErrMsg = mErrMsg
    End Property

    Public Property Get HasError()
        HasError = (Len(mErrMsg) > 0)
    End Property

    '==========================================================================
    ' 파싱 : 성공하면 True
    '==========================================================================
    Public Function Parse(ByVal pText)
        mS         = CStr(pText & "")
        mLen       = Len(mS)
        mPos       = 1
        mErrMsg    = ""
        mRoot      = Null
        mRootIsObj = False
        Parse      = False

        If mLen = 0 Then mErrMsg = "빈 문자열입니다." : Exit Function

        ' UTF-8 BOM 이 문자로 들어온 경우 건너뛴다
        If AscW(Mid(mS, 1, 1)) = -257 Or AscW(Mid(mS, 1, 1)) = 65279 Then mPos = 2

        Dim v
        ReadValue v
        If HasError Then Exit Function

        SkipWs
        If mPos <= mLen Then
            mErrMsg = "JSON 뒤에 남은 문자가 있습니다. (위치 " & mPos & ")"
            Exit Function
        End If

        If IsObject(v) Then
            Set mRoot  = v
            mRootIsObj = True
        Else
            mRoot      = v
            mRootIsObj = False
        End If
        Parse = True
    End Function

    '--------------------------------------------------------------------------
    ' 파서 내부
    '--------------------------------------------------------------------------
    Private Sub SkipWs()
        Dim c
        Do While mPos <= mLen
            c = Mid(mS, mPos, 1)
            If c = " " Or c = vbTab Or c = vbCr Or c = vbLf Then
                mPos = mPos + 1
            Else
                Exit Do
            End If
        Loop
    End Sub

    '<Desc>값 하나를 읽어 outV 에 넣는다. 객체면 Set, 아니면 대입.</Desc>
    Private Sub ReadValue(ByRef outV)
        outV = Null
        SkipWs
        If mPos > mLen Then mErrMsg = "값이 오기 전에 문자열이 끝났습니다." : Exit Sub

        Dim c
        c = Mid(mS, mPos, 1)

        If c = "{" Then
            Dim d
            Set d = ReadObject()
            Set outV = d

        ElseIf c = "[" Then
            outV = ReadArray()

        ElseIf c = """" Then
            outV = ReadString()

        ElseIf c = "t" Then
            If Mid(mS, mPos, 4) = "true" Then
                mPos = mPos + 4 : outV = True
            Else
                mErrMsg = "true 가 아닙니다. (위치 " & mPos & ")"
            End If

        ElseIf c = "f" Then
            If Mid(mS, mPos, 5) = "false" Then
                mPos = mPos + 5 : outV = False
            Else
                mErrMsg = "false 가 아닙니다. (위치 " & mPos & ")"
            End If

        ElseIf c = "n" Then
            If Mid(mS, mPos, 4) = "null" Then
                mPos = mPos + 4 : outV = Null
            Else
                mErrMsg = "null 이 아닙니다. (위치 " & mPos & ")"
            End If

        ElseIf c = "-" Or (c >= "0" And c <= "9") Then
            outV = ReadNumber()

        Else
            mErrMsg = "예상치 못한 문자 '" & c & "' (위치 " & mPos & ")"
        End If
    End Sub

    Private Function ReadObject()
        Dim d, k, tmp, c
        Set d = Server.CreateObject("Scripting.Dictionary")
        d.CompareMode = 0                      ' JSON 키는 대소문자를 구분한다
        Set ReadObject = d

        mPos = mPos + 1                        ' {
        SkipWs
        If mPos <= mLen Then
            If Mid(mS, mPos, 1) = "}" Then mPos = mPos + 1 : Exit Function
        End If

        Do
            SkipWs
            If mPos > mLen Then mErrMsg = "객체가 닫히지 않았습니다." : Exit Function
            If Mid(mS, mPos, 1) <> """" Then
                mErrMsg = "객체 키는 문자열이어야 합니다. (위치 " & mPos & ")"
                Exit Function
            End If

            k = ReadString()
            If HasError Then Exit Function

            SkipWs
            If mPos > mLen Then mErrMsg = "키 뒤에 : 가 없습니다." : Exit Function
            If Mid(mS, mPos, 1) <> ":" Then
                mErrMsg = "키 뒤에 : 가 없습니다. (위치 " & mPos & ")"
                Exit Function
            End If
            mPos = mPos + 1

            ReadValue tmp
            If HasError Then Exit Function

            ' Dictionary.Add 는 인자로 넘기므로 객체든 값이든 그대로 들어간다
            If d.Exists(k) Then d.Remove k
            d.Add k, tmp

            SkipWs
            If mPos > mLen Then mErrMsg = "객체가 닫히지 않았습니다." : Exit Function
            c = Mid(mS, mPos, 1)
            If c = "," Then
                mPos = mPos + 1
            ElseIf c = "}" Then
                mPos = mPos + 1
                Exit Do
            Else
                mErrMsg = "객체에서 , 또는 } 를 기대했습니다. (위치 " & mPos & ")"
                Exit Function
            End If
        Loop
    End Function

    Private Function ReadArray()
        Dim arr, n, tmp, c
        arr = Array()
        n = 0
        ReadArray = arr

        mPos = mPos + 1                        ' [
        SkipWs
        If mPos <= mLen Then
            If Mid(mS, mPos, 1) = "]" Then mPos = mPos + 1 : Exit Function
        End If

        Do
            ReadValue tmp
            If HasError Then ReadArray = arr : Exit Function

            ReDim Preserve arr(n)
            If IsObject(tmp) Then Set arr(n) = tmp Else arr(n) = tmp
            n = n + 1

            SkipWs
            If mPos > mLen Then mErrMsg = "배열이 닫히지 않았습니다." : ReadArray = arr : Exit Function
            c = Mid(mS, mPos, 1)
            If c = "," Then
                mPos = mPos + 1
            ElseIf c = "]" Then
                mPos = mPos + 1
                Exit Do
            Else
                mErrMsg = "배열에서 , 또는 ] 를 기대했습니다. (위치 " & mPos & ")"
                ReadArray = arr
                Exit Function
            End If
        Loop

        ReadArray = arr
    End Function

    Private Function ReadString()
        Dim sb, c, code
        ReadString = ""
        mPos = mPos + 1                        ' 여는 따옴표
        sb = ""

        Do While mPos <= mLen
            c = Mid(mS, mPos, 1)

            If c = """" Then
                mPos = mPos + 1
                ReadString = sb
                Exit Function

            ElseIf c = "\" Then
                mPos = mPos + 1
                If mPos > mLen Then mErrMsg = "이스케이프가 끊겼습니다." : Exit Function
                c = Mid(mS, mPos, 1)
                If c = """" Then
                    sb = sb & """"
                ElseIf c = "\" Then
                    sb = sb & "\"
                ElseIf c = "/" Then
                    sb = sb & "/"
                ElseIf c = "b" Then
                    sb = sb & Chr(8)
                ElseIf c = "f" Then
                    sb = sb & Chr(12)
                ElseIf c = "n" Then
                    sb = sb & vbLf
                ElseIf c = "r" Then
                    sb = sb & vbCr
                ElseIf c = "t" Then
                    sb = sb & vbTab
                ElseIf c = "u" Then
                    If mPos + 4 > mLen Then mErrMsg = "\u 뒤 4자리가 부족합니다." : Exit Function
                    code = Mid(mS, mPos + 1, 4)
                    If Not IsHex4(code) Then mErrMsg = "\u" & code & " 가 16진수가 아닙니다." : Exit Function
                    sb = sb & ChrW(CLng("&H" & code))
                    mPos = mPos + 4
                Else
                    mErrMsg = "알 수 없는 이스케이프 \" & c
                    Exit Function
                End If
                mPos = mPos + 1

            Else
                sb = sb & c
                mPos = mPos + 1
            End If
        Loop

        mErrMsg = "문자열이 닫히지 않았습니다."
    End Function

    Private Function IsHex4(ByVal s)
        Dim i, c
        IsHex4 = False
        If Len(s) <> 4 Then Exit Function
        For i = 1 To 4
            c = LCase(Mid(s, i, 1))
            If Not ((c >= "0" And c <= "9") Or (c >= "a" And c <= "f")) Then Exit Function
        Next
        IsHex4 = True
    End Function

    Private Function ReadNumber()
        Dim st, c, s
        st = mPos
        Do While mPos <= mLen
            c = Mid(mS, mPos, 1)
            If (c >= "0" And c <= "9") Or c = "-" Or c = "+" Or c = "." Or c = "e" Or c = "E" Then
                mPos = mPos + 1
            Else
                Exit Do
            End If
        Loop
        s = Mid(mS, st, mPos - st)
        If Not IsNumeric(s) Then
            mErrMsg = "숫자 형식이 아닙니다 : " & s
            ReadNumber = 0
            Exit Function
        End If
        ReadNumber = CDbl(s)
    End Function

    '==========================================================================
    ' 경로 조회 :  "data.items[0].name"
    '==========================================================================
    '<Desc>경로를 따라간 결과를 outV 에 넣고, 찾았으면 outFound = True</Desc>
    Private Sub Walk(ByVal pPath, ByRef outV, ByRef outFound)
        ' ★ 값을 옮길 때 반드시 임시 변수(el)를 거친다.
        '   cur = cur(idx) 처럼 배열을 담은 변수를 자기 인덱스 결과로 덮어쓰면
        '   VBScript 가 실패한다.
        Dim cur, curIsObj, parts, i, seg, nm, idx, p1, p2, ub, el

        outV     = Null
        outFound = False

        If mRootIsObj Then Set cur = mRoot Else cur = mRoot
        curIsObj = mRootIsObj

        If Len(CStr(pPath & "")) = 0 Then
            If curIsObj Then Set outV = cur Else outV = cur
            outFound = True
            Exit Sub
        End If

        parts = Split(CStr(pPath), ".")
        For i = 0 To UBound(parts)
            seg = parts(i)
            If Len(seg) = 0 Then Exit Sub

            nm = seg
            p1 = InStr(seg, "[")
            If p1 > 0 Then nm = Left(seg, p1 - 1)

            If Len(nm) > 0 Then
                If Not curIsObj Then Exit Sub
                If TypeName(cur) <> "Dictionary" Then Exit Sub
                If Not cur.Exists(nm) Then Exit Sub
                If IsObject(cur.Item(nm)) Then
                    Set el = cur.Item(nm)
                    Set cur = el
                    curIsObj = True
                Else
                    el = cur.Item(nm)
                    cur = el
                    curIsObj = False
                End If
            End If

            Do While p1 > 0
                p2 = InStr(p1, seg, "]")
                If p2 = 0 Then Exit Sub
                idx = Mid(seg, p1 + 1, p2 - p1 - 1)
                If Not IsNumeric(idx) Then Exit Sub
                If curIsObj Then Exit Sub
                If Not IsArray(cur) Then Exit Sub
                On Error Resume Next
                ub = -1
                ub = UBound(cur)
                If Err.Number <> 0 Then Err.Clear : On Error GoTo 0 : Exit Sub
                On Error GoTo 0
                If CLng(idx) < 0 Or CLng(idx) > ub Then Exit Sub
                If IsObject(cur(CLng(idx))) Then
                    Set el = cur(CLng(idx))
                    Set cur = el
                    curIsObj = True
                Else
                    el = cur(CLng(idx))
                    cur = el
                    curIsObj = False
                End If
                p1 = InStr(p2, seg, "[")
            Loop
        Next

        If curIsObj Then Set outV = cur Else outV = cur
        outFound = True
    End Sub

    Public Function Exists(ByVal pPath)
        Dim v, f
        Walk pPath, v, f
        If Not f Then Exists = False : Exit Function
        If IsObject(v) Then Exists = True : Exit Function
        Exists = Not IsNull(v)
    End Function

    Public Function Str(ByVal pPath, ByVal pInit)
        Dim v, f
        Str = pInit
        Walk pPath, v, f
        If Not f Then Exit Function
        If IsObject(v) Then Exit Function
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If VarType(v) = vbBoolean Then
            If v Then Str = "true" Else Str = "false"
            Exit Function
        End If
        Str = CStr(v)
    End Function

    Public Function Num(ByVal pPath, ByVal pInit)
        Dim v, f
        Num = pInit
        Walk pPath, v, f
        If Not f Then Exit Function
        If IsObject(v) Then Exit Function
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If Not IsNumeric(CStr(v)) Then Exit Function
        Num = CDbl(CStr(v))
    End Function

    Public Function Bln(ByVal pPath, ByVal pInit)
        Dim v, f
        Bln = pInit
        Walk pPath, v, f
        If Not f Then Exit Function
        If IsObject(v) Then Exit Function
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If VarType(v) = vbBoolean Then Bln = v : Exit Function
        Bln = (LCase(CStr(v)) = "true" Or CStr(v) = "1")
    End Function

    Public Function Count(ByVal pPath)
        Dim v, f
        Count = 0
        Walk pPath, v, f
        If Not f Then Exit Function
        If IsObject(v) Then Exit Function
        If Not IsArray(v) Then Exit Function
        On Error Resume Next
        Count = UBound(v) + 1
        If Err.Number <> 0 Then Count = 0 : Err.Clear
        On Error GoTo 0
    End Function

    '==========================================================================
    ' 생성 : 문자열을 JSON 리터럴로 (감싸는 따옴표 포함)
    '==========================================================================
    Public Function Enc(ByVal v)
        Dim s, i, c, n
        If IsNull(v) Or IsEmpty(v) Then s = "" Else s = CStr(v)
        Enc = """"
        For i = 1 To Len(s)
            c = Mid(s, i, 1)
            n = AscW(c)
            If n < 0 Then n = n + 65536
            If c = """" Then
                Enc = Enc & "\"""
            ElseIf c = "\" Then
                Enc = Enc & "\\"
            ElseIf c = vbLf Then
                Enc = Enc & "\n"
            ElseIf c = vbCr Then
                Enc = Enc & "\r"
            ElseIf c = vbTab Then
                Enc = Enc & "\t"
            ElseIf n < 32 Then
                Enc = Enc & "\u" & Right("000" & Hex(n), 4)
            Else
                Enc = Enc & c
            End If
        Next
        Enc = Enc & """"
    End Function

End Class

Dim Json
Set Json = New CJson
%>
