<%
'==============================================================================
' model/contact/Contact.Class.asp  -  문의하기 (tb_contact)
'==============================================================================

Const CT_ID      = 0
Const CT_TYPE    = 1
Const CT_NAME    = 2
Const CT_COMPANY = 3
Const CT_EMAIL   = 4
Const CT_MOBILE  = 5
Const CT_SUBJECT = 6
Const CT_CONTENT = 7
Const CT_ISREAD  = 8
Const CT_ISREPLY = 9
Const CT_REPLY   = 10
Const CT_REPLYDT = 11
Const CT_IP      = 12
Const CT_REGDT   = 13

Class CContact

    Public DBHelper

    Private Sub Class_Initialize()
        Set DBHelper = New CDBHelper
        DBHelper.ConnectionString = ConnectionString(DBCONN_JKWCOM)
    End Sub

    Private Function Cols()
        Cols = " contact_id, COALESCE(contact_type,''), writer_name, COALESCE(company,''), " & _
               " email, COALESCE(mobile,''), subject, content, is_read, is_reply, " & _
               " COALESCE(reply_content,''), reply_dt, COALESCE(writer_ip,''), reg_dt "
    End Function

    '<Desc>문의 등록. 새 contact_id 반환</Desc>
    Public Function Contact_i(ByVal pType, ByVal pName, ByVal pCompany, ByVal pEmail, _
                              ByVal pMobile, ByVal pSubject, ByVal pContent, ByVal pAgree)
        With DBHelper
            .Sql = "INSERT INTO tb_contact " & _
                   " (contact_type, writer_name, company, email, mobile, subject, content, is_agree, writer_ip) " & _
                   "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            .SetParamVarchar(pType)
            .SetParamVarchar(pName)
            .SetParamVarchar(pCompany)
            .SetParamVarchar(pEmail)
            .SetParamVarchar(pMobile)
            .SetParamVarchar(pSubject)
            .SetParamText(pContent)
            .SetParamBit(pAgree)
            .SetParamVarchar(RequestUtil.ClientIp())
        End With
        Contact_i = DBHelper.ExecuteIdentity()
    End Function

    '<Desc>같은 IP 의 최근 도배 방지 : 최근 pMinutes 분 내 등록 건수</Desc>
    Public Function RecentByIp_c(ByVal pMinutes)
        Dim v
        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_contact " & _
                   " WHERE writer_ip = ? AND reg_dt > DATEADD(MINUTE, -?, CURRENT_TIMESTAMP)"
            .SetParamVarchar(RequestUtil.ClientIp())
            .SetParamInt(pMinutes)
        End With
        v = DBHelper.ExecuteScalar()
        RecentByIp_c = StringUtil.ToInt(v, 0)
    End Function

    '==========================================================================
    ' 관리자
    '==========================================================================
    Public Function Contact_l(ByVal pWord, ByVal pOnlyUnread, ByVal pOffset, ByVal pRows)
        Dim ww, wu
        ww = "" : wu = ""
        If Not StringUtil.IsBlank(pWord) Then ww = " AND (subject LIKE ? OR writer_name LIKE ? OR email LIKE ?) "
        If StringUtil.ToBool(pOnlyUnread)  Then wu = " AND is_read = 0 "

        With DBHelper
            .Sql = "SELECT " & Cols() & " FROM tb_contact WHERE 1 = 1 " & ww & wu & _
                   " ORDER BY contact_id DESC OFFSET ? ROWS FETCH NEXT ? ROWS ONLY"
            If Not StringUtil.IsBlank(pWord) Then
                .SetParamVarchar("%" & pWord & "%")
                .SetParamVarchar("%" & pWord & "%")
                .SetParamVarchar("%" & pWord & "%")
            End If
            .SetParamInt(pOffset)
            .SetParamInt(pRows)
        End With
        Contact_l = DBHelper.ExecuteGetRows()
    End Function

    Public Function Contact_c(ByVal pWord, ByVal pOnlyUnread)
        Dim ww, wu, v
        ww = "" : wu = ""
        If Not StringUtil.IsBlank(pWord) Then ww = " AND (subject LIKE ? OR writer_name LIKE ? OR email LIKE ?) "
        If StringUtil.ToBool(pOnlyUnread)  Then wu = " AND is_read = 0 "

        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_contact WHERE 1 = 1 " & ww & wu
            If Not StringUtil.IsBlank(pWord) Then
                .SetParamVarchar("%" & pWord & "%")
                .SetParamVarchar("%" & pWord & "%")
                .SetParamVarchar("%" & pWord & "%")
            End If
        End With
        v = DBHelper.ExecuteScalar()
        Contact_c = StringUtil.ToInt(v, 0)
    End Function

    Public Function Contact_v(ByVal pId)
        With DBHelper
            .Sql = "SELECT " & Cols() & " FROM tb_contact WHERE contact_id = ?"
            .SetParamInt(pId)
        End With
        Contact_v = DBHelper.ExecuteGetRows()
    End Function

    Public Sub Read_u(ByVal pId)
        With DBHelper
            .Sql = "UPDATE tb_contact SET is_read = 1 WHERE contact_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Reply_u(ByVal pId, ByVal pReply)
        With DBHelper
            .Sql = "UPDATE tb_contact SET reply_content = ?, is_reply = 1, is_read = 1, " & _
                   "       reply_dt = CURRENT_TIMESTAMP WHERE contact_id = ?"
            .SetParamText(pReply)
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Sub Contact_d(ByVal pId)
        With DBHelper
            .Sql = "DELETE FROM tb_contact WHERE contact_id = ?"
            .SetParamInt(pId)
        End With
        DBHelper.Execute()
    End Sub

    Public Function Unread_c()
        Dim v
        With DBHelper
            .Sql = "SELECT COUNT(*) FROM tb_contact WHERE is_read = 0"
        End With
        v = DBHelper.ExecuteScalar()
        Unread_c = StringUtil.ToInt(v, 0)
    End Function

End Class

Dim Contact
Set Contact = New CContact
%>
