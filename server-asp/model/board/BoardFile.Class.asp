<%
'==============================================================================
' model/board/BoardFile.Class.asp  -  게시판 첨부파일 (tb_board_file)
'------------------------------------------------------------------------------
' 물리 파일명(save_name)은 예측 불가능한 키로 저장하여 원본명 노출과
' 덮어쓰기를 막는다. 다운로드는 반드시 view/board/Download.asp 를 경유한다.
'==============================================================================

'--- File_l() 결과 인덱스 ----------------------------------------------------
Const BF_ID       = 0
Const BF_ORGNAME  = 1
Const BF_SAVENAME = 2
Const BF_SAVEPATH = 3
Const BF_SIZE     = 4
Const BF_EXT      = 5
Const BF_ISIMAGE  = 6
Const BF_DOWNCNT  = 7

Class CBoardFile

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '<Desc>게시글의 첨부 목록</Desc>
    Public Function File_l(ByVal pArticleId)
        With DBHelper
            .Sql = "SELECT file_id, org_name, save_name, save_path, file_size, " & _
                   "       COALESCE(file_ext,''), is_image, down_count " & _
                   "  FROM tb_board_file WHERE article_id = ? ORDER BY sort_no, file_id"
            .SetParamBigInt(pArticleId)
        End With
        File_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>파일 1건 (다운로드용)</Desc>
    Public Function File_v(ByVal pFileId)
        With DBHelper
            .Sql = "SELECT f.file_id, f.org_name, f.save_name, f.save_path, f.file_size, " & _
                   "       COALESCE(f.file_ext,''), f.is_image, f.down_count, " & _
                   "       f.board_id, f.article_id " & _
                   "  FROM tb_board_file f WHERE f.file_id = ?"
            .SetParamBigInt(pFileId)
        End With
        File_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>게시글의 첫 번째 이미지 (썸네일 자동 지정용). 없으면 ""</Desc>
    Public Function FirstImage_v(ByVal pArticleId)
        Dim v
        With DBHelper
            .Sql = "SELECT TOP 1 CONCAT(save_path, '/', save_name) " & _
                   "  FROM tb_board_file WHERE article_id = ? AND is_image = 1 " & _
                   " ORDER BY sort_no, file_id"
            .SetParamBigInt(pArticleId)
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Then FirstImage_v = "" Else FirstImage_v = CStr(v)
    End Function

    Public Function File_i(ByVal pArticleId, ByVal pBoardId, ByVal pOrgName, ByVal pSaveName, _
                           ByVal pSavePath, ByVal pSize, ByVal pExt, ByVal pSortNo)
        Dim newId
        With DBHelper
            .Sql = "INSERT INTO tb_board_file " & _
                   " (article_id, board_id, org_name, save_name, save_path, file_size, file_ext, is_image, sort_no) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamBigInt(pArticleId)
            .SetParamVarchar(pBoardId)
            .SetParamVarchar(pOrgName)
            .SetParamVarchar(pSaveName)
            .SetParamVarchar(pSavePath)
            .SetParamInt(pSize)
            .SetParamVarchar(pExt)
            .SetParamBit(StringUtil.IsImageExt(pExt))
            .SetParamInt(pSortNo)
        End With
        newId = DBHelper.ExecuteIdentity()

        Article.SyncCount pArticleId
        File_i = newId
    End Function

    '<Desc>DB 레코드 + 물리 파일 삭제</Desc>
    Public Sub File_d(ByVal pFileId)
        Dim arr, articleId, phys

        arr = File_v(pFileId)
        If Not IsArray(arr) Then Exit Sub

        articleId = arr(9, 0)
        phys = Server.MapPath(UpUrl(arr(BF_SAVEPATH, 0)) & "/" & arr(BF_SAVENAME, 0))

        With DBHelper
            .Sql = "DELETE FROM tb_board_file WHERE file_id = ?"
            .SetParamBigInt(pFileId)
        End With
        DBHelper.Execute()

        DeletePhysFile phys
        Article.SyncCount articleId
    End Sub

    '<Desc>게시글의 첨부 전체 삭제 (물리 파일 포함)</Desc>
    Public Sub FileAll_d(ByVal pArticleId)
        Dim arr, i
        arr = File_l(pArticleId)
        If Not IsArray(arr) Then Exit Sub

        For i = 0 To UBound(arr, 2)
            DeletePhysFile Server.MapPath(UpUrl(arr(BF_SAVEPATH, i)) & "/" & arr(BF_SAVENAME, i))
        Next

        With DBHelper
            .Sql = "DELETE FROM tb_board_file WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        DBHelper.Execute()

        Article.SyncCount pArticleId
    End Sub

    Public Sub DownCountUp(ByVal pFileId)
        With DBHelper
            .Sql = "UPDATE tb_board_file SET down_count = down_count + 1 WHERE file_id = ?"
            .SetParamBigInt(pFileId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>현재 첨부 개수 (개수 제한 검사용)</Desc>
    Public Function File_c(ByVal pArticleId)
        Dim v
        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_board_file WHERE article_id = ?"
            .SetParamBigInt(pArticleId)
        End With
        v = DBHelper.ExecuteScalar()
        File_c = StringUtil.ToInt(v, 0)
    End Function

End Class

Dim BoardFile
Set BoardFile = New CBoardFile
%>
