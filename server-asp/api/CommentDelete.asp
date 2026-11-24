<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/CommentDelete.asp  -  POST  댓글 삭제
'------------------------------------------------------------------------------
' URL  : /asp/api/CommentDelete.asp?bid=free
' body : { "articleId": 123, "commentId": 45, "guestPw": "", "_csrf": "..." }
'==============================================================================

NeedPost
NeedCsrf

Dim artId, cmtId, gPw, cmtArr, cWid, cHasPw, okDel

artId = BodyInt("articleId", 0)
cmtId = BodyInt("commentId", 0)
gPw   = Left(BodyStr("guestPw", 20), 20)

If artId <= 0 Or cmtId <= 0 Then FailBadRequest "글 번호 또는 댓글 번호가 없습니다."

cmtArr = Comment.Comment_v(cmtId)
If Not IsArray(cmtArr) Then FailNotFound "이미 삭제된 댓글입니다."
If AVI(cmtArr, 0, 0) <> artId Then FailBadRequest "이 글의 댓글이 아닙니다."
If AV(cmtArr, 3, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

cWid   = AVI(cmtArr, 1, 0)
cHasPw = AVB(cmtArr, 2, 0)

okDel = False
If bdCanAdmin Then okDel = True
If Auth.MyId() > 0 And Auth.MyId() = cWid Then okDel = True

If (Not okDel) And cWid = 0 And cHasPw Then
    If StringUtil.IsBlank(gPw) Then ApiFail "403 Forbidden", "GUEST_PW_REQUIRED", "비밀번호를 입력해 주세요."
    If Comment.ChkGuestPw(cmtId, gPw) Then
        okDel = True
    Else
        ApiFail "403 Forbidden", "GUEST_PW", "비밀번호가 일치하지 않습니다."
    End If
End If

If Not okDel Then FailForbidden "삭제 권한이 없습니다."

Comment.Comment_d cmtId, artId

ApiBegin
    JOut.N "id",      cmtId
    JOut.B "deleted", True
ApiEnd
%>
