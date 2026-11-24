<%
'==============================================================================
' model/common/Menu.Class.asp  -  사이트 메뉴 (tb_menu)
'------------------------------------------------------------------------------
' GNB 는 이 테이블로 자동 생성된다. 메뉴 추가 = INSERT 1건, 코드 수정 0줄.
'==============================================================================

'--- Menu_l() 결과 배열 인덱스 -----------------------------------------------
Const MNU_ID     = 0
Const MNU_PARENT = 1
Const MNU_CODE   = 2
Const MNU_NAME   = 3
Const MNU_URL    = 4
Const MNU_TARGET = 5
Const MNU_DEPTH  = 6

Class CMenu

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '<Desc>노출 가능한 전체 메뉴 (1·2 depth 를 정렬 순서대로 한 번에)</Desc>
    '<Param name="pLevel">현재 사용자 권한 레벨</Param>
    Public Function Menu_l(ByVal pLevel)
        With DBHelper
            .Sql = "SELECT m.menu_id, COALESCE(m.parent_id, 0), m.menu_code, m.menu_name, " & _
                   "       COALESCE(m.menu_url, ''), m.menu_target, m.menu_depth " & _
                   "  FROM tb_menu m " & _
                   "  LEFT JOIN tb_menu p ON p.menu_id = m.parent_id " & _
                   " WHERE m.is_use = 1 AND m.auth_level <= ? " & _
                   "   AND (m.parent_id IS NULL OR p.is_use = 1) " & _
                   " ORDER BY COALESCE(p.sort_no, m.sort_no), m.menu_depth, m.sort_no"
            .SetParamInt(pLevel)
        End With
        Menu_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>특정 1depth 메뉴의 하위 메뉴 (LNB 용)</Desc>
    Public Function SubMenu_l(ByVal pParentCode, ByVal pLevel)
        With DBHelper
            .Sql = "SELECT m.menu_id, COALESCE(m.parent_id,0), m.menu_code, m.menu_name, " & _
                   "       COALESCE(m.menu_url,''), m.menu_target, m.menu_depth " & _
                   "  FROM tb_menu m " & _
                   " INNER JOIN tb_menu p ON p.menu_id = m.parent_id " & _
                   " WHERE p.menu_code = ? AND m.is_use = 1 AND m.auth_level <= ? " & _
                   " ORDER BY m.sort_no"
            .SetParamVarchar(pParentCode)
            .SetParamInt(pLevel)
        End With
        SubMenu_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>메뉴 코드로 1건 조회 (menu_name, menu_url)</Desc>
    Public Function Menu_v(ByVal pCode)
        With DBHelper
            .Sql = "SELECT menu_id, COALESCE(parent_id,0), menu_code, menu_name, " & _
                   "       COALESCE(menu_url,''), menu_target, menu_depth " & _
                   "  FROM tb_menu WHERE menu_code = ?"
            .SetParamVarchar(pCode)
        End With
        Menu_v = DBHelper.ExecuteGetRows()
    End Function

    '--------------------------------------------------------------------------
    ' 관리자
    '--------------------------------------------------------------------------
    Public Function MenuAll_l()
        With DBHelper
            .Sql = "SELECT m.menu_id, COALESCE(m.parent_id,0), m.menu_code, m.menu_name, " & _
                   "       COALESCE(m.menu_url,''), m.menu_target, m.menu_depth, m.sort_no, " & _
                   "       m.auth_level, m.is_use " & _
                   "  FROM tb_menu m " & _
                   "  LEFT JOIN tb_menu p ON p.menu_id = m.parent_id " & _
                   " ORDER BY COALESCE(p.sort_no, m.sort_no), m.menu_depth, m.sort_no"
        End With
        MenuAll_l = DBHelper.ExecuteGetRows()
    End Function

    Public Sub Menu_u(ByVal pMenuId, ByVal pName, ByVal pUrl, ByVal pSortNo, ByVal pAuthLevel, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_menu SET menu_name = ?, menu_url = ?, sort_no = ?, " & _
                   "       auth_level = ?, is_use = ? WHERE menu_id = ?"
            .SetParamVarchar(pName)
            .SetParamVarchar(pUrl)
            .SetParamInt(pSortNo)
            .SetParamInt(pAuthLevel)
            .SetParamBit(pIsUse)
            .SetParamInt(pMenuId)
        End With
        DBHelper.Execute()
    End Sub

End Class

Dim Menu
Set Menu = New CMenu
%>
