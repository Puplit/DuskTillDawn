/* Player-written item descriptions: the satchel's edit card.
   Eligibility shown here is a courtesy - the server re-checks every rule. */

var PUP_DESC = (function () {
    var myCharId = null;
    var open = false;
    var MAX = 300;

    function escapeHtml(s) {
        return String(s === null || s === undefined ? "" : s)
            .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    }

    /* Shows the markup as written - pictures and links included, since
       descriptions here use them. Only the parts the server would strip are
       pulled out, so the preview is honest without running anything. */
    function preview(src) {
        return String(src || "")
            .replace(/<\s*script[\s\S]*?<\s*\/\s*script\s*>/gi, "")
            .replace(/<\s*style[\s\S]*?<\s*\/\s*style\s*>/gi, "")
            .replace(/\son[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, "")
            .replace(/(href|src)\s*=\s*("|')?\s*(javascript|data|vbscript):[^"'>\s]*("|')?/gi, "");
    }

    function plainLength(s) {
        return String(s || "").replace(/<[^>]*>/g, "").length;
    }

    function meta(item) {
        var m = item && item.metadata;
        if (typeof m === "string") { try { m = JSON.parse(m); } catch (e) { m = null; } }
        return m && typeof m === "object" ? m : null;
    }

    function canEdit(item) {
        if (!item || myCharId === null) return false;
        if (item.type === "item_weapon") return false;
        var m = meta(item);
        if (!m || m.descLocked) return false;
        return m.crafter != null && Number(m.crafter) === Number(myCharId);
    }

    function close() {
        if (!open) return;
        open = false;
        $("#pupDescCard").remove();
    }

    function save(item) {
        var text = $("#pupDescInput").val() || "";
        $.post("https://" + GetParentResourceName() + "/PupDescSave",
            JSON.stringify({ id: item.id, text: text }));
        close();
    }

    function render(item) {
        var m = meta(item) || {};
        var current = m.description != null ? String(m.description) : "";
        var name = UTILS.GET_DISPLAY_LABEL(item);

        $("#pupDescCard").remove();
        $("body").append(
            '<div id="pupDescCard">' +
            '  <div class="pup-desc-box">' +
            '    <div class="pup-desc-title">' + escapeHtml(name) + "</div>" +
            '    <textarea id="pupDescInput" maxlength="2000" spellcheck="false"></textarea>' +
            '    <div class="pup-desc-count"><span id="pupDescLen">0</span>/' + MAX + " text</div>" +
            '    <div class="pup-desc-label">Preview</div>' +
            '    <div class="pup-desc-preview" id="pupDescPreview"></div>' +
            '    <div class="pup-desc-warn" id="pupDescWarn"></div>' +
            '    <div class="pup-desc-savedhead">' +
            '      <span>Saved</span>' +
            '      <button id="pupDescKeep" class="pup-desc-mini">Save this one</button>' +
            "    </div>" +
            '    <div class="pup-desc-saved" id="pupDescSaved"></div>' +
            '    <div class="pup-desc-actions">' +
            '      <button id="pupDescSave" class="pup-desc-btn">Save description</button>' +
            '      <button id="pupDescCancel" class="pup-desc-btn pup-desc-btn--ghost">Cancel</button>' +
            "    </div>" +
            "  </div>" +
            "</div>"
        );

        $("#pupDescInput").val(current);
        open = true;

        function refresh() {
            var v = $("#pupDescInput").val() || "";
            var n = plainLength(v);
            $("#pupDescLen").text(n);
            $("#pupDescLen").toggleClass("over", n > MAX);
            $("#pupDescPreview").html(preview(v));
            /* emptying it is one-way: say so before they commit */
            $("#pupDescWarn").text(v.trim() === ""
                ? "Saving it empty closes this item for good - you will not be able to change it again."
                : "");
            $("#pupDescSave").prop("disabled", n > MAX);
        }

        $("#pupDescInput").on("input", refresh);
        refresh();
        $("#pupDescInput").trigger("focus");

        $("#pupDescSave").on("click", function () { save(item); });
        $("#pupDescCancel").on("click", close);

        /* the same twenty the crafting bench keeps - one list, read from there */
        var saved = [];
        var MAX_SAVED = 20;

        function pushSaved() {
            $.post("https://" + GetParentResourceName() + "/PupDescSavedSet",
                JSON.stringify({ list: saved }));
            drawSaved();
        }

        function drawSaved() {
            var $box = $("#pupDescSaved");
            if (!saved.length) {
                $box.html('<div class="pup-desc-empty">Nothing saved yet.</div>');
                return;
            }
            $box.empty();
            saved.forEach(function (text, i) {
                /* an image-only entry strips to nothing, so give it a placeholder label */
                var short = text.replace(/<[^>]*>/g, "").trim();
                if (!short) short = /<\s*img/i.test(text) ? "(picture)" : "(formatting)";
                if (short.length > 48) short = short.slice(0, 48) + "...";
                var $row = $('<div class="pup-desc-savedrow"></div>');
                $row.append($('<span class="pup-desc-savedtext"></span>').text(short));
                $row.append($('<button class="pup-desc-mini">Use</button>').on("click", function () {
                    $("#pupDescInput").val(text);
                    refresh();
                }));
                $row.append($('<button class="pup-desc-mini pup-desc-mini--bad">Delete</button>').on("click", function () {
                    saved.splice(i, 1);
                    pushSaved();
                }));
                $box.append($row);
            });
        }

        $("#pupDescKeep").on("click", function () {
            var v = ($("#pupDescInput").val() || "").trim();
            if (!v) return;
            saved = saved.filter(function (d) { return d !== v; });
            saved.unshift(v);
            while (saved.length > MAX_SAVED) saved.pop();
            pushSaved();
        });

        $.post("https://" + GetParentResourceName() + "/PupDescSavedGet", "{}", function (res) {
            saved = (res && Array.isArray(res.list)) ? res.list : [];
            drawSaved();
        });
        drawSaved();
    }

    /* Esc closes the card FIRST. Capture phase, so it lands before the satchel's
       own keyup on body, which would otherwise close the whole inventory. */
    document.addEventListener("keyup", function (e) {
        if (!open) return;
        if (e.key === "Escape" || e.keyCode === 27) {
            e.stopPropagation();
            e.preventDefault();
            close();
        }
    }, true);

    window.addEventListener("message", function (ev) {
        var d = ev.data || {};
        if (d.action === "pup_descWho") myCharId = d.charid != null ? Number(d.charid) : null;
        if (d.action === "closeinventory" || d.action === "close") close();
    });

    $(function () {
        $.post("https://" + GetParentResourceName() + "/PupDescWho", "{}", function (res) {
            if (res && res.charid != null) myCharId = Number(res.charid);
        });

        /* matched to the satchel: 'crock', white on flat dark, hairline rules and
           transparent outlined buttons - the same vocabulary as the pack filter
           dialog and the sort confirm popup */
        $("head").append(
            "<style>" +
            "#pupDescCard{position:fixed;inset:0;z-index:99999;display:flex;align-items:center;justify-content:center;" +
                "background:rgba(0,0,0,.6);font-family:'crock',serif;" +
                "text-shadow:0 1px 2px rgba(0,0,0,.95)}" +
            ".pup-desc-box{width:32vw;min-width:360px;background:rgba(12,10,8,.97);" +
                "border:1px solid rgba(255,255,255,.18);border-radius:2px;padding:1.4vh 1vw;color:#ece7dc}" +
            ".pup-desc-title{font-size:1.05vw;line-height:1.2;color:#fff;padding-bottom:.8vh;margin-bottom:1vh;" +
                "border-bottom:1px solid rgba(255,255,255,.12)}" +
            "#pupDescInput{width:100%;height:12vh;resize:none;background:rgba(0,0,0,.35);color:#fff;" +
                "border:1px solid rgba(255,255,255,.18);border-radius:2px;padding:.6vh .5vw;" +
                "font-family:'crock',serif;font-size:.8vw;line-height:1.4;outline:none}" +
            "#pupDescInput:focus{border-color:rgba(245,240,230,.45)}" +
            ".pup-desc-count{text-align:right;font-size:.65vw;color:#d8d2c4;margin-top:.4vh}" +
            ".pup-desc-count .over{color:#a83232}" +
            ".pup-desc-label{font-size:.65vw;text-transform:uppercase;letter-spacing:.08em;color:#d8d2c4;margin:1.2vh 0 .4vh}" +
            ".pup-desc-preview{min-height:6vh;background:rgba(0,0,0,.35);border:1px solid rgba(255,255,255,.12);" +
                "border-radius:2px;padding:.6vh .5vw;font-size:.8vw;line-height:1.4;word-wrap:break-word}" +
            ".pup-desc-preview img{display:block;margin:.4vh auto 0;max-width:100%;max-height:18vh}" +
            ".pup-desc-warn{min-height:2vh;color:#a83232;font-size:.68vw;margin-top:.6vh;line-height:1.3}" +
            ".pup-desc-actions{display:flex;gap:.4vw;justify-content:flex-end;margin-top:1.2vh}" +
            ".pup-desc-btn{background:transparent;color:#f5f0e6;border:1px solid rgba(245,240,230,.4);border-radius:2px;" +
                "padding:.6vh .8vw;font-size:.72vw;cursor:pointer;font-family:'crock',serif}" +
            ".pup-desc-btn:hover{background:rgba(255,255,255,.08)}" +
            ".pup-desc-btn:disabled{opacity:.4;cursor:default;background:transparent}" +
            ".pup-desc-savedhead{display:flex;align-items:center;justify-content:space-between;" +
                "font-size:.65vw;text-transform:uppercase;letter-spacing:.08em;color:#d8d2c4;margin:1.4vh 0 .4vh}" +
            ".pup-desc-saved{max-height:14vh;overflow-y:auto;border:1px solid rgba(255,255,255,.12);" +
                "border-radius:2px;background:rgba(0,0,0,.35)}" +
            ".pup-desc-saved::-webkit-scrollbar{width:.3vw}" +
            ".pup-desc-saved::-webkit-scrollbar-thumb{background:rgba(255,255,255,.35)}" +
            ".pup-desc-savedrow{display:flex;align-items:center;gap:.4vw;padding:.7vh .4vw;" +
                "border-bottom:1px solid rgba(255,255,255,.12)}" +
            ".pup-desc-savedrow:last-child{border-bottom:none}" +
            ".pup-desc-savedrow:hover{background:rgba(255,255,255,.08)}" +
            ".pup-desc-savedtext{flex:1;font-size:.72vw;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}" +
            ".pup-desc-empty{padding:.7vh .5vw;font-size:.68vw;color:#d8d2c4;opacity:.7}" +
            ".pup-desc-mini{background:transparent;color:#f5f0e6;border:1px solid rgba(245,240,230,.4);border-radius:2px;" +
                "padding:.35vh .5vw;font-size:.65vw;cursor:pointer;font-family:'crock',serif}" +
            ".pup-desc-mini:hover{background:rgba(255,255,255,.08)}" +
            ".pup-desc-mini--bad{border-color:rgba(168,50,50,.75);color:#e8b4b4}" +
            ".pup-desc-mini--bad:hover{background:rgba(168,50,50,.25)}" +
            "</style>"
        );
    });

    return {
        canEdit: canEdit, open: render, close: close,
        isOpen: function () { return open; },
        /* render-time guard for descriptions written before the server sanitiser */
        clean: preview,
    };
})();
