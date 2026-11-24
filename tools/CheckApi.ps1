# =============================================================================
#  jkw.com  -  React 스택 JSON API (E2E) 검증
# -----------------------------------------------------------------------------
#  이 리포지토리에 동봉된 Classic ASP 백엔드(server-asp)가
#  React 가 기대하는 JSON 을 주는지 본다.
#
#    1. 부트스트랩 (Config.asp)           - 사이트/메뉴/게시판/세션/CSRF
#    2. 로그인 + 세션 유지 + 토큰 재발급
#    3. 조회계 (Main / About / Portfolio)
#    4. 게시판 목록 / 글 등록 / 상세 / 한글 왕복
#    5. 첨부 업로드 (multipart) + 상세 반영 확인
#    6. 댓글 등록
#    7. 글 삭제
#    8. 문의 등록
#    9. CSRF 토큰 없는 POST 가 403 으로 막히는지
#   10. 로그아웃
#
#  사용 :  powershell -ExecutionPolicy Bypass -File tools\CheckApi.ps1
#          powershell -ExecutionPolicy Bypass -File tools\CheckApi.ps1 -Base http://localhost:8080
#          powershell -ExecutionPolicy Bypass -File tools\CheckApi.ps1 -ApiPath /server-asp/api
#          (-ApiPath 는 src\app\config.js 의 API_BASE 와 같아야 한다)
# =============================================================================
param(
    [string]$Base    = 'http://localhost:8080',
    # 동봉 백엔드의 URL 경로. 이 폴더가 사이트 루트면 '/server-asp/api'
    [string]$ApiPath = '/react/server-asp/api',
    [string]$Bid     = 'free',
    [string]$Id      = 'admin',
    [string]$Pw      = 'admin1234!'
)

$ErrorActionPreference = 'Continue'
$fail = 0
$UA   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
$API  = $Base + $ApiPath

function Head($t) { Write-Host ''; Write-Host ('=== ' + $t + ' ===') -ForegroundColor Cyan }
function Ok($t)   { Write-Host ('  [OK] ' + $t) -ForegroundColor Green }
function Bad($t)  { Write-Host ('  [!!] ' + $t) -ForegroundColor Red; $script:fail++ }
function Info($t) { Write-Host ('       ' + $t) -ForegroundColor DarkGray }

# 쿠키(ASP 세션)를 유지하는 웹 세션
$sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$sess.UserAgent = $UA

$script:csrf = ''

# -----------------------------------------------------------------------------
# 공통 : 응답을 UTF-8 로 직접 디코딩한다.
#   Invoke-RestMethod 에 맡기면 Content-Type 해석에 따라 한글이 깨질 수 있다.
#   이 검증의 핵심 중 하나가 "한글이 왕복에서 살아남는가" 이므로 직접 읽는다.
# -----------------------------------------------------------------------------
function Call-Api {
    param(
        [string]$Path,
        [string]$Method = 'GET',
        [hashtable]$Body = $null,
        [byte[]]$RawBody = $null,
        [string]$ContentType = 'application/json; charset=utf-8',
        [switch]$NoCsrf,
        [switch]$AllowFail
    )

    # ★ -WebSession 과 함께 넘긴 헤더는 세션에 "누적"된다.
    #   한 번 X-CSRF-Token 을 보내면 다음 요청에서 헤더를 빼도 세션이 계속 붙여 보낸다.
    #   그래서 CSRF 가드를 시험할 때는 세션에 남은 헤더를 직접 지워야 한다.
    #   (이걸 안 해서 "토큰 없는 POST" 가 200 으로 성공해 가드가 깨진 것처럼 보였다)
    $headers = @{ Accept = 'application/json' }
    if ($NoCsrf) {
        if ($sess.Headers.ContainsKey('X-CSRF-Token')) { [void]$sess.Headers.Remove('X-CSRF-Token') }
    } elseif ($script:csrf -ne '') {
        $headers['X-CSRF-Token'] = $script:csrf
    }

    $args = @{
        Uri             = ($API + '/' + $Path)
        Method          = $Method
        WebSession      = $sess
        Headers         = $headers
        UseBasicParsing = $true
        TimeoutSec      = 30
        ErrorAction     = 'Stop'
    }

    if ($Method -eq 'POST') {
        if ($RawBody) {
            $args['Body'] = $RawBody
        } else {
            if ($null -eq $Body) { $Body = @{} }
            if (-not $NoCsrf) { $Body['_csrf'] = $script:csrf }
            $args['Body'] = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 5 -Compress))
        }
        $args['ContentType'] = $ContentType
    }

    $status = 0
    $text   = ''
    try {
        $r = Invoke-WebRequest @args
        $status = [int]$r.StatusCode
        $text   = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    } catch [Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $status = [int]$resp.StatusCode
            # ★ 4xx/5xx 본문은 ErrorDetails.Message 에서 꺼낸다.
            #   Invoke-WebRequest 는 오류 응답 스트림을 이미 끝까지 읽어버려서
            #   GetResponseStream() 을 그냥 읽으면 빈 문자열이 나온다.
            #   (이걸 몰라 "ApiFail 이 본문을 못 내보낸다"고 오진할 뻔했다)
            $text = ''
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $text = $_.ErrorDetails.Message
            } else {
                $st = $resp.GetResponseStream()
                if ($st.CanSeek) { $st.Position = 0 }
                $sr = New-Object IO.StreamReader($st, [Text.Encoding]::UTF8)
                $text = $sr.ReadToEnd()
            }
        } else {
            if (-not $AllowFail) { Bad ($Path + '  연결 실패 : ' + $_.Exception.Message) }
            return $null
        }
    }

    $json = $null
    try { $json = $text | ConvertFrom-Json } catch {
        if (-not $AllowFail) {
            $plain = ($text -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()
            Bad ($Path + '  JSON 이 아닌 응답 (HTTP ' + $status + ') : ' + $plain.Substring(0, [Math]::Min(160, $plain.Length)))
        }
        return [pscustomobject]@{ status = $status; json = $null; text = $text }
    }

    return [pscustomobject]@{ status = $status; json = $json; text = $text }
}

