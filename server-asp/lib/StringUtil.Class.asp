<%
'==============================================================================
' lib/StringUtil.Class.asp  -  문자열 유틸리티
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / _Gcommon/Lib/StringUtil.Class.asp
' 사용 : StringUtil.HtmlEnc(v) ... 뷰에서 자주 쓰는 3개는 전역 축약 함수 제공
'        HE(v) = HtmlEnc, UE(v) = UrlEnc, JE(v) = JsEnc
'==============================================================================
Class CStringUtil

    '--------------------------------------------------------------------------
    ' 이스케이프
    '--------------------------------------------------------------------------

    '<Desc>HTML 이스케이프. DB 값을 화면에 찍을 때 반드시 통과시킨다.</Desc>
    Public Function HtmlEnc(ByVal v)
        Dim s
        If IsNull(v) Or IsEmpty(v) Then HtmlEnc = "" : Exit Function
        s = CStr(v)
        s = Replace(s, "&", "&amp;")
        s = Replace(s, "<", "&lt;")
        s = Replace(s, ">", "&gt;")
        s = Replace(s, """", "&quot;")
        s = Replace(s, "'", "&#39;")
        HtmlEnc = s
    End Function

    '<Desc>HTML 이스케이프 + 줄바꿈을 br 로</Desc>
    Public Function HtmlEncBr(ByVal v)
        HtmlEncBr = Replace(Replace(HtmlEnc(v), vbCrLf, "<br>"), vbLf, "<br>")
    End Function

    Public Function UrlEnc(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then UrlEnc = "" : Exit Function
        UrlEnc = Server.URLEncode(CStr(v))
    End Function

    Public Function JsEnc(ByVal v)
        Dim s
        If IsNull(v) Or IsEmpty(v) Then JsEnc = "" : Exit Function
        s = CStr(v)
        s = Replace(s, "\", "\\")
        s = Replace(s, """", "\""")
        s = Replace(s, "'", "\'")
        s = Replace(s, vbCrLf, "\n")
        s = Replace(s, vbCr, "\n")
        s = Replace(s, vbLf, "\n")
        s = Replace(s, "</", "<\/")
        JsEnc = s
    End Function

    '<Desc>HTML 태그 전부 제거 (목록 요약, meta description 용)</Desc>
    Public Function StripTags(ByVal v)
        Dim re, s
        If IsNull(v) Or IsEmpty(v) Then StripTags = "" : Exit Function
        s = CStr(v)

        Set re = New RegExp
        re.Global = True : re.IgnoreCase = True : re.MultiLine = True
        re.Pattern = "<[^>]*>"
        s = re.Replace(s, " ")
        Set re = Nothing

        s = Replace(s, "&nbsp;", " ")
        s = Replace(s, "&amp;",  "&")
        s = Replace(s, "&lt;",   "<")
        s = Replace(s, "&gt;",   ">")
        s = Replace(s, "&quot;", """")
        s = Replace(s, "&#39;",  "'")
        s = Replace(s, vbCrLf, " ")
        s = Replace(s, vbTab,  " ")

        Do While InStr(s, "  ") > 0
            s = Replace(s, "  ", " ")
        Loop
        StripTags = Trim(s)
    End Function

    '<Desc>에디터 본문 정화 : 스크립트성 요소만 제거하고 서식은 유지</Desc>
    '<Desc>신뢰할 수 없는 입력을 HTML 로 출력해야 할 때 사용</Desc>
    Public Function SafeHtml(ByVal v)
        Dim re, s
        If IsNull(v) Or IsEmpty(v) Then SafeHtml = "" : Exit Function
        s = CStr(v)

        Set re = New RegExp
        re.Global = True : re.IgnoreCase = True : re.MultiLine = True

        re.Pattern = "<\s*(script|iframe|frame|frameset|object|embed|applet|form|meta|link|base|style)[\s\S]*?>"
        s = re.Replace(s, "")
        re.Pattern = "<\s*/\s*(script|iframe|frame|frameset|object|embed|applet|form|style)\s*>"
        s = re.Replace(s, "")
        re.Pattern = "\son[a-z]+\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)"
        s = re.Replace(s, "")
        re.Pattern = "(href|src|action|formaction)\s*=\s*[""']?\s*(javascript|vbscript|data)\s*:"
        s = re.Replace(s, "$1=""#""")
        re.Pattern = "expression\s*\("
        s = re.Replace(s, "")

        Set re = Nothing
        SafeHtml = s
    End Function

    '--------------------------------------------------------------------------
    ' 값 처리
    '--------------------------------------------------------------------------

    Public Function Nz(ByVal v, ByVal d)
        If IsNull(v) Or IsEmpty(v) Then
            Nz = d
        ElseIf CStr(v) = "" Then
            Nz = d
        Else
            Nz = v
        End If
    End Function

    Public Function IsBlank(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then IsBlank = True : Exit Function
        IsBlank = (Trim(CStr(v)) = "")
    End Function

    Public Function ToInt(ByVal v, ByVal d)
        ' ★ IsNumeric(v) 으로 먼저 걸러내면 안 된다.
        '   BIGINT / DECIMAL 컬럼은 ADO 에서 VT_DECIMAL(VarType 14) 로 넘어오고,
        '   VBScript 의 IsNumeric 은 이 타입을 숫자로 인정하지 않는다(False).
        '   그래서 article_id 같은 BIGINT 가 전부 기본값으로 떨어졌다.
        '   CStr 로 문자열화한 뒤 판정하면 Decimal 도 정상 처리된다.
        Dim s
        ToInt = d
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        On Error Resume Next
        s = Trim(CStr(v) & "")
        If Err.Number <> 0 Then Err.Clear : Exit Function
        If Len(s) = 0 Then Exit Function
        If Not IsNumeric(s) Then Exit Function
        ToInt = CLng(CDbl(s))
        If Err.Number <> 0 Then ToInt = d : Err.Clear
        On Error GoTo 0
    End Function

    '<Desc>Decimal(BIGINT) 까지 안전하게 숫자로 판정</Desc>
    Public Function IsNum(ByVal v)
        Dim s
        IsNum = False
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If VarType(v) = vbBoolean Then Exit Function
        On Error Resume Next
        s = Trim(CStr(v) & "")
        If Err.Number <> 0 Then Err.Clear : Exit Function
        On Error GoTo 0
        If Len(s) = 0 Then Exit Function
        IsNum = IsNumeric(s)
    End Function

    '<Desc>BIT 컬럼(0/1/True) → Boolean</Desc>
    Public Function ToBool(ByVal v)
        ToBool = False
        If IsNull(v) Or IsEmpty(v) Then Exit Function
        If VarType(v) = vbBoolean Then ToBool = v : Exit Function
        If IsNum(v) Then ToBool = (CDbl(CStr(v)) <> 0) : Exit Function
        ToBool = (LCase(CStr(v)) = "true" Or CStr(v) = "1" Or LCase(CStr(v)) = "y")
    End Function

    '<Desc>글자수 자르기 (한글 1자 = 1자)</Desc>
    Public Function Cut(ByVal v, ByVal n)
        Dim s
        s = Trim(CStr(Nz(v, "")))
        If Len(s) <= n Then
            Cut = s
        Else
            Cut = Left(s, n) & "…"
        End If
    End Function

    Public Function Comma(ByVal v)
        If Not IsNumeric(Nz(v, 0)) Then Comma = "0" : Exit Function
        Comma = FormatNumber(CDbl(v), 0, -1, 0, -1)
    End Function

    Public Function SizeStr(ByVal bytes)
        Dim b
        b = CDbl(Nz(bytes, 0))
        If b >= 1073741824 Then
            SizeStr = FormatNumber(b / 1073741824, 1) & " GB"
        ElseIf b >= 1048576 Then
            SizeStr = FormatNumber(b / 1048576, 1) & " MB"
        ElseIf b >= 1024 Then
            SizeStr = FormatNumber(b / 1024, 1) & " KB"
        Else
            SizeStr = CLng(b) & " B"
        End If
    End Function

    '--------------------------------------------------------------------------
    ' 파일명 / 확장자
    '--------------------------------------------------------------------------

    Public Function GetExt(ByVal fileName)
        Dim s, p
        GetExt = ""
        s = CStr(Nz(fileName, ""))
        p = InStrRev(s, ".")
        If p > 0 And p < Len(s) Then GetExt = LCase(Mid(s, p + 1))
    End Function

    '<Desc>경로 조작 방지 : 파일명에서 디렉터리 성분과 NUL 제거</Desc>
    Public Function BaseName(ByVal path)
        Dim s, p
        s = CStr(Nz(path, ""))
        p = InStrRev(s, "\")
        If p > 0 Then s = Mid(s, p + 1)
        p = InStrRev(s, "/")
        If p > 0 Then s = Mid(s, p + 1)
        s = Replace(s, Chr(0), "")
        s = Replace(s, "..", "")
        If Len(s) > 200 Then s = Right(s, 200)
        BaseName = s
    End Function

    Public Function IsImageExt(ByVal ext)
        IsImageExt = (InStr(",jpg,jpeg,gif,png,webp,bmp,", "," & LCase(CStr(Nz(ext, ""))) & ",") > 0)
    End Function

    '--------------------------------------------------------------------------
    ' 검증
    '--------------------------------------------------------------------------

    Public Function RegTest(ByVal pattern, ByVal v)
        Dim re
        Set re = New RegExp
        re.Global = False : re.IgnoreCase = True
        re.Pattern = pattern
        RegTest = re.Test(CStr(Nz(v, "")))
        Set re = Nothing
    End Function

    Public Function ChkEmail(ByVal v)
        ChkEmail = RegTest("^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$", v)
    End Function

    '<Desc>로그인 아이디 : 영소문자 시작, 영숫자/_ 4~30자</Desc>
    Public Function ChkLoginId(ByVal v)
        ChkLoginId = RegTest("^[a-z][a-z0-9_]{3,29}$", LCase(CStr(Nz(v, ""))))
    End Function

    '<Desc>비밀번호 : ASCII 만, 8자 이상, 영문+숫자 포함</Desc>
    '<Desc>★ ASCII 제한은 4개 스택 간 SHA-256 해시 호환을 위한 필수 규약</Desc>
    Public Function ChkPassword(ByVal v)
        Dim s
        s = CStr(Nz(v, ""))
        ChkPassword = False
        If Len(s) < PW_MIN_LEN Or Len(s) > 64 Then Exit Function
        If Not RegTest("^[\x20-\x7E]+$", s) Then Exit Function
        If Not RegTest("[A-Za-z]", s) Then Exit Function
        If Not RegTest("[0-9]", s)    Then Exit Function
        ChkPassword = True
    End Function

    Public Function ChkMobile(ByVal v)
        ChkMobile = RegTest("^01[016789]-?\d{3,4}-?\d{4}$", Replace(CStr(Nz(v, "")), " ", ""))
    End Function

    '<Desc>숫자만 남긴다. 휴대폰 번호 비교용 (010-1234-5678 / 01012345678 동일 취급)</Desc>
    Public Function DigitsOnly(ByVal v)
        Dim s, i, c
        s = CStr(Nz(v, ""))
        DigitsOnly = ""
        For i = 1 To Len(s)
            c = Mid(s, i, 1)
            If c >= "0" And c <= "9" Then DigitsOnly = DigitsOnly & c
        Next
    End Function

    '--------------------------------------------------------------------------
    ' 생성
    '--------------------------------------------------------------------------

    '<Desc>32자 hex 유니크 키 (업로드 파일명 / salt 용)</Desc>
    '<Desc>Scriptlet.TypeLib 은 최신 Windows 에서 미등록일 수 있어 직접 생성</Desc>
    Public Function NewKey()
        Dim d, s, i
        d = Now()
        s = Right("000" & Year(d), 4) & _
            Right("0" & Month(d), 2) & Right("0" & Day(d), 2) & _
            Right("0" & Hour(d), 2) & Right("0" & Minute(d), 2) & Right("0" & Second(d), 2)
        Randomize Timer * (1 + Len(CStr(Request.ServerVariables("REMOTE_PORT") & "")))
        For i = 1 To 18
            s = s & Mid("0123456789abcdef", Int(Rnd() * 16) + 1, 1)
        Next
        NewKey = LCase(s)
    End Function

    '--------------------------------------------------------------------------
    ' 출력 조각
    '--------------------------------------------------------------------------

    '<Desc>"a,b,c" → 태그 칩 HTML. linkFmt 의 {T} 가 태그값으로 치환된다.</Desc>
    Public Function TagChips(ByVal tags, ByVal linkFmt)
        Dim arr, i, t, s
        s = ""
        If IsBlank(tags) Then TagChips = "" : Exit Function
        arr = Split(CStr(tags), ",")
        For i = 0 To UBound(arr)
            t = Trim(arr(i))
            If t <> "" Then
                If IsBlank(linkFmt) Then
                    s = s & "<span class=""chip"">#" & HtmlEnc(t) & "</span>"
                Else
                    s = s & "<a class=""chip"" href=""" & HtmlEnc(Replace(linkFmt, "{T}", UrlEnc(t))) & """>#" & HtmlEnc(t) & "</a>"
                End If
            End If
        Next
        TagChips = s
    End Function

    '<Desc>검색어 하이라이트 (이미 HtmlEnc 된 문자열에 적용할 것)</Desc>
    Public Function Highlight(ByVal escapedText, ByVal keyword)
        Dim k
        Highlight = escapedText
        If IsBlank(keyword) Then Exit Function
        k = HtmlEnc(Trim(keyword))
        If Len(k) < 1 Then Exit Function
        Highlight = Replace(escapedText, k, "<mark>" & k & "</mark>", 1, -1, 1)
    End Function

End Class

Dim StringUtil
Set StringUtil = New CStringUtil


'##############################################################################
' 전역 축약 함수  -  뷰에서 가장 많이 쓰이는 3개만 짧은 이름을 제공한다.
'##############################################################################
Function HE(ByVal v)
    HE = StringUtil.HtmlEnc(v)
End Function

Function UE(ByVal v)
    UE = StringUtil.UrlEnc(v)
End Function

Function JE(ByVal v)
    JE = StringUtil.JsEnc(v)
End Function

Function HtmlEnc(ByVal v)          ' DBHelper.DBFail 에서도 사용
    HtmlEnc = StringUtil.HtmlEnc(v)
End Function
%>
