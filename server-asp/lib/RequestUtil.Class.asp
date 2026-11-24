<%
'==============================================================================
' lib/RequestUtil.Class.asp  -  Request 유틸리티
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / _Gcommon/Lib/RequestUtil.Class.asp
'        (Value / ValueInit / ChkValueIsNumber / ChkValueIsNull 시그니처 유지)
'
' 사용 : RequestUtil.ValueInit("bid", "")
'        RequestUtil.ValueIntInit("page", 1)
'==============================================================================
Class CRequestUtil

    Private mMinInt, mMaxInt, mMinBigInt, mMaxBigInt

    Public Property Get MinInt()    : MinInt    = mMinInt    : End Property
    Public Property Get MaxInt()    : MaxInt    = mMaxInt    : End Property
    Public Property Get MinBigInt() : MinBigInt = mMinBigInt : End Property
    Public Property Get MaxBigInt() : MaxBigInt = mMaxBigInt : End Property

    Private Sub Class_Initialize()
        mMinInt    = "-2147483648"
        mMaxInt    = "2147483647"
        mMinBigInt = "-9223372036854775808"
        mMaxBigInt = "9223372036854775807"
    End Sub

    '--------------------------------------------------------------------------
    ' 값 획득
    '--------------------------------------------------------------------------

    '<Desc>Request 를 대신한다. Form 우선, 없으면 QueryString.</Desc>
    Public Default Function Value(ByVal pName)
        Dim v
        Value = ""
        v = Request.Form(pName) & ""
        If Len(v) = 0 Then v = Request.QueryString(pName) & ""
        Value = Trim(v)
    End Function

    '<Desc>값이 없으면 pInitVal 을 반환</Desc>
    Public Function ValueInit(ByVal pName, ByVal pInitVal)
        Dim v
        v = Value(pName)
        If Len(v) = 0 Then
            ValueInit = pInitVal
        Else
            ValueInit = v
        End If
    End Function

    '<Desc>정수로 변환. 숫자가 아니면 pInitVal</Desc>
    Public Function ValueIntInit(ByVal pName, ByVal pInitVal)
        Dim v
        v = Value(pName)
        If Len(v) = 0 Then ValueIntInit = pInitVal : Exit Function
        If Not IsNumeric(v) Then ValueIntInit = pInitVal : Exit Function
        On Error Resume Next
        ValueIntInit = CLng(v)
        If Err.Number <> 0 Then ValueIntInit = pInitVal : Err.Clear
        On Error GoTo 0
    End Function

    '<Desc>허용 목록에 없는 값이면 기본값으로 강제 (정렬키 / 검색필드 등)</Desc>
    '<Param name="pAllow">콤마 구분 허용 목록. 예 "title,content,writer"</Param>
    Public Function ValueWhite(ByVal pName, ByVal pAllow, ByVal pDefault)
        Dim v
        v = LCase(Value(pName))
        If Len(v) = 0 Then ValueWhite = pDefault : Exit Function
        If InStr("," & LCase(pAllow) & ",", "," & v & ",") > 0 Then
            ValueWhite = v
        Else
            ValueWhite = pDefault
        End If
    End Function

    Public Function FormValue(ByVal pName)
        FormValue = Trim(Request.Form(pName) & "")
    End Function

    Public Function QueryValue(ByVal pName)
        QueryValue = Trim(Request.QueryString(pName) & "")
    End Function

    '--------------------------------------------------------------------------
    ' 검사
    '--------------------------------------------------------------------------

    Public Function ChkValueIsNumber(ByVal pValue)
        ChkValueIsNumber = False
        If IsNull(pValue) Then Exit Function
        If CStr(pValue) = "" Then Exit Function
        ChkValueIsNumber = IsNumeric(pValue)
    End Function

    Public Function ChkValueIsNull(ByVal pValue)
        ChkValueIsNull = True
        If IsNull(pValue) Or IsEmpty(pValue) Then Exit Function
        ChkValueIsNull = (Len(Trim(CStr(pValue))) = 0)
    End Function

    Public Function IsPost()
        IsPost = (UCase(Request.ServerVariables("REQUEST_METHOD") & "") = "POST")
    End Function

    '<Desc>multipart/form-data 요청인지 (파일 업로드 폼)</Desc>
    Public Function IsMultipart()
        IsMultipart = (InStr(LCase(Request.ServerVariables("CONTENT_TYPE") & ""), "multipart/form-data") > 0)
    End Function

    '--------------------------------------------------------------------------
    ' 클라이언트 정보
    '--------------------------------------------------------------------------

    Public Function ClientIp()
        Dim ip
        ip = Request.ServerVariables("HTTP_X_FORWARDED_FOR") & ""
        If Len(ip) = 0 Then ip = Request.ServerVariables("REMOTE_ADDR") & ""
        If InStr(ip, ",") > 0 Then ip = Trim(Split(ip, ",")(0))
        If Len(ip) > 45 Then ip = Left(ip, 45)
        ClientIp = ip
    End Function

    Public Function UserAgent()
        UserAgent = Left(Request.ServerVariables("HTTP_USER_AGENT") & "", 400)
    End Function

    '<Desc>pc / mobile / tablet</Desc>
    Public Function DeviceType()
        Dim ua
        ua = LCase(UserAgent())
        If InStr(ua, "ipad") > 0 Or (InStr(ua, "android") > 0 And InStr(ua, "mobile") = 0) Then
            DeviceType = "tablet"
        ElseIf InStr(ua, "mobile") > 0 Or InStr(ua, "iphone") > 0 Or InStr(ua, "android") > 0 Then
            DeviceType = "mobile"
        Else
            DeviceType = "pc"
        End If
    End Function

    '<Desc>현재 요청 URL (쿼리스트링 포함)</Desc>
    Public Function CurrentUrl()
        Dim u
        u = Request.ServerVariables("URL") & ""
        If Len(Request.QueryString & "") > 0 Then u = u & "?" & Request.QueryString
        CurrentUrl = u
    End Function

    '<Desc>같은 사이트에서 넘어온 요청인지 (CSRF 보조 방어)</Desc>
    Public Function IsSameOrigin()
        Dim ref, host
        ref  = LCase(Request.ServerVariables("HTTP_REFERER") & "")
        host = LCase(Request.ServerVariables("HTTP_HOST") & "")
        If Len(ref) = 0 Then IsSameOrigin = False : Exit Function
        IsSameOrigin = (InStr(ref, "//" & host) > 0)
    End Function

End Class

Dim RequestUtil
Set RequestUtil = New CRequestUtil
%>
