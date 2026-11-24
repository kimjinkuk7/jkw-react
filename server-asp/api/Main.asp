<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/board/Article.Class.asp"-->
<!--#include file="../model/portfolio/Portfolio.Class.asp"-->
<!--#include file="../model/about/About.Class.asp"-->
<%
'==============================================================================
' api/Main.asp  -  GET  메인 화면 데이터
'------------------------------------------------------------------------------
' code/main/Default.Code.asp 와 같은 데이터를 JSON 으로 내려준다.
'==============================================================================

Dim mainPfArr, mainPfCnt, blogArr, blogCnt, noticeArr, noticeCnt
Dim skillArr, skillCnt, vcArr, statVisit, i

mainPfArr = Portfolio.Main_l(3)         : mainPfCnt = RowCnt(mainPfArr)
blogArr   = Article.Recent_l("blog", 5) : blogCnt   = RowCnt(blogArr)
noticeArr = Article.Recent_l("notice", 5) : noticeCnt = RowCnt(noticeArr)
skillArr  = About.Skill_l("Language")   : skillCnt  = RowCnt(skillArr)

vcArr = Visit.Counter_v()
If IsArray(vcArr) Then statVisit = AVI(vcArr, 1, 0) Else statVisit = 0

ApiBegin

    JOut.ObjOpen "hero"
        JOut.S "headline", Config.ValueInit("hero_headline", GLB_SITE_TITLE)
        JOut.S "sub",      Config.ValueInit("hero_sub", GLB_SITE_DESC)
    JOut.ObjClose

    JOut.ArrOpen "skills"
    For i = 0 To skillCnt - 1
        If i >= 7 Then Exit For
        JOut.S "", AV(skillArr, SK_NAME, i)
    Next
    JOut.ArrClose

    JOut.ObjOpen "stats"
        JOut.S "years",    CStr(About.TotalYears())
        JOut.N "projects", Portfolio.Portfolio_c("")
        JOut.N "posts",    Article.Article_c("blog", 0, "", "")
        JOut.N "visits",   statVisit
    JOut.ObjClose

    JOut.ArrOpen "portfolios"
    For i = 0 To mainPfCnt - 1
        WritePortfolioRow mainPfArr, i
    Next
    JOut.ArrClose

    JOut.ArrOpen "blog"
    For i = 0 To blogCnt - 1
        WriteArticleRow blogArr, i
    Next
    JOut.ArrClose

    JOut.ArrOpen "notice"
    For i = 0 To noticeCnt - 1
        WriteArticleRow noticeArr, i
    Next
    JOut.ArrClose

ApiEnd
%>
