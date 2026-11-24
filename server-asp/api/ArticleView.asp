<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/ArticleView.asp  -  GET  게시글 상세 (본문 + 첨부 + 댓글)
'------------------------------------------------------------------------------
' ?bid=free&id=123
'==============================================================================

If Not bdCanRead Then FailForbidden "글을 읽을 권한이 없습니다."

Dim artId, artArr, artWriterId, artIsSecret, artHasPw, artContent, artHit
Dim fileArr, fileCnt, cmtArr, cmtCnt, prevArr, nextArr, i
Dim hitKey, hitLog

artId = QsInt("id", 0)
If artId <= 0 Then FailBadRequest "id 파라미터가 필요합니다."

artArr = Article.Article_v(artId)
If Not IsArray(artArr) Then FailNotFound "삭제되었거나 존재하지 않는 게시물입니다."

' 다른 게시판 글을 이 게시판으로 여는 것을 막는다
If AV(artArr, AVW_BID, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

artWriterId = AVI(artArr, AVW_WID, 0)
artIsSecret = AVB(artArr, AVW_SECRET, 0)
artHasPw    = AVB(artArr, AVW_HASPW, 0)
artContent  = AV(artArr,  AVW_CONTENT, 0)
artHit      = AVI(artArr, AVW_HIT, 0)

'--- 비밀글 접근 통제 (화면 계층과 같은 세션 키를 쓴다) -----------------------
If artIsSecret Then
    If Not (bdCanAdmin _
            Or (Auth.MyId() > 0 And Auth.MyId() = artWriterId) _
            Or (Session("PWOK_" & bdId & "_" & artId) & "" = "1")) Then
        ApiFail "403 Forbidden", "SECRET_LOCKED", "비밀글입니다. 작성자 또는 관리자만 볼 수 있습니다."
    End If
End If

'--- 조회수 증가 (같은 세션 중복 제외) ---
hitKey = "|" & bdId & ":" & artId & "|"
hitLog = Session("HITLOG") & ""
If InStr(hitLog, hitKey) = 0 Then
    Article.HitUp artId
    artHit = artHit + 1
    If Len(hitLog) > 3000 Then hitLog = ""
    Session("HITLOG") = hitLog & hitKey
End If

fileCnt = 0
If bdUseFile Then
    fileArr = BoardFile.File_l(artId)
    fileCnt = RowCnt(fileArr)
End If

cmtCnt = 0
If bdUseComment Then
    cmtArr = Comment.Comment_l(artId)
    cmtCnt = RowCnt(cmtArr)
End If

prevArr = Article.Sibling_v(bdId, artId, "prev")
nextArr = Article.Sibling_v(bdId, artId, "next")

ApiBegin

    WriteBoard "board", bdArr

    JOut.ObjOpen "article"
        JOut.N "id",           AVI(artArr, AVW_ID, 0)
        JOut.S "boardId",      AV(artArr,  AVW_BID, 0)
        JOut.N "categoryId",   AVI(artArr, AVW_CID, 0)
        JOut.S "categoryName", AV(artArr,  AVW_CNAME, 0)
        JOut.S "title",        AV(artArr,  AVW_TITLE, 0)
        ' 관리자/회원이 입력한 HTML 이다. 화면 계층과 동일하게 SafeHtml 로 거른다.
        JOut.S "contentHtml",  StringUtil.SafeHtml(artContent)
        JOut.N "writerId",     artWriterId
        JOut.S "writerName",   AV(artArr,  AVW_WNAME, 0)
        JOut.N "hitCount",     artHit
        JOut.N "commentCount", AVI(artArr, AVW_CMT, 0)
        JOut.N "fileCount",    AVI(artArr, AVW_FILE, 0)
        JOut.N "likeCount",    AVI(artArr, AVW_LIKE, 0)
        JOut.B "isNotice",     AVB(artArr, AVW_NOTICE, 0)
        JOut.B "isSecret",     artIsSecret
        JOut.D "regDt",        AV(artArr,  AVW_REGDT, 0)
        JOut.D "updDt",        AV(artArr,  AVW_UPDDT, 0)
        JOut.S "tags",         AV(artArr,  AVW_TAGS, 0)
        JOut.S "thumb",        UpUrl(AV(artArr,  AVW_THUMB, 0))
        JOut.S "linkUrl",      AV(artArr,  AVW_LINK, 0)
        JOut.N "depth",        AVI(artArr, AVW_GDEPTH, 0)
    JOut.ObjClose

    JOut.ObjOpen "perm"
        JOut.B "edit",    ApiCanEdit(artWriterId, artHasPw)
        JOut.B "reply",   (bdUseReply And bdCanWrite)
        JOut.B "comment", bdCanComment
        JOut.B "guestPw", (artWriterId = 0 And artHasPw)
    JOut.ObjClose

    JOut.ArrOpen "files"
    For i = 0 To fileCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",       AVI(fileArr, BF_ID, i)
            JOut.S "name",     AV(fileArr,  BF_ORGNAME, i)
            JOut.N "size",     AVI(fileArr, BF_SIZE, i)
            JOut.S "sizeText", StringUtil.SizeStr(AVI(fileArr, BF_SIZE, i))
            JOut.S "ext",      AV(fileArr,  BF_EXT, i)
            JOut.B "isImage",  AVB(fileArr, BF_ISIMAGE, i)
            JOut.N "downCount",AVI(fileArr, BF_DOWNCNT, i)
            ' 다운로드는 ASP 화면 계층의 Download.asp 를 그대로 쓴다 (권한/카운트 동일)
            JOut.S "downUrl",  APP_ROOT & "/api/Download.asp?fid=" & AVI(fileArr, BF_ID, i)
            JOut.S "imageUrl", UpUrl(AV(fileArr, BF_SAVEPATH, i)) & "/" & AV(fileArr, BF_SAVENAME, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

    JOut.ArrOpen "comments"
    For i = 0 To cmtCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",         AVI(cmtArr, CMT_ID, i)
            JOut.N "parentId",   AVI(cmtArr, CMT_PARENT, i)
            JOut.N "depth",      AVI(cmtArr, CMT_DEPTH, i)
            JOut.S "content",    AV(cmtArr,  CMT_CONTENT, i)
            JOut.N "writerId",   AVI(cmtArr, CMT_WID, i)
            JOut.S "writerName", AV(cmtArr,  CMT_WNAME, i)
            JOut.B "isSecret",   AVB(cmtArr, CMT_SECRET, i)
            JOut.D "regDt",      AV(cmtArr,  CMT_REGDT, i)
            JOut.S "regDate",    DateUtil.TimeAgo(AV(cmtArr, CMT_REGDT, i))
            JOut.B "canEdit",    ApiCanEdit(AVI(cmtArr, CMT_WID, i), AVB(cmtArr, CMT_HASPW, i))
        JOut.ObjClose
    Next
    JOut.ArrClose

    If IsArray(prevArr) Then
        JOut.ObjOpen "prev"
            JOut.N "id",    AVI(prevArr, 0, 0)
            JOut.S "title", AV(prevArr,  1, 0)
        JOut.ObjClose
    Else
        JOut.Nul "prev"
    End If

    If IsArray(nextArr) Then
        JOut.ObjOpen "next"
            JOut.N "id",    AVI(nextArr, 0, 0)
            JOut.S "title", AV(nextArr,  1, 0)
        JOut.ObjClose
    Else
        JOut.Nul "next"
    End If

ApiEnd
%>
