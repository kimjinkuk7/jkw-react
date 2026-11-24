<%
'==============================================================================
' App.Conf.asp  -  애플리케이션 전역 설정 (유일한 환경 설정 지점)
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / App.Conf.asp 구조
' 차이 : CodePage 를 949(EUC-KR) → 65001(UTF-8) 로 변경 (신규 프로젝트)
'        DB 접근을 저장 프로시저 전용 → 파라미터 바인딩 SQL 겸용으로 확장
'        (PostgreSQL 이식 시 재작성 비용을 줄이기 위함. docs/DATABASE.md 참고)
'------------------------------------------------------------------------------
' 로딩 순서 (view/xxx.asp)
'     1) @LANGUAGE="VBScript" CODEPAGE="65001" 지시자
'     2) Option Explicit
'     3) include  /code/xxx/Xxx.Code.asp      ← 이 안에서 Common.Code.asp 를 include
'     4) include  /view/include/Header.asp
'     5) HTML
'     6) include  /view/include/Footer.asp
'
' ※ 주석 안에 include 지시자 원문을 적지 말 것.
'   IIS 의 ASP 전처리기는 VBScript 주석 여부와 무관하게 그 토큰을 스캔하므로
'   주석에 적어두면 의도치 않은 중복 또는 순환 include 가 발생한다.
'==============================================================================

'------------------------------------------------------------------------------
' 출력 / 인코딩
'------------------------------------------------------------------------------
Response.Buffer      = True
Response.CodePage    = 65001
Response.CharSet     = "utf-8"
Response.Expires     = -1
' 보안 헤더(X-Content-Type-Options 등)는 web.config 의 customHeaders 에서
' 정적 파일까지 포함해 일괄 지정한다. 여기서 중복 추가하지 않는다.

Session.CodePage     = 65001
Session.LCID         = 1042            ' 한국
Session.Timeout      = 120             ' 분

'------------------------------------------------------------------------------
' 사이트 기본 정보
'------------------------------------------------------------------------------
' DB(tb_config) 에 값이 없을 때 쓰이는 최종 기본값이다.
' 실제 운영 값은 관리자 → 사이트 설정에서 바꾼다 (tb_config.site_title 이 우선).
Const SITE_NAME    = "JKW.com"

'------------------------------------------------------------------------------
' 실행 환경
'------------------------------------------------------------------------------
Const DEBUG_MODE   = True              ' ★ 운영 전환 시 False

'------------------------------------------------------------------------------
' ★ 배치 경로 (이 백엔드가 어떤 URL 아래에 놓였는가)
'------------------------------------------------------------------------------
' 이 3줄이 이 백엔드의 유일한 "위치" 설정이다.
' 소스 include 는 전부 상대경로(#include file=)라 위치와 무관하지만,
' 브라우저가 받는 URL(업로드 이미지)과 Server.MapPath 는 사이트 루트 기준이라
' 접두어가 필요하다.
'
'   IIS 사이트 루트가 react 폴더일 때     APP_ROOT = "/server-asp"
'                                        UPLOAD_ROOT = "/upload"
'   사이트 루트 아래 /react 폴더면        APP_ROOT = "/react/server-asp"   ← 현재
'                                        UPLOAD_ROOT = "/react/upload"
'
' ★ UPLOAD_ROOT 는 APP_ROOT 아래가 아니라 react 폴더 바로 아래의 upload 다.
'   업로드 폴더는 실행 중에 쓰기가 일어나므로 소스(server-asp) 와 분리해 둔다.
'
' ※ VBScript 는 Const 에서 다른 Const 를 참조할 수 없다. (실측: 500 오류)
'   그래서 각각 리터럴로 적는다. 바꿀 때는 반드시 함께 바꿀 것.
'
' VIEW_ROOT : 이 백엔드에는 화면 계층(view)이 없다. React 가 화면을 그린다.
'   ASP 화면으로 넘기는 링크(회원가입·소셜·결제·관리자)는 React 쪽
'   src/app/config.js 의 ASP_VIEW_ROOT 가 관리한다. 여기서는 쓰지 않는다.
Const APP_ROOT     = "/react/server-asp"
Const VIEW_ROOT    = ""

