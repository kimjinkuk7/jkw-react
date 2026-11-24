<!--#include file="../Common.Code.asp"-->
<!--#include file="../../lib/JsonOut.Class.asp"-->
<%
'==============================================================================
' code/api/Api.Code.asp  -  JSON API 공통 (React 스택 전용)
'------------------------------------------------------------------------------
' /asp/api/*.asp 가 모두 이 파일을 첫 줄에 include 한다.
' 화면(view) 계층의 JsAlert / JsGo / Go404 는 HTML 을 뱉으므로 여기서는 쓰지 않는다.
' 모든 실패는 ApiFail() 로 JSON 과 HTTP 상태코드를 함께 돌려준다.
'
' 응답 형식 (항상 이 두 가지 중 하나)
'   성공  { "ok": true,  "data": { ... } }
'   실패  { "ok": false, "error": { "code": "...", "message": "..." } }
'
' ★ Request.Form 을 절대 읽지 말 것.
'   Classic ASP 는 Request.Form 을 한 번이라도 건드리면 Request.BinaryRead 가 실패한다.
'   이 API 의 POST 본문은 JSON 이라 BinaryRead 로 원문 바이트를 직접 읽는다.
'   GET 파라미터는 QsVal() / QsInt() 를 쓴다 (RequestUtil.Value 는 Form 을 읽는다).
'
' ★ 전역 이름은 짧게 짓지 말 것.
'   VBScript 는 대소문자를 구분하지 않고, 전역 Function 이름과 같은 이름으로
'   Dim 을 하면 "다시 정의된 이름"(800a0411) 으로 페이지 전체가 죽는다.
'   처음에 본문 파서를 BS / BI / BB 로 지었더니, 호출하는 쪽에서 쓴
'   루프 변수 Dim bi 와 BI() 가 충돌해 Config.asp 가 통째로 500 이 났다.
'   그래서 BodyStr / BodyInt / BodyBool 처럼 흔한 변수명과 겹치지 않게 바꿨다.
'   JSON 출력 객체도 J 가 아니라 JOut 이다.
'
' ※ 주석 안에 include 지시자 원문을 적지 말 것 (전처리기가 스캔한다).
'==============================================================================

'--- 응답 버퍼 ---------------------------------------------------------------
Dim JOut : Set JOut = New CJsonOut

'--- 요청 본문 (JSON) ---------------------------------------------------------
Dim ApiIn       : Set ApiIn = New CJson
Dim ApiBodyRead : ApiBodyRead = False


'##############################################################################
' 1. 응답
'##############################################################################

Private Sub ApiWrite(ByVal pStatus, ByVal pText)
    Response.Clear
    Response.Status      = pStatus
    Response.ContentType = "application/json"
    Response.CharSet     = "utf-8"
    Response.AddHeader "Cache-Control", "no-store"
    Response.Write pText
    Response.End
End Sub

'<Desc>성공 응답 시작. 이 다음부터 data 객체의 내용을 쓴다.</Desc>
Sub ApiBegin()
    JOut.Reset
    JOut.ObjOpen ""
    JOut.B "ok", True
    JOut.ObjOpen "data"
End Sub

'<Desc>성공 응답 종료 + 전송 (여기서 요청이 끝난다)</Desc>
Sub ApiEnd()
    JOut.ObjClose          ' data
    JOut.ObjClose          ' root
    ApiWrite "200 OK", JOut.Text
End Sub

'<Desc>실패 응답 + 전송 (여기서 요청이 끝난다)</Desc>
Sub ApiFail(ByVal pStatus, ByVal pCode, ByVal pMsg)
    Dim e
    Set e = New CJsonOut
    e.ObjOpen ""
        e.B "ok", False
        e.ObjOpen "error"
            e.S "code",    pCode
            e.S "message", pMsg
        e.ObjClose
    e.ObjClose
    ApiWrite pStatus, e.Text
End Sub

Sub FailBadRequest(ByVal pMsg)
    ApiFail "400 Bad Request", "BAD_REQUEST", pMsg
End Sub

