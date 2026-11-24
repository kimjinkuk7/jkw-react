<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/portfolio/Portfolio.Class.asp"-->
<%
'==============================================================================
' api/PortfolioView.asp  -  GET  포트폴리오 상세
'------------------------------------------------------------------------------
' ?id=12
'==============================================================================

Dim pfId, arr, skArr, skCnt, prevArr, nextArr, i

pfId = QsInt("id", 0)
If pfId <= 0 Then FailBadRequest "id 파라미터가 필요합니다."

arr = Portfolio.Portfolio_v(pfId)
If Not IsArray(arr) Then FailNotFound "존재하지 않거나 공개되지 않은 프로젝트입니다."

' 조회수는 화면 계층(view/portfolio/View.asp)과 같은 규칙으로 올린다.
' 같은 세션에서 반복 호출해도 1회만 올린다.
If Session("JKW_PF_HIT_" & pfId) <> "1" Then
    Portfolio.HitUp pfId
    Session("JKW_PF_HIT_" & pfId) = "1"
End If

skArr   = Portfolio.Skill_l(pfId) : skCnt = RowCnt(skArr)
prevArr = Portfolio.Sibling_v(pfId, "prev")
nextArr = Portfolio.Sibling_v(pfId, "next")

ApiBegin

    JOut.ObjOpen "item"
        JOut.N "id",       AVI(arr, PF_ID, 0)
        JOut.S "title",    AV(arr,  PF_TITLE, 0)
        JOut.S "subtitle", AV(arr,  PF_SUBTITLE, 0)
        JOut.S "summary",  AV(arr,  PF_SUMMARY, 0)
        JOut.S "category", AV(arr,  PF_CATEGORY, 0)
        JOut.S "client",   AV(arr,  PF_CLIENT, 0)
        JOut.S "role",     AV(arr,  PF_ROLE, 0)
        JOut.S "teamSize", AV(arr,  PFV_TEAM, 0)
        JOut.DOnly "periodStart", AV(arr, PF_START, 0)
        JOut.DOnly "periodEnd",   AV(arr, PF_END, 0)
        JOut.B "isOngoing", AVB(arr, PF_ONGOING, 0)
        JOut.S "period",    DateUtil.Period(AV(arr, PF_START, 0), AV(arr, PF_END, 0), AVB(arr, PF_ONGOING, 0))
        JOut.S "siteUrl",  AV(arr,  PF_SITEURL, 0)
        JOut.S "repoUrl",  AV(arr,  PF_REPOURL, 0)
        JOut.S "thumb",    UpUrl(AV(arr,  PF_THUMB, 0))
        JOut.N "hitCount", AVI(arr, PF_HIT, 0)
        ' content 는 관리자가 입력한 HTML 이다.
        ' 화면 계층과 동일하게 SafeHtml 로 스크립트/이벤트 속성을 제거해서 내보낸다.
        JOut.S "contentHtml", StringUtil.SafeHtml(AV(arr, PFV_CONTENT, 0))
    JOut.ObjClose

    JOut.ArrOpen "skills"
    For i = 0 To skCnt - 1
        JOut.ObjOpen ""
            JOut.S "name",  AV(skArr, 0, i)
            JOut.S "color", AV(skArr, 1, i)
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