Dim GLB_HTTP_HOST   : GLB_HTTP_HOST   = Request.ServerVariables("HTTP_HOST") & ""
Dim GLB_REMOTE_ADDR : GLB_REMOTE_ADDR = Request.ServerVariables("REMOTE_ADDR") & ""
Dim GLB_PATH_INFO   : GLB_PATH_INFO   = Request.ServerVariables("PATH_INFO") & ""
Dim GLB_REFERER     : GLB_REFERER     = Request.ServerVariables("HTTP_REFERER") & ""
Dim GLB_SITE_URL    : GLB_SITE_URL    = "http://" & GLB_HTTP_HOST

'------------------------------------------------------------------------------
' 데이터베이스
'------------------------------------------------------------------------------
' DB_PROVIDER
'   "MSOLEDBSQL"   : OLE DB Driver 18   (권장)
'   "MSOLEDBSQL19" : OLE DB Driver 19   (암호화 기본 강제 → 아래에서 옵션 추가)
'   "SQLNCLI11"    : Native Client 11
'   "SQLOLEDB"     : 레거시 - DATETIME2 미지원이므로 사용 금지
'------------------------------------------------------------------------------
Const DBCONN_JKWCOM   = "jkwcom"       ' 논리 DB 이름 (모델에서 이 상수를 쓴다)

Const DB_PROVIDER     = "MSOLEDBSQL"
Const DB_SERVER       = "localhost"    ' 명명 인스턴스면 "localhost\SQLEXPRESS"
Const DB_NAME         = "jkwcom"
Const DB_TRUSTED      = True           ' True = Windows 통합 인증(SSPI)
Const DB_USER         = "jkwcom_app"
Const DB_PASS         = ""
Const DB_TIMEOUT_CONN = 10
Const DB_TIMEOUT_CMD  = 30

'--- 논리 DB 이름 → 접속 문자열 (ZOCBOv7 의 ConnectionString() 과 동일 역할) ---
Function ConnectionString(ByVal pDbName)
    Dim cs
    cs = "Provider=" & DB_PROVIDER & ";" & _
         "Data Source=" & DB_SERVER & ";" & _
         "Initial Catalog=" & DB_NAME & ";"

    If DB_TRUSTED Then
        cs = cs & "Integrated Security=SSPI;"
    Else
        cs = cs & "User ID=" & DB_USER & ";Password=" & DB_PASS & ";"
    End If

    If DB_PROVIDER = "MSOLEDBSQL19" Then
        cs = cs & "Encrypt=Optional;TrustServerCertificate=yes;"
    End If

    ConnectionString = cs
End Function

'------------------------------------------------------------------------------
' 업로드
'------------------------------------------------------------------------------
' ★ APP_ROOT 와 함께 바꿀 것 (위 "배치 경로" 주석 참고)
'   server-asp 아래가 아니라 react 폴더 바로 아래의 upload 다.
Const UPLOAD_ROOT     = "/react/upload"
Const UPLOAD_MAX_SIZE = 20971520       ' 20MB - web.config maxRequestEntityAllowed 와 일치시킬 것

' 게시판 설정(file_ext_allow)에 무엇이 들어있든 아래 확장자는 무조건 거부한다.
Const UPLOAD_DENY_EXT = "asp,asax,ascx,ashx,asmx,aspx,asa,cer,cdx,htr,php,php3,php4,php5,phtml,jsp,jspx,cgi,pl,py,rb,exe,dll,com,bat,cmd,sh,scr,msi,vbs,vbe,js,jse,wsf,wsh,ps1,htaccess,config,inc"

'------------------------------------------------------------------------------
' 목록 / 페이징 기본값
'------------------------------------------------------------------------------
Const DEF_LIST_COUNT = 15
Const DEF_PAGE_BLOCK = 10

'------------------------------------------------------------------------------
' 회원 / 권한
'------------------------------------------------------------------------------
Const LV_BLOCK  = 0                    ' 정지
Const LV_GUEST  = 1                    ' 비회원 (세션 없음)
Const LV_MEMBER = 3                    ' 일반회원
Const LV_STAFF  = 5                    ' 운영자
Const LV_ADMIN  = 9                    ' 최고관리자

'------------------------------------------------------------------------------
' 휴대폰 인증 방식
'------------------------------------------------------------------------------
'   "off"      : 인증 단계 없음 (연락처는 그냥 입력값)
'   "mock"     : ★ 시연용. 버튼을 누르면 인증된 것으로 처리한다.
'                실제로 문자를 보내지 않으므로 번호 소유를 확인하지 않는다.
'                화면에도 시연용임을 표시한다. 운영에서 쓰면 안 된다.
'   "firebase" : Firebase Phone Auth (미구현 - 자리만 잡아둠)
'   "sms"      : 국내 SMS API + 인증번호 (미구현 - 자리만 잡아둠)
'
' 이 값만 바꾸면 화면/처리 로직이 함께 따라가도록 만들어 두었다.
' 실제 인증으로 교체할 때 손댈 곳은 code/member/PhoneAuth_p.Code.asp 한 곳이다.
Const PHONE_AUTH_MODE = "mock"

