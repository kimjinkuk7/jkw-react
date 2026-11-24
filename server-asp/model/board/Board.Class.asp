<%
'==============================================================================
' model/board/Board.Class.asp  -  게시판 정의 (tb_board_master, tb_board_category)
'------------------------------------------------------------------------------
' ★ 이 프로젝트의 핵심 테이블.
'   행 1개 = 게시판 1개. 공지/자유/자료실/갤러리/블로그/방명록이 모두
'   같은 코드(code/board/*, view/board/*)로 동작하고, skin_type 으로 화면만 바뀐다.
'   게시판 추가 = INSERT 1건. ASP 코드 수정 0줄.
'==============================================================================

'--- Board_v() / Board_l() 결과 배열 인덱스 ----------------------------------
Const BM_ID          = 0
Const BM_NAME        = 1
Const BM_DESC        = 2
Const BM_SKIN        = 3
Const BM_LIST_COUNT  = 4
Const BM_PAGE_BLOCK  = 5
Const BM_GAL_COL     = 6
Const BM_USE_COMMENT = 7
Const BM_USE_FILE    = 8
Const BM_USE_CATEGORY= 9
Const BM_USE_SECRET  = 10
Const BM_USE_REPLY   = 11
Const BM_USE_EDITOR  = 12
Const BM_USE_NOTICE  = 13
Const BM_FILE_CNT    = 14
Const BM_FILE_SIZE   = 15
Const BM_FILE_EXT    = 16
Const BM_AUTH_LIST   = 17
Const BM_AUTH_READ   = 18
Const BM_AUTH_WRITE  = 19
Const BM_AUTH_COMMENT= 20
Const BM_AUTH_ADMIN  = 21
Const BM_SORT_NO     = 22
Const BM_IS_USE      = 23

'--- Category_l() 결과 배열 인덱스 -------------------------------------------
Const CAT_ID   = 0
Const CAT_BID  = 1
Const CAT_NAME = 2

