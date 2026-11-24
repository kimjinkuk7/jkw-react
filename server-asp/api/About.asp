<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/about/About.Class.asp"-->
<%
'==============================================================================
' api/About.asp  -  GET  소개 (경력 + 기술스택)
'------------------------------------------------------------------------------
' ?type=work|edu|award|cert   생략하면 전체
' ?group=Language|...         생략하면 전체
'==============================================================================

Dim crArr, crCnt, skArr, skCnt, grArr, grCnt, i

crArr = About.Career_l(QsVal("type")) : crCnt = RowCnt(crArr)
skArr = About.Skill_l(QsVal("group")) : skCnt = RowCnt(skArr)
grArr = About.SkillGroup_l()       : grCnt = RowCnt(grArr)

ApiBegin

    JOut.S "totalYears", CStr(About.TotalYears())

    JOut.ArrOpen "careers"
    For i = 0 To crCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",        AVI(crArr, CR_ID, i)
            JOut.S "type",      AV(crArr,  CR_TYPE, i)
            JOut.S "title",     AV(crArr,  CR_TITLE, i)
            JOut.S "position",  AV(crArr,  CR_POSITION, i)
            JOut.S "orgUrl",    AV(crArr,  CR_ORGURL, i)
            JOut.S "careerDesc",AV(crArr,  CR_DESC, i)
            JOut.DOnly "dateStart", AV(crArr, CR_START, i)
            JOut.DOnly "dateEnd",   AV(crArr, CR_END, i)
            JOut.B "isCurrent", AVB(crArr, CR_CURRENT, i)
            JOut.S "period",    DateUtil.Period(AV(crArr, CR_START, i), AV(crArr, CR_END, i), AVB(crArr, CR_CURRENT, i))
        JOut.ObjClose
    Next
    JOut.ArrClose

    JOut.ArrOpen "skills"
    For i = 0 To skCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",        AVI(skArr, SK_ID, i)
            JOut.S "group",     AV(skArr,  SK_GROUP, i)
            JOut.S "name",      AV(skArr,  SK_NAME, i)
            JOut.N "levelPct",  AVI(skArr, SK_LEVEL, i)
            JOut.N "expYear",   AVI(skArr, SK_EXP, i)
            JOut.S "skillDesc", AV(skArr,  SK_DESC, i)
            JOut.S "color",     AV(skArr,  SK_COLOR, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

    JOut.ArrOpen "skillGroups"
    For i = 0 To grCnt - 1
        JOut.ObjOpen ""
            JOut.S "name",  AV(grArr, 0, i)
            JOut.N "count", AVI(grArr, 1, i)
        JOut.ObjClose
    Next
    JOut.ArrClose

ApiEnd
%>
