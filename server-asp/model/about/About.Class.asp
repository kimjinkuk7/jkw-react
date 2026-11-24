<%
'==============================================================================
' model/about/About.Class.asp  -  경력·학력(tb_career) / 기술스택(tb_skill)
'==============================================================================

'--- Career_l() 결과 인덱스 --------------------------------------------------
Const CR_ID      = 0
Const CR_TYPE    = 1
Const CR_TITLE   = 2
Const CR_POSITION= 3
Const CR_ORGURL  = 4
Const CR_DESC    = 5
Const CR_START   = 6
Const CR_END     = 7
Const CR_CURRENT = 8

'--- Skill_l() 결과 인덱스 ---------------------------------------------------
Const SK_ID      = 0
Const SK_GROUP   = 1
Const SK_NAME    = 2
Const SK_LEVEL   = 3
Const SK_EXP     = 4
Const SK_DESC    = 5
Const SK_COLOR   = 6

Class CAbout

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '==========================================================================
    ' 경력 / 학력 / 수상 / 자격
    '==========================================================================

    '<Desc>pType 이 빈 값이면 전체</Desc>
    Public Function Career_l(ByVal pType)
        Dim wt
        wt = ""
        If Not StringUtil.IsBlank(pType) Then wt = " AND career_type = ? "

        With DBHelper
            .Sql = "SELECT career_id, career_type, title, COALESCE(position,''), " & _
                   "       COALESCE(org_url,''), COALESCE(description,''), " & _
                   "       date_start, date_end, is_current " & _
                   "  FROM tb_career WHERE is_use = 1 " & wt & _
                   " ORDER BY career_type, sort_no, date_start DESC"
            If Not StringUtil.IsBlank(pType) Then .SetParamVarchar(pType)
        End With
        Career_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>총 경력 년수 (work 타입의 기간 합산, 소수 1자리)</Desc>
    Public Function TotalYears()
        Dim v
        With DBHelper
            .Sql = "SELECT CAST(COALESCE(SUM(DATEDIFF(MONTH, date_start, " & _
                   "         COALESCE(date_end, CAST(CURRENT_TIMESTAMP AS DATE)))), 0) AS DECIMAL(6,1)) / 12.0 " & _
                   "  FROM tb_career WHERE career_type = 'work' AND is_use = 1 AND date_start IS NOT NULL"
        End With
        v = DBHelper.ExecuteScalar()
        If IsNull(v) Then TotalYears = 0 Else TotalYears = FormatNumber(CDbl(v), 1)
    End Function

    '==========================================================================
    ' 기술 스택
    '==========================================================================

    Public Function Skill_l(ByVal pGroup)
        Dim wg
        wg = ""
        If Not StringUtil.IsBlank(pGroup) Then wg = " AND skill_group = ? "

        With DBHelper
            .Sql = "SELECT skill_id, skill_group, skill_name, level_pct, " & _
                   "       COALESCE(experience_yr,0), COALESCE(skill_desc,''), COALESCE(color_hex,'') " & _
                   "  FROM tb_skill WHERE is_use = 1 " & wg & _
                   " ORDER BY skill_group, sort_no, skill_name"
            If Not StringUtil.IsBlank(pGroup) Then .SetParamVarchar(pGroup)
        End With
        Skill_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>스킬 그룹 목록  arr(0)=group arr(1)=cnt</Desc>
    Public Function SkillGroup_l()
        With DBHelper
            .Sql = "SELECT skill_group, COUNT(*) FROM tb_skill WHERE is_use = 1 " & _
                   " GROUP BY skill_group ORDER BY MIN(sort_no), skill_group"
        End With
        SkillGroup_l = DBHelper.ExecuteGetRows()
    End Function

    '==========================================================================
    ' 관리자 - 경력
    '==========================================================================
    Public Function CareerAll_l()
        With DBHelper
            .Sql = "SELECT career_id, career_type, title, COALESCE(position,''), " & _
                   "       COALESCE(org_url,''), COALESCE(description,''), " & _
                   "       date_start, date_end, is_current, sort_no, is_use " & _
                   "  FROM tb_career ORDER BY career_type, sort_no, date_start DESC"
        End With
        CareerAll_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function Career_v(ByVal pId)
        With DBHelper
            .Sql = "SELECT career_id, career_type, title, COALESCE(position,''), " & _
                   "       COALESCE(org_url,''), COALESCE(description,''), " & _
                   "       date_start, date_end, is_current, sort_no, is_use " & _
                   "  FROM tb_career WHERE career_id = ?"
            .SetParamInt(pId)
        End With
        Career_v = DBHelper.ExecuteGetRows()
    End Function

    Public Sub Career_i(ByVal pType, ByVal pTitle, ByVal pPosition, ByVal pOrgUrl, ByVal pDesc, _
                        ByVal pStart, ByVal pEnd, ByVal pCurrent, ByVal pSortNo)
        With DBHelper
            .Sql = "INSERT INTO tb_career " & _
                   " (career_type, title, position, org_url, description, date_start, date_end, is_current, sort_no) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pType)
            .SetParamVarchar(pTitle)
            .SetParamVarchar(pPosition)
            .SetParamVarchar(pOrgUrl)
            .SetParamVarchar(pDesc)
            .SetParamDateOnly(pStart)
            .SetParamDateOnly(pEnd)
            .SetParamBit(pCurrent)
            .SetParamInt(pSortNo)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Career_u(ByVal pId, ByVal pType, ByVal pTitle, ByVal pPosition, ByVal pOrgUrl, ByVal pDesc, _
                        ByVal pStart, ByVal pEnd, ByVal pCurrent, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_career SET career_type = ?, title = ?, position = ?, org_url = ?, " & _
                   "  description = ?, date_start = ?, date_end = ?, is_current = ?, sort_no = ?, is_use = ? " & _
                   " WHERE career_id = ?"
            .SetParamVarchar(pType)
            .SetParamVarchar(pTitle)
            .SetParamVarchar(pPosition)
            .SetParamVarchar(pOrgUrl)
            .SetParamVarchar(pDesc)
            .SetParamDateOnly(pStart)
            .SetParamDateOnly(pEnd)
            .SetParamBit(pCurrent)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Career_d(ByVal pId)
        With DBHelper
            .Sql = "DELETE FROM tb_career WHERE career_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    '==========================================================================
    ' 관리자 - 기술 스택
    '==========================================================================
    Public Function SkillAll_l()
        With DBHelper
            .Sql = "SELECT skill_id, skill_group, skill_name, level_pct, " & _
                   "       COALESCE(experience_yr,0), COALESCE(skill_desc,''), COALESCE(color_hex,''), " & _
                   "       sort_no, is_use " & _
                   "  FROM tb_skill ORDER BY skill_group, sort_no, skill_name"
        End With
        SkillAll_l = DBHelper.ExecuteGetRows()
    End Function

    Public Sub Skill_i(ByVal pGroup, ByVal pName, ByVal pLevel, ByVal pExp, ByVal pDesc, ByVal pColor, ByVal pSortNo)
        With DBHelper
            .Sql = "INSERT INTO tb_skill (skill_group, skill_name, level_pct, experience_yr, skill_desc, color_hex, sort_no) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pGroup)
            .SetParamVarchar(pName)
            .SetParamInt(pLevel)
            .SetParamFloat(pExp)
            .SetParamVarchar(pDesc)
            .SetParamVarchar(pColor)
            .SetParamInt(pSortNo)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Skill_u(ByVal pId, ByVal pGroup, ByVal pName, ByVal pLevel, ByVal pExp, _
                       ByVal pDesc, ByVal pColor, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_skill SET skill_group = ?, skill_name = ?, level_pct = ?, " & _
                   "  experience_yr = ?, skill_desc = ?, color_hex = ?, sort_no = ?, is_use = ? " & _
                   " WHERE skill_id = ?"
            .SetParamVarchar(pGroup)
            .SetParamVarchar(pName)
            .SetParamInt(pLevel)
            .SetParamFloat(pExp)
            .SetParamVarchar(pDesc)
            .SetParamVarchar(pColor)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Skill_d(ByVal pId)
        With DBHelper
            .Sql = "DELETE FROM tb_skill WHERE skill_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

End Class

Dim About
Set About = New CAbout
%>