function Need-Ok($res, $label) {
    if ($null -eq $res)              { Bad ($label + '  응답 없음'); return $false }
    if ($null -eq $res.json)         { Bad ($label + '  JSON 파싱 실패'); return $false }
    if (-not $res.json.ok) {
        Bad ($label + '  ok=false  ' + $res.json.error.code + ' : ' + $res.json.error.message)
        return $false
    }
    return $true
}


# =============================================================================
Head '1. 부트스트랩  GET Config.asp'
$r = Call-Api 'Config.asp'
if (Need-Ok $r 'Config.asp') {
    $d = $r.json.data
    $script:csrf = $d.csrf
    if ($d.site.title) { Ok ('site.title = ' + $d.site.title) } else { Bad 'site.title 비어 있음' }
    if ($d.menus.Count -gt 0)  { Ok ('menus  ' + $d.menus.Count + '건') }  else { Bad '메뉴가 비어 있음' }
    if ($d.boards.Count -gt 0) { Ok ('boards ' + $d.boards.Count + '건 : ' + (($d.boards | ForEach-Object { $_.id }) -join ', ')) } else { Bad '게시판이 비어 있음' }
    if ($script:csrf.Length -gt 0) { Ok ('csrf 토큰 발급 (' + $script:csrf.Length + '자)') } else { Bad 'csrf 토큰 없음' }
    if ($d.me.isLogin) { Info '이미 로그인 상태 (이전 세션 쿠키)' }
}

# =============================================================================
Head '2. 로그인  POST Login.asp'
$r = Call-Api 'Login.asp' 'POST' @{ loginId = $Id; password = $Pw }
if (Need-Ok $r 'Login.asp') {
    $d = $r.json.data
    $script:csrf = $d.csrf     # 세션 재발급 -> 토큰이 바뀐다
    if ($d.me.isLogin) { Ok ('로그인 성공 : ' + $d.me.name + ' (level ' + $d.me.level + ')') } else { Bad '로그인 응답에 isLogin=false' }
}

$r = Call-Api 'Config.asp'
if (Need-Ok $r 'Config.asp(로그인 후)') {
    if ($r.json.data.me.isLogin) { Ok '세션 유지됨' } else { Bad '다음 요청에서 세션이 끊김 (쿠키 전달 확인)' }
}

# =============================================================================
Head '3. 조회계'
$r = Call-Api 'Main.asp'
if (Need-Ok $r 'Main.asp') {
    $d = $r.json.data
    Ok ('hero="' + $d.hero.headline + '"  대표PF ' + $d.portfolios.Count + '건  블로그 ' + $d.blog.Count + '건  공지 ' + $d.notice.Count + '건')
    Info ('stats : 경력 ' + $d.stats.years + '년 / 프로젝트 ' + $d.stats.projects + ' / 글 ' + $d.stats.posts + ' / 방문 ' + $d.stats.visits)
}

$r = Call-Api 'About.asp'
if (Need-Ok $r 'About.asp') {
    $d = $r.json.data
    Ok ('경력 ' + $d.careers.Count + '건 / 스킬 ' + $d.skills.Count + '개 / 그룹 ' + $d.skillGroups.Count + '개')
}

