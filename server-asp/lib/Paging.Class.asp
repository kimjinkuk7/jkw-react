<%
'==============================================================================
' lib/Paging.Class.asp  -  페이징 클래스
'------------------------------------------------------------------------------
' 참조 : ZOCBOv7 / Lib/Paging.Class.asp (프로퍼티 Set 방식 유지)
'
' 사용 :
'   With Paging
'       .SetNowPage      = nowPage
'       .SetPageSize     = listCount
'       .SetPageBlock    = pageBlock
'       .SetResultCount  = totalCount
'       .SetPagingUrl    = "List.asp?bid=free&sw=" & UE(sw) & "&page={P}"
'   End With
'   Response.Write Paging.Render()
'
'   offset = Paging.Offset          ' OFFSET ? ROWS 에 넣을 값
'==============================================================================
Class CPaging

    Private mNowPage
    Private mPageSize
    Private mPageBlock
    Private mResultCount
    Private mPagingUrl

    Private Sub Class_Initialize()
        mNowPage     = 1
        mPageSize    = DEF_LIST_COUNT
        mPageBlock   = DEF_PAGE_BLOCK
        mResultCount = 0
        mPagingUrl   = "?page={P}"
    End Sub

    '--------------------------------------------------------------------------
    ' 입력 프로퍼티
    '--------------------------------------------------------------------------
    Public Property Let SetNowPage(ByVal v)
        If IsNumeric(v) Then mNowPage = CLng(v) Else mNowPage = 1
        If mNowPage < 1 Then mNowPage = 1
    End Property

    Public Property Let SetPageSize(ByVal v)
        If IsNumeric(v) Then mPageSize = CLng(v) Else mPageSize = DEF_LIST_COUNT
        If mPageSize < 1 Then mPageSize = DEF_LIST_COUNT
    End Property

    Public Property Let SetPageBlock(ByVal v)
        If IsNumeric(v) Then mPageBlock = CLng(v) Else mPageBlock = DEF_PAGE_BLOCK
        If mPageBlock < 1 Then mPageBlock = DEF_PAGE_BLOCK
    End Property

    Public Property Let SetResultCount(ByVal v)
        If IsNumeric(v) Then mResultCount = CLng(v) Else mResultCount = 0
        If mResultCount < 0 Then mResultCount = 0
    End Property

    Public Property Let SetPagingUrl(ByVal v)
        mPagingUrl = v
    End Property

    '--------------------------------------------------------------------------
    ' 계산 프로퍼티
    '--------------------------------------------------------------------------
    Public Property Get NowPage()
        NowPage = CurPage()
    End Property

    Public Property Get PageSize()
        PageSize = mPageSize
    End Property

    Public Property Get ResultCount()
        ResultCount = mResultCount
    End Property

    '<Desc>총 페이지 수 (최소 1)</Desc>
    Public Property Get TotalPage()
        Dim t
        t = Int((CDbl(mResultCount) + mPageSize - 1) / mPageSize)
        If t < 1 Then t = 1
        TotalPage = t
    End Property

    '<Desc>OFFSET ? ROWS 에 바인딩할 값</Desc>
    Public Property Get Offset()
        Offset = (CurPage() - 1) * mPageSize
    End Property

    '<Desc>목록 좌측 번호 (내림차순). 첫 행이 총건수, 아래로 감소</Desc>
    Public Property Get StartNo()
        StartNo = mResultCount - Offset
    End Property

    '<Desc>범위를 벗어난 페이지 요청을 보정한 현재 페이지</Desc>
    Private Function CurPage()
        Dim p
        p = mNowPage
        If p > TotalPage Then p = TotalPage
        If p < 1 Then p = 1
        CurPage = p
    End Function

    Private Function Link(ByVal p)
        Link = Replace(mPagingUrl, "{P}", CStr(p))
    End Function

    '--------------------------------------------------------------------------
    ' 렌더링
    '--------------------------------------------------------------------------

    '<Desc>번호형 페이지네이션 HTML</Desc>
    Public Function Render()
        Dim s, i, cur, tp, blockNo, sp, ep

        cur = CurPage()
        tp  = TotalPage()

        blockNo = Int((cur - 1) / mPageBlock)
        sp = blockNo * mPageBlock + 1
        ep = sp + mPageBlock - 1
        If ep > tp Then ep = tp

        s = "<nav class=""paging"" aria-label=""페이지 이동"">"

        If cur > 1 Then
            s = s & "<a class=""pg pg-edge"" href=""" & HE(Link(1))       & """ aria-label=""첫 페이지"">&laquo;</a>"
            s = s & "<a class=""pg pg-edge"" href=""" & HE(Link(cur - 1)) & """ aria-label=""이전 페이지"">&lsaquo;</a>"
        Else
            s = s & "<span class=""pg pg-edge is-off"" aria-hidden=""true"">&laquo;</span>"
            s = s & "<span class=""pg pg-edge is-off"" aria-hidden=""true"">&lsaquo;</span>"
        End If

        For i = sp To ep
            If i = cur Then
                s = s & "<strong class=""pg is-on"" aria-current=""page"">" & i & "</strong>"
            Else
                s = s & "<a class=""pg"" href=""" & HE(Link(i)) & """>" & i & "</a>"
            End If
        Next

        If cur < tp Then
            s = s & "<a class=""pg pg-edge"" href=""" & HE(Link(cur + 1)) & """ aria-label=""다음 페이지"">&rsaquo;</a>"
            s = s & "<a class=""pg pg-edge"" href=""" & HE(Link(tp))      & """ aria-label=""마지막 페이지"">&raquo;</a>"
        Else
            s = s & "<span class=""pg pg-edge is-off"" aria-hidden=""true"">&rsaquo;</span>"
            s = s & "<span class=""pg pg-edge is-off"" aria-hidden=""true"">&raquo;</span>"
        End If

        s = s & "</nav>"
        Render = s
    End Function

    '<Desc>모바일/블로그용 "더보기" 버튼</Desc>
    Public Function RenderMore()
        Dim s
        s = ""
        If TotalPage() > CurPage() Then
            s = "<div class=""more-wrap""><a class=""btn btn-more"" href=""" & _
                HE(Link(CurPage() + 1)) & """>더보기 <span class=""more-cnt"">(" & _
                CurPage() & " / " & TotalPage() & ")</span></a></div>"
        End If
        RenderMore = s
    End Function

    '<Desc>"총 128건 / 3 페이지" 요약</Desc>
    Public Function Summary()
        Summary = "총 <strong>" & StringUtil.Comma(mResultCount) & "</strong>건" & _
                  " <span class=""sep"">|</span> " & CurPage() & " / " & TotalPage() & " 페이지"
    End Function

End Class

Dim Paging
Set Paging = New CPaging
%>
