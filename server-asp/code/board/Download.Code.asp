<!--#include file="../Common.Code.asp"-->
<!--#include file="../../model/board/Board.Class.asp"-->
<!--#include file="../../model/board/Article.Class.asp"-->
<!--#include file="../../model/board/BoardFile.Class.asp"-->
<%
'==============================================================================
' code/board/Download.Code.asp  -  첨부파일 다운로드
'------------------------------------------------------------------------------
' /upload 는 web.config 로 직접 접근을 막아두고 이 경로로만 내려준다.
' 그래야 게시판 열람 권한 검사와 다운로드 카운트가 보장된다.
'==============================================================================

Dim fid, fArr, fBoardId, fPhys, fOrgName
fid = RequestUtil.ValueIntInit("fid", 0)
If fid <= 0 Then JsAlert "잘못된 접근입니다."

fArr = BoardFile.File_v(fid)
If Not IsArray(fArr) Then JsAlert "파일 정보를 찾을 수 없습니다."

fBoardId = AV(fArr, 8, 0)

'--- 해당 게시판의 열람 권한 확인 ---
Dim dbArr
dbArr = Board.Board_v(fBoardId)
If Not IsArray(dbArr) Then JsAlert "게시판 정보를 찾을 수 없습니다."
If Not Board.CanRead(dbArr) Then Auth.CheckLevel AVI(dbArr, BM_AUTH_READ, 0)

'--- 원글이 살아있는지 ---
Dim dArt
dArt = Article.Article_v(AVI(fArr, 9, 0))
If Not IsArray(dArt) Then JsAlert "삭제된 게시물의 첨부파일입니다."

'--- 물리 경로 (경로 조작 차단) ---
fOrgName = AV(fArr, BF_ORGNAME, 0)
fPhys    = Server.MapPath(UpUrl(AV(fArr, BF_SAVEPATH, 0)) & "/" & StringUtil.BaseName(AV(fArr, BF_SAVENAME, 0)))

BoardFile.DownCountUp fid
DBDisconnect

FileDownload.Down fPhys, fOrgName
%>