$pfId = 0
$r = Call-Api 'PortfolioList.asp?page=1'
if (Need-Ok $r 'PortfolioList.asp') {
    $d = $r.json.data
    Ok ('포트폴리오 ' + $d.items.Count + ' / 총 ' + $d.paging.totalCount + '건')
    if ($d.items.Count -gt 0) { $pfId = $d.items[0].id }
}

if ($pfId -gt 0) {
    $r = Call-Api ('PortfolioView.asp?id=' + $pfId)
    if (Need-Ok $r 'PortfolioView.asp') {
        Ok ('상세 #' + $pfId + ' : ' + $r.json.data.item.title + '  (스킬 ' + $r.json.data.skills.Count + '개)')
    }
} else {
    Info 'PortfolioView : 데이터가 없어 건너뜀'
}

# =============================================================================
Head ('4. 게시판  GET BoardList.asp?bid=' + $Bid)
$r = Call-Api ('BoardList.asp?bid=' + $Bid + '&page=1')
if (Need-Ok $r 'BoardList.asp') {
    $d = $r.json.data
    Ok ('게시판="' + $d.board.name + '" skin=' + $d.board.skin + '  글 ' + $d.items.Count + ' / 총 ' + $d.paging.totalCount + '건')
    if (-not $d.board.perm.write) { Bad '관리자인데 글쓰기 권한이 false' }
}

$r = Call-Api ('BoardList.asp?bid=' + $Bid + '&sf=title&sw=' + [Uri]::EscapeDataString('없는검색어zzz'))
if (Need-Ok $r 'BoardList.asp(검색)') {
    Ok ('검색 동작 : 결과 ' + $r.json.data.paging.totalCount + '건')
}

# --- 글 등록 (한글 + 따옴표 + 줄바꿈이 그대로 돌아오는지) ---------------------
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$title   = 'React API 검증 ' + $stamp + ' "따옴표" 포함'
$content = "첫 줄 한글`n둘째 줄 <b>태그</b> & 앰퍼샌드"
$newId   = 0

Head '4-1. 글 등록  POST ArticleWrite.asp'
$r = Call-Api ('ArticleWrite.asp?bid=' + $Bid) 'POST' @{ mode = 'write'; id = 0; title = $title; content = $content }
if (Need-Ok $r 'ArticleWrite.asp') {
    $newId = [int]$r.json.data.id
    if ($newId -gt 0) { Ok ('등록 성공 article_id=' + $newId) } else { Bad '새 글 id 가 0' }
}