'------------------------------------------------------------------------------
' 소셜 로그인 (OAuth 2.0 Authorization Code)
'------------------------------------------------------------------------------
' SOCIAL_MODE
'   "mock" : ★ 시연용. 제공자 서버에 가지 않고 가짜 계정으로 로그인한다.
'            키가 없어도 흐름 전체(신규연동 → 자동가입 → 재로그인)를 볼 수 있다.
'   "live" : 실제 OAuth. 아래 CLIENT_ID / SECRET 을 채워야 동작한다.
'
' 키 발급 (모두 무료, 각 개발자 콘솔에서 본인이 등록)
'   구글   https://console.cloud.google.com  → OAuth 클라이언트 ID
'   네이버 https://developers.naver.com/apps
'   카카오 https://developers.kakao.com  (카카오 로그인 활성화 + 동의항목 설정)
'
' ★ 리다이렉트 URI 는 각 콘솔에 아래 값을 그대로 등록해야 한다.
'      http://localhost:8080/asp/view/member/SocialCallback.asp?provider=google
'   운영 전환 시에는 https 주소로 다시 등록한다. (구글은 localhost 만 http 허용)
Const SOCIAL_MODE = "mock"

Const GOOGLE_CLIENT_ID     = ""
Const GOOGLE_CLIENT_SECRET = ""
Const NAVER_CLIENT_ID      = ""
Const NAVER_CLIENT_SECRET  = ""
Const KAKAO_CLIENT_ID      = ""       ' REST API 키
Const KAKAO_CLIENT_SECRET  = ""       ' 카카오는 secret 미사용 설정도 가능(빈값 허용)

'------------------------------------------------------------------------------
' 결제 (개발자 지원금)
'------------------------------------------------------------------------------
' PAY_PROVIDERS  화면에서 고를 수 있는 결제 모듈 목록 (쉼표 구분, 순서대로 노출)
'   "mock"   : 시연용. PG 창 없이 자체 모달에서 성공/실패를 고른다.
'   "toss"   : 토스페이먼츠. 토스가 제공하는 실제 결제창(오버레이)이 뜬다.
'   "inicis" : KG이니시스 웹표준. 이니시스가 제공하는 iframe 결제창이 뜬다.
' PAY_PROVIDER  기본 선택값
'
' ★ PAY_IS_TEST = True 인 동안에는 모든 후원이 is_test = 1 로 저장된다.
'   실결제를 켜려면 사업자등록 + PG 심사가 필요하다.
' ★ 공개 저장소에는 PG 키를 넣지 않는다. 키가 비어 있으면 해당 모듈은
'   화면에서 "준비 안 됨" 으로 표시되므로, 기본값을 mock 으로 둔다.
Const PAY_PROVIDERS  = "toss,inicis,mock"
Const PAY_PROVIDER   = "mock"
Const PAY_IS_TEST    = True
Const PAY_MIN_AMOUNT = 1000
Const PAY_MAX_AMOUNT = 100000

'--- 토스페이먼츠 ---------------------------------------------------------------
'    발급 : https://developers.tosspayments.com  ->  내 개발정보
'    test_ 로 시작하는 키는 실제 결제창이 뜨지만 돈이 움직이지 않는다.
'
'    ★ 비워둔 채로 커밋한다. 로컬에서만 채워 쓸 것.
'      TOSS_SECRET_KEY 는 서버 전용이라 저장소에 올리면 안 된다.
'      둘 중 하나라도 비어 있으면 결제 화면에서 토스가 "준비 안 됨" 으로 표시된다.
Const TOSS_CLIENT_KEY = ""     ' test_ck_... (브라우저에 노출되는 키)
Const TOSS_SECRET_KEY = ""     ' test_sk_... (서버 전용. 절대 노출 금지)

