<%
'==============================================================================
' lib/FileUpload.Class.asp  -  multipart/form-data 업로드 파서
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Lib/FileUpload.Class.asp
' 방식 : 외부 컴포넌트 없이 순수 VBScript + ADODB.Stream 으로 파싱한다.
'        요청 본문을 iso-8859-1(1바이트=1문자, 무손실) 문자열로 읽어 경계를 찾고,
'        파일 본문은 문자열로 복사하지 않고 원본 바이너리 스트림에서
'        오프셋으로 잘라내 저장한다. (메모리 절약)
'
' ★ Request.BinaryRead 를 호출하므로 이 클래스를 Load() 한 뒤에는
'   Request.Form / RequestUtil.Value 를 쓸 수 없다. Upload.Field() 를 쓸 것.
'------------------------------------------------------------------------------
' 사용 :
'   If Upload.Load() Then
'       title = Upload.Field("title")
'       If Upload.HasFile("upfile1") Then
'           If Upload.ChkExt("upfile1", "jpg,png,pdf") Then
'               Upload.SaveAs "upfile1", Server.MapPath("/upload/board/202608"), saveName
'           End If
'       End If
'   End If
'   Upload.Dispose
'==============================================================================
Class CFileUpload

    Private mFields          ' Dictionary : name -> 텍스트 값
    Private mFiles           ' Dictionary : name -> Dictionary(FileName,Ext,Offset,Size,ContentType)
    Private mStream          ' ADODB.Stream (요청 본문 바이너리)
    Private mLoaded
    Private mErrMsg
    Private mTotalBytes

    Private Sub Class_Initialize()
        Set mFields = Server.CreateObject("Scripting.Dictionary")
        Set mFiles  = Server.CreateObject("Scripting.Dictionary")
        mFields.CompareMode = 1                  ' 대소문자 무시
        mFiles.CompareMode  = 1
        mLoaded     = False
        mErrMsg     = ""
        mTotalBytes = 0
    End Sub

    Private Sub Class_Terminate()
        Dispose
    End Sub

    Public Property Get ErrMsg()     : ErrMsg     = mErrMsg     : End Property
    Public Property Get Loaded()     : Loaded     = mLoaded     : End Property
    Public Property Get TotalBytes() : TotalBytes = mTotalBytes : End Property
    Public Property Get FileCount()  : FileCount  = mFiles.Count : End Property
    Public Property Get FileKeys()   : FileKeys   = mFiles.Keys  : End Property

    '==========================================================================
    ' 파싱
    '==========================================================================
    Public Function Load()
        Dim ct, bnd, bin, data, pos, bs, hs, he, cs, nb, clen
        Dim hdr, hdrTxt, nm, fn, ftype, isFile, d

        Load    = False
        mErrMsg = ""
        If mLoaded Then Load = True : Exit Function

        ct = Request.ServerVariables("CONTENT_TYPE") & ""
        If InStr(LCase(ct), "multipart/form-data") = 0 Then
            mErrMsg = "파일 업로드 형식(multipart/form-data)이 아닙니다."
            Exit Function
        End If

        mTotalBytes = Request.TotalBytes
        If mTotalBytes <= 0 Then
            mErrMsg = "전송된 데이터가 없습니다."
            Exit Function
        End If
        If mTotalBytes > UPLOAD_MAX_SIZE Then
            mErrMsg = "전체 전송 용량이 " & StringUtil.SizeStr(UPLOAD_MAX_SIZE) & " 를 초과했습니다."
            Exit Function
        End If

        bnd = GetBoundary(ct)
        If Len(bnd) = 0 Then
            mErrMsg = "요청에서 boundary 를 찾을 수 없습니다."
            Exit Function
        End If

        bin = Request.BinaryRead(mTotalBytes)

        Set mStream = Server.CreateObject("ADODB.Stream")
        mStream.Type = 1
        mStream.Open
        mStream.Write bin
        mStream.Position = 0

        data = BinToLatin1(bin)
        bin  = Empty

        pos = 1
        Do
            bs = InStr(pos, data, bnd, 0)
            If bs = 0 Then Exit Do
            If Mid(data, bs + Len(bnd), 2) = "--" Then Exit Do      ' 종료 boundary

            hs = bs + Len(bnd) + 2                                  ' boundary + CRLF
            he = InStr(hs, data, vbCrLf & vbCrLf, 0)
            If he = 0 Then Exit Do

            hdr = Mid(data, hs, he - hs)
            cs  = he + 4                                            ' 본문 시작 (1-based)

            ' 헤더는 원본 바이트에서 다시 UTF-8 로 읽는다. (한글 파일명 대응)
            ' data 는 1바이트=1문자이므로 문자 위치 - 1 이 곧 바이트 오프셋이다.
            hdrTxt = ReadUtf8At(hs - 1, he - hs)

            nb = InStr(cs, data, bnd, 0)
            If nb = 0 Then Exit Do

            clen = nb - 2 - cs                                      ' 본문 앞의 CRLF 제외
            If clen < 0 Then clen = 0

            nm     = ExtractAttr(hdrTxt, "name")
            fn     = ExtractAttr(hdrTxt, "filename")
            ftype  = ExtractHeader(hdrTxt, "content-type")
            isFile = (InStr(LCase(hdr), "filename=") > 0)

            If Len(nm) > 0 Then
                If isFile Then
                    fn = StringUtil.BaseName(fn)
                    If Len(fn) > 0 And clen > 0 Then
                        Set d = Server.CreateObject("Scripting.Dictionary")
                        d.Add "FileName",    fn
                        d.Add "Ext",         StringUtil.GetExt(fn)
                        d.Add "Offset",      cs - 1                 ' 0-based 바이트 오프셋
                        d.Add "Size",        clen
                        d.Add "ContentType", ftype
                        If mFiles.Exists(nm) Then mFiles.Remove nm
                        mFiles.Add nm, d
                        Set d = Nothing
                    End If
                Else
                    If mFields.Exists(nm) Then
                        mFields(nm) = mFields(nm) & "," & ReadUtf8At(cs - 1, clen)
                    Else
                        mFields.Add nm, ReadUtf8At(cs - 1, clen)
                    End If
                End If
            End If

            pos = nb
        Loop

        data    = ""
        mLoaded = True
        Load    = True
    End Function

    '==========================================================================
    ' 텍스트 필드
    '==========================================================================
    Public Function Field(ByVal pName)
        If mFields.Exists(pName) Then
            Field = Trim(mFields(pName) & "")
        Else
            Field = ""
        End If
    End Function

    Public Function FieldInit(ByVal pName, ByVal pInit)
        Dim v
        v = Field(pName)
        If Len(v) = 0 Then FieldInit = pInit Else FieldInit = v
    End Function

    Public Function FieldInt(ByVal pName, ByVal pInit)
        Dim v
        v = Field(pName)
        If Len(v) = 0 Or Not IsNumeric(v) Then
            FieldInt = pInit
        Else
            FieldInt = CLng(v)
        End If
    End Function

    Public Function HasField(ByVal pName)
        HasField = mFields.Exists(pName)
    End Function

    '==========================================================================
    ' 파일
    '==========================================================================
    Public Function HasFile(ByVal pName)
        HasFile = mFiles.Exists(pName)
    End Function

    Public Function FileName(ByVal pName)
        FileName = ""
        If mFiles.Exists(pName) Then FileName = mFiles(pName)("FileName")
    End Function

    Public Function FileExt(ByVal pName)
        FileExt = ""
        If mFiles.Exists(pName) Then FileExt = mFiles(pName)("Ext")
    End Function

    Public Function FileSize(ByVal pName)
        FileSize = 0
        If mFiles.Exists(pName) Then FileSize = mFiles(pName)("Size")
    End Function

    Public Function FileContentType(ByVal pName)
        FileContentType = ""
        If mFiles.Exists(pName) Then FileContentType = mFiles(pName)("ContentType")
    End Function

    '<Desc>확장자 검사 : 전역 블랙리스트(UPLOAD_DENY_EXT) 우선, 그다음 화이트리스트</Desc>
    Public Function ChkExt(ByVal pName, ByVal pAllowList)
        Dim ext, arr, i
        ChkExt = False
        ext = LCase(FileExt(pName))
        If Len(ext) = 0 Then
            mErrMsg = "확장자가 없는 파일은 업로드할 수 없습니다."
            Exit Function
        End If

        arr = Split(UPLOAD_DENY_EXT, ",")
        For i = 0 To UBound(arr)
            If Trim(arr(i)) = ext Then
                mErrMsg = "허용되지 않는 확장자입니다. (" & ext & ")"
                Exit Function
            End If
        Next

        If StringUtil.IsBlank(pAllowList) Then
            mErrMsg = "이 게시판은 파일 첨부를 지원하지 않습니다."
            Exit Function
        End If

        arr = Split(LCase(pAllowList), ",")
        For i = 0 To UBound(arr)
            If Trim(arr(i)) = ext Then ChkExt = True : Exit Function
        Next

        mErrMsg = "허용된 확장자가 아닙니다. (" & ext & " / 허용: " & pAllowList & ")"
    End Function

    '<Desc>용량 검사. pMaxKB 단위는 KB</Desc>
    Public Function ChkSize(ByVal pName, ByVal pMaxKB)
        Dim sz, mx
        ChkSize = False
        sz = CDbl(FileSize(pName))
        mx = CDbl(pMaxKB) * 1024
        If mx <= 0 Then mx = UPLOAD_MAX_SIZE
        If sz > mx Then
            mErrMsg = "파일 용량이 " & StringUtil.SizeStr(mx) & " 를 초과했습니다. (" & StringUtil.SizeStr(sz) & ")"
            Exit Function
        End If
        ChkSize = True
    End Function

    '<Desc>물리 폴더에 저장. 성공 시 True</Desc>
    Public Function SaveAs(ByVal pName, ByVal pPhysFolder, ByVal pSaveName)
        Dim d, b, out, full, en, ed

        SaveAs = False
        If Not mFiles.Exists(pName) Then
            mErrMsg = "업로드된 파일이 없습니다. (" & pName & ")"
            Exit Function
        End If

        Set d = mFiles(pName)
        EnsureFolder pPhysFolder

        full = pPhysFolder
        If Right(full, 1) <> "\" Then full = full & "\"
        full = full & StringUtil.BaseName(pSaveName)

        mStream.Position = d("Offset")
        b = mStream.Read(d("Size"))

        Set out = Server.CreateObject("ADODB.Stream")
        out.Type = 1
        out.Open
        out.Write b

        On Error Resume Next
        out.SaveToFile full, 2                                     ' adSaveCreateOverWrite
        en = Err.Number : ed = Err.Description
        On Error GoTo 0

        out.Close
        Set out = Nothing

        If en <> 0 Then
            mErrMsg = "파일 저장에 실패했습니다. (" & ed & ")"
            Exit Function
        End If

        SaveAs = True
    End Function

    Public Sub Dispose()
        On Error Resume Next
        If IsObject(mStream) Then
            If Not (mStream Is Nothing) Then
                If mStream.State = 1 Then mStream.Close
                Set mStream = Nothing
            End If
        End If
        On Error GoTo 0
    End Sub

    '==========================================================================
    ' 내부 유틸
    '==========================================================================

    Private Function GetBoundary(ByVal ct)
        Dim p, b
        GetBoundary = ""
        p = InStr(LCase(ct), "boundary=")
        If p = 0 Then Exit Function
        b = Mid(ct, p + 9)
        p = InStr(b, ";")
        If p > 0 Then b = Left(b, p - 1)
        b = Trim(b)
        If Len(b) >= 2 Then
            If Left(b, 1) = """" And Right(b, 1) = """" Then b = Mid(b, 2, Len(b) - 2)
        End If
        If Len(b) = 0 Then Exit Function
        GetBoundary = "--" & b
    End Function

    '<Desc>바이너리 → iso-8859-1 문자열 (1바이트 = 1문자, 무손실)</Desc>
    Private Function BinToLatin1(ByVal b)
        Dim st
        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1 : st.Open
        st.Write b
        st.Position = 0
        st.Type    = 2
        st.Charset = "iso-8859-1"
        BinToLatin1 = st.ReadText
        st.Close
        Set st = Nothing
    End Function

    '<Desc>요청 본문의 지정 구간(바이트)을 UTF-8 로 디코딩</Desc>
    '------------------------------------------------------------------------------
    ' 원본 바이트에서 바로 읽는다. 문자열로 바꿔둔 data 를 거치면 안 된다.
    '   ADODB.Stream 은 Charset="iso-8859-1" 을 읽을 때는 CP1252 로,
    '   쓸 때는 진짜 ISO-8859-1 로 처리해서 왕복이 무손실이 아니다.
    '   (0x80 → U+20AC "€" 로 읽히지만, 되돌릴 때 ISO-8859-1 에 없어 "?" 가 된다)
    '   UTF-8 한글의 뒤따르는 바이트는 0x80~0xBF 라 이 구간에 정면으로 걸린다.
    '------------------------------------------------------------------------------
    Private Function ReadUtf8At(ByVal pOffset, ByVal pLen)
        Dim st, b
        ReadUtf8At = ""
        If pLen <= 0 Then Exit Function
        If pOffset < 0 Then Exit Function

        mStream.Position = pOffset
        b = mStream.Read(pLen)
        If IsNull(b) Then Exit Function

        Set st = Server.CreateObject("ADODB.Stream")
        st.Type = 1 : st.Open
        st.Write b
        st.Position = 0
        st.Type    = 2
        st.Charset = "utf-8"
        ReadUtf8At = st.ReadText
        st.Close
        Set st = Nothing
    End Function

    '<Desc>Content-Disposition 에서 name / filename 속성 추출</Desc>
    Private Function ExtractAttr(ByVal h, ByVal attr)
        Dim re, m
        ExtractAttr = ""
        Set re = New RegExp
        re.IgnoreCase = True : re.Global = False
        re.Pattern = "[;\s]" & attr & "\s*=\s*""([^""]*)"""
        Set m = re.Execute(h)
        If m.Count > 0 Then ExtractAttr = m(0).SubMatches(0)
        Set m = Nothing : Set re = Nothing
    End Function

    Private Function ExtractHeader(ByVal h, ByVal key)
        Dim lines, i, ln, p
        ExtractHeader = ""
        lines = Split(h, vbCrLf)
        For i = 0 To UBound(lines)
            ln = lines(i)
            p  = InStr(ln, ":")
            If p > 0 Then
                If LCase(Trim(Left(ln, p - 1))) = LCase(key) Then
                    ExtractHeader = Trim(Mid(ln, p + 1))
                    Exit Function
                End If
            End If
        Next
    End Function

End Class

Dim Upload
Set Upload = New CFileUpload


'##############################################################################
' 전역 : 폴더 재귀 생성
'##############################################################################
Sub EnsureFolder(ByVal pPhysPath)
    Dim fso, parent
    Set fso = Server.CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(pPhysPath) Then
        parent = fso.GetParentFolderName(pPhysPath)
        If Len(parent) > 0 Then
            If Not fso.FolderExists(parent) Then EnsureFolder parent
        End If
        On Error Resume Next
        fso.CreateFolder pPhysPath
        On Error GoTo 0
    End If
    Set fso = Nothing
End Sub

'##############################################################################
' 전역 : 파일 삭제 (실패해도 예외 없음)
'##############################################################################
Sub DeletePhysFile(ByVal pPhysPath)
    Dim fso
    On Error Resume Next
    Set fso = Server.CreateObject("Scripting.FileSystemObject")
    If fso.FileExists(pPhysPath) Then fso.DeleteFile pPhysPath, True
    Set fso = Nothing
    On Error GoTo 0
End Sub
%>
