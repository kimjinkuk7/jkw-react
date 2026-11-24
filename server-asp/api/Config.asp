<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/board/Board.Class.asp"-->
<%
'==============================================================================
' api/Config.asp  -  GET  부트스트랩
'------------------------------------------------------------------------------
' React 앱이 기동 직후 딱 한 번 호출한다. 로그인/로그아웃 후에도 다시 호출한다.
' 사이트 설정 · GNB 메뉴 · 게시판 목록 · 내 세션 · CSRF 토큰을 한 번에 내려준다.
'==============================================================================

Dim menuArr, menuCnt, mi
Dim bdListArr, bdListCnt, bi

menuArr   = Menu.Menu_l(Auth.MyLevel())
menuCnt   = RowCnt(menuArr)

bdListArr = Board.Board_l(False)
bdListCnt = RowCnt(bdListArr)

ApiBegin

    JOut.ObjOpen "site"
        JOut.S "title",     GLB_SITE_TITLE
        JOut.S "subtitle",  GLB_SITE_SUBTITLE
        JOut.S "siteDesc",  GLB_SITE_DESC
        JOut.S "keywords",  GLB_SITE_KEYWORDS
        JOut.S "ownerName", GLB_OWNER_NAME
        JOut.S "ownerEmail",GLB_OWNER_EMAIL
        JOut.S "github",    GLB_OWNER_GITHUB
        JOut.S "copyright", GLB_COPYRIGHT
        JOut.S "assetVer",  GLB_ASSET_VER
    JOut.ObjClose

    ' 메뉴 URL 은 ASP 화면 기준(/asp/view/...)이라 React 라우트로 쓸 수 없다.
    ' 그래서 menu_code 를 그대로 내려주고, 매핑은 React 쪽 navMap 에서 한다.
    JOut.ArrOpen "menus"
    For mi = 0 To menuCnt - 1
        JOut.ObjOpen ""
            JOut.N "id",       AVI(menuArr, 0, mi)
            JOut.N "parentId", AVI(menuArr, 1, mi)
            JOut.S "code",     AV(menuArr,  2, mi)
            JOut.S "name",     AV(menuArr,  3, mi)
            JOut.S "aspUrl",   AV(menuArr,  4, mi)
            JOut.S "target",   AV(menuArr,  5, mi)
            JOut.N "depth",    AVI(menuArr, 6, mi)
        JOut.ObjClose
    Next
    JOut.ArrClose

    JOut.ArrOpen "boards"
    For bi = 0 To bdListCnt - 1
        JOut.ObjOpen ""
            JOut.S "id",        AV(bdListArr,  BM_ID, bi)
            JOut.S "name",      AV(bdListArr,  BM_NAME, bi)
            JOut.S "boardDesc", AV(bdListArr,  BM_DESC, bi)
            JOut.S "skin",      AV(bdListArr,  BM_SKIN, bi)
        JOut.ObjClose
    Next
    JOut.ArrClose

    WriteMe "me"

    JOut.S "csrf", Auth.Token()

ApiEnd
%>
