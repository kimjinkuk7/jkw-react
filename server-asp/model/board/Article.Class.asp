<%
'==============================================================================
' model/board/Article.Class.asp  -  게시글 (tb_board_article)
'------------------------------------------------------------------------------
' 전 게시판 공용. board_id 로만 구분한다.
'
' 답변형 정렬 : ORDER BY group_no DESC, group_order ASC
'   group_no    = 원글의 article_id (원글은 자기 자신)
'   group_order = 그룹 내 순번 (원글 0, 답변이 붙을수록 증가)
'   group_depth = 들여쓰기 단계
'
' 페이징 : OFFSET ? ROWS FETCH NEXT ? ROWS ONLY  (SQL2012+ / PostgreSQL 동일)
'==============================================================================

'--- Article_l() / Notice_l() / Recent_l() 결과 인덱스 ------------------------
Const ART_ID      = 0
Const ART_BID     = 1
Const ART_CID     = 2
Const ART_CNAME   = 3
Const ART_TITLE   = 4
Const ART_WID     = 5
Const ART_WNAME   = 6
Const ART_HIT     = 7
Const ART_CMT     = 8
Const ART_FILE    = 9
Const ART_LIKE    = 10
Const ART_NOTICE  = 11
Const ART_SECRET  = 12
Const ART_REGDT   = 13
Const ART_THUMB   = 14
Const ART_TAGS    = 15
Const ART_DEPTH   = 16
Const ART_SUMMARY = 17
Const ART_NO      = 18      ' 화면에 찍는 원글 번호 (답변글은 원글과 같은 값)

'--- Article_v() 결과 인덱스 (상세) ------------------------------------------
Const AVW_ID       = 0
Const AVW_BID      = 1
Const AVW_CID      = 2
Const AVW_CNAME    = 3
Const AVW_TITLE    = 4
Const AVW_CONTENT  = 5
Const AVW_CTYPE    = 6
Const AVW_WID      = 7
Const AVW_WNAME    = 8
Const AVW_WEMAIL   = 9
Const AVW_WIP      = 10
Const AVW_HIT      = 11
Const AVW_CMT      = 12
Const AVW_FILE     = 13
Const AVW_LIKE     = 14
Const AVW_NOTICE   = 15
Const AVW_SECRET   = 16
Const AVW_REGDT    = 17
Const AVW_UPDDT    = 18
Const AVW_TAGS     = 19
Const AVW_THUMB    = 20
Const AVW_LINK     = 21
Const AVW_GROUPNO  = 22
Const AVW_GORDER   = 23
Const AVW_GDEPTH   = 24
Const AVW_HASPW    = 25

