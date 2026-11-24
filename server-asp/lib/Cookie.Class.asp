<%
'==============================================================================
' lib/Cookie.Class.asp  -  쿠키 유틸리티
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Lib/Cookie.Class.asp  (Encrypt / Decrypt 시그니처 유지)
'
' ※ 민감 정보는 쿠키에 저장하지 않는다. 세션(Session)을 쓴다.
'   여기 Encrypt 는 "아이디 저장" 같은 비민감 값의 노출 방지용이다.
'==============================================================================
Class CCookie

    Private mDomain
    Private mPath

    Private Sub Class_Initialize()
        mDomain = ""
        mPath   = "/"
    End Sub

    Public Property Let Domain(ByVal v) : mDomain = v : End Property
    Public Property Let Path(ByVal v)   : mPath   = v : End Property

    '<Desc>쿠키 저장. pDays = 0 이면 세션 쿠키</Desc>
    Public Sub SetValue(ByVal pName, ByVal pValue, ByVal pDays)
        Response.Cookies(pName)          = CStr(pValue)
        Response.Cookies(pName).Path     = mPath
        Response.Cookies(pName).HTTPOnly = True
        If Len(mDomain) > 0 Then Response.Cookies(pName).Domain = mDomain
        If IsNumeric(pDays) Then
            If CLng(pDays) > 0 Then Response.Cookies(pName).Expires = DateAdd("d", CLng(pDays), Now())
        End If
    End Sub

    Public Function GetValue(ByVal pName)
        GetValue = Request.Cookies(pName) & ""
    End Function

    Public Sub Remove(ByVal pName)
        Response.Cookies(pName)         = ""
        Response.Cookies(pName).Path    = mPath
        Response.Cookies(pName).Expires = DateAdd("d", -1, Now())
        If Len(mDomain) > 0 Then Response.Cookies(pName).Domain = mDomain
    End Sub

    '<Desc>XOR+Base64 로 인코딩하여 저장</Desc>
    Public Sub Encrypt(ByVal pName, ByVal pValue)
        SetValue pName, Crypt.Encrypt(pValue), 30
    End Sub

    '<Desc>인코딩된 쿠키 읽기</Desc>
    Public Function Decrypt(ByVal pName)
        Decrypt = Crypt.Decrypt(GetValue(pName))
    End Function

End Class

Dim Cookie
Set Cookie = New CCookie
%>
