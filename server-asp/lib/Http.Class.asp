<%
'==============================================================================
' lib/Http.Class.asp  -  외부 HTTP(S) 호출 래퍼
'------------------------------------------------------------------------------
' MSXML2.ServerXMLHTTP.6.0 을 쓴다. (WinHTTP 기반이라 TLS 1.2/1.3 이 붙는다)
' XMLHTTP(클라이언트용) 가 아니라 ServerXMLHTTP 여야 서버측에서 안전하다.
'
' 사용법
'   Http.Reset
'   Http.SetHeader "Authorization", "Basic ..."
'   If Http.Post("https://...", "a=1&b=2", "application/x-www-form-urlencoded") Then
'       ... Http.Status, Http.Body
'   Else
'       ... Http.ErrMsg
'   End If
'
' 주의
'   호출 실패(네트워크/타임아웃)와 HTTP 오류 응답(4xx/5xx)은 다르다.
'   Post/Get 은 "응답을 받았는가"만 True/False 로 돌려준다.
'   4xx/5xx 판단은 Status 로 직접 해야 한다.
'==============================================================================
Class CHttp

    Private mHeaders
    Private mStatus, mBody, mErrMsg
    Public  TimeoutMs

    Private Sub Class_Initialize()
        Set mHeaders = Server.CreateObject("Scripting.Dictionary")
        mHeaders.CompareMode = 1
        TimeoutMs = 10000
        Reset
    End Sub

    Public Sub Reset()
        mHeaders.RemoveAll
        mStatus = 0
        mBody   = ""
        mErrMsg = ""
    End Sub

    Public Property Get Status()
        Status = mStatus
    End Property

    Public Property Get Body()
        Body = mBody
    End Property

    Public Property Get ErrMsg()
        ErrMsg = mErrMsg
    End Property

    Public Property Get IsOk()
        IsOk = (mStatus >= 200 And mStatus < 300)
    End Property

    Public Sub SetHeader(ByVal pName, ByVal pValue)
        If mHeaders.Exists(pName) Then mHeaders.Remove pName
        mHeaders.Add pName, CStr(pValue & "")
    End Sub

    '<Desc>Basic 인증 헤더. 토스페이먼츠 등이 secret_key + ":" 형식을 쓴다.</Desc>
    Public Sub SetBasicAuth(ByVal pUser, ByVal pPass)
        SetHeader "Authorization", "Basic " & Crypt.Base64Encode(CStr(pUser) & ":" & CStr(pPass))
    End Sub

    Public Function HttpGet(ByVal pUrl)
        HttpGet = Send("GET", pUrl, "", "")
    End Function

    Public Function Post(ByVal pUrl, ByVal pBody, ByVal pContentType)
        Post = Send("POST", pUrl, pBody, pContentType)
    End Function

    Public Function PostJson(ByVal pUrl, ByVal pJson)
        PostJson = Send("POST", pUrl, pJson, "application/json; charset=UTF-8")
    End Function

    '--------------------------------------------------------------------------
    Private Function Send(ByVal pMethod, ByVal pUrl, ByVal pBody, ByVal pContentType)
        Dim h, k, bin

        Send    = False
        mStatus = 0
        mBody   = ""
        mErrMsg = ""

        On Error Resume Next

        Set h = Server.CreateObject("MSXML2.ServerXMLHTTP.6.0")
        If Err.Number <> 0 Then
            mErrMsg = "HTTP 개체를 만들 수 없습니다 : " & Err.Description
            Err.Clear : On Error GoTo 0 : Exit Function
        End If

        ' resolve / connect / send / receive
        h.setTimeouts TimeoutMs, TimeoutMs, TimeoutMs, TimeoutMs * 2

        h.open pMethod, CStr(pUrl), False
        If Err.Number <> 0 Then
            mErrMsg = "open 실패 : " & Err.Description
            Err.Clear : Set h = Nothing : On Error GoTo 0 : Exit Function
        End If

        If Len(pContentType) > 0 Then h.setRequestHeader "Content-Type", CStr(pContentType)
        For Each k In mHeaders.Keys
            h.setRequestHeader CStr(k), mHeaders(k)
        Next
        Err.Clear

        If Len(pBody) > 0 Then
            ' 한글이 섞이면 UTF-8 바이트로 보내야 한다. 문자열로 넘기면 인코딩이 어긋난다.
            bin = Utf8Bytes(pBody)
            h.send bin
        Else
            h.send
        End If

        If Err.Number <> 0 Then
            mErrMsg = "전송 실패 : " & Err.Description & " (0x" & Hex(Err.Number) & ")"
            Err.Clear : Set h = Nothing : On Error GoTo 0 : Exit Function
        End If

        mStatus = h.status
        mBody   = Utf8Text(h.responseBody)
        If Err.Number <> 0 Then
            ' 본문이 비었거나 바이너리가 아닐 때
            mBody = h.responseText
            Err.Clear
        End If

        Set h = Nothing
        On Error GoTo 0
        Send = True
    End Function

    '<Desc>문자열 → UTF-8 바이트</Desc>
    Private Function Utf8Bytes(ByVal s)
        Dim st
        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 2 : st.Charset = "utf-8" : st.Open
        st.WriteText CStr(s)
        st.Position = 0
        st.Type = 1
        st.Position = 3                        ' UTF-8 BOM 3바이트 제거
        Utf8Bytes = st.Read
        st.Close
        Set st = Nothing
    End Function

    '<Desc>응답 바이트 → UTF-8 문자열</Desc>
    Private Function Utf8Text(ByVal b)
        Dim st
        Utf8Text = ""
        If IsNull(b) Or IsEmpty(b) Then Exit Function
        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1 : st.Open
        st.Write b
        st.Position = 0
        st.Type    = 2
        st.Charset = "utf-8"
        Utf8Text = st.ReadText
        st.Close
        Set st = Nothing
    End Function

End Class

Dim Http
Set Http = New CHttp
%>