Class CBoard

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    Private Function Cols()
        Cols = "board_id, board_name, COALESCE(board_desc,''), skin_type, " & _
               "list_count, page_block, gallery_col, " & _
               "use_comment, use_file, use_category, use_secret, use_reply, use_editor, use_notice, " & _
               "file_max_count, file_max_size, file_ext_allow, " & _
               "auth_list, auth_read, auth_write, auth_comment, auth_admin, sort_no, is_use "
    End Function

    '==========================================================================
    ' 조회
    '==========================================================================

    '<Desc>게시판 1건. 없거나 미사용이면 Empty</Desc>
    Public Function Board_v(ByVal pBoardId)
        With DBHelper
            .Sql = "SELECT " & Cols() & " FROM tb_board_master WHERE board_id = ? AND is_use = 1"
            .SetParamVarchar(pBoardId)
        End With
        Board_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>사용 중인 게시판 전체 (미사용 포함하려면 pAll = True)</Desc>
    Public Function Board_l(ByVal pAll)
        With DBHelper
            .Sql = "SELECT " & Cols() & " FROM tb_board_master " & _
                   " WHERE (? = 1 OR is_use = 1) ORDER BY sort_no, board_id"
            .SetParamBit(pAll)
        End With
        Board_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>게시판 분류 목록</Desc>
    Public Function Category_l(ByVal pBoardId)
        With DBHelper
            .Sql = "SELECT category_id, board_id, category_name " & _
                   "  FROM tb_board_category " & _
                   " WHERE board_id = ? AND is_use = 1 ORDER BY sort_no, category_id"
            .SetParamVarchar(pBoardId)
        End With
        Category_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>분류 ID 가 해당 게시판의 것인지 검증 (변조 방지)</Desc>
    Public Function IsValidCategory(ByVal pBoardId, ByVal pCategoryId)
        Dim v
        IsValidCategory = False
        If StringUtil.ToInt(pCategoryId, 0) <= 0 Then Exit Function
        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_board_category WHERE category_id = ? AND board_id = ?"
            .SetParamInt(pCategoryId)
            .SetParamVarchar(pBoardId)
        End With
        v = DBHelper.ExecuteScalar()
        IsValidCategory = (StringUtil.ToInt(v, 0) > 0)
    End Function

    '==========================================================================
    ' 권한 판정  (현재 로그인 레벨 >= 게시판 설정 레벨)
    '==========================================================================
    Public Function CanList(ByVal pBoard)    : CanList    = Allowed(pBoard, BM_AUTH_LIST)    : End Function
    Public Function CanRead(ByVal pBoard)    : CanRead    = Allowed(pBoard, BM_AUTH_READ)    : End Function
    Public Function CanWrite(ByVal pBoard)   : CanWrite   = Allowed(pBoard, BM_AUTH_WRITE)   : End Function
    Public Function CanComment(ByVal pBoard) : CanComment = Allowed(pBoard, BM_AUTH_COMMENT) : End Function
    Public Function CanAdmin(ByVal pBoard)   : CanAdmin   = Allowed(pBoard, BM_AUTH_ADMIN)   : End Function

    Private Function Allowed(ByVal pBoard, ByVal pIdx)
        Allowed = False
        If Not IsArray(pBoard) Then Exit Function
        Allowed = (Auth.MyLevel() >= StringUtil.ToInt(pBoard(pIdx, 0), 99))
    End Function

    '<Desc>글/댓글의 수정·삭제 권한 : 작성자 본인이거나 게시판 관리자</Desc>
    Public Function CanModify(ByVal pBoard, ByVal pWriterId)
        CanModify = False
        If CanAdmin(pBoard) Then CanModify = True : Exit Function
        If Auth.MyId() > 0 And StringUtil.ToInt(pWriterId, 0) = Auth.MyId() Then CanModify = True
    End Function

    '==========================================================================
    ' 관리자 - 게시판 CRUD
    '==========================================================================
    Public Sub Board_i(ByVal pBoardId, ByVal pName, ByVal pDesc, ByVal pSkin, ByVal pSortNo)
        With DBHelper
            .Sql = "INSERT INTO tb_board_master (board_id, board_name, board_desc, skin_type, sort_no) " & _
                   "VALUES (?, ?, ?, ?, ?)"
            .SetParamVarchar(pBoardId)
            .SetParamVarchar(pName)
            .SetParamVarchar(pDesc)
            .SetParamVarchar(pSkin)
            .SetParamInt(pSortNo)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Board_u(ByVal pBoardId, ByVal pName, ByVal pDesc, ByVal pSkin, _
                       ByVal pListCount, ByVal pPageBlock, ByVal pGalCol, _
                       ByVal pUseComment, ByVal pUseFile, ByVal pUseCategory, _
                       ByVal pUseSecret, ByVal pUseReply, ByVal pUseEditor, ByVal pUseNotice, _
                       ByVal pFileCnt, ByVal pFileSize, ByVal pFileExt, _
                       ByVal pAuthList, ByVal pAuthRead, ByVal pAuthWrite, _
                       ByVal pAuthComment, ByVal pAuthAdmin, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_board_master SET " & _
                   "  board_name = ?, board_desc = ?, skin_type = ?, " & _
                   "  list_count = ?, page_block = ?, gallery_col = ?, " & _
                   "  use_comment = ?, use_file = ?, use_category = ?, use_secret = ?, " & _
                   "  use_reply = ?, use_editor = ?, use_notice = ?, " & _
                   "  file_max_count = ?, file_max_size = ?, file_ext_allow = ?, " & _
                   "  auth_list = ?, auth_read = ?, auth_write = ?, auth_comment = ?, auth_admin = ?, " & _
                   "  sort_no = ?, is_use = ?, upd_dt = CURRENT_TIMESTAMP " & _
                   " WHERE board_id = ?"
            .SetParamVarchar(pName)
            .SetParamVarchar(pDesc)
            .SetParamVarchar(pSkin)
            .SetParamInt(pListCount)
            .SetParamInt(pPageBlock)
            .SetParamInt(pGalCol)
            .SetParamBit(pUseComment)
            .SetParamBit(pUseFile)
            .SetParamBit(pUseCategory)
            .SetParamBit(pUseSecret)
            .SetParamBit(pUseReply)
            .SetParamBit(pUseEditor)
            .SetParamBit(pUseNotice)
            .SetParamInt(pFileCnt)
            .SetParamInt(pFileSize)
            .SetParamVarchar(pFileExt)
            .SetParamInt(pAuthList)
            .SetParamInt(pAuthRead)
            .SetParamInt(pAuthWrite)
            .SetParamInt(pAuthComment)
            .SetParamInt(pAuthAdmin)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
            .SetParamVarchar(pBoardId)
        End With
        DBHelper.Execute()
    End Sub

    '==========================================================================
    ' 관리자 - 분류 CRUD
    '==========================================================================
    Public Sub Category_i(ByVal pBoardId, ByVal pName, ByVal pSortNo)
        With DBHelper
            .Sql = "INSERT INTO tb_board_category (board_id, category_name, sort_no) VALUES (?, ?, ?)"
            .SetParamVarchar(pBoardId)
            .SetParamVarchar(pName)
            .SetParamInt(pSortNo)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Category_u(ByVal pCategoryId, ByVal pName, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_board_category SET category_name = ?, sort_no = ?, is_use = ? WHERE category_id = ?"
            .SetParamVarchar(pName)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
            .SetParamInt(pCategoryId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Category_d(ByVal pCategoryId)
        With DBHelper
            .Sql = "UPDATE tb_board_article SET category_id = NULL WHERE category_id = ?"
            .SetParamInt(pCategoryId)
        End With
        DBHelper.Execute()

        With DBHelper
            .Sql = "DELETE FROM tb_board_category WHERE category_id = ?"
            .SetParamInt(pCategoryId)
        End With
        DBHelper.Execute()
    End Sub

End Class

Dim Board
Set Board = New CBoard
%>
