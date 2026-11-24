<%
'==============================================================================
' model/common/Config.Class.asp  -  사이트 설정 (tb_config)
'------------------------------------------------------------------------------
' 사용 : Config.Value("site_title")
'        Config.ValueInit("owner_email", "admin@localhost")
'==============================================================================
Class CConfig

    Public  DBHelper
    Private mMap
    Private mLoaded

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
        Set mMap = Server.CreateObject("Scripting.Dictionary")
        mMap.CompareMode = 1
        mLoaded = False
    End Sub

    Private Sub Class_Terminate()
        Set mMap = Nothing
    End Sub

    '<Desc>tb_config 전체를 1회 로드하여 Dictionary 에 캐시</Desc>
    Public Sub Load()
        Dim arr, i
        If mLoaded Then Exit Sub

        With DBHelper
            .Sql = "SELECT config_key, COALESCE(config_value, '') FROM tb_config"
        End With
        arr = DBHelper.ExecuteGetRows()

        If IsArray(arr) Then
            For i = 0 To UBound(arr, 2)
                If Not mMap.Exists(arr(0, i) & "") Then
                    mMap.Add arr(0, i) & "", arr(1, i) & ""
                End If
            Next
        End If
        mLoaded = True
    End Sub

    Public Default Function Value(ByVal pKey)
        Load
        If mMap.Exists(pKey) Then
            Value = mMap(pKey) & ""
        Else
            Value = ""
        End If
    End Function

    Public Function ValueInit(ByVal pKey, ByVal pInit)
        Dim v
        v = Value(pKey)
        If Len(v) = 0 Then ValueInit = pInit Else ValueInit = v
    End Function

    Public Function ValueInt(ByVal pKey, ByVal pInit)
        Dim v
        v = Value(pKey)
        If Len(v) = 0 Or Not IsNumeric(v) Then ValueInt = pInit Else ValueInt = CLng(v)
    End Function

    Public Function ValueBool(ByVal pKey)
        ValueBool = (Value(pKey) = "1")
    End Function

    '--------------------------------------------------------------------------
    ' 관리자
    '--------------------------------------------------------------------------

    '<Desc>그룹별 설정 목록  arr(0)=key arr(1)=value arr(2)=group arr(3)=desc</Desc>
    Public Function Config_l(ByVal pGroup)
        With DBHelper
            .Sql = "SELECT config_key, COALESCE(config_value,''), config_group, COALESCE(config_desc,'') " & _
                   "  FROM tb_config " & _
                   " WHERE (? = '' OR config_group = ?) " & _
                   " ORDER BY config_group, config_key"
            .SetParamVarchar(pGroup)
            .SetParamVarchar(pGroup)
        End With
        Config_l = DBHelper.ExecuteGetRows()
    End Function

    Public Sub Config_u(ByVal pKey, ByVal pValue)
        With DBHelper
            .Sql = "UPDATE tb_config SET config_value = ?, upd_dt = CURRENT_TIMESTAMP WHERE config_key = ?"
            .SetParamText(pValue)
            .SetParamVarchar(pKey)
        End With
        DBHelper.Execute()
        If mMap.Exists(pKey) Then mMap(pKey) = pValue & ""
    End Sub

End Class

Dim Config
Set Config = New CConfig
%>
