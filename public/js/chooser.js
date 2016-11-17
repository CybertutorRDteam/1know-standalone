(function() {
    var pe ;
    OneKnow = {
        choose: function(b) {
            function e(a) {
                (a = JSON.parse(a.data), "success" === a.type && b.success ? b.success(a.data) : "cancel" === a.type && b.cancel && b.cancel(a.data))
            }
            var f = screen.height / 2 - 240,
                g = screen.width / 2 - 320;
            //    c = host_name;
            //b.host && (c = b.host);
            if ( pe )
                window.removeEventListener("message",pe);
            var win = window.open(["/chooser?","type=",b.uploadType,"&unit_uqid=",b.unitUqid].join(""), "1409620722041", ["width=942,height=582,menubar=0,titlebar=0,status=0,top=", f, ",left=", g].join(""));
            win.focus();
            window.addEventListener ? window.addEventListener("message",e) : (window.attachEvent && window.attachEvent("onmessage", e));
            pe = e ;
        }
    }
})();