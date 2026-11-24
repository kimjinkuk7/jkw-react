<%
'==============================================================================
' model/portfolio/Portfolio.Class.asp  -  포트폴리오 (tb_portfolio, tb_portfolio_skill)
'==============================================================================

'--- Portfolio_l() / Main_l() 결과 인덱스 ------------------------------------
Const PF_ID       = 0
Const PF_TITLE    = 1
Const PF_SUBTITLE = 2
Const PF_SUMMARY  = 3
Const PF_CATEGORY = 4
Const PF_CLIENT   = 5
Const PF_ROLE     = 6
Const PF_START    = 7
Const PF_END      = 8
Const PF_ONGOING  = 9
Const PF_SITEURL  = 10
Const PF_REPOURL  = 11
Const PF_THUMB    = 12
Const PF_HIT      = 13
Const PF_ISMAIN   = 14

'--- Portfolio_v() 는 위 항목 + 아래 2개 -------------------------------------
Const PFV_CONTENT = 15
Const PFV_TEAM    = 16

Class CPortfolio

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    Private Function Cols()
        Cols = " portfolio_id, title, COALESCE(subtitle,''), COALESCE(summary,''), " & _
               " COALESCE(category,''), COALESCE(client_name,''), COALESCE(job_role,''), " & _
               " period_start, period_end, is_ongoing, " & _
               " COALESCE(site_url,''), COALESCE(repo_url,''), COALESCE(thumb_file,''), " & _
               " hit_count, is_main "
    End Function

    '==========================================================================
    ' 조회
    '==========================================================================
    Public Function Portfolio_l(ByVal pCategory, ByVal pOffset, ByVal pRows)
        Dim wc
        wc = ""
        If Not StringUtil.IsBlank(pCategory) Then wc = " AND category = ? "

        With DBHelper
            .Sql = "SELECT " & Cols() & " FROM tb_portfolio WHERE is_use = 1 " & wc & _
                   " ORDER BY sort_no, portfolio_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
            If Not StringUtil.IsBlank(pCategory) Then .SetParamVarchar(pCategory)
            .SetParamInt(pOffset)
            .SetParamInt(pRows)
        End With
        Portfolio_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function Portfolio_c(ByVal pCategory)
        Dim wc, v
        wc = ""
        If Not StringUtil.IsBlank(pCategory) Then wc = " AND category = ? "

        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_portfolio WHERE is_use = 1 " & wc
            If Not StringUtil.IsBlank(pCategory) Then .SetParamVarchar(pCategory)
        End With
        v = DBHelper.ExecuteScalar()
        Portfolio_c = StringUtil.ToInt(v, 0)
    End Function

    '<Desc>메인 화면 노출용</Desc>
    Public Function Main_l(ByVal pTop)
        With DBHelper
            .Sql = "SELECT TOP (?) " & Cols() & " FROM tb_portfolio " & _
                   " WHERE is_use = 1 AND is_main = 1 ORDER BY sort_no, portfolio_id DESC"
            .SetParamInt(pTop)
        End With
        Main_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function Portfolio_v(ByVal pId)
        With DBHelper
            .Sql = "SELECT " & Cols() & ", COALESCE(content,''), COALESCE(team_size,'') " & _
                   "  FROM tb_portfolio WHERE portfolio_id = ? AND is_use = 1"
            .SetParamInt(pId)
        End With
        Portfolio_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>사용 중인 카테고리 목록  arr(0)=category arr(1)=cnt</Desc>
    Public Function Category_l()
        With DBHelper
            .Sql = "SELECT COALESCE(category,'ETC'), COUNT(*) FROM tb_portfolio " & _
                   " WHERE is_use = 1 GROUP BY COALESCE(category,'ETC') ORDER BY COUNT(*) DESC"
        End With
        Category_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>해당 포트폴리오의 기술 스택  arr(0)=skill_name arr(1)=color_hex</Desc>
    Public Function Skill_l(ByVal pPortfolioId)
        With DBHelper
            .Sql = "SELECT s.skill_name, COALESCE(s.color_hex,'') " & _
                   "  FROM tb_portfolio_skill ps " & _
                   " INNER JOIN tb_skill s ON s.skill_id = ps.skill_id " & _
                   " WHERE ps.portfolio_id = ? ORDER BY ps.sort_no, s.skill_name"
            .SetParamInt(pPortfolioId)
        End With
        Skill_l = DBHelper.ExecuteGetRows()
    End Function

    Public Sub HitUp(ByVal pId)
        With DBHelper
            .Sql = "UPDATE tb_portfolio SET hit_count = hit_count + 1 WHERE portfolio_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>이전/다음 프로젝트  arr(0)=id arr(1)=title</Desc>
    Public Function Sibling_v(ByVal pId, ByVal pDir)
        Dim op, ord
        If LCase(pDir) = "prev" Then op = ">" : ord = "ASC" Else op = "<" : ord = "DESC"
        With DBHelper
            .Sql = "SELECT TOP 1 portfolio_id, title FROM tb_portfolio " & _
                   " WHERE is_use = 1 AND portfolio_id " & op & " ? ORDER BY portfolio_id " & ord
            .SetParamInt(pId)
        End With
        Sibling_v = DBHelper.ExecuteGetRows()
    End Function

    '==========================================================================
    ' 관리자
    '==========================================================================
    Public Function AdminAll_l()
        With DBHelper
            .Sql = "SELECT " & Cols() & ", COALESCE(content,''), COALESCE(team_size,''), is_use, sort_no " & _
                   "  FROM tb_portfolio ORDER BY sort_no, portfolio_id DESC"
        End With
        AdminAll_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function Admin_v(ByVal pId)
        With DBHelper
            .Sql = "SELECT " & Cols() & ", COALESCE(content,''), COALESCE(team_size,''), is_use, sort_no " & _
                   "  FROM tb_portfolio WHERE portfolio_id = ?"
            .SetParamInt(pId)
        End With
        Admin_v = DBHelper.ExecuteGetRows()
    End Function

    Public Function Portfolio_i(ByVal pTitle, ByVal pSubtitle, ByVal pSummary, ByVal pContent, _
                                ByVal pCategory, ByVal pClient, ByVal pRole, ByVal pTeam, _
                                ByVal pStart, ByVal pEnd, ByVal pOngoing, _
                                ByVal pSiteUrl, ByVal pRepoUrl, ByVal pThumb, _
                                ByVal pIsMain, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "INSERT INTO tb_portfolio " & _
                   " (title, subtitle, summary, content, category, client_name, job_role, team_size, " & _
                   "  period_start, period_end, is_ongoing, site_url, repo_url, thumb_file, " & _
                   "  is_main, sort_no, is_use) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pTitle)
            .SetParamVarchar(pSubtitle)
            .SetParamVarchar(pSummary)
            .SetParamText(pContent)
            .SetParamVarchar(pCategory)
            .SetParamVarchar(pClient)
            .SetParamVarchar(pRole)
            .SetParamVarchar(pTeam)
            .SetParamDateOnly(pStart)
            .SetParamDateOnly(pEnd)
            .SetParamBit(pOngoing)
            .SetParamVarchar(pSiteUrl)
            .SetParamVarchar(pRepoUrl)
            .SetParamVarchar(pThumb)
            .SetParamBit(pIsMain)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
        End With
        Portfolio_i = DBHelper.ExecuteIdentity()
    End Function

    Public Sub Portfolio_u(ByVal pId, ByVal pTitle, ByVal pSubtitle, ByVal pSummary, ByVal pContent, _
                           ByVal pCategory, ByVal pClient, ByVal pRole, ByVal pTeam, _
                           ByVal pStart, ByVal pEnd, ByVal pOngoing, _
                           ByVal pSiteUrl, ByVal pRepoUrl, ByVal pThumb, _
                           ByVal pIsMain, ByVal pSortNo, ByVal pIsUse)
        With DBHelper
            .Sql = "UPDATE tb_portfolio SET title = ?, subtitle = ?, summary = ?, content = ?, " & _
                   "  category = ?, client_name = ?, job_role = ?, team_size = ?, " & _
                   "  period_start = ?, period_end = ?, is_ongoing = ?, " & _
                   "  site_url = ?, repo_url = ?, thumb_file = ?, " & _
                   "  is_main = ?, sort_no = ?, is_use = ?, upd_dt = CURRENT_TIMESTAMP " & _
                   " WHERE portfolio_id = ?"
            .SetParamVarchar(pTitle)
            .SetParamVarchar(pSubtitle)
            .SetParamVarchar(pSummary)
            .SetParamText(pContent)
            .SetParamVarchar(pCategory)
            .SetParamVarchar(pClient)
            .SetParamVarchar(pRole)
            .SetParamVarchar(pTeam)
            .SetParamDateOnly(pStart)
            .SetParamDateOnly(pEnd)
            .SetParamBit(pOngoing)
            .SetParamVarchar(pSiteUrl)
            .SetParamVarchar(pRepoUrl)
            .SetParamVarchar(pThumb)
            .SetParamBit(pIsMain)
            .SetParamInt(pSortNo)
            .SetParamBit(pIsUse)
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Portfolio_d(ByVal pId)
        With DBHelper
            .Sql = "DELETE FROM tb_portfolio WHERE portfolio_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    '<Desc>기술 스택 매핑 재설정 (콤마 구분 skill_id 목록)</Desc>
    Public Sub Skill_p(ByVal pPortfolioId, ByVal pSkillIds)
        Dim arr, i, sid, n

        With DBHelper
            .Sql = "DELETE FROM tb_portfolio_skill WHERE portfolio_id = ?"
            .SetParamInt(pPortfolioId)
        End With
        DBHelper.Execute()

        If StringUtil.IsBlank(pSkillIds) Then Exit Sub

        arr = Split(pSkillIds, ",")
        n = 0
        For i = 0 To UBound(arr)
            sid = StringUtil.ToInt(Trim(arr(i)), 0)
            If sid > 0 Then
                With DBHelper
                    .Sql = "INSERT INTO tb_portfolio_skill (portfolio_id, skill_id, sort_no) VALUES (?, ?, ?)"
                    .SetParamInt(pPortfolioId)
                    .SetParamInt(sid)
                    .SetParamInt(n)
                End With
                DBHelper.Execute()
                n = n + 1
            End If
        Next
    End Sub

    '<Desc>해당 포트폴리오에 매핑된 skill_id 목록 (콤마 문자열)</Desc>
    Public Function SkillIds(ByVal pPortfolioId)
        Dim arr, i, s
        s = ""
        With DBHelper
            .Sql = "SELECT skill_id FROM tb_portfolio_skill WHERE portfolio_id = ? ORDER BY sort_no"
            .SetParamInt(pPortfolioId)
        End With
        arr = DBHelper.ExecuteGetRows()
        If IsArray(arr) Then
            For i = 0 To UBound(arr, 2)
                If Len(s) > 0 Then s = s & ","
                s = s & arr(0, i)
            Next
        End If
        SkillIds = s
    End Function

End Class

Dim Portfolio
Set Portfolio = New CPortfolio
%>
