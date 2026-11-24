<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/portfolio/Portfolio.Class.asp"-->
<%
'==============================================================================
' api/PortfolioList.asp  -  GET  포트폴리오 목록
'------------------------------------------------------------------------------
' ?category=WEB&page=1&size=9
'==============================================================================

Dim cate, page, size, total, offset, arr, cnt, catArr, catCnt, i

cate = Left(QsVal("category"), 30)
page = QsInt("page", 1)
size = QsInt("size", 9)
If page < 1 Then page = 1
If size < 1 Or size > 50 Then size = 9

total  = Portfolio.Portfolio_c(cate)
offset = (page - 1) * size

arr    = Portfolio.Portfolio_l(cate, offset, size) : cnt    = RowCnt(arr)
catArr = Portfolio.Category_l()                    : catCnt = RowCnt(catArr)

ApiBegin

    JOut.S "category", cate

    JOut.ArrOpen "items"
    For i = 0 To cnt - 1
        WritePortfolioRow arr, i
    Next
    JOut.ArrClose

    JOut.ArrOpen "categories"
    For i = 0 To catCnt - 1
        JOut.ObjOpen ""
            JOut.S "name",  AV(catArr, 0, i)
            JOut.N "count", AVI(catArr, 1, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

    WritePaging "paging", page, size, total

ApiEnd
%>
