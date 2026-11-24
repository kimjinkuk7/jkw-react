<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/ArticleDelete.asp  -  POST  게시글 삭제 (논리 삭제)
'------------------------------------------------------------------------------
' URL  : /asp/api/ArticleDelete.asp?bid=free
' body : { "id": 123, "guestPw": "", "_csrf": "..." }
'==============================================================================

NeedPost
NeedCsrf

Dim artId, gPw, artArr, aWid, aHasPw, okDel

artId = BodyInt("id", 0)
gPw   = Left(BodyStr("guestPw", 20), 20)

If artId <= 0 Then FailBadRequest "삭제할 글 번호가 없습니다."

artArr = Article.Article_v(artId)
If Not IsArray(artArr) Then FailNotFound "이미 삭제되었거나 존재하지 않는 게시물입니다."
If AV(artArr, AVW_BID, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

aWid   = AVI(artArr, AVW_WID, 0)
aHasPw = AVB(artArr, AVW_HASPW, 0)

okDel = False
If bdCanAdmin Then okDel = True
If Auth.MyId() > 0 And Auth.MyId() = aWid Then okDel = True

If (Not okDel) And aWid = 0 And aHasPw Then
    If Session("PWOK_" & bdId & "_" & artId) & "" = "1" Then
        okDel = True
    ElseIf Len(gPw) > 0 Then
        If Article.ChkGuestPw(artId, gPw) Then
            okDel = True
        Else
            ApiFail "403 Forbidden", "GUEST_PW", "비밀번호가 일치하지 않습니다."
        End If
    End If
End If

If Not okDel Then FailForbidden "삭제 권한이 없습니다."

Article.Article_d artId
Session("PWOK_" & bdId & "_" & artId) = ""

ApiBegin
    JOut.N "id",      artId
    JOut.S "boardId", bdId
    JOut.B "deleted", True
ApiEnd
%>
