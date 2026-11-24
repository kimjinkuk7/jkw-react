<%
'==============================================================================
' lib/DBHelper.Class.asp  -  데이터 접근 헬퍼
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 이 사용하는 _Gcommon/Helper/DBHelper.Class.asp 의 API 를 재현.
'        (StoredProc / SetParamXxx / SetOutput / Execute / ExecuteGetRows /
'         GetParameter / ConnectionString)
'
' 확장 : .Sql 프로퍼티를 추가하여 파라미터 바인딩 SQL 도 쓸 수 있게 함.
'        저장 프로시저는 PostgreSQL 이식 시 전부 재작성해야 하므로,
'        이 프로젝트는 인라인 파라미터 SQL 을 기본으로 한다.
'
' ★ ADODB 를 직접 다루는 유일한 파일. 모델/코드 계층은 이 클래스만 사용한다.
' ★ SQL 문자열에 값을 직접 붙이지 말 것. 반드시 ? 플레이스홀더 + SetParamXxx.
'------------------------------------------------------------------------------
' 사용 예 (모델 클래스 안에서)
'
'   Public Function Article_l(ByVal pBoardId, ByVal pOffset, ByVal pRows)
'       With DBHelper
'           .Sql = "SELECT article_id, title FROM tb_board_article " & _
'                  " WHERE board_id = ? AND is_del = 0 " & _
'                  " ORDER BY group_no DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
'           .SetParamVarchar(pBoardId)
'           .SetParamInt(pOffset)
'           .SetParamInt(pRows)
'       End With
'       Article_l = DBHelper.ExecuteGetRows()      ' 2차원 배열 arr(컬럼, 행) 또는 Empty
'   End Function
'==============================================================================

'--- ADO 상수 ----------------------------------------------------------------
Const adUseClient        = 3
Const adOpenStatic       = 3
Const adLockReadOnly     = 1
Const adCmdText          = 1
Const adCmdStoredProc    = 4
Const adExecuteNoRecords = 128
Const adStateOpen        = 1

Const adParamInput       = 1
Const adParamOutput      = 2
Const adParamReturnValue = 4

Const adSmallInt         = 2
Const adInteger          = 3
Const adSingle           = 4
Const adDouble           = 5
Const adCurrency         = 6
Const adDate             = 7
Const adBoolean          = 11
Const adBigInt           = 20
Const adNumeric          = 131
Const adDBDate           = 133
Const adDBTimeStamp      = 135
Const adVarChar          = 200
Const adLongVarChar      = 201
Const adVarWChar         = 202
Const adLongVarWChar     = 203