Sub FailNotFound(ByVal pMsg)
    ApiFail "404 Not Found", "NOT_FOUND", pMsg
End Sub

Sub FailForbidden(ByVal pMsg)
    ApiFail "403 Forbidden", "FORBIDDEN", pMsg
End Sub


'##############################################################################
' 2. 요청 파라미터
'##############################################################################

'<Desc>쿼리스트링 값 (Request.Form 을 건드리지 않는다)</Desc>
Function QsVal(ByVal pName)
    QsVal = Trim(Request.QueryString(pName) & "")
End Function

Function QsInit(ByVal pName, ByVal pInit)
    Dim v : v = QsVal(pName)
    If Len(v) = 0 Then QsInit = pInit Else QsInit = v
End Function

Function QsInt(ByVal pName, ByVal pInit)
    QsInt = StringUtil.ToInt(QsVal(pName), pInit)
End Function

'<Desc>허용 목록 밖의 값은 기본값으로 떨어뜨린다</Desc>
Function QsWhite(ByVal pName, ByVal pAllow, ByVal pDefault)
    Dim v, i, a
    v = LCase(QsVal(pName))
    a = Split(LCase(pAllow), ",")
    For i = 0 To UBound(a)
        If v = Trim(a(i)) Then QsWhite = v : Exit Function
    Next
    QsWhite = pDefault
End Function

'--- POST JSON 본문 -----------------------------------------------------------

'<Desc>요청 본문을 UTF-8 로 읽어 JSON 파싱한다 (한 번만 실행된다)</Desc>
Sub ApiLoadBody()
    Dim n, bin, st, txt

    If ApiBodyRead Then Exit Sub
    ApiBodyRead = True

    n = Request.TotalBytes
    If n <= 0 Then Exit Sub

    bin = Request.BinaryRead(n)

    ' ADODB.Stream 으로 UTF-8 디코딩한다.
    ' iso-8859-1 을 거치면 한글이 깨진다 (lib/FileUpload.Class.asp 주석 참고).
    Set st = Server.CreateObject("ADODB.Stream")
    st.Type = 1 : st.Open
    st.Write bin
    st.Position = 0
    st.Type    = 2
    st.Charset = "utf-8"
    txt = st.ReadText
    st.Close
    Set st = Nothing

    If Len(Trim(txt)) = 0 Then Exit Sub

    If Not ApiIn.Parse(txt) Then
        FailBadRequest "요청 본문이 올바른 JSON 이 아닙니다. (" & ApiIn.ErrMsg & ")"
    End If
End Sub

'<Desc>본문 문자열 (앞뒤 공백 제거 + 길이 제한. pMaxLen 이 0 이면 제한 없음)</Desc>
Function BodyStr(ByVal pPath, ByVal pMaxLen)
    Dim v
    ApiLoadBody
    v = Trim(ApiIn.Str(pPath, ""))
    If pMaxLen > 0 Then v = Left(v, pMaxLen)
    BodyStr = v
End Function

'<Desc>본문 문자열 (공백 보존. 글 본문처럼 그대로 받아야 하는 값)</Desc>
Function BodyRaw(ByVal pPath, ByVal pMaxLen)
    Dim v
    ApiLoadBody
    v = ApiIn.Str(pPath, "")
    If pMaxLen > 0 Then v = Left(v, pMaxLen)
    BodyRaw = v
End Function

Function BodyInt(ByVal pPath, ByVal pInit)
    ApiLoadBody
    BodyInt = StringUtil.ToInt(ApiIn.Str(pPath, CStr(pInit)), pInit)
End Function

Function BodyBool(ByVal pPath)
    ApiLoadBody
    BodyBool = ApiIn.Bln(pPath, False)
End Function


'##############################################################################
' 3. 관문 (method / CSRF / 권한)
'##############################################################################

Sub NeedPost()
    If Not RequestUtil.IsPost() Then
        ApiFail "405 Method Not Allowed", "METHOD_NOT_ALLOWED", "POST 요청만 허용합니다."
    End If
End Sub

