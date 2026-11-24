<!--#include file="../App.Conf.asp"-->
<!--#include file="../lib/StringUtil.Class.asp"-->
<!--#include file="../lib/DateUtil.Class.asp"-->
<!--#include file="../lib/RequestUtil.Class.asp"-->
<!--#include file="../lib/DBHelper.Class.asp"-->
<!--#include file="../lib/Crypt.Class.asp"-->
<!--#include file="../lib/Cookie.Class.asp"-->
<!--#include file="../lib/Paging.Class.asp"-->
<!--#include file="../lib/FileDownload.Class.asp"-->
<!--#include file="../lib/Json.Class.asp"-->
<!--#include file="../lib/Http.Class.asp"-->
<!--#include file="../model/common/Config.Class.asp"-->
<!--#include file="../model/common/Menu.Class.asp"-->
<!--#include file="../model/common/Auth.Class.asp"-->
<!--#include file="../model/common/Visit.Class.asp"-->
<%
'==============================================================================
' code/Common.Code.asp  -  전역 공통 (모든 Code 파일이 최초로 include)
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Code/Common.Code.asp
'
' 페이지 작성 규약  (실제 예시는 README.md 3장 참고)
'
'   [view/board/List.asp]  ← URL 진입점
'     1) @LANGUAGE / CODEPAGE 지시자
'     2) Option Explicit
'     3) include  /code/board/List.Code.asp
'     4) include  /view/include/Header.asp
'     5) HTML
'     6) include  /view/include/Footer.asp
'
'   [code/board/List.Code.asp]  ← 컨트롤러
'     1) include  /code/Common.Code.asp          (또는 모듈 공통 Board.Code.asp)
'     2) include  /model/board/Board.Class.asp   (필요한 모델만)
'     3) 권한 확인 → 파라미터 수집 → 모델 호출 → 변수 준비
'
' ★ @LANGUAGE 지시자와 Option Explicit 은 실제 요청되는 파일(view)에 둔다.
'   include 파일에 두면 IIS 설정에 따라 무시될 수 있다. (ZOCBOv7 과 다른 점)
'
' ★ 주석 안에 include 지시자 원문을 적지 말 것.
'   ASP 전처리기가 주석 여부와 무관하게 스캔하여 순환 include 가 발생한다.
'==============================================================================


'##############################################################################
' 1. GetRows() 2차원 배열 접근 헬퍼
'------------------------------------------------------------------------------
' 모델은 DBHelper.ExecuteGetRows() 결과를 그대로 반환한다.
'   arr(컬럼인덱스, 행인덱스)   결과 없으면 Empty
'##############################################################################

'<Desc>행 개수. 결과 없으면 0</Desc>
Function RowCnt(ByVal arr)
    RowCnt = 0
    If Not IsArray(arr) Then Exit Function
    On Error Resume Next
    RowCnt = UBound(arr, 2) + 1
    If Err.Number <> 0 Then RowCnt = 0 : Err.Clear
    On Error GoTo 0
End Function

'<Desc>값 (NULL 은 빈 문자열)</Desc>
Function AV(ByVal arr, ByVal c, ByVal r)
    AV = ""
    If Not IsArray(arr) Then Exit Function
    On Error Resume Next
    If IsNull(arr(c, r)) Then AV = "" Else AV = arr(c, r)
    If Err.Number <> 0 Then AV = "" : Err.Clear
    On Error GoTo 0
End Function

'<Desc>값을 HTML 이스케이프해서 반환 (뷰에서 가장 많이 쓰임)</Desc>
Function AVH(ByVal arr, ByVal c, ByVal r)
    AVH = StringUtil.HtmlEnc(AV(arr, c, r))
End Function

'<Desc>정수 값</Desc>
Function AVI(ByVal arr, ByVal c, ByVal r)
    AVI = StringUtil.ToInt(AV(arr, c, r), 0)
End Function

'<Desc>Boolean 값 (BIT 컬럼)</Desc>
Function AVB(ByVal arr, ByVal c, ByVal r)
    AVB = StringUtil.ToBool(AV(arr, c, r))
End Function

'<Desc>VBScript 에는 삼항 연산자가 없어 뷰가 지저분해지므로 헬퍼로 대신한다.</Desc>
'<Desc>주의 : IIf 와 달리 인자를 미리 평가하므로 부작용 있는 식은 넣지 말 것.</Desc>
Function IIfStr(ByVal cond, ByVal sTrue, ByVal sFalse)
    If cond Then IIfStr = sTrue Else IIfStr = sFalse
End Function


'##############################################################################
' 2. 화면 전환 / 알림
'##############################################################################

