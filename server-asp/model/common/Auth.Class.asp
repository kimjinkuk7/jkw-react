<%
'==============================================================================
' model/common/Auth.Class.asp  -  인증 / 권한 / CSRF
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Model/Common/Auth.Class.asp
'
' 로그인 결과 코드
'    1 : 성공
'    0 : 아이디 없음 또는 비밀번호 불일치
'   -1 : 정지된 계정
'   -2 : 로그인 실패 누적으로 잠김
'==============================================================================
Class CAuth

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '==========================================================================
    ' 세션 조회
    '==========================================================================
    Public Function IsLogin()
        IsLogin = (MyId() > 0)
    End Function

    Public Function MyId()
        Dim v
        v = Session(SKEY_MID)
        If IsEmpty(v) Or IsNull(v) Then MyId = 0 : Exit Function
        If Not IsNumeric(v) Then MyId = 0 : Exit Function
        MyId = CLng(v)
    End Function

    Public Function MyLevel()
        Dim v
        v = Session(SKEY_LEVEL)
        If IsEmpty(v) Or IsNull(v) Then MyLevel = LV_GUEST : Exit Function
        If Not IsNumeric(v) Then MyLevel = LV_GUEST : Exit Function
        MyLevel = CLng(v)
    End Function

    Public Function MyLoginId() : MyLoginId = Session(SKEY_LOGIN) & "" : End Function
    Public Function MyNick()    : MyNick    = Session(SKEY_NICK)  & "" : End Function
    Public Function MyName()    : MyName    = Session(SKEY_NAME)  & "" : End Function

    Public Function IsAdmin() : IsAdmin = (MyLevel() >= LV_ADMIN) : End Function
    Public Function IsStaff() : IsStaff = (MyLevel() >= LV_STAFF) : End Function

    '<Desc>표시용 이름 (닉네임 우선)</Desc>
    Public Function DisplayName()
        Dim n
        n = MyNick()
        If Len(n) = 0 Then n = MyName()
        If Len(n) = 0 Then n = MyLoginId()
        DisplayName = n
    End Function

    '==========================================================================
    ' 로그인 / 로그아웃
    '==========================================================================

    '<Desc>로그인 처리. 결과 코드 반환</Desc>
    Public Function Login(ByVal pLoginId, ByVal pPlainPw)
        Dim arr, memberId, dbPw, salt, uName, nick, level, isUse, isDel
        Dim failCnt, lockUntil, inputHash

        Login = 0

        If StringUtil.IsBlank(pLoginId) Or StringUtil.IsBlank(pPlainPw) Then
            LoginLog_i pLoginId, Null, 0, "입력값 누락"
            Exit Function
        End If

        With DBHelper
            .Sql = "SELECT member_id, user_pw, user_salt, user_name, nickname, member_level, " & _
                   "       is_use, is_del, pw_fail_count, lock_until_dt " & _
                   "  FROM tb_member WHERE login_id = ?"
            .SetParamVarchar(LCase(pLoginId))
        End With
        arr = DBHelper.ExecuteGetRows()

        If Not IsArray(arr) Then
            LoginLog_i pLoginId, Null, 0, "존재하지 않는 아이디"
            Exit Function
        End If

        memberId  = CLng(arr(0, 0))
        dbPw      = LCase(Trim(arr(1, 0) & ""))
        salt      = Trim(arr(2, 0) & "")
        uName     = arr(3, 0) & ""
        nick      = arr(4, 0) & ""
        level     = CLng(arr(5, 0))
        isUse     = StringUtil.ToBool(arr(6, 0))
        isDel     = StringUtil.ToBool(arr(7, 0))
        failCnt   = CLng(arr(8, 0))
        lockUntil = arr(9, 0)

        '--- 탈퇴 / 정지 ---
        If isDel Or (Not isUse) Or level <= LV_BLOCK Then
            LoginLog_i pLoginId, memberId, 0, "정지 또는 탈퇴 계정"
            Login = -1
            Exit Function
        End If

        '--- 잠금 ---
        If IsDate(lockUntil) Then
            If CDate(lockUntil) > Now() Then
                LoginLog_i pLoginId, memberId, 0, "로그인 잠금 상태"
                Login = -2
                Exit Function
            End If
        End If

        '--- 비밀번호 대조 ---
        inputHash = Crypt.HashPassword(salt, pPlainPw)

        If inputHash <> dbPw Or Len(dbPw) <> 64 Then
            FailCountUp memberId, failCnt
            LoginLog_i pLoginId, memberId, 0, "비밀번호 불일치"
            If failCnt + 1 >= LOGIN_FAIL_LIMIT Then Login = -2 Else Login = 0
            Exit Function
        End If

        '--- 성공 ---
        LoginSuccess memberId
        SetSession memberId, LCase(pLoginId), level, nick, uName
        LoginLog_i pLoginId, memberId, 1, ""
        Login = 1
    End Function

    Private Sub FailCountUp(ByVal pMemberId, ByVal pCurCount)
        Dim lockDt
        If pCurCount + 1 >= LOGIN_FAIL_LIMIT Then
            lockDt = DateAdd("n", LOGIN_LOCK_MIN, Now())
        Else
            lockDt = Null
        End If

        With DBHelper
            .Sql = "UPDATE tb_member SET pw_fail_count = pw_fail_count + 1, lock_until_dt = ? WHERE member_id = ?"
            .SetParamDate(lockDt)
            .SetParamInt(pMemberId)
        End With
        DBHelper.Execute()
    End Sub

    Private Sub LoginSuccess(ByVal pMemberId)
        With DBHelper
            .Sql = "UPDATE tb_member " & _
                   "   SET login_count   = login_count + 1, " & _
                   "       last_login_dt = CURRENT_TIMESTAMP, " & _
                   "       last_login_ip = ?, " & _
                   "       pw_fail_count = 0, " & _
                   "       lock_until_dt = NULL " & _
                   " WHERE member_id = ?"
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamInt(pMemberId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>세션 발급</Desc>
    '<Desc>※ Session.Abandon 을 여기서 호출하면 안 된다. Classic ASP 의 Abandon 은</Desc>
    '<Desc>  현재 요청 끝에 세션을 파기하므로, 이후에 담은 값이 전부 사라진다.</Desc>
    '<Desc>  IIS 가 세션 ID 를 직접 발급하고 외부 주입 ID 를 수용하지 않으므로</Desc>
    '<Desc>  기존 값 제거 + 지문 재발급으로 충분하다.</Desc>
    Public Sub SetSession(ByVal pMemberId, ByVal pLoginId, ByVal pLevel, ByVal pNick, ByVal pName)
        Session.Contents.RemoveAll

        Session(SKEY_MID)   = pMemberId
        Session(SKEY_LOGIN) = pLoginId
        Session(SKEY_LEVEL) = pLevel
        Session(SKEY_NICK)  = pNick
        Session(SKEY_NAME)  = pName
        Session(SKEY_FP)    = Fingerprint()
        Session(SKEY_CSRF)  = StringUtil.NewKey()
    End Sub

    Public Sub Logout()
        Session.Contents.RemoveAll
        Session.Abandon
    End Sub

    '<Desc>세션 탈취 완화 : User-Agent 지문 대조</Desc>
    Private Function Fingerprint()
        Fingerprint = CStr(Len(RequestUtil.UserAgent())) & "-" & _
                      CStr(Abs(Hash32(RequestUtil.UserAgent())))
    End Function

    Private Function Hash32(ByVal s)
        ' VBScript 의 Mod 연산자는 피연산자를 Long(32비트 부호있는 정수)으로 변환한다.
        ' h * 31 + c 는 UA 6글자만 돼도 2,147,483,647 을 넘어 오버플로(800a0006)가 난다.
        ' 그래서 Mod 대신 Double 연산으로 나머지를 구한다 (Double 은 2^53 까지 정확).
        Dim i, h
        Const H32_MOD = 2147483647
        h = 0
        For i = 1 To Len(s)
            h = (h * 31) + AscW(Mid(s, i, 1))
            h = h - Int(h / H32_MOD) * H32_MOD
        Next
        Hash32 = h
    End Function

    '<Desc>세션 유효성 확인. 지문이 다르면 강제 로그아웃</Desc>
    Public Sub ValidateSession()
        If Not IsLogin() Then Exit Sub
        If (Session(SKEY_FP) & "") <> Fingerprint() Then Logout
    End Sub

    '==========================================================================
    ' 권한 체크 (페이지 진입 시 첫 줄에서 호출)
    '==========================================================================

    '<Desc>권한 부족 시 로그인 페이지로 보낸다</Desc>
    Public Sub CheckLevel(ByVal pNeedLevel)
        If MyLevel() >= pNeedLevel Then Exit Sub

        If IsLogin() Then
            JsAlertGo "접근 권한이 없습니다.", U("/main/Default.asp")
        Else
            JsAlertGo "로그인이 필요합니다.", U("/member/Login.asp") & "?rurl=" & UE(RequestUtil.CurrentUrl())
        End If
    End Sub

    Public Sub CheckAdmin()
        If MyLevel() >= LV_ADMIN Then Exit Sub
        If IsLogin() Then
            JsAlertGo "관리자만 접근할 수 있습니다.", U("/main/Default.asp")
        Else
            JsAlertGo "관리자 로그인이 필요합니다.", U("/admin/Login.asp") & "?rurl=" & UE(RequestUtil.CurrentUrl())
        End If
    End Sub

    Public Sub CheckStaff()
        If MyLevel() >= LV_STAFF Then Exit Sub
        JsAlertGo "운영자 권한이 필요합니다.", U("/main/Default.asp")
    End Sub

    '==========================================================================
    ' CSRF 토큰
    '==========================================================================
    Public Function Token()
        If Len(Session(SKEY_CSRF) & "") = 0 Then
            Session(SKEY_CSRF) = StringUtil.NewKey()
        End If
        Token = Session(SKEY_CSRF) & ""
    End Function

    '<Desc>폼 안에 넣을 hidden 필드</Desc>
    Public Function TokenField()
        TokenField = "<input type=""hidden"" name=""_csrf"" value=""" & HE(Token()) & """>"
    End Function

    '<Desc>_ok / _p 처리 페이지 첫 줄에서 호출. 불일치면 즉시 차단</Desc>
    Public Sub CheckToken(ByVal pValue)
        If Len(Token()) = 0 Then JsAlert "세션이 만료되었습니다. 다시 시도해 주세요."
        If CStr(pValue) <> Token() Then JsAlert "잘못된 접근입니다. (CSRF)"
    End Sub

    '==========================================================================
    ' 로그
    '==========================================================================
    Public Sub LoginLog_i(ByVal pLoginId, ByVal pMemberId, ByVal pSuccess, ByVal pReason)
        On Error Resume Next
        With DBHelper
            .Sql = "INSERT INTO tb_login_log (login_id, member_id, is_success, fail_reason, ip, user_agent) " & _
                   "VALUES (?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pLoginId)
            .SetParamInt(pMemberId)
            .SetParamBit(pSuccess)
            .SetParamVarchar(pReason)
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamVarchar(RequestUtil.UserAgent())
        End With
        DBHelper.Execute()
        On Error GoTo 0
    End Sub

End Class

Dim Auth
Set Auth = New CAuth
%>
