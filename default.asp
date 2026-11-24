<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<%
'==============================================================================
' default.asp  -  React 스택 진입 스텁
'------------------------------------------------------------------------------
' 이 폴더에는 소스(src, public, package.json), 동봉 백엔드(server-asp),
' 업로드 폴더(upload), 그리고 빌드 산출물(dist)이 함께 있다.
' 브라우저에 보여줄 것은 dist 뿐이므로 그쪽으로 보낸다.
'
' ★ 배포 위치를 바꾸면 아래 SPA_PATH 도 바꾼다.
'   react 폴더가 사이트 루트면 "/dist/" , 사이트 루트 아래 react 면 "/react/dist/"
'   (server-asp/App.Conf.asp 의 SPA_ROOT 와 같은 값이어야 한다)
'==============================================================================
Const SPA_PATH = "/react/dist/"

Response.Status = "302 Found"
Response.AddHeader "Location", SPA_PATH
Response.End
%>
