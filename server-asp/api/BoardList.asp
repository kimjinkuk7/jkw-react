<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/ApiBoard.Code.asp"-->
<%
'==============================================================================
' api/BoardList.asp  -  GET  게시판 목록
'------------------------------------------------------------------------------
' ?bid=free&page=1&cid=0&sf=all&sw=검색어
'==============================================================================

If Not bdCanList Then FailForbidden "목록을 볼 권한이 없습니다."

Dim page, cateId, sf, sw, total, offset
Dim listArr, listCnt, noticeArr, noticeCnt, catArr, catCnt, tagArr, tagCnt, i

page   = QsInt("page", 1)
cateId = QsInt("cid", 0)
sf     = QsWhite("sf", "all,title,content,writer,tags", "all")
sw     = Left(QsVal("sw"), 50)

If page < 1 Then page = 1
If cateId > 0 Then
    If Not Board.IsValidCategory(bdId, cateId) Then cateId = 0
End If

total   = Article.Article_c(bdId, cateId, sf, sw)
offset  = (page - 1) * bdListCount
listArr = Article.Article_l(bdId, cateId, sf, sw, offset, bdListCount)
listCnt = RowCnt(listArr)

'--- 공지 (1페이지 & 검색 없을 때만) ---
noticeCnt = 0
If bdUseNotice And page = 1 And StringUtil.IsBlank(sw) And cateId = 0 Then
    noticeArr = Article.Notice_l(bdId)
    noticeCnt = RowCnt(noticeArr)
End If

'--- 분류 ---
catCnt = 0
If bdUseCategory Then
    catArr = Board.Category_l(bdId)
    catCnt = RowCnt(catArr)
End If

'--- 태그 클라우드 (블로그 스킨) ---
tagCnt = 0
If bdSkin = "blog" Then
    tagArr = Article.TagCloud_l(bdId, 20)
    tagCnt = RowCnt(tagArr)
End If

ApiBegin

    WriteBoard "board", bdArr

    JOut.ObjOpen "query"
        JOut.N "page",       page
        JOut.N "categoryId", cateId
        JOut.S "searchField",sf
        JOut.S "searchWord", sw
    JOut.ObjClose

    JOut.ArrOpen "notices"
    For i = 0 To noticeCnt - 1
        WriteArticleRow noticeArr, i
    Next
    JOut.ArrClose

    JOut.ArrOpen "items"
    For i = 0 To listCnt - 1
        WriteArticleRow listArr, i
    Next
    JOut.ArrClose

    JOut.ArrOpen "categories"
    For i = 0 To catCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",   AVI(catArr, CAT_ID, i)
            JOut.S "name", AV(catArr,  CAT_NAME, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

    JOut.ArrOpen "tags"
    For i = 0 To tagCnt - 1
        JOut.ObjOpen ""
            JOut.S "name",  AV(tagArr, 0, i)
            JOut.N "count", AVI(tagArr, 1, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

    WritePaging "paging", page, bdListCount, total

ApiEnd
%>