Class CDBHelper

    Private mConnStr
    Private mCmdText
    Private mIsProc
    Private mParams          ' Dictionary : idx -> Array(name, type, direction, size, value)
    Private mParamCount
    Private mOutValues       ' Dictionary : "@name" -> 실행 후 값
    Private mAffected

    '--------------------------------------------------------------------------
    ' 생성자 / 소멸자
    '--------------------------------------------------------------------------
    Private Sub Class_Initialize()
        Set mParams    = Server.CreateObject("Scripting.Dictionary")
        Set mOutValues = Server.CreateObject("Scripting.Dictionary")
        mParamCount = 0
        mIsProc     = False
        mCmdText    = ""
        mConnStr    = ""
        mAffected   = 0
    End Sub

    Private Sub Class_Terminate()
        Set mParams    = Nothing
        Set mOutValues = Nothing
    End Sub

    '--------------------------------------------------------------------------
    ' 프로퍼티
    '--------------------------------------------------------------------------
    Public Property Let ConnectionString(ByVal v)
        mConnStr = v
    End Property
    Public Property Get ConnectionString()
        ConnectionString = mConnStr
    End Property

    '--- 저장 프로시저 지정 (지정 시 파라미터 초기화) ---
    Public Property Let StoredProc(ByVal v)
        mCmdText = v
        mIsProc  = True
        ClearParams
    End Property

    '--- 인라인 SQL 지정 (지정 시 파라미터 초기화) ---
    Public Property Let Sql(ByVal v)
        mCmdText = v
        mIsProc  = False
        ClearParams
    End Property

    Public Property Get CommandText()
        CommandText = mCmdText
    End Property

    '--- 마지막 실행의 영향 행 수 ---
    Public Property Get Affected()
        Affected = mAffected
    End Property

    Public Sub ClearParams()
        mParams.RemoveAll
        mOutValues.RemoveAll
        mParamCount = 0
    End Sub

    '--------------------------------------------------------------------------
    ' 파라미터 등록
    '--------------------------------------------------------------------------
    Private Sub Push(ByVal pName, ByVal pType, ByVal pDir, ByVal pSize, ByVal pVal)
        mParams.Add mParamCount, Array(pName, pType, pDir, pSize, pVal)
        mParamCount = mParamCount + 1
    End Sub

    '--- 문자열 (NVARCHAR) : 빈 문자열도 그대로 전달, Null 이면 NULL ---
    Public Sub SetParamVarchar(ByVal v)
        Dim s, n
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adVarWChar, adParamInput, 1, Null
        Else
            s = CStr(v)
            n = Len(s)
            If n = 0 Then n = 1
            If n > 4000 Then
                Push "", adLongVarWChar, adParamInput, n, s
            Else
                Push "", adVarWChar, adParamInput, n, s
            End If
        End If
    End Sub

    '--- 긴 문자열 (NVARCHAR(MAX)) ---
    Public Sub SetParamText(ByVal v)
        Dim s, n
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adLongVarWChar, adParamInput, 1, Null
        Else
            s = CStr(v)
            n = Len(s)
            If n = 0 Then n = 1
            Push "", adLongVarWChar, adParamInput, n, s
        End If
    End Sub

    '--- 숫자 판정 : VBScript 의 IsNumeric 은 VT_DECIMAL(BIGINT/DECIMAL 컬럼에서
    '    ADO 가 돌려주는 타입)을 숫자로 보지 않는다. 그대로 쓰면 BIGINT id 를
    '    파라미터로 넘길 때 조용히 NULL 이 되어버린다. CStr 로 바꿔 판정한다.
    '    (lib 간 의존을 만들지 않기 위해 StringUtil 을 쓰지 않고 여기에 둔다)
    Private Function NumOk(ByVal v)
        Dim s
        NumOk = False
        On Error Resume Next
        s = Trim(CStr(v) & "")
        If Err.Number <> 0 Then Err.Clear : Exit Function
        On Error GoTo 0
        If Len(s) = 0 Then Exit Function
        NumOk = IsNumeric(s)
    End Function

    '--- 정수 : 비어있거나 숫자가 아니면 NULL ---
    Public Sub SetParamInt(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adInteger, adParamInput, 0, Null
        ElseIf Not NumOk(v) Then
            Push "", adInteger, adParamInput, 0, Null
        Else
            Push "", adInteger, adParamInput, 0, CLng(CDbl(CStr(v)))
        End If
    End Sub

    '--- 정수 : NULL 대신 0 을 쓰고 싶을 때 ---
    Public Sub SetParamIntZero(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adInteger, adParamInput, 0, 0
        ElseIf Not NumOk(v) Then
            Push "", adInteger, adParamInput, 0, 0
        Else
            Push "", adInteger, adParamInput, 0, CLng(CDbl(CStr(v)))
        End If
    End Sub

    Public Sub SetParamBigInt(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adBigInt, adParamInput, 0, Null
        ElseIf Not NumOk(v) Then
            Push "", adBigInt, adParamInput, 0, Null
        Else
            Push "", adBigInt, adParamInput, 0, CDbl(CStr(v))
        End If
    End Sub

    Public Sub SetParamFloat(ByVal v)
        If IsNull(v) Or IsEmpty(v) Or Not NumOk(v) Then
            Push "", adDouble, adParamInput, 0, Null
        Else
            Push "", adDouble, adParamInput, 0, CDbl(CStr(v))
        End If
    End Sub

    '--- BIT : 0/1 로 전달 ---
    Public Sub SetParamBit(ByVal v)
        Dim b
        b = 0
        If Not (IsNull(v) Or IsEmpty(v)) Then
            If VarType(v) = vbBoolean Then
                If v Then b = 1
            ElseIf IsNumeric(v) Then
                If CLng(v) <> 0 Then b = 1
            ElseIf LCase(CStr(v)) = "true" Or CStr(v) = "1" Or LCase(CStr(v)) = "y" Then
                b = 1
            End If
        End If
        Push "", adBoolean, adParamInput, 0, CBool(b = 1)
    End Sub

    '--- 날짜/시간 : 날짜가 아니면 NULL ---
    Public Sub SetParamDate(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adDBTimeStamp, adParamInput, 0, Null
        ElseIf Not IsDate(v) Then
            Push "", adDBTimeStamp, adParamInput, 0, Null
        Else
            Push "", adDBTimeStamp, adParamInput, 0, CDate(v)
        End If
    End Sub

    '--- 날짜만 (DATE 컬럼) ---
    Public Sub SetParamDateOnly(ByVal v)
        If IsNull(v) Or IsEmpty(v) Then
            Push "", adDBDate, adParamInput, 0, Null
        ElseIf Not IsDate(v) Then
            Push "", adDBDate, adParamInput, 0, Null
        Else
            Push "", adDBDate, adParamInput, 0, CDate(v)
        End If
    End Sub

    Public Sub SetParamNull()
        Push "", adVarWChar, adParamInput, 1, Null
    End Sub

    '--- 저장 프로시저 OUTPUT 파라미터 ---
    Public Sub SetOutput(ByVal pName, ByVal pType)
        Push pName, pType, adParamOutput, 0, Null
    End Sub

    Public Sub SetOutputSize(ByVal pName, ByVal pType, ByVal pSize)
        Push pName, pType, adParamOutput, pSize, Null
    End Sub

    '--- 실행 후 OUTPUT 값 읽기 ---
    Public Function GetParameter(ByVal pName)
        If mOutValues.Exists(pName) Then
            GetParameter = mOutValues(pName)
        Else
            GetParameter = Null
        End If
    End Function

    '--------------------------------------------------------------------------
    ' 내부 : Command 생성
    '--------------------------------------------------------------------------
    Private Function BuildCmd()
        Dim cmd, i, a, p

        Set cmd = Server.CreateObject("ADODB.Command")
        Set cmd.ActiveConnection = SharedConn(mConnStr)

        If mIsProc Then
            cmd.CommandType = adCmdStoredProc
        Else
            cmd.CommandType = adCmdText
        End If

        cmd.CommandText    = mCmdText
        cmd.CommandTimeout = DB_TIMEOUT_CMD
        cmd.Prepared       = False

        For i = 0 To mParamCount - 1
            a = mParams(i)
            Set p = cmd.CreateParameter(a(0), a(1), a(2), a(3), a(4))
            cmd.Parameters.Append p
            Set p = Nothing
        Next

        Set BuildCmd = cmd
    End Function

    '--- 실행 후 OUTPUT 파라미터 값 회수 ---
    Private Sub CaptureOutputs(ByRef cmd)
        Dim i, a
        For i = 0 To mParamCount - 1
            a = mParams(i)
            If a(2) = adParamOutput And a(0) <> "" Then
                On Error Resume Next
                mOutValues(a(0)) = cmd.Parameters(a(0)).Value
                On Error GoTo 0
            End If
        Next
    End Sub

    '--------------------------------------------------------------------------
    ' 실행
    '--------------------------------------------------------------------------

    '--- 결과셋 없는 실행 (INSERT / UPDATE / DELETE / 프로시저) ---
    Public Sub Execute()
        Dim cmd, n, en, ed
        Set cmd = BuildCmd()

        On Error Resume Next
        cmd.Execute n, , adExecuteNoRecords
        en = Err.Number : ed = Err.Description
        On Error GoTo 0

        If en <> 0 Then DBFail "Execute", mCmdText, ed

        If IsNumeric(n) Then mAffected = CLng(n) Else mAffected = 0
        CaptureOutputs cmd
        Set cmd = Nothing
    End Sub

    '--- 2차원 배열 반환 : arr(컬럼인덱스, 행인덱스). 결과 없으면 Empty ---
    '    ZOCBOv7 모델 계층의 표준 반환 형태. IsArray() 로 판정한다.
    Public Function ExecuteGetRows()
        Dim cmd, rs, en, ed
        ExecuteGetRows = Empty

        Set cmd = BuildCmd()
        Set rs  = Server.CreateObject("ADODB.Recordset")
        rs.CursorLocation = adUseClient

        On Error Resume Next
        rs.Open cmd, , adOpenStatic, adLockReadOnly
        en = Err.Number : ed = Err.Description
        On Error GoTo 0

        If en <> 0 Then DBFail "ExecuteGetRows", mCmdText, ed

        If rs.State = adStateOpen Then
            If Not (rs.BOF And rs.EOF) Then ExecuteGetRows = rs.GetRows()
            rs.Close
        End If

        Set rs = Nothing
        CaptureOutputs cmd
        Set cmd = Nothing
    End Function

    '--- 연결 해제된 Recordset 반환 (컬럼명으로 접근해야 할 때) ---
    Public Function ExecuteGetRs()
        Dim cmd, rs, en, ed

        Set cmd = BuildCmd()
        Set rs  = Server.CreateObject("ADODB.Recordset")
        rs.CursorLocation = adUseClient

        On Error Resume Next
        rs.Open cmd, , adOpenStatic, adLockReadOnly
        en = Err.Number : ed = Err.Description
        On Error GoTo 0

        If en <> 0 Then DBFail "ExecuteGetRs", mCmdText, ed

        If rs.State = adStateOpen Then Set rs.ActiveConnection = Nothing
        Set cmd = Nothing
        Set ExecuteGetRs = rs
    End Function

    '--- 첫 행 첫 컬럼 (없으면 Null) ---
    Public Function ExecuteScalar()
        Dim arr
        ExecuteScalar = Null
        arr = ExecuteGetRows()
        If IsArray(arr) Then
            If UBound(arr, 2) >= 0 Then ExecuteScalar = arr(0, 0)
        End If
    End Function

    '--- INSERT 후 새 IDENTITY 값 반환 (.Sql 전용) ---
    '    SET NOCOUNT ON 을 붙여야 INSERT 의 rowcount 결과셋이 끼어들지 않는다.
    Public Function ExecuteIdentity()
        Dim v
        mCmdText = "SET NOCOUNT ON; " & mCmdText & "; SELECT CAST(SCOPE_IDENTITY() AS BIGINT) AS new_id;"
        v = ExecuteScalar()
        If IsNull(v) Or IsEmpty(v) Then
            ExecuteIdentity = 0
        Else
            ExecuteIdentity = CDbl(v)
        End If
    End Function

End Class


'##############################################################################
' 전역 : 공유 커넥션
'------------------------------------------------------------------------------
' 모델 클래스마다 DBHelper 를 하나씩 갖지만, 커넥션은 요청당 1개만 연다.
'##############################################################################
Function SharedConn(ByVal pConnStr)
    Dim en, ed

    If g_sharedConn Is Nothing Then
        Set g_sharedConn = Server.CreateObject("ADODB.Connection")
        g_sharedConn.CursorLocation    = adUseClient
        g_sharedConn.ConnectionTimeout = DB_TIMEOUT_CONN
        g_sharedConn.CommandTimeout    = DB_TIMEOUT_CMD

        On Error Resume Next
        g_sharedConn.Open pConnStr
        en = Err.Number : ed = Err.Description
        On Error GoTo 0

        If en <> 0 Then
            Set g_sharedConn = Nothing
            DBFail "DB 접속", pConnStr, ed
        End If
    End If

    Set SharedConn = g_sharedConn
End Function

Sub DBDisconnect()
    On Error Resume Next
    If Not (g_sharedConn Is Nothing) Then
        If g_sharedConn.State = adStateOpen Then g_sharedConn.Close
        Set g_sharedConn = Nothing
    End If
    On Error GoTo 0
End Sub

'--- 트랜잭션 ----------------------------------------------------------------
Sub TxBegin()
    SharedConn(ConnectionString(DBCONN_JKWCOM)).BeginTrans
End Sub

Sub TxCommit()
    On Error Resume Next
    g_sharedConn.CommitTrans
    On Error GoTo 0
End Sub

Sub TxRollback()
    On Error Resume Next
    g_sharedConn.RollbackTrans
    On Error GoTo 0
End Sub


'##############################################################################
' 전역 : DB 오류 화면
'##############################################################################
Sub DBFail(ByVal pWhere, ByVal pSql, ByVal pDesc)
    Dim h
    Response.Clear
    Response.Status = "500 Internal Server Error"

    h = "<!DOCTYPE html><html lang=""ko""><head><meta charset=""utf-8"">" & _
        "<meta name=""viewport"" content=""width=device-width,initial-scale=1"">" & _
        "<title>데이터베이스 오류</title><style>" & _
        "body{font:15px/1.7 -apple-system,'Malgun Gothic',sans-serif;margin:0;padding:40px 16px;background:#f6f7f9;color:#212529}" & _
        ".box{max-width:860px;margin:0 auto;background:#fff;border:1px solid #e3e5e8;border-radius:12px;padding:28px}" & _
        "h1{font-size:19px;margin:0 0 6px}.sub{color:#6c757d;font-size:13px;margin:0 0 20px}" & _
        "dt{font-weight:700;font-size:13px;color:#495057;margin-top:14px}" & _
        "dd{margin:4px 0 0;font-family:Consolas,monospace;font-size:12.5px;white-space:pre-wrap;word-break:break-all;background:#f1f3f5;padding:10px 12px;border-radius:6px}" & _
        ".hint{margin-top:22px;font-size:13px;color:#495057;border-top:1px solid #eee;padding-top:16px}" & _
        ".hint code{background:#eef1f4;padding:1px 6px;border-radius:4px}" & _
        "</style></head><body><div class=""box"">"

    If DEBUG_MODE Then
        h = h & "<h1>데이터베이스 오류</h1>" & _
                "<p class=""sub"">DEBUG_MODE = True 이므로 상세 정보를 표시합니다. 운영 전 App.Conf.asp 에서 False 로 변경하세요.</p><dl>" & _
                "<dt>위치</dt><dd>" & HtmlEnc(pWhere) & "</dd>" & _
                "<dt>메시지</dt><dd>" & HtmlEnc(pDesc) & "</dd>" & _
                "<dt>SQL / 접속문자열</dt><dd>" & HtmlEnc(pSql) & "</dd></dl>" & _
                "<div class=""hint""><b>점검 순서</b><br>" & _
                "1. SQL Server 서비스 &rarr; <code>Start-Service MSSQLSERVER</code><br>" & _
                "2. DB/테이블 생성 &rarr; <code>db\mssql\01_schema.sql</code>, <code>02_seed.sql</code><br>" & _
                "3. IIS 응용 프로그램 풀 ID 에 <code>jkwcom</code> 접근 권한 부여<br>" & _
                "4. <code>App.Conf.asp</code> 의 DB_SERVER / DB_PROVIDER 확인" & _
                "</div>"
    Else
        h = h & "<h1>일시적인 오류가 발생했습니다</h1><p class=""sub"">잠시 후 다시 시도해 주세요.</p>"
    End If

    h = h & "</div></body></html>"
    Response.Write h
    Response.End
End Sub
%>