Private Sub WriteScriptPage(ByVal js)
    Response.Clear
    Response.ContentType = "text/html"
    Response.Write "<!DOCTYPE html><html lang=""ko""><head><meta charset=""utf-8"">" & _
                   "<meta name=""viewport"" content=""width=device-width,initial-scale=1""></head><body>" & _
                   "<script type=""text/javascript"">" & js & "</script></body></html>"
    Response.End
End Sub

'<Desc>알림 후 이전 페이지로</Desc>
Sub JsAlert(ByVal msg)
    WriteScriptPage "alert('" & JE(msg) & "');history.back();"
End Sub

'<Desc>알림 후 지정 URL 로 이동</Desc>
Sub JsAlertGo(ByVal msg, ByVal url)
    WriteScriptPage "alert('" & JE(msg) & "');location.replace('" & JE(url) & "');"
End Sub

'<Desc>알림 없이 이동</Desc>
Sub JsGo(ByVal url)
    WriteScriptPage "location.replace('" & JE(url) & "');"
End Sub

'<Desc>팝업 : 알림 후 부모 새로고침 + 닫기</Desc>
Sub JsAlertClose(ByVal msg)
    WriteScriptPage "alert('" & JE(msg) & "');if(window.opener){window.opener.location.reload();}window.close();"
End Sub

'<Desc>404 처리</Desc>
Sub Go404(ByVal msg)
    Response.Status = "404 Not Found"
    JsAlertGo msg, U("/main/Default.asp")
End Sub


'##############################################################################
' 3. 링크 헬퍼
'##############################################################################

'<Desc>게시판 목록 URL</Desc>
Function BoardListUrl(ByVal pBid)
    BoardListUrl = U("/board/List.asp") & "?bid=" & UE(pBid)
End Function

'<Desc>게시판 상세 URL</Desc>
Function BoardViewUrl(ByVal pBid, ByVal pArticleId)
    BoardViewUrl = U("/board/View.asp") & "?bid=" & UE(pBid) & "&id=" & pArticleId
End Function

'<Desc>현재 목록 상태(페이지/검색)를 유지하는 쿼리스트링 조각</Desc>
Function ListStateQs()
    Dim s
    s = ""
    If Len(RequestUtil.Value("page")) > 0 Then s = s & "&page=" & UE(RequestUtil.Value("page"))
    If Len(RequestUtil.Value("sf"))   > 0 Then s = s & "&sf="   & UE(RequestUtil.Value("sf"))
    If Len(RequestUtil.Value("sw"))   > 0 Then s = s & "&sw="   & UE(RequestUtil.Value("sw"))
    If Len(RequestUtil.Value("cid"))  > 0 Then s = s & "&cid="  & UE(RequestUtil.Value("cid"))
    ListStateQs = s
End Function


'##############################################################################
' 4. 업로드 경로
'##############################################################################

'<Desc>게시판 첨부 저장 폴더 (URL 경로). 예 /upload/board/202608</Desc>
Function BoardUploadPath()
    BoardUploadPath = UPLOAD_ROOT & "/board/" & DateUtil.YearMonth()
End Function

'<Desc>URL 경로 → 물리 경로</Desc>
Function PhysPath(ByVal pUrlPath)
    PhysPath = Server.MapPath(pUrlPath)
End Function

'<Desc>
' DB 에 저장된 업로드 경로를 이 스택의 UPLOAD_ROOT 기준으로 다시 붙인다.
'
' 각 스택이 자기 폴더 아래에 upload 를 갖게 되면서(/asp/upload, /react/upload)
' DB 의 save_path / thumb_file 에 어떤 접두어가 들어 있든 현재 스택 것으로 맞춰야 한다.
' 같은 DB 를 여러 스택이 공유해도 첨부가 깨지지 않게 하는 지점이 여기 한 곳이다.
'
'   "/upload/board/202611"      → "/asp/upload/board/202611"
'   "/asp/upload/board/202611"  → "/asp/upload/board/202611"   (그대로. 멱등)
'   "/react/upload/board/..."   → "/asp/upload/board/..."
'   "http://..." 같은 외부 URL  → 손대지 않는다
'</Desc>
Function UpUrl(ByVal pStored)
    Dim s, p
    s = Trim(pStored & "")
    If Len(s) = 0 Then UpUrl = "" : Exit Function
    s = Replace(s, "\", "/")
    If InStr(1, s, "://", 1) > 0 Then UpUrl = s : Exit Function

    p = InStr(1, s, "/upload/", 1)
    If p > 0 Then
        UpUrl = UPLOAD_ROOT & Mid(s, p + 7)      ' "/upload" 는 7자 → 그 뒤 "/board/..." 부터
    ElseIf LCase(Right(s, 7)) = "/upload" Then
        UpUrl = UPLOAD_ROOT
    Else
        UpUrl = s
    End If
End Function
%>
<!--#include file="../conf/Common.Conf.asp"-->
