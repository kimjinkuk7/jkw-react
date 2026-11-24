<%
'==============================================================================
' lib/Crypt.Class.asp  -  해시 / 인코딩
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Lib/Crypt.Class.asp
'
' ★ 비밀번호 해시 규약 (4개 스택 공통)
'      user_pw = LOWER( HEX( SHA2_256( user_salt || 평문비밀번호 ) ) )   64자
'      user_salt = 32자 hex 랜덤
'      비밀번호는 ASCII 문자만 허용 (StringUtil.ChkPassword 가 강제)
'
'   Classic ASP 에는 SHA-256 내장 구현이 없으므로 SQL Server 의 HASHBYTES 를
'   계산기로 사용한다. 입력이 ASCII 이면 아래와 결과가 완전히 동일하다.
'      PostgreSQL : encode(digest(salt||pw,'sha256'),'hex')
'      Java       : MessageDigest.getInstance("SHA-256")
'      Python     : hashlib.sha256((salt+pw).encode()).hexdigest()
'      PHP        : hash('sha256', $salt.$pw)
'==============================================================================
Class CCrypt

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '--------------------------------------------------------------------------
    ' 해시
    '--------------------------------------------------------------------------

    '<Desc>SHA-256 hex(소문자 64자). 입력은 ASCII 여야 이식성이 보장된다.</Desc>
    Public Function Sha256Hex(ByVal pText)
        Dim v
        With DBHelper
            .Sql = "SELECT LOWER(CONVERT(CHAR(64), HASHBYTES('SHA2_256', CAST(? AS VARCHAR(4000))), 2))"
            .SetParamVarchar(CStr(pText))
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Or IsEmpty(v) Then
            Sha256Hex = ""
        Else
            Sha256Hex = LCase(Trim(CStr(v)))
        End If
    End Function

    '<Desc>회원 비밀번호 해시</Desc>
    Public Function HashPassword(ByVal pSalt, ByVal pPlain)
        HashPassword = Sha256Hex(CStr(pSalt) & CStr(pPlain))
    End Function

    '<Desc>32자 hex salt 생성 (SQL NEWID 사용 - 암호학적으로 충분)</Desc>
    Public Function MakeSalt()
        Dim v
        With DBHelper
            .Sql = "SELECT LOWER(REPLACE(CONVERT(VARCHAR(36), NEWID()), '-', ''))"
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Or IsEmpty(v) Then
            MakeSalt = StringUtil.NewKey()
        Else
            MakeSalt = LCase(Trim(CStr(v)))
        End If
    End Function

    '<Desc>비회원 글 비밀번호 (짧은 숫자 허용) - salt 없이 고정 접두어 사용</Desc>
    Public Function HashGuestPw(ByVal pPlain)
        HashGuestPw = Sha256Hex("guestsalt00000000000000000000000" & CStr(pPlain))
    End Function

    '--------------------------------------------------------------------------
    ' Base64  (MSXML 의 bin.base64 노드를 이용)
    '--------------------------------------------------------------------------

    Private Function TextToBytes(ByVal s)
        Dim st
        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 2 : st.Charset = "utf-8" : st.Open
        st.WriteText s
        st.Position = 0
        st.Type = 1
        st.Position = 3                       ' UTF-8 BOM 3바이트 건너뜀
        TextToBytes = st.Read
        st.Close
        Set st = Nothing
    End Function

    Private Function BytesToText(ByVal b)
        Dim st
        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1 : st.Open
        st.Write b
        st.Position = 0
        st.Type = 2 : st.Charset = "utf-8"
        BytesToText = st.ReadText
        st.Close
        Set st = Nothing
    End Function

    Public Function Base64Encode(ByVal s)
        Dim xml, node
        If StringUtil.IsBlank(s) Then Base64Encode = "" : Exit Function
        Set xml  = Server.CreateObject("MSXML2.DOMDocument.6.0")
        Set node = xml.createElement("b64")
        node.dataType = "bin.base64"
        node.nodeTypedValue = TextToBytes(CStr(s))
        Base64Encode = Replace(Replace(node.text, vbCr, ""), vbLf, "")
        Set node = Nothing : Set xml = Nothing
    End Function

    Public Function Base64Decode(ByVal s)
        Dim xml, node
        Base64Decode = ""
        If StringUtil.IsBlank(s) Then Exit Function
        On Error Resume Next
        Set xml  = Server.CreateObject("MSXML2.DOMDocument.6.0")
        Set node = xml.createElement("b64")
        node.dataType = "bin.base64"
        node.text = CStr(s)
        Base64Decode = BytesToText(node.nodeTypedValue)
        If Err.Number <> 0 Then Base64Decode = "" : Err.Clear
        On Error GoTo 0
        Set node = Nothing : Set xml = Nothing
    End Function

    '--------------------------------------------------------------------------
    ' 쿠키용 가역 인코딩 (XOR + Base64)
    '--------------------------------------------------------------------------
    ' ※ 강력한 암호화가 아니다. 아이디 저장 등 비민감 값에만 사용할 것.
    '    민감 정보는 세션에 두고 쿠키에는 넣지 않는다.
    '--------------------------------------------------------------------------

    Private Function XorText(ByVal s, ByVal k)
        Dim i, r, kc
        r = ""
        If Len(k) = 0 Then k = "x"
        For i = 1 To Len(s)
            kc = Asc(Mid(k, ((i - 1) Mod Len(k)) + 1, 1))
            r = r & ChrW(AscW(Mid(s, i, 1)) Xor (kc Mod 128))
        Next
        XorText = r
    End Function

    Public Function Encrypt(ByVal s)
        If StringUtil.IsBlank(s) Then Encrypt = "" : Exit Function
        Encrypt = Base64Encode(XorText(CStr(s), CRYPT_KEY))
    End Function

    Public Function Decrypt(ByVal s)
        Dim d
        Decrypt = ""
        If StringUtil.IsBlank(s) Then Exit Function
        d = Base64Decode(CStr(s))
        If Len(d) = 0 Then Exit Function
        Decrypt = XorText(d, CRYPT_KEY)
    End Function

End Class

Dim Crypt
Set Crypt = New CCrypt
%>
