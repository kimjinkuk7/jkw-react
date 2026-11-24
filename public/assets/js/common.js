/* ============================================================================
   jkw.com  -  공통 스크립트  (라이브러리 의존 없음 / ES5 호환)
   ★ Classic ASP / Spring Boot / Python / PHP 가 이 파일 하나를 공유한다.
   ----------------------------------------------------------------------------
   그래서 서버 주소를 이 파일에 적지 않는다. 스택마다 URL 이 다르기 때문이다.
     Classic ASP  /asp/view/donate/Order_p.asp
     Spring Boot  /donate/order
   각 스택의 공통 헤더가 아래 형태로 자기 주소를 알려준다.

     window.JKW = { urls: { phoneAuth: '...', donateOrder: '...',
                            donateApprove: '...', donateCancel: '...',
                            inicisPay: '...', payResult: '...' } };

   inicisPay / payResult 에는 order 값이 뒤에 붙으므로 '?order=' 까지 포함한
   접두어를 준다. 값이 없으면 ASP 기본 경로를 쓴다(하위 호환).
   ============================================================================ */
(function () {
    'use strict';

    /* ------------------------------------------------------------------
       0. 헬퍼
       ------------------------------------------------------------------ */
    function $(sel, ctx) { return (ctx || document).querySelector(sel); }
    function $$(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }
    function on(el, ev, fn) { if (el) el.addEventListener(ev, fn, false); }

    /* 서버가 알려준 엔드포인트. 없으면 Classic ASP 기본값 */
    var URLS = (window.JKW && window.JKW.urls) || {};
    function ep(key, def) { return URLS[key] || def; }

    /* ------------------------------------------------------------------
       1. 모바일 네비게이션
       ------------------------------------------------------------------ */
    function initNav() {
        var btn = $('.nav-toggle');
        var body = document.body;
        if (!btn) return;

        on(btn, 'click', function () {
            var open = body.classList.toggle('nav-open');
            btn.setAttribute('aria-expanded', open ? 'true' : 'false');
        });

        /* 데스크톱 폭으로 넓어지면 모바일 메뉴 상태 해제 */
        var mq = window.matchMedia('(min-width: 1024px)');
        function onChange() { if (mq.matches) body.classList.remove('nav-open'); }
        if (mq.addEventListener) mq.addEventListener('change', onChange);
        else if (mq.addListener) mq.addListener(onChange);

        /* ESC 로 닫기 */
        on(document, 'keydown', function (e) {
            if (e.key === 'Escape' && body.classList.contains('nav-open')) {
                body.classList.remove('nav-open');
                btn.setAttribute('aria-expanded', 'false');
            }
        });

        /* 모바일에서 하위 메뉴 있는 1depth 는 토글로 동작 */
        $$('#gnb .gnb-label').forEach(function (lb) {
            on(lb, 'click', function () {
                if (window.innerWidth >= 1024) return;
                lb.parentNode.classList.toggle('is-open');
                var sub = $('.sub-menu', lb.parentNode);
                if (sub) sub.style.display = lb.parentNode.classList.contains('is-open') ? 'flex' : '';
            });
        });
    }

    /* ------------------------------------------------------------------
       2. 다크/라이트 테마 토글
          기본은 OS 설정을 따르고, 사용자가 고르면 localStorage 에 고정
       ------------------------------------------------------------------ */
    function initTheme() {
        var KEY = 'jkw-theme';
        var saved = null;
        try { saved = localStorage.getItem(KEY); } catch (e) { /* 사생활 보호 모드 */ }
        if (saved === 'dark' || saved === 'light') {
            document.documentElement.setAttribute('data-theme', saved);
        }

        $$('.theme-toggle').forEach(function (btn) {
            on(btn, 'click', function () {
                var cur = document.documentElement.getAttribute('data-theme');
                if (!cur) {
                    cur = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
                }
                var next = cur === 'dark' ? 'light' : 'dark';
                document.documentElement.setAttribute('data-theme', next);
                try { localStorage.setItem(KEY, next); } catch (e) { }
                btn.setAttribute('aria-label', next === 'dark' ? '라이트 모드로 전환' : '다크 모드로 전환');
            });
        });
    }

    /* ------------------------------------------------------------------
       3. 폼 검증
          data-required / data-label / data-minlen / data-type=email|pw
       ------------------------------------------------------------------ */
    window.jkwValidate = function (form) {
        var fields = $$('[data-required], [data-minlen], [data-type]', form);
        for (var i = 0; i < fields.length; i++) {
            var f = fields[i];
            var v = (f.value || '').replace(/^\s+|\s+$/g, '');
            var label = f.getAttribute('data-label') || '항목';

            if (f.hasAttribute('data-required') && v === '') {
                alert(label + '을(를) 입력해 주세요.');
                f.focus();
                return false;
            }
            if (v === '') continue;

            var minlen = parseInt(f.getAttribute('data-minlen') || '0', 10);
            if (minlen > 0 && v.length < minlen) {
                alert(label + '은(는) ' + minlen + '자 이상 입력해 주세요.');
                f.focus();
                return false;
            }

            var type = f.getAttribute('data-type');
            if (type === 'email' && !/^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/.test(v)) {
                alert('이메일 형식이 올바르지 않습니다.');
                f.focus();
                return false;
            }
            if (type === 'loginid' && !/^[a-z][a-z0-9_]{3,29}$/.test(v)) {
                alert('아이디는 영소문자로 시작하는 영문·숫자·_ 조합 4~30자여야 합니다.');
                f.focus();
                return false;
            }
            if (type === 'pw') {
                /* 서버(StringUtil.ChkPassword)와 동일한 규칙 : ASCII, 8자+, 영문+숫자 */
                if (!/^[\x20-\x7E]+$/.test(v)) {
                    alert('비밀번호는 영문·숫자·특수문자(ASCII)만 사용할 수 있습니다.\n한글은 사용할 수 없습니다.');
                    f.focus(); return false;
                }
                if (v.length < 8) { alert('비밀번호는 8자 이상이어야 합니다.'); f.focus(); return false; }
                if (!/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) {
                    alert('비밀번호에 영문과 숫자를 모두 포함해 주세요.');
                    f.focus(); return false;
                }
            }
            if (type === 'pwconfirm') {
                var target = $('[name="' + f.getAttribute('data-target') + '"]', form);
                if (target && target.value !== v) {
                    alert('비밀번호가 일치하지 않습니다.');
                    f.focus(); return false;
                }
            }
        }

        /* 중복 제출 방지 : 페이지가 이동한다는 전제의 처리다.
           AJAX 로 직접 제출을 처리하는 폼(data-no-lock)은 페이지가 그대로 남으므로
           여기서 잠그면 다시 누를 수 없게 된다. 그런 폼은 스스로 버튼 상태를 관리한다. */
        if (!form.hasAttribute('data-no-lock')) {
            var submits = $$('button[type=submit], input[type=submit]', form);
            setTimeout(function () {
                submits.forEach(function (b) { b.disabled = true; b.classList.add('is-off'); });
            }, 0);
        }
        return true;
    };

    /* 중복 제출 방지로 disabled 된 버튼을 되살린다.
       서버가 검증에 실패하면 alert 후 history.back() 으로 되돌려보내는데(JsAlert),
       그때 브라우저가 복원한 DOM 에는 disabled 가 그대로 남아 재전송이 불가능해진다.
       pageshow 는 최초 로드와 뒤로가기 복원(bfcache) 모두에서 발생한다. */
    function reenableSubmits() {
        $$('button[type=submit], input[type=submit]').forEach(function (b) {
            b.disabled = false;
            b.classList.remove('is-off');
        });
    }

    function initForms() {
        $$('form[data-validate]').forEach(function (form) {
            on(form, 'submit', function (e) {
                if (!window.jkwValidate(form)) e.preventDefault();
            });
        });

        on(window, 'pageshow', reenableSubmits);

        /* 글자수 카운터 */
        $$('[data-counter]').forEach(function (el) {
            var out = $('#' + el.getAttribute('data-counter'));
            if (!out) return;
            function upd() { out.textContent = el.value.length; }
            on(el, 'input', upd);
            upd();
        });
    }

    /* ------------------------------------------------------------------
       4. 삭제 확인
       ------------------------------------------------------------------ */
    function initConfirm() {
        $$('[data-confirm]').forEach(function (el) {
            on(el, 'click', function (e) {
                if (!confirm(el.getAttribute('data-confirm'))) e.preventDefault();
            });
        });
    }

    /* ------------------------------------------------------------------
       5. 댓글 - 답글 폼 토글
       ------------------------------------------------------------------ */
    window.jkwReplyToggle = function (commentId) {
        var box = document.getElementById('reply-form-' + commentId);
        if (!box) return;
        var show = box.style.display !== 'block';
        $$('.reply-form').forEach(function (b) { b.style.display = 'none'; });
        box.style.display = show ? 'block' : 'none';
        if (show) { var t = $('textarea', box); if (t) t.focus(); }
    };

    /* ------------------------------------------------------------------
       6. 첨부 파일 입력 동적 추가
       ------------------------------------------------------------------ */
    window.jkwAddFile = function (wrapId, maxCount) {
        var wrap = document.getElementById(wrapId);
        if (!wrap) return;
        var rows = $$('.file-row', wrap);
        if (rows.length >= maxCount) {
            alert('첨부파일은 최대 ' + maxCount + '개까지 등록할 수 있습니다.');
            return;
        }
        var idx = rows.length + 1;
        var div = document.createElement('div');
        div.className = 'file-row';
        div.innerHTML = '<input type="file" name="upfile' + idx + '" class="input">' +
                        '<button type="button" class="btn btn-sm" onclick="this.parentNode.remove()">삭제</button>';
        wrap.appendChild(div);
    };

    /* ------------------------------------------------------------------
       7. 맨 위로
       ------------------------------------------------------------------ */
    function initTop() {
        var btn = $('#btn-top');
        if (!btn) return;
        function toggle() { btn.style.display = window.pageYOffset > 400 ? 'grid' : 'none'; }
        on(window, 'scroll', toggle);
        on(btn, 'click', function (e) {
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });
        toggle();
    }

    /* ------------------------------------------------------------------
       8. 본문 내 넓은 표 가로 스크롤 래핑
       ------------------------------------------------------------------ */
    function initWideTable() {
        $$('.view-body table').forEach(function (tb) {
            if (tb.parentNode.classList.contains('table-scroll')) return;
            var w = document.createElement('div');
            w.className = 'table-scroll';
            tb.parentNode.insertBefore(w, tb);
            w.appendChild(tb);
        });
    }

    /* ------------------------------------------------------------------
       9. 휴대폰 인증 (회원가입)
       ------------------------------------------------------------------
       서버가 인증 상태를 세션에 들고 있으므로 여기서는 화면 표시만 담당한다.
       인증 후 번호를 고치면 표시를 지운다 (서버도 번호가 다르면 거부한다).
       ------------------------------------------------------------------ */
    function initPhoneAuth() {
        var sendBtn = $('#j-phone-btn');
        var input   = $('#j-mobile');
        var state   = $('#j-phone-state');
        var otpBox  = $('#j-otp-box');
        var otpIn   = $('#j-otp');
        var otpBtn  = $('#j-otp-btn');
        var otpTime = $('#j-otp-timer');
        var otpHint = $('#j-otp-hint');
        if (!sendBtn || !input || !state) return;

        var form  = sendBtn.closest ? sendBtn.closest('form') : null;
        var token = form ? $('input[name=_csrf]', form) : null;
        var verified = '';                      /* 인증 완료된 번호(숫자만) */
        var timer = null, left = 0;

        function digits(s) { return (s || '').replace(/[^0-9]/g, ''); }

        function paint(kind, msg) {
            state.textContent = msg || '';
            state.className = 'form-help' + (kind ? ' phone-' + kind : '');
        }

        function post(body, done) {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', ep('phoneAuth', '/asp/view/member/PhoneAuth_p.asp'), true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) return;
                done(xhr.status === 200 ? (xhr.responseText || '') : '');
            };
            xhr.send('_csrf=' + encodeURIComponent(token ? token.value : '') + '&' + body);
        }

        function stopTimer() {
            if (timer) { clearInterval(timer); timer = null; }
            if (otpTime) otpTime.textContent = '';
        }

        function startTimer(sec) {
            left = sec;
            stopTimer();
            function tick() {
                if (!otpTime) return;
                if (left <= 0) {
                    stopTimer();
                    otpTime.textContent = '만료';
                    otpTime.className = 'otp-timer is-out';
                    return;
                }
                var m = Math.floor(left / 60), s = left % 60;
                otpTime.textContent = m + ':' + (s < 10 ? '0' : '') + s;
                otpTime.className = 'otp-timer';
                left--;
            }
            tick();
            timer = setInterval(tick, 1000);
        }

        function closeOtp() {
            stopTimer();
            if (otpBox) otpBox.hidden = true;
            if (otpIn) otpIn.value = '';
            if (otpHint) otpHint.textContent = '';
        }

        /* 번호를 고치면 인증 상태와 입력 단계를 모두 되돌린다 */
        on(input, 'input', function () {
            if (verified && digits(input.value) !== verified) {
                verified = '';
                paint('', '');
                closeOtp();
                sendBtn.textContent = '인증번호 받기';
                sendBtn.disabled = false;
            }
        });

        /* --- 1단계 : 인증번호 받기 --- */
        on(sendBtn, 'click', function () {
            var num = digits(input.value);
            if (!num) { paint('bad', '번호를 먼저 입력해 주세요.'); input.focus(); return; }

            sendBtn.disabled = true;
            paint('', '인증번호를 요청하는 중…');

            post('act=send&mobile=' + encodeURIComponent(input.value), function (txt) {
                sendBtn.disabled = false;
                var p = txt.split('|');
                if (p[0] !== 'OK') {
                    paint('bad', p[1] || '인증번호 발급에 실패했습니다.');
                    return;
                }
                sendBtn.textContent = '재발송';
                paint('', '인증번호를 발송했습니다. 아래에 입력해 주세요.');
                if (otpBox) otpBox.hidden = false;
                if (otpIn) { otpIn.value = ''; otpIn.focus(); }
                startTimer(parseInt(p[2], 10) || 180);

                /* 시연 모드에서만 서버가 인증번호를 함께 돌려준다 */
                if (otpHint) {
                    otpHint.textContent = p[3]
                        ? '시연용 안내 · 발송된 인증번호는 ' + p[3] + ' 입니다 (tb_phone_auth 에 저장됨)'
                        : '';
                }
            });
        });

        /* --- 2단계 : 인증번호 확인 --- */
        if (otpBtn) {
            on(otpBtn, 'click', function () {
                var code = digits(otpIn ? otpIn.value : '');
                if (!code) { paint('bad', '인증번호를 입력해 주세요.'); if (otpIn) otpIn.focus(); return; }

                otpBtn.disabled = true;
                paint('', '확인 중…');

                post('act=verify&mobile=' + encodeURIComponent(input.value) + '&code=' + encodeURIComponent(code),
                function (txt) {
                    otpBtn.disabled = false;
                    var p = txt.split('|');
                    if (p[0] === 'OK') {
                        verified = p[2] || digits(input.value);
                        closeOtp();
                        sendBtn.textContent = '인증 완료';
                        sendBtn.disabled = true;
                        paint('ok', '휴대폰 인증이 완료되었습니다.');
                    } else {
                        var msg = p[1] || '인증에 실패했습니다.';
                        if (p[2] !== undefined && p[2] !== '') msg += ' (남은 시도 ' + p[2] + '회)';
                        paint('bad', msg);
                        if (otpIn) { otpIn.select(); otpIn.focus(); }
                    }
                });
            });

            /* 엔터로 확인 */
            on(otpIn, 'keydown', function (e) {
                if (e.key === 'Enter') { e.preventDefault(); otpBtn.click(); }
            });
        }

        /* 번호를 적었는데 인증하지 않았으면 가입을 막는다 (서버도 다시 검사한다) */
        if (form) {
            on(form, 'submit', function (e) {
                var num = digits(input.value);
                if (num && num !== verified) {
                    alert('휴대폰 인증을 완료해 주세요.');
                    paint('bad', '인증이 필요합니다.');
                    input.focus();
                    e.preventDefault();
                    e.stopImmediatePropagation();
                }
            }, false);
        }
    }

    /* ------------------------------------------------------------------
       10. 소셜 로그인 : 별도 창으로 열기
       ------------------------------------------------------------------
       실제 OAuth 와 같은 방식이다. 팝업이 제공자(또는 모의) 화면을 거쳐
       콜백까지 처리한 뒤, 부모 창을 옮기고 스스로 닫는다.
       팝업이 차단되면 같은 창에서 이동하도록 둔다(기본 링크 동작).
       ------------------------------------------------------------------ */
    function initSocialPopup() {
        $$('a[data-social]').forEach(function (a) {
            on(a, 'click', function (e) {
                var w = 480, h = 660;
                var y = window.top.outerHeight / 2 + window.top.screenY - (h / 2);
                var x = window.top.outerWidth  / 2 + window.top.screenX - (w / 2);
                var url = a.getAttribute('href') + '&popup=1';
                var p = window.open(url, 'jkw_social',
                    'width=' + w + ',height=' + h + ',left=' + x + ',top=' + y +
                    ',resizable=yes,scrollbars=yes');
                if (p) { e.preventDefault(); p.focus(); }
                /* 팝업이 막혔으면 preventDefault 를 하지 않아 그대로 이동한다 */
            });
        });
    }

    /* ------------------------------------------------------------------
       11. 모의 결제창 (개발자 지원금)
       ------------------------------------------------------------------
       실제 PG 연동과 순서를 같게 둔다.
         ① 주문 생성(서버)  ② 결제창  ③ 승인 요청(서버)  ④ 완료
       카드번호는 읽기 전용 표시일 뿐이고 서버로 보내지 않는다.
       ------------------------------------------------------------------ */
    function initPgModal() {
        var form  = $('#donate-form');
        var modal = $('#pg-modal');
        if (!form || !modal) return;                 /* mock 모드가 아니면 모달이 없다 */

        var token   = $('input[name=_csrf]', form);
        var elSteps = $('#pg-steps');
        var elAmt   = $('#pg-amount');
        var elOrder = $('#pg-order');
        var elFields= $('#pg-fields');
        var elProg  = $('#pg-progress');
        var elProgT = $('#pg-progress-txt');
        var elDone  = $('#pg-done');
        var elTid   = $('#pg-tid');
        var elErr   = $('#pg-err');
        var elAct   = $('#pg-actions');
        var btnPay  = $('#pg-pay');
        var btnFail = $('#pg-fail');
        var btnClose= $('#pg-close');
        var order = '', method = '신용카드', busy = false;

        function comma(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }

        function step(n) {
            $$('li', elSteps).forEach(function (li) {
                var s = parseInt(li.getAttribute('data-step'), 10);
                li.classList.toggle('is-done', s < n);
                li.classList.toggle('is-on',   s === n);
            });
        }

        function show(el, on) { if (el) el.hidden = !on; }

        /* <dialog> 네이티브 모달. backdrop / 포커스 트랩 / ESC / inert 를 브라우저가 처리한다.
           showModal 이 없는 구형 브라우저는 open 속성으로 폴백한다. */
        function open() {
            if (modal.showModal) { if (!modal.open) modal.showModal(); }
            else { modal.setAttribute('open', ''); }
        }
        function close() {
            if (busy) return;
            /* 승인 전에 닫으면 ready 주문을 정리한다 (PG 창을 닫은 것과 같은 처리) */
            if (order) { cancelOrder(order, '사용자가 결제창을 닫았습니다.'); order = ''; }
            lockSubmit(false);
            if (modal.close) { if (modal.open) modal.close(); }
            else { modal.removeAttribute('open'); }
        }

        function post(url, body, done) {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', url, true);
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) return;
                done(xhr.status === 200 ? (xhr.responseText || '') : '');
            };
            xhr.send('_csrf=' + encodeURIComponent(token ? token.value : '') + '&' + body);
        }

        /* --- 결제수단 탭 --- */
        $$('.pg-m').forEach(function (b) {
            on(b, 'click', function () {
                $$('.pg-m').forEach(function (x) { x.classList.remove('is-on'); });
                b.classList.add('is-on');
                method = b.getAttribute('data-method') || '신용카드';
                /* 카드가 아니면 카드 입력 영역을 감춘다 */
                show(elFields, method === '신용카드');
            });
        });

        function pickedPg() {
            var r = $('input[name=pg]:checked', form);
            return r ? r.value : 'mock';
        }

        /* 후원하기 버튼 잠금/해제. 결제창을 닫고 돌아와도 다시 누를 수 있어야 한다. */
        function lockSubmit(on) {
            $$('button[type=submit]', form).forEach(function (b) {
                b.disabled = !!on;
                b.classList.toggle('is-off', !!on);
            });
        }

        /* PG 창을 닫으면 ready 로 남은 주문을 정리한다 */
        function cancelOrder(orderId, reason) {
            if (!orderId) return;
            post(ep('donateCancel', '/asp/view/donate/Cancel_p.asp'),
                 'order=' + encodeURIComponent(orderId) +
                 '&reason=' + encodeURIComponent(reason || ''),
                 function () { /* 실패해도 화면 흐름을 막지 않는다 */ });
        }

        /* --- ① 후원 폼 제출 → 주문 생성 → 결제 모듈별로 분기 --- */
        on(form, 'submit', function (e) {
            /* ★ jkwValidate 가 이미 막은 제출이면 아무것도 하지 않는다.
                 이 확인이 없으면 필수값(이름 등)이 비어 경고가 떴는데도
                 결제창이 그대로 열린다. */
            if (e.defaultPrevented) return;
            if (busy) { e.preventDefault(); return; }
            e.preventDefault();

            var pg = pickedPg();
            busy = true;
            lockSubmit(true);

            var fd = 'amount='      + encodeURIComponent($('#dn-amount').value) +
                     '&donor_name=' + encodeURIComponent($('#dn-name').value) +
                     '&message='    + encodeURIComponent($('#dn-msg').value) +
                     '&pg='         + encodeURIComponent(pg) +
                     '&is_public='  + ($('input[name=is_public]', form).checked ? '1' : '');

            /* mock 은 자체 모달을 먼저 띄워 진행 상황을 보여준다.
               toss / inicis 는 PG 가 자기 결제창을 띄우므로 우리 모달을 열지 않는다. */
            if (pg === 'mock') {
                step(1);
                show(elProg, true); show(elDone, false); show(elErr, false); show(elAct, false);
                if (elProgT) elProgT.textContent = '주문을 생성하는 중…';
                open();
            }

            post(ep('donateOrder', '/asp/view/donate/Order_p.asp'), fd, function (txt) {
                busy = false;
                var p = txt.split('|');
                if (p[0] !== 'OK') {
                    lockSubmit(false);            /* 다시 시도할 수 있어야 한다 */
                    if (pg === 'mock') {
                        step(1);
                        show(elProg, false);
                        show(elErr, true);
                        elErr.textContent = p[1] || '주문 생성에 실패했습니다.';
                    } else {
                        alert(p[1] || '주문 생성에 실패했습니다.');
                    }
                    return;
                }

                order = p[1];
                var amount = parseInt(p[2], 10) || 0;
                var donor  = p[3] || '후원자';

                /* 이니시스는 페이지가 이동하므로 잠금을 그대로 둔다 */
                if (pg === 'inicis') {
                    location.href = ep('inicisPay', '/asp/view/donate/InicisPay.asp?order=') + encodeURIComponent(order);
                    return;
                }
                /* 토스는 같은 페이지에 결제창이 뜬다. 닫고 돌아올 수 있으므로 잠금을 푼다 */
                if (pg === 'toss') { lockSubmit(false); payToss(order, amount, donor); return; }

                /* mock */
                lockSubmit(false);
                if (elOrder) elOrder.textContent = order;
                if (elAmt)   elAmt.textContent = comma(amount) + '원';
                step(2);
                show(elProg, false);
                show(elAct, true);
                if (btnPay) btnPay.disabled = false;
            });
        }, false);

        /* --- 토스페이먼츠 : 토스가 제공하는 결제창을 띄운다 --- */
        function payToss(orderId, amount, donor) {
            var key = form.getAttribute('data-toss-key') || '';
            if (!window.TossPayments || !key) {
                alert('토스 결제 모듈을 불러오지 못했습니다.');
                lockSubmit(false);
                return;
            }
            var origin = location.protocol + '//' + location.host;
            try {
                TossPayments(key).requestPayment('카드', {
                    amount:       amount,
                    orderId:      orderId,
                    orderName:    '개발자 지원금',
                    customerName: donor,
                    successUrl:   origin + ep('payResult', '/asp/view/donate/PayResult.asp?order=') + encodeURIComponent(orderId),
                    failUrl:      origin + ep('payResult', '/asp/view/donate/PayResult.asp?order=') + encodeURIComponent(orderId)
                }).catch(function (err) {
                    /* 창을 닫거나 취소하면 여기로 온다. 주문을 정리하고 버튼을 되살린다.
                       이 처리가 없으면 ready 주문이 쌓이고 후원하기 버튼이 죽는다. */
                    var code = (err && err.code) ? err.code : '';
                    var m    = (err && err.message) ? err.message : '';
                    cancelOrder(orderId, code === 'USER_CANCEL' ? '사용자가 결제창을 닫았습니다.' : (m || '결제 시작 실패'));
                    lockSubmit(false);
                    order = '';
                    if (code !== 'USER_CANCEL' && m) alert('결제를 진행할 수 없습니다 : ' + m);
                });
            } catch (err) {
                cancelOrder(orderId, '결제창을 열 수 없습니다.');
                lockSubmit(false);
                order = '';
                alert('결제를 시작할 수 없습니다.');
            }
        }

        /* --- ③ 승인 요청 --- */
        function approve(result) {
            if (busy || !order) return;
            busy = true;
            step(3);
            show(elAct, false); show(elErr, false);
            show(elProg, true);
            if (elProgT) elProgT.textContent = result === 'fail' ? '취소 처리 중…' : '승인 요청 중…';

            /* 실제 PG 승인도 수백 ms 걸린다. 흐름이 보이도록 약간 지연한다. */
            setTimeout(function () {
                post(ep('donateApprove', '/asp/view/donate/Approve_p.asp'),
                     'order=' + encodeURIComponent(order) +
                     '&result=' + encodeURIComponent(result) +
                     '&method=' + encodeURIComponent(method),
                function (txt) {
                    busy = false;
                    show(elProg, false);
                    var p = txt.split('|');
                    if (p[0] === 'OK') {
                        step(4);
                        show(elDone, true);
                        if (elTid) elTid.textContent = '거래번호 ' + (p[1] || '');
                        setTimeout(function () {
                            location.href = ep('payResult', '/asp/view/donate/PayResult.asp?order=') + encodeURIComponent(order);
                        }, 1100);
                    } else {
                        step(3);
                        show(elErr, true);
                        elErr.textContent = p[1] || '승인에 실패했습니다.';
                        setTimeout(function () {
                            location.href = ep('payResult', '/asp/view/donate/PayResult.asp?order=') + encodeURIComponent(order);
                        }, 1400);
                    }
                });
            }, 700);
        }

        if (btnPay)   on(btnPay,   'click', function () { approve('success'); });
        if (btnFail)  on(btnFail,  'click', function () { approve('fail'); });
        if (btnClose) on(btnClose, 'click', close);

        /* backdrop 클릭으로 닫기 : <dialog> 는 backdrop 클릭이 dialog 자신을 타깃으로 한다 */
        on(modal, 'click', function (e) { if (e.target === modal) close(); });

        /* ESC : 승인 중에는 닫히지 않게 막는다 (네이티브 cancel 이벤트) */
        on(modal, 'cancel', function (e) { if (busy) e.preventDefault(); });
    }

    /* ------------------------------------------------------------------
       실행
       ------------------------------------------------------------------ */
    function ready(fn) {
        if (document.readyState !== 'loading') fn();
        else document.addEventListener('DOMContentLoaded', fn);
    }

    ready(function () {
        initNav();
        initTheme();
        initForms();
        initConfirm();
        initTop();
        initWideTable();
        initPhoneAuth();
        initSocialPopup();
        initPgModal();
    });
})();
