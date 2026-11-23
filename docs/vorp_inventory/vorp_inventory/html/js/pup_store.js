/* =============================================================================
 * pup store owner tools - NUI module
 *
 * Shop stock rows carry `forsale` from pup_mercantile. Owners and managers get a
 * right-click on every stocked row to take it off sale or put it back; a row
 * that is off sale is drawn faded for them and is never sent to customers at
 * all (pup_mercantile buildShopList). Loaded after pup_storagebox.js so it wraps the
 * already-wrapped BIND_ITEM_DATA.
 * ========================================================================== */
(function () {
    function post(path, payload) {
        $.post("https://" + GetParentResourceName() + "/" + path, JSON.stringify(payload || {}));
    }

    function isOwnerStore() {
        return type === "store" && typeof geninfo !== "undefined" && geninfo && geninfo.isowner != 0;
    }

    // window.pupBox is published by pup_storagebox.js, which loads first.
    // A box straight off the shelf has no container yet; the server makes one
    // on the first buy, so an unopened box is offered the same as any other.
    function hasBox() {
        return !!(window.pupBox && window.pupBox.carried().length);
    }

    // Goods go straight into the box, so satchel weight never limits the buy.
    // pup_mercantile re-prices and re-checks everything; the owner/customer wording is only a label.
    function buyIntoBox(current) {
        if (!hasBox()) return;
        var most = (current.itemcount != null && current.itemcount > 0) ? current.itemcount : null;
        var owns = isOwnerStore();

        dialog.prompt({
            title: "How many into the box?" + (most ? " (" + most + " in stock)" : ""),
            button: owns ? "Move" : "Buy",
            required: false,
            item: current.label || current.name,
            type: current.type,
            input: { type: "number", autofocus: "true" },
            validate: function (value) {
                var n = parseInt(value, 10);
                if (!isFinite(n) || n <= 0 || (most && n > most)) { dialog.close(); return; }
                window.pupBox.choose(function (box) {
                    post("PupStoreBuyIntoBox", {
                        store: typeof StoreId !== "undefined" ? StoreId : null,
                        boxItemId: box.itemId,
                        rowId: current.id,
                        rowName: current.name,
                        amount: n,
                    });
                });
                return true;
            },
        });
    }

    var stockBindItemData = INVENTORY.SECONDARY.BIND_ITEM_DATA;
    INVENTORY.SECONDARY.BIND_ITEM_DATA = function (item, index) {
        stockBindItemData.call(this, item, index);
        if (type !== "store" || !item) return;

        var $cell = $("#secondInventoryElement").find("#item-" + index);
        if (!$cell.length) return;

        // shelved rows read as such at a glance
        if (item.forsale === false) {
            $cell.addClass("pup-off-sale").css("opacity", 0.45);
        }

        // bound for every shopper: owner rows are added inside, customers get "Buy into storage box"
        $cell.contextMenu(
            function () {
                var current = $(this).data("item") || item;
                var off = current.forsale === false;
                var entries = [];

                if (hasBox() && current.type !== "item_weapon") {
                    entries.push({
                        text: isOwnerStore() ? "Move into storage box" : "Buy into storage box",
                        action: function () { buyIntoBox(current); },
                    });
                }
                if (!isOwnerStore()) return [entries];

                entries.push(
                    {
                        text: off ? "Put on sale" : "Take off sale",
                        action: function () {
                            post("PupStoreToggleSale", { id: current.id, type: current.type });
                        },
                    },
                    {
                        // price takes decimals, so no IS_INT here - the server rounds to 2dp
                        text: "Set price",
                        action: function () {
                            dialog.prompt({
                                title: "Set price (now $" + (current.price != null ? current.price : 0) + ")",
                                button: "Confirm",
                                required: false,
                                item: current.label || current.name,
                                type: current.type,
                                input: { type: "number", autofocus: "true" },
                                validate: function (value) {
                                    var n = parseFloat(value);
                                    if (!isFinite(n) || n <= 0) { dialog.close(); return; }
                                    post("PupStoreSetPrice", {
                                        id: current.id, type: current.type, price: n,
                                    });
                                    return true;
                                },
                            });
                        },
                    }
                );
                return [entries];
            },
            {
                offsetX: 1,
                offsetY: 1,
                beforeShow: function () {
                    var current = $(this).data("item") || item;
                    if (isOwnerStore()) return true;
                    return hasBox() && !!current && current.type !== "item_weapon";
                },
            }
        );
    };
})();
