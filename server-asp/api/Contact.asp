<%@ LANGUAGE="VBScript" CODEPAGE="65001" %>
<% Option Explicit %>
<!--#include file="../code/api/Api.Code.asp"-->
<!--#include file="../model/contact/Contact.Class.asp"-->
<%
'==============================================================================
' api/Contact.asp  -  POST  문의 접수
'------------------------------------------------------------------------------
' body : { "contactType": "...", "name": "...", "company": "", "email": "...",
'          "mobile": "", "subject": "...", "content": "...", "agree": true,
'          "_csrf": "..." }
'
' 메일 발송(CDO)은 화면 계층(code/contact/Send_p.Code.asp)에만 둔다.
' SMTP 설정이 없는 환경에서 API 응답이 지연되는 것을 피하기 위함이다.
'==============================================================================

NeedPost
NeedCsrf

Dim sType, sName, sCompany, sEmail, sMobile, sSubject, sContent, sAgree, linkCnt, newId

sType    = Left(BodyStr("contactType", 30), 30)
sName    = Left(BodyStr("name", 50), 50)
sCompany = Left(BodyStr("company", 100), 100)
sEmail   = Left(BodyStr("email", 100), 100)
sMobile  = Left(BodyStr("mobile", 20), 20)
sSubject = Left(BodyStr("subject", 200), 200)
sContent = Left(BodyRaw("content", 4000), 4000)
sAgree   = BodyBool("agree")

If Not sAgree                      Then FailBadRequest "개인정보 수집 및 이용에 동의해 주세요."
If StringUtil.IsBlank(sName)       Then FailBadRequest "이름을 입력해 주세요."
If StringUtil.IsBlank(sEmail)      Then FailBadRequest "이메일을 입력해 주세요."
If Not StringUtil.ChkEmail(sEmail) Then FailBadRequest "이메일 형식이 올바르지 않습니다."
If StringUtil.IsBlank(sSubject)    Then FailBadRequest "제목을 입력해 주세요."
If Len(Trim(sContent)) < 10        Then FailBadRequest "문의 내용을 10자 이상 입력해 주세요."

'--- 도배 방지 : 같은 IP 로 10분 내 3건 초과 차단 ---
If Contact.RecentByIp_c(10) >= 3 Then
    ApiFail "429 Too Many Requests", "RATE_LIMIT", _
            "짧은 시간에 너무 많은 문의를 보내셨습니다. 잠시 후 다시 시도해 주세요."
End If

'--- 스팸 필터 : 본문에 링크가 과도하게 많으면 차단 ---
linkCnt = UBound(Split(LCase(sContent) & " ", "http"))
If linkCnt > 5 Then FailBadRequest "본문에 링크가 너무 많습니다. 내용을 확인해 주세요."

newId = Contact.Contact_i(sType, sName, sCompany, sEmail, sMobile, sSubject, sContent, sAgree)
If newId <= 0 Then ApiFail "500 Internal Server Error", "SAVE_FAILED", "접수에 실패했습니다. 잠시 후 다시 시도해 주세요."

ApiBegin
    JOut.N "id", newId
    JOut.S "message", "문의가 정상적으로 접수되었습니다. 빠른 시일 내에 회신드리겠습니다."
ApiEnd
%>
