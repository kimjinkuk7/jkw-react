<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<%
'==============================================================================
' api/Logout.asp  -  POST  로그아웃
'------------------------------------------------------------------------------
' Session.Abandon 은 "이번 요청이 끝날 때" 세션을 파기한다.
' 따라서 이 응답에 담는 csrf 토큰은 이미 쓸 수 없는 값이다.
' React 는 로그아웃 뒤 반드시 Config.asp 를 다시 호출해 새 토큰을 받아야 한다.
'==============================================================================

NeedPost
NeedCsrf

Auth.Logout

ApiBegin
    JOut.B "loggedOut", True
ApiEnd
%>