Class CArticle

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '==========================================================================
    ' 내부 : 목록 컬럼 / 검색 조건
    '==========================================================================
    '<Desc>목록/최근글 공통 컬럼. 순서는 ART_* 상수와 반드시 일치해야 한다.</Desc>
    '--------------------------------------------------------------------------
    ' 마지막 컬럼(ART_NO)은 화면에 찍는 글 번호다.
    ' 행 위치로 번호를 매기면 답변글이 번호를 소비해 "5 - 3 2" 처럼 중간이 빈,
    ' 즉 삭제된 글이 있는 것처럼 보인다. 그래서 원글 묶음(group_no)의 순위를 쓴다.
    '   · 가장 오래된 원글 = 1, 최신 원글 = 원글 총수
    '   · 답변글은 원글과 같은 번호를 받는다 (화면에서는 - 로 표시)
    '   · 윈도 함수는 OFFSET 적용 전에 계산되므로 페이지를 넘겨도 번호가 어긋나지 않는다
    ' DENSE_RANK 는 표준 SQL 이라 PostgreSQL 이식에도 그대로 쓴다.
    '--------------------------------------------------------------------------
    Private Function ListCols()
        ListCols = " a.article_id, a.board_id, COALESCE(a.category_id,0), COALESCE(c.category_name,''), " & _
                   " a.title, COALESCE(a.writer_id,0), COALESCE(m.nickname, a.writer_name), " & _
                   " a.hit_count, a.comment_count, a.file_count, a.like_count, " & _
                   " a.is_notice, a.is_secret, a.reg_dt, COALESCE(a.thumb_file,''), " & _
                   " COALESCE(a.tags,''), a.group_depth, " & _
                   " LEFT(CAST(COALESCE(a.content,'') AS NVARCHAR(4000)), 400), " & _
                   " CAST(DENSE_RANK() OVER (ORDER BY a.group_no ASC) AS INT) "
    End Function

    Private Function ListFrom()
        ListFrom = "  FROM tb_board_article a " & _
                   "  LEFT JOIN tb_board_category c ON c.category_id = a.category_id " & _
                   "  LEFT JOIN tb_member         m ON m.member_id   = a.writer_id "
    End Function

    '<Desc>검색 WHERE 조각. 허용된 필드만 사용한다.</Desc>
    Private Function SearchWhere(ByVal pField, ByVal pWord)
        SearchWhere = ""
        If StringUtil.IsBlank(pWord) Then Exit Function
        Select Case LCase(pField)
            Case "title"   : SearchWhere = " AND a.title LIKE ? "
            Case "content" : SearchWhere = " AND CAST(a.content AS NVARCHAR(MAX)) LIKE ? "
            Case "writer"  : SearchWhere = " AND COALESCE(m.nickname, a.writer_name) LIKE ? "
            Case "tags"    : SearchWhere = " AND a.tags LIKE ? "
            Case Else      : SearchWhere = " AND (a.title LIKE ? OR CAST(a.content AS NVARCHAR(MAX)) LIKE ?) "
        End Select
    End Function

    '<Desc>SearchWhere 와 짝을 이루어 파라미터를 넣는다 (순서 일치 필수)</Desc>
    Private Sub SearchParams(ByVal pField, ByVal pWord)
        Dim kw
        If StringUtil.IsBlank(pWord) Then Exit Sub
        kw = "%" & Trim(pWord) & "%"
        Select Case LCase(pField)
            Case "title", "content", "writer", "tags"
                DBHelper.SetParamVarchar(kw)
            Case Else
                DBHelper.SetParamVarchar(kw)
                DBHelper.SetParamVarchar(kw)
        End Select
    End Sub

    '==========================================================================
    ' 목록
    '==========================================================================

    '<Desc>일반 글 목록 (공지 제외)</Desc>
    Public Function Article_l(ByVal pBoardId, ByVal pCategoryId, ByVal pField, ByVal pWord, _
                              ByVal pOffset, ByVal pRows)
        Dim wCate, wSrch
        wCate = "" : wSrch = SearchWhere(pField, pWord)
        If StringUtil.ToInt(pCategoryId, 0) > 0 Then wCate = " AND a.category_id = ? "

        With DBHelper
            .Sql = "SELECT " & ListCols() & ListFrom() & _
                   " WHERE a.board_id = ? AND a.is_del = 0 AND a.is_notice = 0 " & wCate & wSrch & _
                   " ORDER BY a.group_no DESC, a.group_order ASC " & _
                   " OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
            .SetParamVarchar(pBoardId)
            If StringUtil.ToInt(pCategoryId, 0) > 0 Then .SetParamInt(pCategoryId)
        End With
        SearchParams pField, pWord
        DBHelper.SetParamInt(pOffset)
        DBHelper.SetParamInt(pRows)

        Article_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>일반 글 총 건수 (Article_l 과 동일 조건)</Desc>
    Public Function Article_c(ByVal pBoardId, ByVal pCategoryId, ByVal pField, ByVal pWord)
        Dim wCate, wSrch, v
        wCate = "" : wSrch = SearchWhere(pField, pWord)
        If StringUtil.ToInt(pCategoryId, 0) > 0 Then wCate = " AND a.category_id = ? "

        With DBHelper
            .Sql = "SELECT COUNT(*) " & ListFrom() & _
                   " WHERE a.board_id = ? AND a.is_del = 0 AND a.is_notice = 0 " & wCate & wSrch
            .SetParamVarchar(pBoardId)
            If StringUtil.ToInt(pCategoryId, 0) > 0 Then .SetParamInt(pCategoryId)
        End With
        SearchParams pField, pWord

        v = DBHelper.ExecuteScalar()
        Article_c = StringUtil.ToInt(v, 0)
    End Function

    '<Desc>상단 고정 공지 (목록 1페이지에만 노출)</Desc>
    Public Function Notice_l(ByVal pBoardId)
        With DBHelper
            .Sql = "SELECT " & ListCols() & ListFrom() & _
                   " WHERE a.board_id = ? AND a.is_del = 0 AND a.is_notice = 1 " & _
                   " ORDER BY a.article_id DESC"
            .SetParamVarchar(pBoardId)
        End With
        Notice_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>메인 화면 위젯용 최근 글</Desc>
    Public Function Recent_l(ByVal pBoardId, ByVal pTop)
        With DBHelper
            .Sql = "SELECT TOP (?) " & ListCols() & ListFrom() & _
                   " WHERE a.board_id = ? AND a.is_del = 0 " & _
                   " ORDER BY a.article_id DESC"
            .SetParamInt(pTop)
            .SetParamVarchar(pBoardId)
        End With
        Recent_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>태그 목록 (블로그 사이드바)  arr(0)=tag arr(1)=cnt</Desc>
    Public Function TagCloud_l(ByVal pBoardId, ByVal pTop)
        With DBHelper
            .Sql = "SELECT TOP (?) LTRIM(RTRIM(s.value)) AS tag, COUNT(*) AS cnt " & _
                   "  FROM tb_board_article a " & _
                   " CROSS APPLY STRING_SPLIT(COALESCE(a.tags,''), ',') s " & _
                   " WHERE a.board_id = ? AND a.is_del = 0 AND LTRIM(RTRIM(s.value)) <> '' " & _
                   " GROUP BY LTRIM(RTRIM(s.value)) " & _
                   " ORDER BY COUNT(*) DESC, tag ASC"
            .SetParamInt(pTop)
            .SetParamVarchar(pBoardId)
        End With
        TagCloud_l = DBHelper.ExecuteGetRows()
    End Function

    '==========================================================================
    ' 상세
    '==========================================================================
    Public Function Article_v(ByVal pArticleId)
        With DBHelper
            .Sql = "SELECT a.article_id, a.board_id, COALESCE(a.category_id,0), COALESCE(c.category_name,''), " & _
                   "       a.title, COALESCE(a.content,''), a.content_type, " & _
                   "       COALESCE(a.writer_id,0), COALESCE(m.nickname, a.writer_name), " & _
                   "       COALESCE(a.writer_email,''), COALESCE(a.writer_ip,''), " & _
                   "       a.hit_count, a.comment_count, a.file_count, a.like_count, " & _
                   "       a.is_notice, a.is_secret, a.reg_dt, a.upd_dt, " & _
                   "       COALESCE(a.tags,''), COALESCE(a.thumb_file,''), COALESCE(a.link_url,''), " & _
                   "       a.group_no, a.group_order, a.group_depth, " & _
                   "       CASE WHEN a.writer_pw IS NULL THEN 0 ELSE 1 END " & _
                   "  FROM tb_board_article a " & _
                   "  LEFT JOIN tb_board_category c ON c.category_id = a.category_id " & _
                   "  LEFT JOIN tb_member         m ON m.member_id   = a.writer_id " & _
                   " WHERE a.article_id = ? AND a.is_del = 0"
            .SetParamBigInt(pArticleId)
        End With
        Article_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>이전글 / 다음글  arr(0)=id arr(1)=title  (pDir : "prev" | "next")</Desc>
    Public Function Sibling_v(ByVal pBoardId, ByVal pArticleId, ByVal pDir)
        Dim op, ord
        If LCase(pDir) = "prev" Then
            op = "<" : ord = "DESC"          ' 목록이 최신순이므로 "이전글" = 더 오래된 글
        Else
            op = ">" : ord = "ASC"
        End If

        With DBHelper
            .Sql = "SELECT TOP 1 article_id, title FROM tb_board_article " & _
                   " WHERE board_id = ? AND is_del = 0 AND is_notice = 0 AND article_id " & op & " ? " & _
                   " ORDER BY article_id " & ord
            .SetParamVarchar(pBoardId)
            .SetParamBigInt(pArticleId)
        End With
        Sibling_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>조회수 증가 (같은 세션에서 중복 증가 방지는 Code 계층에서 처리)</Desc>
    Public Sub HitUp(ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET hit_count = hit_count + 1 WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>비회원 글 비밀번호 확인</Desc>
    Public Function ChkGuestPw(ByVal pArticleId, ByVal pPlainPw)
        Dim v
        ChkGuestPw = False
        With DBHelper
            .Sql = "SELECT COALESCE(writer_pw,'') FROM tb_board_article WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Then Exit Function
        If Len(Trim(v & "")) <> 64 Then Exit Function
        ChkGuestPw = (LCase(Trim(v & "")) = Crypt.HashGuestPw(pPlainPw))
    End Function

    '==========================================================================
    ' 등록 / 수정 / 삭제
    '==========================================================================

    '<Desc>새 글 등록. 새 article_id 반환</Desc>
    Public Function Article_i(ByVal pBoardId, ByVal pCategoryId, ByVal pTitle, ByVal pContent, _
                              ByVal pWriterId, ByVal pWriterName, ByVal pWriterPwHash, ByVal pWriterEmail, _
                              ByVal pTags, ByVal pThumb, ByVal pLinkUrl, ByVal pIsNotice, ByVal pIsSecret)
        Dim newId

        With DBHelper
            .Sql = "INSERT INTO tb_board_article " & _
                   " (board_id, category_id, title, content, content_type, " & _
                   "  writer_id, writer_name, writer_pw, writer_email, writer_ip, " & _
                   "  tags, thumb_file, link_url, is_notice, is_secret, group_no, group_order, group_depth) " & _
                   "VALUES (?, ?, ?, ?, 'html', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0)"
            .SetParamVarchar(pBoardId)
            .SetParamInt(NullIfZero(pCategoryId))
            .SetParamVarchar(pTitle)
            .SetParamText(pContent)
            .SetParamInt(NullIfZero(pWriterId))
            .SetParamVarchar(pWriterName)
            .SetParamVarchar(pWriterPwHash)
            .SetParamVarchar(pWriterEmail)
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamVarchar(pTags)
            .SetParamVarchar(pThumb)
            .SetParamVarchar(pLinkUrl)
            .SetParamBit(pIsNotice)
            .SetParamBit(pIsSecret)
        End With
        newId = DBHelper.ExecuteIdentity()

        '--- 원글은 자기 자신을 그룹으로 ---
        If newId > 0 Then
            With DBHelper
                .Sql = "UPDATE tb_board_article SET group_no = ? WHERE article_id = ?"
                .SetParamBigInt(newId)
                .SetParamBigInt(newId)
            End With
            DBHelper.Execute()
        End If

        Article_i = newId
    End Function

    '<Desc>답변글 등록. 부모 글 아래 자리를 만들고 삽입한다.</Desc>
    Public Function Reply_i(ByVal pBoardId, ByVal pParentId, ByVal pTitle, ByVal pContent, _
                            ByVal pWriterId, ByVal pWriterName, ByVal pWriterPwHash, ByVal pWriterEmail)
        Dim arr, gNo, gOrder, gDepth, newId

        With DBHelper
            .Sql = "SELECT group_no, group_order, group_depth, COALESCE(category_id,0) " & _
                   "  FROM tb_board_article WHERE article_id = ? AND board_id = ?"
            .SetParamBigInt(pParentId)
            .SetParamVarchar(pBoardId)
        End With
        arr = DBHelper.ExecuteGetRows()
        If Not IsArray(arr) Then Reply_i = 0 : Exit Function

        gNo    = CDbl(arr(0, 0))
        gOrder = CLng(arr(1, 0))
        gDepth = CLng(arr(2, 0))

        '--- 같은 그룹에서 뒤쪽 글들을 한 칸씩 민다 ---
        With DBHelper
            .Sql = "UPDATE tb_board_article SET group_order = group_order + 1 " & _
                   " WHERE board_id = ? AND group_no = ? AND group_order > ?"
            .SetParamVarchar(pBoardId)
            .SetParamBigInt(gNo)
            .SetParamInt(gOrder)
        End With
        DBHelper.Execute()

        With DBHelper
            .Sql = "INSERT INTO tb_board_article " & _
                   " (board_id, category_id, title, content, content_type, " & _
                   "  writer_id, writer_name, writer_pw, writer_email, writer_ip, " & _
                   "  group_no, group_order, group_depth, parent_id) " & _
                   "VALUES (?, ?, ?, ?, 'html', ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pBoardId)
            .SetParamInt(NullIfZero(arr(3, 0)))
            .SetParamVarchar(pTitle)
            .SetParamText(pContent)
            .SetParamInt(NullIfZero(pWriterId))
            .SetParamVarchar(pWriterName)
            .SetParamVarchar(pWriterPwHash)
            .SetParamVarchar(pWriterEmail)
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamBigInt(gNo)
            .SetParamInt(gOrder + 1)
            .SetParamInt(gDepth + 1)
            .SetParamBigInt(pParentId)
        End With
        newId = DBHelper.ExecuteIdentity()

        Reply_i = newId
    End Function

    Public Sub Article_u(ByVal pArticleId, ByVal pCategoryId, ByVal pTitle, ByVal pContent, _
                         ByVal pTags, ByVal pThumb, ByVal pLinkUrl, ByVal pIsNotice, ByVal pIsSecret)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET " & _
                   "  category_id = ?, title = ?, content = ?, tags = ?, thumb_file = ?, " & _
                   "  link_url = ?, is_notice = ?, is_secret = ?, upd_dt = CURRENT_TIMESTAMP " & _
                   " WHERE article_id = ?"
            .SetParamInt(NullIfZero(pCategoryId))
            .SetParamVarchar(pTitle)
            .SetParamText(pContent)
            .SetParamVarchar(pTags)
            .SetParamVarchar(pThumb)
            .SetParamVarchar(pLinkUrl)
            .SetParamBit(pIsNotice)
            .SetParamBit(pIsSecret)
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>논리 삭제 (복구 가능)</Desc>
    Public Sub Article_d(ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET is_del = 1, upd_dt = CURRENT_TIMESTAMP WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>논리 삭제 복구 (관리자)</Desc>
    Public Sub Restore_u(ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET is_del = 0, upd_dt = CURRENT_TIMESTAMP WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>공지 지정 / 해제 토글 (관리자)</Desc>
    Public Sub NoticeToggle_u(ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET is_notice = CASE WHEN is_notice = 1 THEN 0 ELSE 1 END " & _
                   " WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>삭제 여부와 무관하게 1건 조회 (관리자용)</Desc>
    Public Function AdminArticle_v(ByVal pArticleId)
        With DBHelper
            .Sql = "SELECT article_id, board_id, title, COALESCE(writer_id,0), is_del, is_notice " & _
                   "  FROM tb_board_article WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        AdminArticle_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>물리 삭제 (관리자 전용. 댓글/첨부는 FK CASCADE 로 함께 삭제)</Desc>
    Public Sub Article_del_p(ByVal pArticleId)
        With DBHelper
            .Sql = "DELETE FROM tb_board_article WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>첨부 개수 / 댓글 개수 재계산</Desc>
    Public Sub SyncCount(ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE a SET " & _
                   "  a.comment_count = (SELECT COUNT(*) FROM tb_board_comment c " & _
                   "                      WHERE c.article_id = a.article_id AND c.is_del = 0), " & _
                   "  a.file_count    = (SELECT COUNT(*) FROM tb_board_file f " & _
                   "                      WHERE f.article_id = a.article_id) " & _
                   "  FROM tb_board_article a WHERE a.article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>대표 이미지 갱신 (갤러리/블로그 썸네일)</Desc>
    Public Sub Thumb_u(ByVal pArticleId, ByVal pThumb)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET thumb_file = ? WHERE article_id = ?"
            .SetParamVarchar(pThumb)
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()
    End Sub

    '==========================================================================
    ' 관리자
    '==========================================================================
    Public Function AdminArticle_l(ByVal pBoardId, ByVal pWord, ByVal pOffset, ByVal pRows)
        Dim wb, ww
        wb = "" : ww = ""
        If Not StringUtil.IsBlank(pBoardId) Then wb = " AND a.board_id = ? "
        If Not StringUtil.IsBlank(pWord)    Then ww = " AND a.title LIKE ? "

        With DBHelper
            .Sql = "SELECT a.article_id, a.board_id, b.board_name, a.title, " & _
                   "       COALESCE(m.nickname, a.writer_name), a.hit_count, a.comment_count, " & _
                   "       a.is_notice, a.is_del, a.reg_dt " & _
                   "  FROM tb_board_article a " & _
                   " INNER JOIN tb_board_master b ON b.board_id = a.board_id " & _
                   "  LEFT JOIN tb_member       m ON m.member_id = a.writer_id " & _
                   " WHERE 1 = 1 " & wb & ww & _
                   " ORDER BY a.article_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
            If Not StringUtil.IsBlank(pBoardId) Then .SetParamVarchar(pBoardId)
            If Not StringUtil.IsBlank(pWord)    Then .SetParamVarchar("%" & pWord & "%")
            .SetParamInt(pOffset)
            .SetParamInt(pRows)
        End With
        AdminArticle_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function AdminArticle_c(ByVal pBoardId, ByVal pWord)
        Dim wb, ww, v
        wb = "" : ww = ""
        If Not StringUtil.IsBlank(pBoardId) Then wb = " AND a.board_id = ? "
        If Not StringUtil.IsBlank(pWord)    Then ww = " AND a.title LIKE ? "

        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_board_article a WHERE 1 = 1 " & wb & ww
            If Not StringUtil.IsBlank(pBoardId) Then .SetParamVarchar(pBoardId)
            If Not StringUtil.IsBlank(pWord)    Then .SetParamVarchar("%" & pWord & "%")
        End With
        v = DBHelper.ExecuteScalar()
        AdminArticle_c = StringUtil.ToInt(v, 0)
    End Function

    '==========================================================================
    ' 내부 유틸
    '==========================================================================
    Private Function NullIfZero(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then NullIfZero = Null : Exit Function
        ' IsNumeric 은 BIGINT/DECIMAL(VT_DECIMAL) 을 숫자로 보지 않으므로 StringUtil.IsNum 을 쓴다
        If Not StringUtil.IsNum(v) Then NullIfZero = Null : Exit Function
        If CDbl(CStr(v)) <= 0 Then NullIfZero = Null Else NullIfZero = CLng(CDbl(CStr(v)))
    End Function

End Class

Dim Article
Set Article = New CArticle
%>
