<%
'==============================================================================
' lib/FileDownload.Class.asp  -  파일 다운로드 스트리밍
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Lib/FileDownload.Class.asp  (Down 메서드 시그니처 유지)
'
' ★ /upload 는 web.config 로 직접 접근을 막고, 반드시 이 클래스를 경유한다.
'   그래야 권한 검사 · 다운로드 카운트 · 원본 파일명 복원이 가능하다.
'==============================================================================
Class CFileDownload

    Private mChunkSize

    Private Sub Class_Initialize()
        mChunkSize = 262144                       ' 256KB 씩 전송
    End Sub

    '<Desc>물리 경로의 파일을 pDownName 이름으로 전송</Desc>
    Public Sub Down(ByVal pPhysPath, ByVal pDownName)
        Dim fso, st, sz, sent, buf, nm

        Set fso = Server.CreateObject("Scripting.FileSystemObject")
        If Not fso.FileExists(pPhysPath) Then
            Set fso = Nothing
            Fail "파일을 찾을 수 없습니다."
            Exit Sub
        End If
        sz = fso.GetFile(pPhysPath).Size
        Set fso = Nothing

        nm = StringUtil.BaseName(pDownName)
        If Len(nm) = 0 Then nm = "download"

        ' ★ Buffer = False 로 두면 안 된다.
        '   Classic ASP 에서 Response.Flush 는 버퍼링이 꺼져 있으면 런타임 오류를 낸다.
        '   그 시점엔 헤더가 이미 나가 있어 오류 화면조차 못 보내고 연결이 그냥 끊긴다
        '   (브라우저에는 "사이트에 연결할 수 없음", curl 은 exit 56).
        '   청크마다 Flush 해서 메모리를 억제하려면 버퍼링을 켠 상태로 Flush 해야 한다.
        Response.Buffer = True
        Response.Clear
        Response.ContentType = "application/octet-stream"
        Response.AddHeader "Content-Length", CStr(sz)
        Response.AddHeader "Content-Transfer-Encoding", "binary"
        Response.AddHeader "Content-Disposition", DispositionHeader(nm)
        Response.AddHeader "Cache-Control", "private, max-age=0"
        Response.AddHeader "Pragma", "no-cache"

        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1
        st.Open
        st.LoadFromFile pPhysPath
        st.Position = 0

        sent = 0
        Do While sent < sz
            If Not Response.IsClientConnected Then Exit Do
            buf = st.Read(mChunkSize)
            If IsNull(buf) Then Exit Do              ' EOF
            Response.BinaryWrite buf
            Response.Flush
            ' 실제로 읽은 위치로 누적한다. mChunkSize 를 그대로 더하면
            ' 마지막 청크에서 실제 전송량과 어긋난다.
            sent = st.Position
        Loop

        st.Close
        Set st = Nothing
        Response.End
    End Sub

    '<Desc>이미지 등을 브라우저에 인라인 표시</Desc>
    Public Sub Inline(ByVal pPhysPath, ByVal pContentType)
        Dim fso, st

        Set fso = Server.CreateObject("Scripting.FileSystemObject")
        If Not fso.FileExists(pPhysPath) Then
            Set fso = Nothing
            Response.Status = "404 Not Found"
            Response.End
        End If
        Set fso = Nothing

        Response.Clear
        Response.Buffer = True
        Response.ContentType = pContentType
        Response.AddHeader "Cache-Control", "public, max-age=604800"

        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1
        st.Open
        st.LoadFromFile pPhysPath
        Response.BinaryWrite st.Read
        st.Close
        Set st = Nothing
        Response.End
    End Sub

    '--------------------------------------------------------------------------
    ' 내부
    '--------------------------------------------------------------------------

    '<Desc>한글 파일명 대응 : RFC 5987 filename* + ASCII 폴백</Desc>
    Private Function DispositionHeader(ByVal nm)
        Dim enc, ascii
        enc = Server.URLEncode(nm)
        enc = Replace(enc, "+", "%20")

        ascii = AsciiFallback(nm)

        DispositionHeader = "attachment; filename=""" & ascii & """; filename*=UTF-8''" & enc
    End Function

    '<Desc>비 ASCII 문자를 _ 로 치환한 폴백 파일명</Desc>
    Private Function AsciiFallback(ByVal nm)
        Dim i, c, r
        r = ""
        For i = 1 To Len(nm)
            c = AscW(Mid(nm, i, 1))
            If c < 0 Then c = c + 65536
            If c >= 32 And c <= 126 And c <> 34 And c <> 92 Then
                r = r & Mid(nm, i, 1)
            Else
                r = r & "_"
            End If
        Next
        If Len(r) = 0 Then r = "download"
        AsciiFallback = r
    End Function

    Private Sub Fail(ByVal msg)
        Response.Clear
        Response.ContentType = "text/html"
        Response.Write "<!DOCTYPE html><html lang=""ko""><head><meta charset=""utf-8""></head><body>"
        Response.Write "<script>alert('" & JE(msg) & "');history.back();</script></body></html>"
        Response.End
    End Sub

End Class

Dim FileDownload
Set FileDownload = New CFileDownload
%>