'--- KG이니시스 웹표준 ----------------------------------------------------------
'    이니시스는 누구나 쓸 수 있는 테스트 상점 정보를 문서에 공개해 두었다.
'    (상점아이디와 그 짝이 되는 signKey 한 쌍)
'    발급 : https://manual.inicis.com  ->  웹표준 결제 연동 가이드
'
'    ★ 비워둔 채로 커밋한다. 로컬에서만 채워 쓸 것.
'      둘 중 하나라도 비어 있으면 결제 화면에서 이니시스가 "준비 안 됨" 으로 표시된다.
Const INICIS_MID      = ""     ' 테스트 상점아이디 (가이드 문서 참고)
Const INICIS_SIGNKEY  = ""     ' 위 MID 와 짝이 되는 signKey (가이드 문서에 공개돼 있다)
Const INICIS_TEST_JS  = "https://stgstdpay.inicis.com/stdjs/INIStdPay.js"   ' 테스트
Const INICIS_LIVE_JS  = "https://stdpay.inicis.com/stdjs/INIStdPay.js"      ' 운영

Const LOGIN_FAIL_LIMIT = 5
Const LOGIN_LOCK_MIN   = 10
Const PW_MIN_LEN       = 8

' 세션 키
Const SKEY_MID    = "JKW_MEMBER_ID"
Const SKEY_LEVEL  = "JKW_MEMBER_LEVEL"
Const SKEY_LOGIN  = "JKW_LOGIN_ID"
Const SKEY_NICK   = "JKW_NICKNAME"
Const SKEY_NAME   = "JKW_USERNAME"
Const SKEY_CSRF   = "JKW_CSRF_TOKEN"
Const SKEY_FP     = "JKW_FINGERPRINT"

'------------------------------------------------------------------------------
' 쿠키 암호화 키 (Crypt.Class.asp)
'------------------------------------------------------------------------------
' ★ 쿠키 암호화 키. 배포할 때마다 서로 다른 임의 문자열로 바꿀 것.
'   이 값이 그대로면 쿠키를 누구나 복호화할 수 있다.
Const CRYPT_KEY = "SET-YOUR-OWN-RANDOM-KEY-HERE"

'------------------------------------------------------------------------------
' 페이지 전역 상태 (각 계층이 채운다)
'------------------------------------------------------------------------------
Dim g_sharedConn   : Set g_sharedConn = Nothing   ' lib/DBHelper.Class.asp
Dim g_pageTitle    : g_pageTitle   = ""           ' view/include/Header.asp
Dim g_pageDesc     : g_pageDesc    = ""
Dim g_menuCode     : g_menuCode    = ""           ' 현재 메뉴 하이라이트
Dim g_subMenuCode  : g_subMenuCode = ""
Dim g_lnbParent    : g_lnbParent   = ""           ' view/include/Lnb.asp - 하위메뉴 탭의 부모 menu_code
Dim g_bodyClass    : g_bodyClass   = ""
Dim g_extraHead    : g_extraHead   = ""
Dim g_extraScript  : g_extraScript = ""
Dim g_isAdminPage  : g_isAdminPage = False

'------------------------------------------------------------------------------
' URL 헬퍼 - 모든 내부 링크는 이 함수를 거친다
'------------------------------------------------------------------------------
Function U(ByVal pPath)
    U = SpaUrl(pPath)
End Function

'------------------------------------------------------------------------------
' ASP 화면 경로 → React SPA 경로
'------------------------------------------------------------------------------
' 원본 ASP 스택에서 U() 는 VIEW_ROOT 를 앞에 붙여 .asp 화면 주소를 만들었다.
' 이 백엔드에는 화면이 없고 React 가 화면을 그리므로, 리다이렉트 대상(JsAlertGo 등)을
' SPA 라우트로 바꿔준다.
'
' 실제로 이 경로를 타는 것은 api/Download.asp 뿐이다
' (권한 부족 / 삭제된 글이면 alert 후 이동). 나머지 API 는 전부 JSON 으로 실패를 돌려준다.
Const SPA_ROOT = "/react/dist"          ' ★ 배포 위치에 맞출 것 (사이트 루트면 "/dist")

Function SpaUrl(ByVal pPath)
    Dim p : p = LCase(Trim(pPath & ""))
    If InStr(p, "/member/login") > 0 Then
        SpaUrl = SPA_ROOT & "/login"
    ElseIf InStr(p, "/admin/login") > 0 Then
        SpaUrl = SPA_ROOT & "/login"
    ElseIf InStr(p, "/board/list") > 0 Then
        SpaUrl = SPA_ROOT & "/board"
    ElseIf InStr(p, "/board/view") > 0 Then
        SpaUrl = SPA_ROOT & "/board"
    Else
        SpaUrl = SPA_ROOT & "/"
    End If
End Function
%>
