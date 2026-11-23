/* =============================================================================
 * Storage box bridge - NUI module
 *
 * Only wraps the stock functions, so vorp_inventory's own code is untouched.
 *
 * Behaviours:
 *   1. Drag a stamped box from the satchel onto a container  -> tip its contents in
 *      (PupDepositBoxToInv) instead of moving the box itself.
 *   2. Right-click an item inside a container -> "Transfer to box", pick one of the
 *      boxes you are carrying, item goes straight into it.
 *   3. A box that still holds items cannot be listed in a store.
 *
 * Loaded last, so INVENTORY.SECONDARY and the data.js globals already exist.
 * ========================================================================== */
(function () {
    // Item names that ARE storage boxes. Filled by the pup_boxNames message from
    // pup_StorageBox; until then every check below simply reads false.
    window.pupBoxItemNames = window.pupBoxItemNames || [];

    // Dropping a box on one of these empties it into the container and destroys the
    // box. MoveToPlayer is absent: handing someone a box should hand over the box.
    var BOX_DEPOSIT_EVENTS = {
        MoveToCustom: true,
        MoveToCart: true,
        MoveToHorse: true,
        MoveToHideout: true,
        MoveToClan: true,
        MoveToContainer: true,
        MoveTosteal: true,
        MoveToHouse: true,
    };

    var TRANSFER_LABEL = "Transfer to box";
    var PICKER_TITLE = "Transfer to Box";

    function post(path, payload) {
        $.post("https://" + GetParentResourceName() + "/" + path, JSON.stringify(payload || {}));
    }

    /* debug trace: the NUI has no in-game console, so this routes a line to F8 through the client */
    function boxdbg(msg, extra) {
        try { post("PupBoxDebug", { msg: String(msg), extra: extra || {} }); } catch (e) {}
    }


    function isBoxName(name) {
        return !!name && window.pupBoxItemNames.indexOf(name) !== -1;
    }

    /** Metadata arrives as an object most of the time and a JSON string sometimes. */
    function readMeta(item) {
        if (!item) return null;
        var meta = item.metadata;
        if (typeof meta === "string") {
            try {
                meta = JSON.parse(meta);
            } catch (e) {
                return null;
            }
        }
        return meta && typeof meta === "object" ? meta : null;
    }

    /** A box that has been used at least once and therefore owns an inventory. */
    function stampedBoxId(item) {
        var meta = readMeta(item);
        return meta && meta.boxId ? String(meta.boxId) : null;
    }

    /** The id of whatever container is currently open in the secondary panel. */
    function secondaryInvId() {
        switch (type) {
            case "custom": return typeof customId !== "undefined" ? customId : null;
            case "house": return typeof houseId !== "undefined" ? houseId : null;
            case "hideout": return typeof hideoutId !== "undefined" ? hideoutId : null;
            case "clan": return typeof clanid !== "undefined" ? clanid : null;
            case "cart": return typeof wagonid !== "undefined" ? wagonid : null;
            case "horse": return typeof horseid !== "undefined" ? horseid : null;
            case "steal": return typeof stealid !== "undefined" ? stealid : null;
            case "Container": return typeof Containerid !== "undefined" ? Containerid : null;
            default: return null;
        }
    }

    /** Every box currently in the satchel, stamped or not. */
    function carriedBoxes() {
        var boxes = [];
        $("#inventoryElement .item").each(function () {
            var invItem = $(this).data("item");
            if (!invItem) return;

            var boxId = stampedBoxId(invItem);
            // itemId is the INVENTORY row either way - idOrBoxId is not, for a
            // stamped box it is the container id, and callers need both
            if (boxId) {
                boxes.push({ label: invItem.label || invItem.name, isNew: false, idOrBoxId: boxId, itemId: invItem.id, itemName: invItem.name });
            } else if (isBoxName(invItem.name)) {
                boxes.push({ label: invItem.label || invItem.name, isNew: true, idOrBoxId: invItem.id, itemId: invItem.id, itemName: invItem.name });
            }
        });
        return boxes;
    }

    // -----------------------------------------------------------------------
    // Box picker overlay: its own markup and styles, scoped under #pup-box-picker
    // -----------------------------------------------------------------------
    var pending = null;

    function ensurePickerDom() {
        if (document.getElementById("pup-box-picker")) return;

        var style = document.createElement("style");
        style.id = "pup-box-picker-style";
        style.textContent = [
            // solid colour under the ink image, light text, so it reads against a dark scene
            "#pup-box-picker{position:fixed;inset:0;z-index:10050;display:none;align-items:center;justify-content:center;background:rgba(0,0,0,.72);}",
            "#pup-box-picker.pup-open{display:flex;}",
            "#pup-box-picker .pup-bp-panel{min-width:24vw;max-width:34vw;max-height:60vh;overflow:hidden auto;padding:2.6vh 2vw;",
            "background-color:rgba(14,11,9,.97);background-image:var(--inventory-image);background-repeat:no-repeat;background-position:center;background-size:100% 100%;",
            "border:1px solid rgba(190,165,120,.35);border-radius:4px;box-shadow:0 1vh 3vh rgba(0,0,0,.7);",
            "font-family:inherit;color:#efe3c8;text-shadow:0 1px 2px #000;text-align:center;}",
            "#pup-box-picker .pup-bp-title{font-size:2vh;letter-spacing:.1em;text-transform:uppercase;margin-bottom:1.8vh;color:#fff;}",
            "#pup-box-picker .pup-bp-list{list-style:none;margin:0;padding:0;}",
            "#pup-box-picker .pup-bp-list li{cursor:pointer;padding:1.1vh 1vw;margin:.5vh 0;font-size:1.7vh;color:#efe3c8;",
            "background-color:rgba(255,255,255,.06);border:1px solid rgba(190,165,120,.25);border-radius:3px;",
            "background-image:var(--dropdown-image);background-repeat:no-repeat;background-position:center;background-size:100% 100%;}",
            "#pup-box-picker .pup-bp-list li:hover{color:#fff;background-color:rgba(190,165,120,.22);background-image:var(--selection-box-image);}",
            "#pup-box-picker .pup-bp-tag{opacity:.7;font-size:1.3vh;margin-left:.4vw;}",
            "#pup-box-picker .pup-bp-cancel{margin-top:1.6vh;cursor:pointer;font-size:1.45vh;letter-spacing:.08em;text-transform:uppercase;color:#d9c9a4;opacity:.8;}",
            "#pup-box-picker .pup-bp-cancel:hover{opacity:1;color:#fff;}",
        ].join("");
        document.head.appendChild(style);

        var root = document.createElement("div");
        root.id = "pup-box-picker";
        root.innerHTML =
            '<div class="pup-bp-panel">' +
            '<div class="pup-bp-title"></div>' +
            '<ul class="pup-bp-list"></ul>' +
            '<div class="pup-bp-cancel">Cancel</div>' +
            "</div>";
        document.body.appendChild(root);

        $(root).on("click", function (e) {
            if (e.target === root) closePicker();
        });
        $(root).on("click", ".pup-bp-cancel", closePicker);
        $(root).on("click", ".pup-bp-list li", function () {
            var $li = $(this);
            sendTransfer($li.data("isNew") === true, $li.data("target"), $li.data("itemName") || null);
        });
    }

    function closePicker() {
        pending = null;
        $("#pup-box-picker").removeClass("pup-open");
    }

    // Drawn through the same dialog panel as the pack filter, so the two read as
    // one UI. Picking a row acts immediately; X or Esc cancels.
    // `onPick` makes the picker reusable: without it a row starts the stock
    // transfer, with it the caller decides what the chosen box is for.
    function openPicker(boxes, onPick) {
        if (!boxes || !boxes.length) return;
        var listId = "pupBoxList" + Date.now();

        var html = '<div class="pup-filter-list" id="' + listId + '">';
        boxes.forEach(function (box, i) {
            html += '<label data-i="' + i + '">';
            html += '<img src="img/items/' + escapeHtml(box.itemName || "") + '.png"'
                 + ' onerror="this.style.display=\'none\'" />';
            html += "<span>" + escapeHtml(box.label || "") + "</span>";
            html += '<span class="pup-filter-off" style="margin-left:auto;">'
                 + (box.isNew ? "new" : "in use") + "</span>";
            html += "</label>";
        });
        html += "</div>";

        dialog.alert({
            title: PICKER_TITLE,
            message: html,
            button: "Cancel",
            callback: function () { pending = null; },
        });

        var $list = $("#" + listId);
        $list.closest(".dialog-alert").addClass("pup-filter");

        $list.on("click", "label", function () {
            var box = boxes[parseInt($(this).attr("data-i"), 10)];
            if (!box) return;
            dialog.close();
            if (onPick) { closePicker(); onPick(box); return; }
            sendTransfer(box.isNew === true, box.idOrBoxId, box.itemName || null);
        });
    }

    // Escape closes only the picker. Capture phase, so it never reaches the body
    // handler that would otherwise close the whole inventory underneath it.
    document.addEventListener(
        "keyup",
        function (e) {
            if (!pending) return;
            if (e.key !== "Escape" && e.keyCode !== 27) return;
            e.stopPropagation();
            closePicker();
        },
        true
    );

    function sendTransfer(isNew, idOrBoxId, boxItemName) {
        var data = pending;
        closePicker();
        boxdbg("sendTransfer", { isNew: isNew, idOrBoxId: String(idOrBoxId), hasPending: !!data });
        if (!data) {
            boxdbg("ABORT: picker had no pending transfer");
            return;
        }

        if (isNew) {
            post("PupSendItemToNewBox", {
                item: data.item,
                sourceInvId: data.sourceInvId,
                invType: data.invType,
                qty: data.qty,
                targetItemId: parseInt(idOrBoxId, 10),
                targetItemName: boxItemName,
            });
        } else {
            post("PupSendItemToBox", {
                item: data.item,
                sourceInvId: data.sourceInvId,
                invType: data.invType,
                qty: data.qty,
                targetBoxId: String(idOrBoxId),
            });
        }
    }

    // Shared with pup_store.js, which needs the same boxes and the same picker
    // for "buy into box". One box picks itself rather than opening a list of one.
    window.pupBox = {
        carried: carriedBoxes,
        isBoxName: isBoxName,
        stampedBoxId: stampedBoxId,
        // `filter` narrows the list - buying needs a box that already owns an
        // inventory, so it asks for stamped ones only
        choose: function (onPick, filter) {
            var boxes = carriedBoxes();
            if (filter) boxes = boxes.filter(filter);
            if (!boxes.length) return false;
            if (boxes.length === 1) { onPick(boxes[0]); return true; }
            openPicker(boxes, onPick);
            return true;
        },
        stamped: function (b) { return b.isNew === false; },
    };

    function beginTransfer(item, sourceInvId, qty) {
        var boxes = carriedBoxes();
        boxdbg("beginTransfer", {
            item: item && item.name,
            itemId: item && item.id,
            sourceInvId: String(sourceInvId),
            invType: type,
            qty: qty,
            boxesFound: boxes.length,
            knownBoxNames: (window.pupBoxItemNames || []).length,
        });
        if (!boxes.length) {
            boxdbg("ABORT: no box found in the satchel - nothing to transfer into");
            return;
        }

        pending = { item: item, sourceInvId: String(sourceInvId), invType: type, qty: qty };
        openPicker(boxes);
    }

    function transferToBox(item, sourceInvId) {
        if (isValidating) return;
        UTILS.PROCESS_EVENT_VALIDATION();

        if (!carriedBoxes().length) return;

        if (item.count > 1) {
            dialog.prompt({
                title: LANGUAGE.prompttitle,
                button: LANGUAGE.promptaccept,
                required: false,
                item: item,
                type: item.type,
                input: { type: "number", autofocus: "true" },
                validate: function (value) {
                    if (!value || value <= 0 || value > item.count || !UTILS.IS_INT(value)) {
                        dialog.close();
                        return;
                    }
                    beginTransfer(item, sourceInvId, parseInt(value, 10));
                    return true;
                },
            });
            return;
        }

        beginTransfer(item, sourceInvId, 1);
    }

    // -----------------------------------------------------------------------
    // 1. Deposit intercept - wraps the stock secondary post
    // -----------------------------------------------------------------------
    var stockPostQty = INVENTORY.SECONDARY.POST_ACTION_POST_QTY;
    INVENTORY.SECONDARY.POST_ACTION_POST_QTY = function (eventName, itemData, id, propertyName, qty, info) {
        // a used job pack dropped on a container: full = Unload (the pack stays in the satchel), empty = stored as a plain
        // pack so it stacks. An unused pack is an ordinary item and deposits normally.
        if (BOX_DEPOSIT_EVENTS[eventName] === true && isPackName(itemData && itemData.name) && stampedBoxId(itemData)) {
            if (isValidating) return;
            UTILS.PROCESS_EVENT_VALIDATION();
            post("PupPackUnload", { item: itemData, targetType: propertyName, targetId: id, drop: true });
            return;
        }
        if (BOX_DEPOSIT_EVENTS[eventName] === true && stampedBoxId(itemData)) {
            if (isValidating) return;
            UTILS.PROCESS_EVENT_VALIDATION();
            post("PupDepositBoxToInv", { item: itemData, targetType: propertyName, targetId: id });
            return;
        }
        return stockPostQty.call(this, eventName, itemData, id, propertyName, qty, info);
    };

    // -----------------------------------------------------------------------
    // 3. A used box cannot be put up for sale. Both store entry points are wrapped
    //    rather than the droppable, so the shift-quick-move path is covered too.
    // -----------------------------------------------------------------------
    function blockUsedBox(itemData) {
        if (!isBoxName(itemData && itemData.name)) return false;
        // job packs are decided server side: pup_mercantile refuses only a loaded one
        if (isPackName(itemData.name)) return false;
        // a stamped storage box holds something
        var boxId = stampedBoxId(itemData);
        if (!boxId) return false;

        // the owner tips the contents onto the shelves (new items land shelved); a customer is refused
        if (typeof geninfo !== "undefined" && geninfo && geninfo.isowner != 0) {
            post("PupBoxDumpToStore", { id: itemData.id, boxId: boxId });
            return true;
        }

        post("PupBoxBlockStore", {});
        return true;
    }

    var stockMoveToStore = INVENTORY.SECONDARY.MOVE_TO_STORE;
    INVENTORY.SECONDARY.MOVE_TO_STORE = function (itemData, qty) {
        if (blockUsedBox(itemData)) return;
        return stockMoveToStore.call(this, itemData, qty);
    };

    var stockStorePriceDialog = INVENTORY.SECONDARY.OPEN_STORE_PRICE_DIALOG;
    INVENTORY.SECONDARY.OPEN_STORE_PRICE_DIALOG = function (itemData, qty) {
        if (blockUsedBox(itemData)) return;
        return stockStorePriceDialog.call(this, itemData, qty);
    };

    // -----------------------------------------------------------------------
    // 2. "Transfer to box" on every item drawn in the secondary panel
    // -----------------------------------------------------------------------
    var stockBindItemData = INVENTORY.SECONDARY.BIND_ITEM_DATA;
    INVENTORY.SECONDARY.BIND_ITEM_DATA = function (item, index) {
        stockBindItemData.call(this, item, index);

        // Scoped to the secondary grid: the main grid can hold the same #item-N id.
        var $cell = $("#secondInventoryElement").find("#item-" + index);
        if (!$cell.length) return;

        $cell.contextMenu(
            function () {
                var current = $(this).data("item") || item;
                return [[
                    {
                        text: TRANSFER_LABEL,
                        action: function () {
                            transferToBox(current, secondaryInvId());
                        },
                    },
                ]];
            },
            {
                offsetX: 1,
                offsetY: 1,
                beforeShow: function () {
                    var current = $(this).data("item") || item;
                    if (!current || current.type === "item_weapon") return false;
                    if (current.canRemove === false) return false;
                    if (type === "store" || type === "steal" || type === "player") return false;
                    if (secondaryInvId() === null) return false;
                    // Storing a box inside a box is refused server-side anyway.
                    if (isBoxName(current.name)) return false;
                    return carriedBoxes().length > 0;
                },
            }
        );
    };

    // -----------------------------------------------------------------------
    // 4. Job packs (miner / lumber): right-click in the satchel gets Unload and
    //    Filter on top of the stock Use / Give / Destroy. The stock menu is bound
    //    per cell in ADD_MAIN_ITEM_ROW, so the pack cells are rebound here with
    //    the same entries plus ours.
    // -----------------------------------------------------------------------
    window.pupPackItemNames = window.pupPackItemNames || [];

    function isPackName(name) {
        return !!name && window.pupPackItemNames.indexOf(name) !== -1;
    }

    var stockAddMainItemRow = INVENTORY.MAIN.ADD_MAIN_ITEM_ROW;
    INVENTORY.MAIN.ADD_MAIN_ITEM_ROW = function (domId, item) {
        stockAddMainItemRow.call(this, domId, item);
        // boxes too, for "Sell contents here" while a shop is open
        if (!item || (!isPackName(item.name) && !isBoxName(item.name))) return;

        var $cell = $(INVENTORY.MAIN.GET_ITEM_SELECTOR(domId));
        if (!$cell.length) return;
        $cell.off("contextmenu");

        $cell.contextMenu(
            function () {
                var current = $(this).data("item") || item;
                var stamped = stampedBoxId(current);
                var entries = [{
                    text: LANGUAGE.use,
                    action: function () {
                        $.post("https://" + GetParentResourceName() + "/UseItem", JSON.stringify({
                            item: current.name, type: current.type, hash: current.hash, amount: current.count, id: current.id,
                        }));
                    },
                }];
                if (isPackName(current.name) && stamped && type !== "store") {
                    entries.push({
                        text: "Unload",
                        action: function () {
                            post("PupPackUnload", { item: current, targetType: type, targetId: secondaryInvId() });
                        },
                    });
                    entries.push({
                        text: "Filter",
                        action: function () {
                            post("PupPackFilter", { item: current });
                        },
                    });
                }
                // the shop prices everything inside and pays; the box stays yours
                if (stamped && type === "store") {
                    entries.push({
                        text: "Sell contents here",
                        action: function () {
                            // same confirm panel the destroy prompt uses: only `true` acts
                            dialog.alert({
                                title: "Sell from " + (current.label || current.name) + "?",
                                message: '<div class="pup-filter-sub">The shop takes everything inside that it buys.'
                                       + (isPackName(current.name)
                                            ? ' The pack stays yours.'
                                            : ' If it empties, the box goes with the goods.') + '</div>',
                                button: "Sell",
                                callback: function (ok) {
                                    if (ok !== true) return;
                                    post("PupStoreSellBox", { store: StoreId, boxItemId: current.id });
                                },
                            });
                        },
                    });
                }
                if (current.canRemove && type === "main") {
                    entries.push({
                        text: INVENTORY.MAIN.CTX_MENU_GIVE_ROOT(),
                        action: function () { return INVENTORY.MAIN.GIVE.ITEM(current); },
                    });
                    entries.push({
                        text: INVENTORY.MAIN.CTX_MENU_DROP_ROOT(),
                        action: function () { return INVENTORY.MAIN.DROP.ITEM(current); },
                    });
                }
                return [entries];
            },
            { offsetX: 1, offsetY: 1 }
        );
    };

    // -----------------------------------------------------------------------
    // 5. Pack filter dialog: the stock Quantity dialog with a tick list in it.
    //    Accept posts the ticked names back; Esc / X / outside click discards.
    // -----------------------------------------------------------------------
    function escapeHtml(s) {
        return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
            return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
        });
    }

    function openPackFilter(info) {
        var materials = Array.isArray(info.materials) ? info.materials : [];
        if (!materials.length) return;
        var picked = info.picked || {};
        var text = info.text || {};
        var listId = "pupFilterList" + Date.now();

        var html = '<div class="pup-filter-sub">' + escapeHtml(text.title || "") + "</div>";
        html += '<div class="pup-filter-list" id="' + listId + '">';
        materials.forEach(function (m) {
            var on = picked[m.name] === true;
            html += '<label>';
            html += '<input type="checkbox" value="' + escapeHtml(m.name) + '"' + (on ? " checked" : "") + " />";
            html += '<img src="img/items/' + escapeHtml(m.name) + '.png" onerror="this.style.display=\'none\'" />';
            html += '<span' + (on ? "" : ' class="pup-filter-off"') + ">" + escapeHtml(m.label || m.name) + "</span>";
            html += "</label>";
        });
        html += "</div>";
        html += '<span class="pup-filter-all">' + escapeHtml(text.all || "Tick everything") + "</span>";
        html += '<div class="pup-filter-save-desc">' + escapeHtml(text.saveDesc || "") + "</div>";

        dialog.alert({
            title: info.label || "",
            message: html,
            button: text.save || LANGUAGE.promptaccept || "Accept",
            callback: function (ok) {
                if (ok !== true) return;
                var filter = {};
                var ticked = 0;
                $("#" + listId + " input:checked").each(function () {
                    filter[$(this).val()] = true;
                    ticked++;
                });
                post("PupPackFilterSet", {
                    itemId: info.itemId,
                    boxId: info.boxId,
                    filter: filter,
                    all: ticked === materials.length,
                });
            },
        });

        var $list = $("#" + listId);
        var $box = $list.closest(".dialog-alert").addClass("pup-filter");
        // greyed label follows the tick
        $list.on("change", "input", function () {
            $(this).siblings("span").toggleClass("pup-filter-off", !this.checked);
        });
        $box.find(".pup-filter-all").on("click", function () {
            $list.find("input").prop("checked", true).trigger("change");
        });
    }

    // -----------------------------------------------------------------------
    // Messages from client/controllers/pup_storageBox.lua
    // -----------------------------------------------------------------------
    window.addEventListener("message", function (event) {
        var data = event.data || {};

        if (data.action === "pup_boxNames") {
            window.pupBoxItemNames = Array.isArray(data.names) ? data.names : [];
            window.pupPackItemNames = Array.isArray(data.packs) ? data.packs : [];
            return;
        }

        if (data.action === "pup_packFilter") {
            openPackFilter(data.data || {});
            return;
        }

        if (data.action === "pup_closeSecondary") {
            closePicker();
            $(".tooltip").remove();
            $(".site-cm-box").remove();
            $("#secondInventoryHud").fadeOut();
            $("body").removeClass("main-inv-with-secondary");
            INVENTORY.SECONDARY.SLOT_COUNT = null;
            // The container is gone, so the satchel goes back to normal routing -
            // leaving `type` stale would keep the main context menus suppressed.
            if (type !== "normal") type = "main";
            dialog.close();
        }
    });

    // The Lua broadcast can fire before this page exists, so ask once on load.
    $(function () {
        $.post("https://" + GetParentResourceName() + "/PupRequestBoxNames", "{}", function (res) {
            if (typeof res === "string") {
                try {
                    res = JSON.parse(res);
                } catch (e) {
                    return;
                }
            }
            if (res && Array.isArray(res.names) && res.names.length) {
                window.pupBoxItemNames = res.names;
            }
            if (res && Array.isArray(res.packs)) {
                window.pupPackItemNames = res.packs;
            }
        });
    });
})();
