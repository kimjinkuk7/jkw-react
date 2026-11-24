<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<%
'==============================================================================
' api/Login.asp  -  POST  로그인
'------------------------------------------------------------------------------
' body : { "loginId": "...", "password": "...", "_csrf": "..." }
'
' ★ 로그인 성공 시 Auth.SetSession 이 세션을 비우고 다시 채우므로 CSRF 토큰이 바뀐다.
'   React 가 이후 POST 에서 옛 토큰을 쓰면 403 이 되므로 새 토큰을 함께 내려준다.
'==============================================================================

NeedPost
NeedCsrf

Dim inId, inPw, rc
inId = Left(LCase(BodyStr("loginId", 30)), 30)
inPw = Left(BodyRaw("password", 64), 64)

If StringUtil.IsBlank(inId) Then FailBadRequest "아이디를 입력해 주세요."
If StringUtil.IsBlank(inPw) Then FailBadRequest "비밀번호를 입력해 주세요."

rc = Auth.Login(inId, inPw)

Select Case rc
    Case 1
        ' 통과
    Case -1
        ApiFail "401 Unauthorized", "ACCOUNT_BLOCKED", "정지되었거나 탈퇴한 계정입니다. 관리자에게 문의해 주세요."
    Case -2
        ApiFail "401 Unauthorized", "ACCOUNT_LOCKED", _
                "로그인 실패가 " & LOGIN_FAIL_LIMIT & "회 누적되어 " & LOGIN_LOCK_MIN & "분간 로그인이 제한됩니다."
    Case Else
        ApiFail "401 Unauthorized", "LOGIN_FAILED", "아이디 또는 비밀번호가 일치하지 않습니다."
End Select

ApiBegin
    WriteMe "me"
    JOut.S "csrf", Auth.Token()
ApiEnd
%>
