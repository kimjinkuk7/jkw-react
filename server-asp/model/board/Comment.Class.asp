<%
'==============================================================================
' model/board/Comment.Class.asp  -  댓글 (tb_board_comment)
'------------------------------------------------------------------------------
' 1단계 대댓글까지 지원 (comment_depth 0 / 1)
' 정렬 : 부모 댓글 순서 → 그 아래 대댓글
'==============================================================================

'--- Comment_l() 결과 인덱스 -------------------------------------------------
Const CMT_ID     = 0
Const CMT_PARENT = 1
Const CMT_DEPTH  = 2
Const CMT_CONTENT= 3
Const CMT_WID    = 4
Const CMT_WNAME  = 5
Const CMT_HASPW  = 6
Const CMT_SECRET = 7
Const CMT_REGDT  = 8
Const CMT_WLEVEL = 9

Class CComment

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '<Desc>게시글의 댓글 전체 (부모 → 대댓글 순)</Desc>
    Public Function Comment_l(ByVal pArticleId)
        With DBHelper
            .Sql = "SELECT c.comment_id, COALESCE(c.parent_id,0), c.comment_depth, c.content, " & _
                   "       COALESCE(c.writer_id,0), COALESCE(m.nickname, c.writer_name), " & _
                   "       CASE WHEN c.writer_pw IS NULL THEN 0 ELSE 1 END, " & _
                   "       c.is_secret, c.reg_dt, COALESCE(m.member_level,0) " & _
                   "  FROM tb_board_comment c " & _
                   "  LEFT JOIN tb_member m ON m.member_id = c.writer_id " & _
                   " WHERE c.article_id = ? AND c.is_del = 0 " & _
                   " ORDER BY COALESCE(NULLIF(c.parent_id, 0), c.comment_id), c.comment_id"
            .SetParamBigInt(pArticleId)
        End With
        Comment_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>댓글 1건 (권한 확인용)  arr(0)=article_id arr(1)=writer_id arr(2)=has_pw</Desc>
    Public Function Comment_v(ByVal pCommentId)
        With DBHelper
            .Sql = "SELECT article_id, COALESCE(writer_id,0), " & _
                   "       CASE WHEN writer_pw IS NULL THEN 0 ELSE 1 END, board_id, content " & _
                   "  FROM tb_board_comment WHERE comment_id = ? AND is_del = 0"
            .SetParamBigInt(pCommentId)
        End With
        Comment_v = DBHelper.ExecuteGetRows()
    End Function

    Public Function Comment_i(ByVal pArticleId, ByVal pBoardId, ByVal pParentId, _
                              ByVal pContent, ByVal pWriterId, ByVal pWriterName, _
                              ByVal pWriterPwHash, ByVal pIsSecret)
        Dim depth, newId

        depth = 0
        If StringUtil.ToInt(pParentId, 0) > 0 Then depth = 1

        With DBHelper
            .Sql = "INSERT INTO tb_board_comment " & _
                   " (article_id, board_id, parent_id, comment_depth, content, " & _
                   "  writer_id, writer_name, writer_pw, writer_ip, is_secret) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamBigInt(pArticleId)
            .SetParamVarchar(pBoardId)
            .SetParamBigInt(NullIfZero(pParentId))
            .SetParamInt(depth)
            .SetParamVarchar(pContent)
            .SetParamInt(NullIfZero(pWriterId))
            .SetParamVarchar(pWriterName)
            .SetParamVarchar(pWriterPwHash)
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamBit(pIsSecret)
        End With
        newId = DBHelper.ExecuteIdentity()

        Article.SyncCount pArticleId
        Comment_i = newId
    End Function

    Public Sub Comment_u(ByVal pCommentId, ByVal pContent)
        With DBHelper
            .Sql = "UPDATE tb_board_comment SET content = ?, upd_dt = CURRENT_TIMESTAMP WHERE comment_id = ?"
            .SetParamVarchar(pContent)
            .SetParamBigInt(pCommentId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>논리 삭제 후 게시글의 댓글수 재계산</Desc>
    Public Sub Comment_d(ByVal pCommentId, ByVal pArticleId)
        With DBHelper
            .Sql = "UPDATE tb_board_comment SET is_del = 1 WHERE comment_id = ? OR parent_id = ?"
            .SetParamBigInt(pCommentId)
            .SetParamBigInt(pCommentId)
        End With
        DBHelper.Execute()

        Article.SyncCount pArticleId
    End Sub

    Public Function ChkGuestPw(ByVal pCommentId, ByVal pPlainPw)
        Dim v
        ChkGuestPw = False
        With DBHelper
            .Sql = "SELECT COALESCE(writer_pw,'') FROM tb_board_comment WHERE comment_id = ?"
            .SetParamBigInt(pCommentId)
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Then Exit Function
        If Len(Trim(v & "")) <> 64 Then Exit Function
        ChkGuestPw = (LCase(Trim(v & "")) = Crypt.HashGuestPw(pPlainPw))
    End Function

    '<Desc>최근 댓글 (메인/관리자)  arr : id, board_id, article_id, content, writer, reg_dt</Desc>
    Public Function Recent_l(ByVal pTop)
        With DBHelper
            .Sql = "SELECT TOP (?) c.comment_id, c.board_id, c.article_id, c.content, " & _
                   "       COALESCE(m.nickname, c.writer_name), c.reg_dt, a.title " & _
                   "  FROM tb_board_comment c " & _
                   " INNER JOIN tb_board_article a ON a.article_id = c.article_id AND a.is_del = 0 " & _
                   "  LEFT JOIN tb_member m ON m.member_id = c.writer_id " & _
                   " WHERE c.is_del = 0 " & _
                   " ORDER BY c.comment_id DESC"
            .SetParamInt(pTop)
        End With
        Recent_l = DBHelper.ExecuteGetRows()
    End Function

    Private Function NullIfZero(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then NullIfZero = Null : Exit Function
        ' IsNumeric 은 BIGINT/DECIMAL(VT_DECIMAL) 을 숫자로 보지 않으므로 StringUtil.IsNum 을 쓴다
        If Not StringUtil.IsNum(v) Then NullIfZero = Null : Exit Function
        If CDbl(CStr(v)) <= 0 Then NullIfZero = Null Else NullIfZero = CDbl(CStr(v))
    End Function

End Class

Dim Comment
Set Comment = New CComment
%>
