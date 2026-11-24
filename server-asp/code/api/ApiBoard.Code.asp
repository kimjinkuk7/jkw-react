<!--#include file="Api.Code.asp"-->
<!--#include file="../../model/board/Board.Class.asp"-->
<!--#include file="../../model/board/Article.Class.asp"-->
<!--#include file="../../model/board/Comment.Class.asp"-->
<!--#include file="../../model/board/BoardFile.Class.asp"-->
<%
'==============================================================================
' code/api/ApiBoard.Code.asp  -  게시판 API 공통
'------------------------------------------------------------------------------
' code/board/Board.Code.asp 와 같은 역할이지만, 실패했을 때 Go404(HTML) 가 아니라
' ApiFail(JSON) 로 끝난다. 그래서 별도 파일로 둔다.
'
' ★ bid 는 반드시 QueryString 으로만 받는다.
'   POST 본문은 JSON 이고 BinaryRead 로 읽는데, 여기서 본문을 먼저 읽어버리면
'   호출하는 쪽에서 파라미터를 꺼낼 때 순서가 꼬인다. 그래서 글쓰기/삭제 요청도
'   URL 에 ?bid=... 를 붙이도록 통일했다.
'==============================================================================

Dim bdId, bdArr
Dim bdName, bdDesc, bdSkin, bdListCount, bdPageBlock
Dim bdUseComment, bdUseFile, bdUseCategory, bdUseSecret, bdUseReply, bdUseNotice
Dim bdCanList, bdCanRead, bdCanWrite, bdCanComment, bdCanAdmin

bdId = LCase(QsVal("bid"))

' 형식 검증 : 영소문자로 시작하는 영숫자/_ 2~20자
If Not StringUtil.RegTest("^[a-z][a-z0-9_]{1,19}$", bdId) Then
    FailBadRequest "게시판 아이디(bid)가 올바르지 않습니다."
End If

bdArr = Board.Board_v(bdId)
If Not IsArray(bdArr) Then
    FailNotFound "존재하지 않거나 사용 중지된 게시판입니다."
End If

bdName        = AV(bdArr,  BM_NAME, 0)
bdDesc        = AV(bdArr,  BM_DESC, 0)
bdSkin        = AV(bdArr,  BM_SKIN, 0)
bdListCount   = AVI(bdArr, BM_LIST_COUNT, 0)
bdPageBlock   = AVI(bdArr, BM_PAGE_BLOCK, 0)

bdUseComment  = AVB(bdArr, BM_USE_COMMENT, 0)
bdUseFile     = AVB(bdArr, BM_USE_FILE, 0)
bdUseCategory = AVB(bdArr, BM_USE_CATEGORY, 0)
bdUseSecret   = AVB(bdArr, BM_USE_SECRET, 0)
bdUseReply    = AVB(bdArr, BM_USE_REPLY, 0)
bdUseNotice   = AVB(bdArr, BM_USE_NOTICE, 0)

bdCanList    = Board.CanList(bdArr)
bdCanRead    = Board.CanRead(bdArr)
bdCanWrite   = Board.CanWrite(bdArr)
bdCanComment = Board.CanComment(bdArr)
bdCanAdmin   = Board.CanAdmin(bdArr)


'<Desc>로그인 상태면 세션 이름, 아니면 입력한 비회원 이름</Desc>
Function ApiWriterName(ByVal pInputName)
    If Auth.IsLogin() Then
        ApiWriterName = Auth.DisplayName()
    Else
        ApiWriterName = Left(Trim(pInputName), 20)
    End If
End Function

'<Desc>글/댓글 수정·삭제 가능 여부 (관리자 / 본인 / 비회원 비밀번호 보유)</Desc>
Function ApiCanEdit(ByVal pWriterId, ByVal pHasPw)
    ApiCanEdit = False
    If bdCanAdmin Then ApiCanEdit = True : Exit Function
    If Auth.MyId() > 0 And StringUtil.ToInt(pWriterId, 0) = Auth.MyId() Then ApiCanEdit = True : Exit Function
    If StringUtil.ToInt(pWriterId, 0) = 0 And StringUtil.ToBool(pHasPw) Then ApiCanEdit = True
End Function
%>