'<Desc>CSRF 토큰. 헤더 X-CSRF-Token 우선, 없으면 본문 _csrf</Desc>
Function CsrfIn()
    Dim t
    t = Trim(Request.ServerVariables("HTTP_X_CSRF_TOKEN") & "")
    If Len(t) = 0 Then t = BodyStr("_csrf", 64)
    CsrfIn = t
End Function

'<Desc>세션 토큰과 대조. 화면 계층 Auth.CheckToken 은 HTML 을 뱉으므로 쓰지 않는다.</Desc>
Sub NeedCsrf()
    Dim mine
    mine = Auth.Token()
    If Len(mine) = 0 Or CsrfIn() <> mine Then
        ApiFail "403 Forbidden", "CSRF", "보안 토큰이 일치하지 않습니다. 새로고침 후 다시 시도해 주세요."
    End If
End Sub

Sub NeedLogin()
    If Not Auth.IsLogin() Then
        ApiFail "401 Unauthorized", "LOGIN_REQUIRED", "로그인이 필요합니다."
    End If
End Sub

Sub NeedLevel(ByVal pLevel)
    If Auth.MyLevel() >= pLevel Then Exit Sub
    If Auth.IsLogin() Then
        FailForbidden "접근 권한이 없습니다."
    Else
        ApiFail "401 Unauthorized", "LOGIN_REQUIRED", "로그인이 필요합니다."
    End If
End Sub


'##############################################################################
' 4. 직렬화 헬퍼  (GetRows 2차원 배열 -> JSON)
'##############################################################################

'<Desc>현재 로그인 상태를 me 객체로 쓴다</Desc>
Sub WriteMe(ByVal pName)
    JOut.ObjOpen pName
        JOut.B "isLogin", Auth.IsLogin()
        JOut.N "id",      Auth.MyId()
        JOut.S "loginId", Auth.MyLoginId()
        JOut.S "name",    Auth.DisplayName()
        JOut.N "level",   Auth.MyLevel()
        JOut.B "isStaff", Auth.IsStaff()
        JOut.B "isAdmin", Auth.IsAdmin()
    JOut.ObjClose
End Sub

'<Desc>페이징 정보를 paging 객체로 쓴다</Desc>
Sub WritePaging(ByVal pName, ByVal pPage, ByVal pSize, ByVal pTotal)
    Dim tp
    tp = 1
    If pSize > 0 Then
        tp = Int(pTotal / pSize)
        If pTotal Mod pSize > 0 Then tp = tp + 1
        If tp < 1 Then tp = 1
    End If
    JOut.ObjOpen pName
        JOut.N "page",       pPage
        JOut.N "pageSize",   pSize
        JOut.N "totalCount", pTotal
        JOut.N "totalPage",  tp
    JOut.ObjClose
End Sub

'<Desc>게시판 설정(Board_v 결과 1행)을 board 객체로 쓴다</Desc>
Sub WriteBoard(ByVal pName, ByVal arr)
    JOut.ObjOpen pName
        JOut.S "id",          AV(arr,  BM_ID, 0)
        JOut.S "name",        AV(arr,  BM_NAME, 0)
        JOut.S "boardDesc",   AV(arr,  BM_DESC, 0)
        JOut.S "skin",        AV(arr,  BM_SKIN, 0)
        JOut.N "listCount",   AVI(arr, BM_LIST_COUNT, 0)
        JOut.N "pageBlock",   AVI(arr, BM_PAGE_BLOCK, 0)
        JOut.N "galleryCol",  AVI(arr, BM_GAL_COL, 0)
        JOut.B "useComment",  AVB(arr, BM_USE_COMMENT, 0)
        JOut.B "useFile",     AVB(arr, BM_USE_FILE, 0)
        JOut.B "useCategory", AVB(arr, BM_USE_CATEGORY, 0)
        JOut.B "useSecret",   AVB(arr, BM_USE_SECRET, 0)
        JOut.B "useReply",    AVB(arr, BM_USE_REPLY, 0)
        JOut.B "useEditor",   AVB(arr, BM_USE_EDITOR, 0)
        JOut.B "useNotice",   AVB(arr, BM_USE_NOTICE, 0)
        JOut.ObjOpen "perm"
            JOut.B "list",    Board.CanList(arr)
            JOut.B "read",    Board.CanRead(arr)
            JOut.B "write",   Board.CanWrite(arr)
            JOut.B "comment", Board.CanComment(arr)
            JOut.B "admin",   Board.CanAdmin(arr)
        JOut.ObjClose
    JOut.ObjClose
