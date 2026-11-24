<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<!--#include file="../lib/FileUpload.Class.asp"-->
<%
'==============================================================================
' api/FileUpload.asp  -  POST(multipart)  게시글 첨부 업로드
'------------------------------------------------------------------------------
' JSON 으로는 파일을 보낼 수 없다. React 는 글을 먼저 저장(ArticleWrite.asp)한 뒤
' 이 엔드포인트로 FormData 를 보낸다.
'
' URL   : /asp/api/FileUpload.asp?bid=free&id=123&_csrf=...
'         ★ 모든 파라미터가 쿼리스트링이다.
'           multipart 본문은 Upload.Load() 가 BinaryRead 로 읽으므로,
'           그 전에 Request.Form 을 건드리면 업로드가 통째로 실패한다.
' body  : multipart/form-data,  파일 필드 이름 = upfile1 ~ upfileN
'==============================================================================

NeedPost

' CSRF 는 쿼리스트링 또는 헤더로 받는다 (본문을 읽을 수 없으므로)
Dim csrfQs
csrfQs = Trim(Request.ServerVariables("HTTP_X_CSRF_TOKEN") & "")
If Len(csrfQs) = 0 Then csrfQs = QsVal("_csrf")
If Len(Auth.Token()) = 0 Or csrfQs <> Auth.Token() Then
    ApiFail "403 Forbidden", "CSRF", "보안 토큰이 일치하지 않습니다. 새로고침 후 다시 시도해 주세요."
End If

If Not RequestUtil.IsMultipart() Then FailBadRequest "multipart/form-data 요청이 아닙니다."

Dim artId, artArr, aWid, aHasPw, bdFileCnt, bdFileSize, bdFileExt
artId = QsInt("id", 0)
If artId <= 0 Then FailBadRequest "id 파라미터가 필요합니다."

If Not bdUseFile Then FailBadRequest "이 게시판은 첨부파일을 사용하지 않습니다."

bdFileCnt  = AVI(bdArr, BM_FILE_CNT, 0)
bdFileSize = AVI(bdArr, BM_FILE_SIZE, 0)
bdFileExt  = AV(bdArr,  BM_FILE_EXT, 0)
If bdFileCnt <= 0 Then FailBadRequest "이 게시판은 첨부파일을 사용하지 않습니다."

artArr = Article.Article_v(artId)
If Not IsArray(artArr) Then FailNotFound "삭제되었거나 존재하지 않는 게시물입니다."
If AV(artArr, AVW_BID, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

aWid   = AVI(artArr, AVW_WID, 0)
aHasPw = AVB(artArr, AVW_HASPW, 0)
If Not ApiCanEdit(aWid, aHasPw) Then FailForbidden "이 글에 첨부할 권한이 없습니다."

'--- 본문 파싱 ---
If Not Upload.Load() Then FailBadRequest Upload.ErrMsg

Dim urlPath, physFolder, curCnt, ui, fld, ext, saveNm, savedCnt, fid
urlPath    = BoardUploadPath()
physFolder = Server.MapPath(urlPath)
curCnt     = BoardFile.File_c(artId)
savedCnt   = 0

ApiBegin
    JOut.ArrOpen "files"

    For ui = 1 To bdFileCnt
        fld = "upfile" & ui
        If Upload.HasFile(fld) Then
            If curCnt >= bdFileCnt Then Exit For

            If Not Upload.ChkExt(fld, bdFileExt)   Then Upload.Dispose : FailBadRequest Upload.ErrMsg
            If Not Upload.ChkSize(fld, bdFileSize) Then Upload.Dispose : FailBadRequest Upload.ErrMsg

            ext    = Upload.FileExt(fld)
            saveNm = StringUtil.NewKey() & "." & ext

            If Not Upload.SaveAs(fld, physFolder, saveNm) Then
                Upload.Dispose
                ApiFail "500 Internal Server Error", "SAVE_FAILED", Upload.ErrMsg
            End If

            fid = BoardFile.File_i(artId, bdId, Upload.FileName(fld), saveNm, urlPath, _
                                   Upload.FileSize(fld), ext, curCnt)
            curCnt   = curCnt + 1
            savedCnt = savedCnt + 1

            JOut.ObjOpen ""
                JOut.N "id",       fid
                JOut.S "name",     Upload.FileName(fld)
                JOut.N "size",     Upload.FileSize(fld)
                JOut.S "sizeText", StringUtil.SizeStr(Upload.FileSize(fld))
                JOut.S "ext",      ext
                JOut.B "isImage",  StringUtil.IsImageExt(ext)
                JOut.S "downUrl",  APP_ROOT & "/api/Download.asp?fid=" & fid
                JOut.S "imageUrl", urlPath & "/" & saveNm
            JOut.ObjClose
        End If
    Next

    JOut.ArrClose

    '--- 갤러리 / 블로그 : 첫 이미지를 대표 썸네일로 ---
    If bdSkin = "gallery" Or bdSkin = "blog" Then
        Article.Thumb_u artId, BoardFile.FirstImage_v(artId)
    End If

    Upload.Dispose

    JOut.N "savedCount", savedCnt
    JOut.N "totalCount", curCnt
ApiEnd
%>
