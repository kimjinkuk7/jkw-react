<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/ArticleWrite.asp  -  POST  글 등록 / 수정 / 답변
'------------------------------------------------------------------------------
' URL  : /asp/api/ArticleWrite.asp?bid=free          (bid 는 반드시 쿼리스트링)
' body : {
'          "mode": "write" | "modify" | "reply",
'          "id": 0,                 modify/reply 일 때 대상 글 번호
'          "categoryId": 0,
'          "title": "...", "content": "...", "tags": "", "linkUrl": "",
'          "isNotice": false, "isSecret": false,
'          "guestName": "", "guestPw": "",
'          "_csrf": "..."
'        }
'
' 첨부파일은 JSON 으로 보낼 수 없다. 글을 먼저 저장한 뒤
' api/FileUpload.asp 로 multipart 업로드한다.
'==============================================================================

NeedPost
NeedCsrf

Dim wMode, artId, pTitle, pContent, pCateId, pTags, pLink, pIsNotice, pIsSecret
Dim gName, gPw, myId, writerNm, writerPwHash, newId, oldArr, oWid, oHasPw, okMod

wMode = LCase(BodyStr("mode", 10))
If wMode <> "modify" And wMode <> "reply" Then wMode = "write"

artId     = BodyInt("id", 0)
pTitle    = Left(BodyStr("title", 200), 200)
pContent  = BodyRaw("content", 0)
pCateId   = BodyInt("categoryId", 0)
pTags     = Left(BodyStr("tags", 300), 300)
pLink     = Left(BodyStr("linkUrl", 300), 300)
pIsNotice = BodyBool("isNotice")
pIsSecret = BodyBool("isSecret")
gName     = Left(BodyStr("guestName", 20), 20)
gPw       = Left(BodyStr("guestPw", 20), 20)

'--- 권한 ---
If Not bdCanWrite Then FailForbidden "글쓰기 권한이 없습니다."
If pIsNotice And Not bdCanAdmin Then pIsNotice = False
If Not bdUseSecret Then pIsSecret = False
If wMode = "reply" And Not bdUseReply Then FailBadRequest "이 게시판은 답변 기능을 사용하지 않습니다."

'--- 방명록은 제목 고정 ---
If bdSkin = "guest" Then pTitle = "방명록"

'--- 유효성 ---
If StringUtil.IsBlank(pTitle)   Then FailBadRequest "제목을 입력해 주세요."
If StringUtil.IsBlank(pContent) Then FailBadRequest "내용을 입력해 주세요."

If pCateId > 0 Then
    If Not Board.IsValidCategory(bdId, pCateId) Then pCateId = 0
End If

'--- 비회원 처리 ---
myId = Auth.MyId()
If myId > 0 Then
    writerNm     = Auth.DisplayName()
    writerPwHash = Null
Else
    If StringUtil.IsBlank(gName) Then FailBadRequest "작성자 이름을 입력해 주세요."
    writerNm = gName
    If wMode = "modify" Then
        ' 비워두면 기존 비밀번호를 유지한다
        If StringUtil.IsBlank(gPw) Then
            writerPwHash = Null
        Else
            writerPwHash = Crypt.HashGuestPw(gPw)
        End If
    Else
        If Len(gPw) < 4 Then FailBadRequest "비밀번호를 4자 이상 입력해 주세요."
        writerPwHash = Crypt.HashGuestPw(gPw)
    End If
End If

'--- 본문 정화 ---
pContent = StringUtil.SafeHtml(pContent)

'==============================================================================
' 저장
'==============================================================================
Select Case wMode

    Case "modify"
        If artId <= 0 Then FailBadRequest "수정할 글 번호가 없습니다."
        oldArr = Article.Article_v(artId)
        If Not IsArray(oldArr) Then FailNotFound "삭제되었거나 존재하지 않는 게시물입니다."
        If AV(oldArr, AVW_BID, 0) <> bdId Then FailBadRequest "게시판이 일치하지 않습니다."

        oWid   = AVI(oldArr, AVW_WID, 0)
        oHasPw = AVB(oldArr, AVW_HASPW, 0)
        okMod  = False
        If bdCanAdmin Then okMod = True
        If myId > 0 And myId = oWid Then okMod = True

        ' 비회원 글 : 세션 인증(PWOK) 또는 이번 요청의 guestPw 로 확인한다.
        If (Not okMod) And oWid = 0 And oHasPw Then
            If Session("PWOK_" & bdId & "_" & artId) & "" = "1" Then
                okMod = True
            ElseIf Len(gPw) > 0 Then
                If Article.ChkGuestPw(artId, gPw) Then
                    okMod = True
                    Session("PWOK_" & bdId & "_" & artId) = "1"
                    ' 기존 비밀번호로 본인 확인만 한 것이므로 해시를 갈아끼우지 않는다
                    writerPwHash = Null
                Else
                    ApiFail "403 Forbidden", "GUEST_PW", "비밀번호가 일치하지 않습니다."
                End If
            End If
        End If

        If Not okMod Then FailForbidden "수정 권한이 없습니다."

        Article.Article_u artId, pCateId, pTitle, pContent, pTags, _
                          AV(oldArr, AVW_THUMB, 0), pLink, pIsNotice, pIsSecret

        If myId = 0 And Not IsNull(writerPwHash) Then UpdateGuestPw artId, writerPwHash

        newId = artId

    Case "reply"
        If artId <= 0 Then FailBadRequest "답변 대상 글 번호가 없습니다."
        newId = Article.Reply_i(bdId, artId, pTitle, pContent, myId, writerNm, writerPwHash, Null)
        If newId <= 0 Then ApiFail "500 Internal Server Error", "SAVE_FAILED", "답변 등록에 실패했습니다."

    Case Else
        newId = Article.Article_i(bdId, pCateId, pTitle, pContent, myId, writerNm, writerPwHash, _
                                  Null, pTags, "", pLink, pIsNotice, pIsSecret)
        If newId <= 0 Then ApiFail "500 Internal Server Error", "SAVE_FAILED", "등록에 실패했습니다."

End Select

' 비회원이 방금 쓴 글은 바로 수정/삭제할 수 있게 인증 세션을 열어둔다
If myId = 0 And wMode <> "modify" Then Session("PWOK_" & bdId & "_" & newId) = "1"

ApiBegin
    JOut.N "id",      newId
    JOut.S "boardId", bdId
    JOut.S "mode",    wMode
ApiEnd


'##############################################################################
' 내부
'##############################################################################

'<Desc>비회원 글 비밀번호 갱신 (code/board/Write_p.Code.asp 와 동일)</Desc>
Sub UpdateGuestPw(ByVal pArticleId, ByVal pHash)
    Dim h
    Set h = New CDBHelper
    h.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    With h
        .Sql = "UPDATE tb_board_article SET writer_pw = ? WHERE article_id = ?"
        .SetParamVarchar(pHash)
        .SetParamBigInt(pArticleId)
    End With
    h.Execute()
    Set h = Nothing
End Sub
%>