End Sub

'<Desc>목록 1행(Article_l / Notice_l / Recent_l 결과)을 배열 원소로 쓴다</Desc>
Sub WriteArticleRow(ByVal arr, ByVal r)
    JOut.ObjOpen ""
        JOut.N "id",           AVI(arr, ART_ID, r)
        JOut.S "boardId",      AV(arr,  ART_BID, r)
        JOut.N "no",           AVI(arr, ART_NO, r)
        JOut.N "categoryId",   AVI(arr, ART_CID, r)
        JOut.S "categoryName", AV(arr,  ART_CNAME, r)
        JOut.S "title",        AV(arr,  ART_TITLE, r)
        JOut.S "summary",      StringUtil.Cut(StringUtil.StripTags(AV(arr, ART_SUMMARY, r)), 160)
        JOut.N "writerId",     AVI(arr, ART_WID, r)
        JOut.S "writerName",   AV(arr,  ART_WNAME, r)
        JOut.N "hitCount",     AVI(arr, ART_HIT, r)
        JOut.N "commentCount", AVI(arr, ART_CMT, r)
        JOut.N "fileCount",    AVI(arr, ART_FILE, r)
        JOut.N "likeCount",    AVI(arr, ART_LIKE, r)
        JOut.B "isNotice",     AVB(arr, ART_NOTICE, r)
        JOut.B "isSecret",     AVB(arr, ART_SECRET, r)
        JOut.B "isNew",        DateUtil.IsNew(AV(arr, ART_REGDT, r), 48)
        JOut.D "regDt",        AV(arr,  ART_REGDT, r)
        JOut.S "regDate",      DateUtil.ListDate(AV(arr, ART_REGDT, r))
        JOut.S "thumb",        UpUrl(AV(arr,  ART_THUMB, r))
        JOut.S "tags",         AV(arr,  ART_TAGS, r)
        JOut.N "depth",        AVI(arr, ART_DEPTH, r)
    JOut.ObjClose
End Sub

'<Desc>포트폴리오 1행(Portfolio_l / Main_l 결과)을 배열 원소로 쓴다</Desc>
Sub WritePortfolioRow(ByVal arr, ByVal r)
    JOut.ObjOpen ""
        JOut.N "id",       AVI(arr, PF_ID, r)
        JOut.S "title",    AV(arr,  PF_TITLE, r)
        JOut.S "subtitle", AV(arr,  PF_SUBTITLE, r)
        JOut.S "summary",  AV(arr,  PF_SUMMARY, r)
        JOut.S "category", AV(arr,  PF_CATEGORY, r)
        JOut.S "client",   AV(arr,  PF_CLIENT, r)
        JOut.S "role",     AV(arr,  PF_ROLE, r)
        JOut.DOnly "periodStart", AV(arr, PF_START, r)
        JOut.DOnly "periodEnd",   AV(arr, PF_END, r)
        JOut.B "isOngoing", AVB(arr, PF_ONGOING, r)
        JOut.S "period",    DateUtil.Period(AV(arr, PF_START, r), AV(arr, PF_END, r), AVB(arr, PF_ONGOING, r))
        JOut.S "siteUrl",  AV(arr,  PF_SITEURL, r)
        JOut.S "repoUrl",  AV(arr,  PF_REPOURL, r)
        JOut.S "thumb",    UpUrl(AV(arr,  PF_THUMB, r))
        JOut.N "hitCount", AVI(arr, PF_HIT, r)
        JOut.B "isMain",   AVB(arr, PF_ISMAIN, r)
    JOut.ObjClose
End Sub
%>
