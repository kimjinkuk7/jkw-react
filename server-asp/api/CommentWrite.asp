<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/CommentWrite.asp  -  POST  댓글 등록
'------------------------------------------------------------------------------
' URL  : /asp/api/CommentWrite.asp?bid=free
' body : { "articleId": 123, "parentId": 0, "content": "...",
'          "guestName": "", "guestPw": "", "_csrf": "..." }
'==============================================================================

NeedPost
NeedCsrf

Dim artId, parentId, cContent, gName, gPw, artArr, pArr, myId, nameFinal, pwHash, newId

artId    = BodyInt("articleId", 0)
parentId = BodyInt("parentId", 0)
cContent = Left(BodyRaw("content", 1000), 1000)
gName    = Left(BodyStr("guestName", 20), 20)
gPw      = Left(BodyStr("guestPw", 20), 20)

If artId <= 0 Then FailBadRequest "글 번호가 없습니다."
If Not bdUseComment Then FailBadRequest "이 게시판은 댓글을 사용하지 않습니다."
If Not bdCanComment Then FailForbidden "댓글 작성 권한이 없습니다."
If StringUtil.IsBlank(cContent) Then FailBadRequest "댓글 내용을 입력해 주세요."

artArr = Article.Article_v(artId)
If Not IsArray(artArr) Then FailNotFound "삭제되었거나 존재하지 않는 게시물입니다."
If AV(artArr, AVW_BID, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

'--- 대댓글 대상이 이 글의 댓글인지 확인 ---
If parentId > 0 Then
    pArr = Comment.Comment_v(parentId)
    If Not IsArray(pArr) Then FailNotFound "원 댓글을 찾을 수 없습니다."
    If AVI(pArr, 0, 0) <> artId Then FailBadRequest "원 댓글이 이 글의 댓글이 아닙니다."
End If

myId = Auth.MyId()
If myId > 0 Then
    nameFinal = Auth.DisplayName()
    pwHash    = Null
Else
    If StringUtil.IsBlank(gName) Then FailBadRequest "이름을 입력해 주세요."
    If Len(gPw) < 4 Then FailBadRequest "비밀번호를 4자 이상 입력해 주세요."
    nameFinal = gName
    pwHash    = Crypt.HashGuestPw(gPw)
End If

newId = Comment.Comment_i(artId, bdId, parentId, cContent, myId, nameFinal, pwHash, False)
If newId <= 0 Then ApiFail "500 Internal Server Error", "SAVE_FAILED", "댓글 등록에 실패했습니다."

ApiBegin
    JOut.N "id",        newId
    JOut.N "articleId", artId
ApiEnd
%>
