<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/FileDelete.asp  -  POST  게시글 첨부 삭제 (DB + 물리 파일)
'------------------------------------------------------------------------------
' URL  : /asp/api/FileDelete.asp?bid=free
' body : { "fileId": 12, "_csrf": "..." }
'==============================================================================

NeedPost
NeedCsrf

Dim fileId, fArr, artId, artArr

fileId = BodyInt("fileId", 0)
If fileId <= 0 Then FailBadRequest "fileId 가 필요합니다."

fArr = BoardFile.File_v(fileId)
If Not IsArray(fArr) Then FailNotFound "이미 삭제되었거나 존재하지 않는 첨부입니다."

' File_v 결과 : 8=board_id, 9=article_id
If AV(fArr, 8, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."
artId = AVI(fArr, 9, 0)

artArr = Article.Article_v(artId)
If Not IsArray(artArr) Then FailNotFound "원 글이 존재하지 않습니다."
If Not ApiCanEdit(AVI(artArr, AVW_WID, 0), AVB(artArr, AVW_HASPW, 0)) Then
    FailForbidden "이 글의 첨부를 삭제할 권한이 없습니다."
End If

BoardFile.File_d fileId

'--- 갤러리 / 블로그 : 대표 썸네일 재계산 ---
If bdSkin = "gallery" Or bdSkin = "blog" Then
    Article.Thumb_u artId, BoardFile.FirstImage_v(artId)
End If

ApiBegin
    JOut.N "fileId",  fileId
    JOut.B "deleted", True
ApiEnd
%>
