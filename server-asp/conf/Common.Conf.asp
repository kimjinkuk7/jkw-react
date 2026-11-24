<%
'==============================================================================
' conf/Common.Conf.asp  -  요청 공통 초기화
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Conf/Common.Conf.asp
' 호출 : code/Common.Code.asp 의 마지막에서 include 된다.
'        (모든 lib / model 이 로드된 뒤에 실행되어야 한다)
'==============================================================================

'------------------------------------------------------------------------------
' 1. 사이트 설정 로드 (tb_config → Dictionary 캐시)
'------------------------------------------------------------------------------
Config.Load

Dim GLB_SITE_TITLE    : GLB_SITE_TITLE    = Config.ValueInit("site_title",    SITE_NAME)
Dim GLB_SITE_SUBTITLE : GLB_SITE_SUBTITLE = Config.ValueInit("site_subtitle", "")
Dim GLB_SITE_DESC     : GLB_SITE_DESC     = Config.ValueInit("site_desc",     "")
Dim GLB_SITE_KEYWORDS : GLB_SITE_KEYWORDS = Config.ValueInit("site_keywords", "")
Dim GLB_OWNER_NAME    : GLB_OWNER_NAME    = Config.ValueInit("owner_name",    "")
Dim GLB_OWNER_EMAIL   : GLB_OWNER_EMAIL   = Config.ValueInit("owner_email",   "")
Dim GLB_OWNER_GITHUB  : GLB_OWNER_GITHUB  = Config.ValueInit("owner_github",  "")
Dim GLB_COPYRIGHT     : GLB_COPYRIGHT     = Config.ValueInit("copyright",     "&copy; " & Year(Now()) & " " & SITE_NAME)

'--- 정적 리소스 캐시 무효화 키 (CSS/JS 수정 시 이 값을 바꾸면 갱신된다) ---
Dim GLB_ASSET_VER     : GLB_ASSET_VER     = Config.ValueInit("asset_ver", "20260820")

'------------------------------------------------------------------------------
' 2. 세션 유효성 검사 (지문 불일치 시 강제 로그아웃)
'------------------------------------------------------------------------------
Auth.ValidateSession

Dim GLB_IS_LOGIN  : GLB_IS_LOGIN  = Auth.IsLogin()
Dim GLB_MY_ID     : GLB_MY_ID     = Auth.MyId()
Dim GLB_MY_LEVEL  : GLB_MY_LEVEL  = Auth.MyLevel()
Dim GLB_MY_NAME   : GLB_MY_NAME   = Auth.DisplayName()

'------------------------------------------------------------------------------
' 3. 화면 기본값 (각 Code 파일에서 덮어쓴다)
'------------------------------------------------------------------------------
g_pageTitle = GLB_SITE_TITLE
g_pageDesc  = GLB_SITE_DESC

'------------------------------------------------------------------------------
' 4. 방문 로그
'    GET 요청만 기록한다. (처리 페이지 / 다운로드 / POST 는 제외)
'------------------------------------------------------------------------------
Dim GLB_CUR_URL : GLB_CUR_URL = RequestUtil.CurrentUrl()

'    /asp/api/ (React 스택이 쓰는 JSON API) 도 제외한다.
'    SPA 는 화면 하나를 그리는 데 API 를 여러 번 호출하므로, 세지 않으면
'    같은 한 번의 방문이 수 건으로 부풀어 통계가 ASP 스택과 어긋난다.
If Not RequestUtil.IsPost() Then
    If InStr(LCase(GLB_PATH_INFO), "/admin/")   = 0 _
       And InStr(LCase(GLB_PATH_INFO), "/api/")    = 0 _
       And InStr(LCase(GLB_PATH_INFO), "download") = 0 _
       And InStr(LCase(GLB_PATH_INFO), "_p.asp")   = 0 Then
        Visit.Visit_i GLB_CUR_URL
    End If
End If
%>
