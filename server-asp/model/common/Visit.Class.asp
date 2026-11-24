<%
'==============================================================================
' model/common/Visit.Class.asp  -  방문 로그 / 통계 (tb_visit_log, tb_visit_stat)
'==============================================================================
Class CVisit

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    '<Desc>페이지뷰 1건 기록. 실패해도 화면은 정상 진행시킨다.</Desc>
    Public Sub Visit_i(ByVal pPageUrl)
        On Error Resume Next
        With DBHelper
            .Sql = "INSERT INTO tb_visit_log " & _
                   "  (visit_date, ip, member_id, page_url, referer, user_agent, device_type) " & _
                   "VALUES (CAST(CURRENT_TIMESTAMP AS DATE), ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamInt(IIfZeroNull(Auth.MyId()))
            .SetParamVarchar(Left(pPageUrl, 300))
            .SetParamVarchar(Left(GLB_REFERER, 500))
            .SetParamVarchar(RequestUtil.UserAgent())
            .SetParamVarchar(RequestUtil.DeviceType())
        End With
        DBHelper.Execute()
        On Error GoTo 0
    End Sub

    Private Function IIfZeroNull(ByVal v)
        If IsNumeric(v) Then
            If CLng(v) > 0 Then IIfZeroNull = CLng(v) : Exit Function
        End If
        IIfZeroNull = Null
    End Function

    '<Desc>오늘 / 전체 방문수  arr(0)=today arr(1)=total</Desc>
    Public Function Counter_v()
        With DBHelper
            .Sql = "SELECT " & _
                   "  (SELECT COUNT(*) FROM tb_visit_log WHERE visit_date = CAST(CURRENT_TIMESTAMP AS DATE)), " & _
                   "  (SELECT COALESCE(SUM(total_cnt),0) FROM tb_visit_stat) + " & _
                   "  (SELECT COUNT(*) FROM tb_visit_log)"
        End With
        Counter_v = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>최근 N일 일별 통계  arr(0)=date arr(1)=total arr(2)=unique</Desc>
    Public Function Stat_l(ByVal pDays)
        With DBHelper
            .Sql = "SELECT CONVERT(VARCHAR(10), v.visit_date, 120), COUNT(*), COUNT(DISTINCT v.ip) " & _
                   "  FROM tb_visit_log v " & _
                   " WHERE v.visit_date > DATEADD(DAY, -?, CAST(CURRENT_TIMESTAMP AS DATE)) " & _
                   " GROUP BY v.visit_date " & _
                   " ORDER BY v.visit_date DESC"
            .SetParamInt(pDays)
        End With
        Stat_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>기기별 비율  arr(0)=device arr(1)=cnt</Desc>
    Public Function DeviceStat_l(ByVal pDays)
        With DBHelper
            .Sql = "SELECT COALESCE(device_type,'pc'), COUNT(*) " & _
                   "  FROM tb_visit_log " & _
                   " WHERE visit_date > DATEADD(DAY, -?, CAST(CURRENT_TIMESTAMP AS DATE)) " & _
                   " GROUP BY COALESCE(device_type,'pc') ORDER BY COUNT(*) DESC"
            .SetParamInt(pDays)
        End With
        DeviceStat_l = DBHelper.ExecuteGetRows()
    End Function

    '<Desc>일별 집계 프로시저 실행 (관리자 수동 / 에이전트용)</Desc>
    Public Sub Aggregate_p()
        On Error Resume Next
        With DBHelper
            .StoredProc = "dbo.usp_visit_stat_aggregate"
            .SetParamDateOnly(Date())
        End With
        DBHelper.Execute()
        On Error GoTo 0
    End Sub

End Class

Dim Visit
Set Visit = New CVisit
%>