if ($newId -gt 0) {
    Head '4-2. 상세  GET ArticleView.asp'
    $r = Call-Api ('ArticleView.asp?bid=' + $Bid + '&id=' + $newId)
    if (Need-Ok $r 'ArticleView.asp') {
        $a = $r.json.data.article
        if ($a.title -eq $title) { Ok '제목 왕복 일치 (한글 + 따옴표)' }
        else { Bad ('제목 불일치' + "`n       보낸값 : " + $title + "`n       받은값 : " + $a.title) }

        if ($a.contentHtml -match '첫 줄 한글') { Ok '본문 한글 보존' } else { Bad '본문 한글이 깨졌거나 비어 있음' }
        if ($r.json.data.perm.edit) { Ok '수정 권한 perm.edit = true' } else { Bad 'perm.edit 가 false' }
    }

    # ----------------------------------------------------------------------
    Head '5. 첨부 업로드  POST FileUpload.asp (multipart)'
    $bl = $r.json.data.board
    if (-not $bl.useFile) {
        Info ('게시판 ' + $Bid + ' 는 첨부를 쓰지 않음 - 건너뜀')
    } else {
        $boundary = '----jkwCheck' + [Guid]::NewGuid().ToString('N')
        $fileName = 'check-' + $stamp + '.txt'
        $fileBody = '첨부 본문 ' + $stamp

        $ms = New-Object IO.MemoryStream
        $w  = New-Object IO.StreamWriter($ms, (New-Object Text.UTF8Encoding($false)))
        $w.Write("--$boundary`r`n")
        $w.Write("Content-Disposition: form-data; name=`"upfile1`"; filename=`"$fileName`"`r`n")
        $w.Write("Content-Type: text/plain`r`n`r`n")
        $w.Write($fileBody)
        $w.Write("`r`n--$boundary--`r`n")
        $w.Flush()
        $bytes = $ms.ToArray()
        $w.Dispose(); $ms.Dispose()

        $r2 = Call-Api ('FileUpload.asp?bid=' + $Bid + '&id=' + $newId) 'POST' $null $bytes ('multipart/form-data; boundary=' + $boundary)
        if (Need-Ok $r2 'FileUpload.asp') {
            if ([int]$r2.json.data.savedCount -ge 1) { Ok ('업로드 ' + $r2.json.data.savedCount + '건  (' + $r2.json.data.files[0].name + ')') }
            else { Bad '업로드 건수가 0' }
        }

        $r3 = Call-Api ('ArticleView.asp?bid=' + $Bid + '&id=' + $newId)
        if (Need-Ok $r3 'ArticleView.asp(첨부 확인)') {
            if ($r3.json.data.files.Count -ge 1) { Ok ('상세에 첨부 ' + $r3.json.data.files.Count + '건 반영') }
            else { Bad '상세에 첨부가 보이지 않음' }
        }
    }

    # ----------------------------------------------------------------------
    Head '6. 댓글  POST CommentWrite.asp'
    $r = Call-Api ('CommentWrite.asp?bid=' + $Bid) 'POST' @{ articleId = $newId; parentId = 0; content = '검증 댓글 한글 ' + $stamp }
    if (Need-Ok $r 'CommentWrite.asp') {
        Ok ('댓글 등록 comment_id=' + $r.json.data.id)
        $r2 = Call-Api ('ArticleView.asp?bid=' + $Bid + '&id=' + $newId)
        if (Need-Ok $r2 'ArticleView.asp(댓글 확인)') {
            if ($r2.json.data.comments.Count -ge 1) { Ok ('상세에 댓글 ' + $r2.json.data.comments.Count + '건 반영') }
            else { Bad '상세에 댓글이 보이지 않음' }
        }
    }

    # ----------------------------------------------------------------------
    Head '9. CSRF 가드  (토큰 없이 POST)'
    $r = Call-Api ('CommentWrite.asp?bid=' + $Bid) 'POST' @{ articleId = $newId; content = '토큰 없는 요청' } $null 'application/json; charset=utf-8' -NoCsrf -AllowFail
    if ($null -ne $r -and $r.status -eq 403 -and $null -ne $r.json -and -not $r.json.ok -and $r.json.error.code -eq 'CSRF') {
        Ok 'CSRF 토큰 없는 POST 가 403 으로 차단됨'
    } else {
        Bad ('CSRF 가드 실패 : HTTP ' + $(if ($r) { $r.status } else { '응답없음' }))
    }

    # ----------------------------------------------------------------------
    Head '7. 글 삭제  POST ArticleDelete.asp'
    $r = Call-Api ('ArticleDelete.asp?bid=' + $Bid) 'POST' @{ id = $newId }
    if (Need-Ok $r 'ArticleDelete.asp') { Ok ('삭제 완료 article_id=' + $newId) }

    $r = Call-Api ('ArticleView.asp?bid=' + $Bid + '&id=' + $newId) 'GET' $null $null 'application/json' -AllowFail
    if ($null -ne $r -and $r.status -eq 404) { Ok '삭제된 글은 404' } else { Bad ('삭제 후에도 조회됨 : HTTP ' + $(if ($r) { $r.status } else { '?' })) }
}

# =============================================================================
Head '8. 문의  POST Contact.asp'
$r = Call-Api 'Contact.asp' 'POST' @{
    contactType = '기술 질문'
    name        = 'API 검증'
    company     = ''
    email       = 'check@example.com'
    mobile      = ''
    subject     = 'React 스택 검증 ' + $stamp
    content     = '자동 검증 스크립트가 보낸 문의입니다. 한글이 깨지지 않아야 합니다.'
    agree       = $true
}
if ($null -ne $r -and $null -ne $r.json) {
    if ($r.json.ok) { Ok ('문의 접수 id=' + $r.json.data.id) }
    elseif ($r.json.error.code -eq 'RATE_LIMIT') { Info '도배 방지에 걸림 (정상 동작). 10분 뒤 다시 시도' }
    else { Bad ('Contact.asp  ' + $r.json.error.code + ' : ' + $r.json.error.message) }
}

# =============================================================================
Head '10. 로그아웃  POST Logout.asp'
$r = Call-Api 'Logout.asp' 'POST' @{}
if (Need-Ok $r 'Logout.asp') { Ok '로그아웃 요청 성공' }

$script:csrf = ''
$r = Call-Api 'Config.asp'
if (Need-Ok $r 'Config.asp(로그아웃 후)') {
    if (-not $r.json.data.me.isLogin) { Ok '세션이 끊김' } else { Bad '로그아웃 후에도 로그인 상태' }
}

# =============================================================================
Write-Host ''
if ($fail -eq 0) { Write-Host '전체 통과' -ForegroundColor Green; exit 0 }
else { Write-Host ('문제 ' + $fail + '건') -ForegroundColor Red; exit 1 }
