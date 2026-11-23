INVENTORY.SECONDARY = {
    MIN_SLOTS: 24,
    // pup: the secondary panel is a SLOT grid like the main satchel. The container's
    // capacity (house invspace, custom-inventory limit, ...) is its slot count, so the
    // grid is padded out to that many cells and the footer ring reads used/total slots.
    // MAX_SLOTS only guards the DOM against a silly capacity; 'oo' (stores) resolves to
    // null and falls back to the stock MIN_SLOTS grid.
    SLOT_COUNT: null,

    MAX_SLOTS: function () {
        // `let Config` in config.js is not a window property - read it directly
        if (typeof Config === "undefined") return 200;
        return Config.SecondaryInventoryMaxSlotCount || 200;
    },

    // TRUE capacity of the container, used for the footer ring. Not clamped: a market
    // stall really can hold 10100, and reporting "/200" there would be a lie.
    // 'oo' / missing resolves to null = unlimited.
    RESOLVE_SLOT_COUNT: function (capacity) {
        const n = parseFloat(String(capacity === undefined || capacity === null ? "" : capacity).trim());
        if (!isFinite(n) || n <= 0) return null;
        return Math.floor(n);
    },

    // How many CELLS to draw. Separate from SLOT_COUNT purely as a DOM guard - a
    // 10100-slot container must not create 10100 nodes. Items themselves always
    // render, so a big container still shows everything it holds; this only caps
    // how many trailing EMPTY slots get padded in.
    GRID_SLOTS: function () {
        if (!this.SLOT_COUNT) return this.MIN_SLOTS;
        return Math.max(this.MIN_SLOTS, Math.min(this.SLOT_COUNT, this.MAX_SLOTS()));
    },

    ACTION_TAKE_LIST: {
        custom: { action: "TakeFromCustom", id: () => customId, customtype: "id" },
        player: { action: "TakeFromPlayer", id: () => playerId, customtype: "player" },
        cart: { action: "TakeFromCart", id: () => wagonid, customtype: "wagon" },
        house: { action: "TakeFromHouse", id: () => houseId, customtype: "house" },
        hideout: { action: "TakeFromHideout", id: () => hideoutId, customtype: "hideout" },
        clan: { action: "TakeFromClan", id: () => clanid, customtype: "clan" },
        steal: { action: "TakeFromsteal", id: () => stealid, customtype: "steal" },
        Container: { action: "TakeFromContainer", id: () => Containerid, customtype: "Container" },
        horse: { action: "TakeFromHorse", id: () => horseid, customtype: "horse" },
    },

    ACTION_MOVE_LIST: {
        custom: { action: "MoveToCustom", id: () => customId, customtype: "id" },
        player: { action: "MoveToPlayer", id: () => playerId, customtype: "player" },
        cart: { action: "MoveToCart", id: () => wagonid, customtype: "wagon" },
        house: { action: "MoveToHouse", id: () => houseId, customtype: "house" },
        hideout: { action: "MoveToHideout", id: () => hideoutId, customtype: "hideout" },
        clan: { action: "MoveToClan", id: () => clanid, customtype: "clan" },
        steal: { action: "MoveTosteal", id: () => stealid, customtype: "steal" },
        Container: { action: "MoveToContainer", id: () => Containerid, customtype: "Container" },
        horse: { action: "MoveToHorse", id: () => horseid, customtype: "horse" },
    },

    POST_ACTION_POST_QTY: function (eventName, itemData, id, propertyName, qty, info) {
        if (isValidating) return;

        UTILS.PROCESS_EVENT_VALIDATION();

        $.post(
            `https://${GetParentResourceName()}/${eventName}`,
            JSON.stringify({
                item: itemData,
                type: itemData.type,
                number: qty,
                [propertyName]: id,
                info: info,
            })
        );
    },

    POST_ACTION: function (eventName, itemData, id, propertyName, info) {
        INVENTORY.DISABLE(500);
        if (itemData.type != "item_weapon") {
            if (itemData.count === 1 || isShiftActive === true) {
                const qty = isShiftActive ? itemData.count : 1;
                this.POST_ACTION_POST_QTY(eventName, itemData, id, propertyName, qty, info);
                return;
            }

            if (altDragActive && itemData.count > 1) {
                const qty = Math.ceil(itemData.count / 2);
                altDragActive = false;
                this.POST_ACTION_POST_QTY(eventName, itemData, id, propertyName, qty, info);
                return;
            }

            const self = this;
            dialog.prompt({
                title: LANGUAGE.prompttitle,
                button: LANGUAGE.promptaccept,
                required: true,
                item: itemData,
                type: itemData.type,
                input: {
                    type: "number",
                    autofocus: "true",
                },

                validate: function (value) {
                    if (!value || value <= 0 || value > Config.MaxItemTransferAmount || !UTILS.IS_INT(value)) {
                        $.post(`https://${GetParentResourceName()}/TransferLimitExceeded`, JSON.stringify({
                            max: Config.MaxItemTransferAmount,
                        }));

                        dialog.close();
                    } else {
                        self.POST_ACTION_POST_QTY(eventName, itemData, id, propertyName, value, info);
                    }
                },
            });
        } else {
            this.POST_ACTION_POST_QTY(eventName, itemData, id, propertyName, 1, info);
        }
    },

    TAKE_FROM_STORE: function (itemData, qty) {
        if (isValidating) return;

        UTILS.PROCESS_EVENT_VALIDATION();

        $.post(
            `https://${GetParentResourceName()}/TakeFromStore`,
            JSON.stringify({
                item: itemData,
                type: itemData.type,
                number: qty,
                price: itemData.price,
                geninfo: geninfo,
                store: StoreId,
            })
        );
    },

    MOVE_TO_STORE: function (itemData, qty) {
        if (isValidating) return;

        UTILS.PROCESS_EVENT_VALIDATION();

        $.post(
            `https://${GetParentResourceName()}/MoveToStore`,
            JSON.stringify({
                item: itemData,
                type: itemData.type,
                number: qty,
                geninfo: geninfo,
                store: StoreId,
            })
        );
    },

    MOVE_TO_STORE_PRICED: function (itemData, qty, price) {
        if (isValidating) return;

        UTILS.PROCESS_EVENT_VALIDATION();

        $.post(
            `https://${GetParentResourceName()}/MoveToStore`,
            JSON.stringify({
                item: itemData,
                type: itemData.type,
                number: qty,
                price: price,
                geninfo: geninfo,
                store: StoreId,
            })
        );
    },

    OPEN_STORE_PRICE_DIALOG: function (itemData, qty) {
        if (isValidating) return;

        UTILS.PROCESS_EVENT_VALIDATION();

        const self = this;
        dialog.prompt({
            title: LANGUAGE.prompttitle2,
            button: LANGUAGE.promptaccept,
            required: true,
            item: itemData,
            type: itemData.type,
            input: {
                type: "number",
                autofocus: "true",
            },
            validate: function (value2) {
                if (!value2) {
                    dialog.close();
                    return;
                }

                self.MOVE_TO_STORE_PRICED(itemData, qty, value2);
            },
        });
    },

    INIT_HANDLERS: function () {
        const S = INVENTORY.SECONDARY;

        $(document).on("click.shiftQuickMove", "#inventoryElement .item", function (e) {
            if (!e.shiftKey) return;
            if (type === "normal" || type === "main") return;
            const itemData = $(this).data("item");
            if (!itemData) return;
            const info = $("#secondInventoryElement").data("info");
            if (type in S.ACTION_MOVE_LIST) {
                const { action, id, customtype } = S.ACTION_MOVE_LIST[type];
                S.POST_ACTION(action, itemData, id(), customtype, info);
            } else if (type === "store") {
                INVENTORY.DISABLE(500);
                if (itemData.type !== "item_weapon") {
                    const qty = itemData.count;
                    if (geninfo.isowner != 0) {
                        S.OPEN_STORE_PRICE_DIALOG(itemData, qty);
                    } else {
                        S.MOVE_TO_STORE(itemData, qty);
                    }
                } else {
                    S.MOVE_TO_STORE(itemData, 1);
                }
            }
        });

        $(document).on("click.shiftQuickTake", "#secondInventoryElement .item", function (e) {
            if (!e.shiftKey) return;
            if (type === "normal" || type === "main") return;

            const itemData = $(this).data("item");
            if (!itemData) return;

            const info = $("#secondInventoryElement").data("info");
            if (type in S.ACTION_TAKE_LIST) {
                const { action, id, customtype } = S.ACTION_TAKE_LIST[type];
                S.POST_ACTION(action, itemData, id(), customtype, info);
            } else if (type === "store") {
                INVENTORY.DISABLE(500);
                const quantity = itemData.type !== "item_weapon" ? itemData.count : 1;
                S.TAKE_FROM_STORE(itemData, quantity);
            }
        });

        $("#inventoryElement").droppable({
            drop: function (_, ui) {
                // arranging the shop must never move stock: droppable fires for
                // sortable items too, so a drag that strays over the satchel
                // would otherwise take the item out of the shop for real
                if (INVENTORY.SECONDARY.SORT_ON) return;
                itemData = ui.draggable.data("item");
                itemInventory = ui.draggable.data("inventory");
                var info = $("#secondInventoryElement").data("info");

                if (itemInventory === "second") {
                    if (type in S.ACTION_TAKE_LIST) {
                        const { action, id, customtype } = S.ACTION_TAKE_LIST[type];
                        const Id = id();
                        S.POST_ACTION(action, itemData, Id, customtype, info);
                    } else if (type === "store") {
                        INVENTORY.DISABLE(500);
                        if (itemData.type != "item_weapon") {
                            if (itemData.count === 1 || isShiftActive === true) {
                                const qty = isShiftActive ? itemData.count : 1;
                                S.TAKE_FROM_STORE(itemData, qty);
                                return;
                            }

                            dialog.prompt({
                                title: LANGUAGE.prompttitle,
                                button: LANGUAGE.promptaccept,
                                required: true,
                                item: itemData,
                                type: itemData.type,
                                input: {
                                    type: "number",
                                    autofocus: "true",
                                },

                                validate: function (value) {
                                    if (!value) {
                                        dialog.close();
                                        return;
                                    }

                                    if (!UTILS.IS_INT(value)) {
                                        return;
                                    }

                                    S.TAKE_FROM_STORE(itemData, value);
                                },
                            });
                        } else {
                            S.TAKE_FROM_STORE(itemData, 1);
                        }
                    }
                }
            },
        });

        $("#secondInventoryElement").droppable({
            drop: function (_, ui) {
                // same guard as the satchel side: a reorder is not a transfer
                if (INVENTORY.SECONDARY.SORT_ON) return;
                itemData = ui.draggable.data("item");
                itemInventory = ui.draggable.data("inventory");
                var info = $(this).data("info");
                const $drag = ui.draggable;

                if (itemInventory === "main") {
                    if (type in S.ACTION_MOVE_LIST || type === "store") {
                        $drag.data("invDropAccepted", true);
                    }
                    if (type in S.ACTION_MOVE_LIST) {
                        const { action, id, customtype } = S.ACTION_MOVE_LIST[type];
                        const Id = id();
                        S.POST_ACTION(action, itemData, Id, customtype, info);
                    } else if (type === "store") {
                        INVENTORY.DISABLE(500);

                        if (itemData.type != "item_weapon") {
                            if (itemData.count === 1 || isShiftActive === true) {
                                const qty = isShiftActive ? itemData.count : 1;
                                if (geninfo.isowner != 0) {
                                    S.OPEN_STORE_PRICE_DIALOG(itemData, qty);
                                } else {
                                    S.MOVE_TO_STORE(itemData, qty);
                                }
                                return;
                            }

                            dialog.prompt({
                                title: LANGUAGE.prompttitle,
                                button: LANGUAGE.promptaccept,
                                required: true,
                                item: itemData,
                                type: itemData.type,
                                input: {
                                    type: "number",
                                    autofocus: "true",
                                },
                                validate: function (value) {
                                    if (!value) {
                                        dialog.close();
                                        return;
                                    }

                                    if (!UTILS.IS_INT(value)) {
                                        return;
                                    }

                                    if (geninfo.isowner != 0) {
                                        S.OPEN_STORE_PRICE_DIALOG(itemData, value);
                                    } else {
                                        S.MOVE_TO_STORE(itemData, value);
                                    }
                                },
                            });
                        } else {
                            const qty = 1;
                            if (geninfo.isowner != 0) {
                                S.OPEN_STORE_PRICE_DIALOG(itemData, qty);
                            } else {
                                S.MOVE_TO_STORE(itemData, qty);
                            }
                        }
                    }
                }
            },
        });
    },

    BIND_ITEM_DATA: function (item, index) {
        $("#item-" + index).data("item", item);
        $("#item-" + index).data("inventory", "second");
    },

    LOAD_ITEM_CELL: function (item, index, group, count, limit) {
        if (item.type === "item_weapon") return;

        const { tooltipData, degradation, image, label, weight, durability } = UTILS.GET_ITEM_METADATA_INFO(item, true);
        const itemWeight = UTILS.GET_ITEM_WEIGHT(weight, 1);
        const groupKey = UTILS.GET_GROUP_KEY(group);
        const { tooltipContent, url } = INVENTORY.TOOLTIP.GET_CONTENT(image, groupKey, group, limit, itemWeight, degradation, tooltipData, count, durability);
        const iconOpacityExtra = UTILS.ITEM_ICON_OPACITY_EXTRA(item);

        /* pup: items from a shop that never runs out arrive flagged infinite and
           simply show 1 - one is what you take, and it never runs out. (The
           inventory font has no infinity glyph.) Player and society shops hold
           real stock and are unflagged, so they show the number. */
        const badge = item.infinite ? 1 : count;

        $("#secondInventoryElement").append(
            `<div data-label='${label}' data-group='${group}' class='item item-filled' id="item-${index}" data-tooltip='${tooltipContent}'><span class='item-inv-icon' style='${UTILS.INVENTORY_SLOT_BACKGROUND_STYLE(url, "4.5vw", "7.7vh", iconOpacityExtra)}'></span>${(item.infinite || count > 0) ? `<div class='count'><span style='color:Black'>${badge}</span></div>` : ``}</div>`
        );

        UTILS.APPLY_RARITY_SLOT_CLASSES($("#item-" + index), item);
    },

    LOAD_WEAPON_CELL: function (item, index, group) {
        if (item.type != "item_weapon") return;

        const serial = item.serial_number ? "<br>" + LANGUAGE.labels.serial + UTILS.ESCAPE_HTML(String(item.serial_number)) : "";
        const info = serial + INVENTORY.TOOLTIP.ADD_WEAPON(item);
        const weight = UTILS.GET_ITEM_WEIGHT(item.weight, item.count);
        const url = imageCache[item.name];
        const iconOpacityExtra = UTILS.ITEM_ICON_OPACITY_EXTRA(item);
        $("#secondInventoryElement").append(
            `<div data-label='${item.label}' data-group ='${group}' class='item item-filled' id='item-${index}' data-tooltip="${weight + info}">
        <span class='item-inv-icon' style='${UTILS.INVENTORY_SLOT_BACKGROUND_STYLE(url, "4.5vw", "7.7vh", iconOpacityExtra)}'></span>
        ${INVENTORY.WEAPON.GET_AMMO_ICON(item)}
        <div class='equipped-icon' style='display: ${!item.used && !item.used2 ? "none" : "block"};'></div>
    </div>`
        );
    },

    // pup: the last list this panel rendered, so SORT has something to reorder.
    // Nothing else caches it - SETUP is always handed a fresh array.
    LAST_ITEMS: [],
    LAST_INFO: {},

    // Camp storage sorts the STORED array server side, so the order survives
    // reopening and everyone in the camp sees the same grid. Every other
    // container is visual only - nobody owns them, so nothing is rearranged
    // for other players.
    SORT: function () {
        const S = this;

        // clanid starts at 0 and is set on display; 0 is never a real camp
        if (type === "clan" && clanid) {
            $.post(
                `https://${GetParentResourceName()}/SortClanInventory`,
                JSON.stringify({ clan: clanid })
            );
            return;
        }
        if (type === "hideout" && hideoutId) {
            $.post(
                `https://${GetParentResourceName()}/SortHideoutInventory`,
                JSON.stringify({ hideout: hideoutId })
            );
            return;
        }

        const items = (S.LAST_ITEMS || []).slice();
        if (items.length < 2) return;

        items.sort(function (a, b) {
            const wa = a.type === "item_weapon";
            const wb = b.type === "item_weapon";
            if (wa !== wb) return wa ? 1 : -1;          // items first, weapons last
            const la = UTILS.GET_DISPLAY_LABEL(a).toLowerCase();
            const lb = UTILS.GET_DISPLAY_LABEL(b).toLowerCase();
            return la.localeCompare(lb);
        });

        S.SETUP(items, S.LAST_INFO || {});

        // pup: A to Z writes the order down the same path the manual Sort/Save
        // uses, so it sticks for everybody, not just until the next open.
        S.SAVE_ORDER(items);
    },

    // the order the server stores, taken from a list rather than the grid
    SAVE_ORDER: function (items) {
        if (!Array.isArray(items) || items.length < 2) return;

        // same shape CAPTURE_ORDER produces, so the existing server handlers parse it
        const order = items.map(function (it) {
            return { id: it.id, t: it.type };
        });

        if (type === "clan") {
            $.post(`https://${GetParentResourceName()}/ChangeOrderClan`,
                JSON.stringify({ clan: clanid, inventoryItems: order }));
        } else if (type === "hideout") {
            $.post(`https://${GetParentResourceName()}/ChangeOrderHideout`,
                JSON.stringify({ hideout: hideoutId, inventoryItems: order }));
        } else if (type === "custom") {
            $.post(`https://${GetParentResourceName()}/changeOrderCustom`,
                JSON.stringify({ customId: customId, inventoryItems: order }));
        } else if (type === "store") {
            $.post(`https://${GetParentResourceName()}/changeOrderStore`,
                JSON.stringify({ StoreId: StoreId, inventoryItems: order }));
        }
    },

    SETUP: function (items, info) {
        const S = this;
        S.LAST_ITEMS = Array.isArray(items) ? items.slice() : [];
        S.LAST_INFO = info || {};

        // pup: shop owners can arrange their store grid (see SORT_ENABLE). The
        // server already sends the list in saved order; re-sorting here is belt
        // and braces for any path that rebuilds the list client side. Only stores
        // carry a sortingnumber, so every other container keeps its natural order.
        // Array.sort is stable, so equal numbers keep the order the server sent.
        if (type === "store" && Array.isArray(items)) {
            items = items.slice().sort((a, b) => (a.sortingnumber || 0) - (b.sortingnumber || 0));
        }
        $("#secondInventoryElement").html("").data("info", info);
        var divCount = 0;

        if (items.length > 0) {
            $.each(items, function () {
                divCount = divCount + 1;
            });

            for (const [index, item] of items.entries()) {
                count = item.count;
                const group = item.type != "item_weapon" ? !item.group ? 1 : item.group : 5;
                const limit = item.limit;
                S.LOAD_ITEM_CELL(item, index, group, count, limit);
                S.LOAD_WEAPON_CELL(item, index, group);
                S.BIND_ITEM_DATA(item, index);
            }
        }

        const minSlots = S.GRID_SLOTS();
        if (divCount < minSlots) {
            const emptySlots = minSlots - divCount;
            for (var i = 0; i < emptySlots; i++) {
                $("#secondInventoryElement").append(`<div class='item' data-group='0'></div>`);
            }
        }

        S.RECALCULATE_CURRENT_CAPACITY();
        if (window.__pupUpdateCapRing) window.__pupUpdateCapRing();
    },

    RECALCULATE_CURRENT_CAPACITY: function () {
        let total = 0;
        $("#secondInventoryElement .item").each(function () {
            const d = $(this).data("item");
            if (!d) return;
            const count = d.type === "item_weapon" ? 1 : Number(d.count);
            if (Number.isFinite(count)) {
                total += count;
            }
        });
        this.SET_CURRENT_CAPACITY(total);
    },

    ITEM_ADDED: function (item) {
        if (!item) return;
        const S = this;
        const $inv = $("#secondInventoryElement");
        const group = item.type !== "item_weapon" ? item.group || 1 : 5;
        const index = "sa_" + item.id + "_" + Date.now();

        S.LOAD_ITEM_CELL(item, index, group, item.count, item.limit);
        S.LOAD_WEAPON_CELL(item, index, group);
        S.BIND_ITEM_DATA(item, index);

        const $newEl = $inv.children("#item-" + index);

        const $firstEmpty = $inv.children(".item").filter(function () {
            return !$(this).data("item") && $(this)[0] !== $newEl[0];
        }).first();

        if ($firstEmpty.length) {
            $newEl.insertBefore($firstEmpty);
            $inv.children(".item").filter(function () {
                return !$(this).data("item");
            }).last().remove();
        }

        $newEl.draggable({
            helper: function (event) {
                return UTILS.BUILD_INVENTORY_DRAG_HELPER(this, event);
            },
            appendTo: "body",
            zIndex: 99999,
            revert: "invalid",
            distance: 8,
            start: function (event) {
                if (disabled) return false;
                altDragActive = !!(event.altKey || event.originalEvent?.altKey);
                stopTooltip = true;
                itemData = $(this).data("item");
                itemInventory = "second";
            },
            stop: function () {
                altDragActive = false;
                stopTooltip = false;
                itemData = $(this).data("item");
                itemInventory = "second";
            },
        });

        S.RECALCULATE_CURRENT_CAPACITY();
    },

    ITEM_REMOVED: function (id, itemType) {
        const $inv = $("#secondInventoryElement");
        $inv.children(".item").filter(function () {
            const d = $(this).data("item");
            return d && d.id == id && d.type === itemType;
        }).remove();

        const total = $inv.children(".item").length;
        const minSlots = this.GRID_SLOTS();
        if (total < minSlots) {
            $inv.append(`<div class='item' data-group='0'></div>`);
        }

        this.RECALCULATE_CURRENT_CAPACITY();
    },

    ITEM_UPDATED: function (id, count) {
        const $el = $("#secondInventoryElement .item").filter(function () {
            const d = $(this).data("item");
            return d && d.id == id;
        });
        if (!$el.length) return;
        // pup: bare count here, NOT "held/limit" like the satchel. Containers
        // register with ignoreItemStackLimit = true, so a per-item limit is
        // meaningless in a stash and only misleads.
        const d0 = $el.data("item");
        // an infinite shop slot stays on 1 - the stock never moved
        $el.find(".count span").text(d0 && d0.infinite ? 1 : count);
        const d = d0;
        if (d) {
            d.count = count;
            $el.data("item", d);
        }

        this.RECALCULATE_CURRENT_CAPACITY();
    },

    SET_TITLE: function (title) {
        const el = document.getElementById("satchelTitle");
        if (el) el.innerHTML = title;
    },

    SET_CURRENT_CAPACITY: function (cap) {
        const cur = document.getElementById("current-cap-value");
        if (cur) cur.innerHTML = cap;
        UTILS.APPLY_INV_CAPACITY_WARNING($("#secondInventoryHud .capacity"), cap, SECONDARY_CAPACITY);
    },

    SET_CAPACITY: function (cap, weight) {
        $(".capacity").show();
        const capEl = document.getElementById("capacity-value");
        if (capEl) capEl.innerHTML = weight ? weight + " " + Config.WeightMeasure : cap;

        const w = weight != null && weight !== "" && !Number.isNaN(Number(weight)) ? Number(weight) : NaN;
        const m = Number.isFinite(w) ? w : Number(cap);
        SECONDARY_CAPACITY = Number.isFinite(m) && m > 0 ? m : null;

        const curNode = document.getElementById("current-cap-value");
        const currentNum = curNode != null ? parseFloat(String(curNode.textContent || "0").trim(), 10) : 0;
        const cur = Number.isFinite(currentNum) ? currentNum : 0;
        UTILS.APPLY_INV_CAPACITY_WARNING($("#secondInventoryHud .capacity"), cur, SECONDARY_CAPACITY);
    },

    INIT: function (title, capacity, weight, isShop, shopType) {
        // pup: resolve this container's slot count before anything renders
        this.SLOT_COUNT = this.RESOLVE_SLOT_COUNT(capacity);
        // pup: a shop has no capacity worth showing - see updateCapRing in ui.html
        this.IS_SHOP = isShop === true;
        // 1 = NPC store, 2 = player shop, 3 = society shop; 0 when unknown
        this.SHOP_TYPE = Number(shopType) || 0;
        $("#secondInventoryHud").append(
            `<div class='controls'><div class='controls-center'><input type='text' id='secondarysearch' placeholder='${LANGUAGE.inventorysearch}'/></div></div>`
        );
        // pup: SHOP OWNERS ONLY - arrange the store grid and save the order for
        // every customer. Gated on both checks: the panel must be a store, and
        // isowner comes from the server (pup_mercantile re-derives it, never trusts
        // the client), so a customer browsing the same shop gets no button.
        // .controls is removed and rebuilt on every open (mainInvScript.js:2715),
        // so the length check is only a guard against a double INIT.
        this.SORT_ON = false;
        // pup: every custom container (house, society, saddlebag, wagon, motel),
        // camp storage and hideout gets the same Sort/Save; the order is shared,
        // whoever saves it arranges it for all. Saddlebags and wagons open as "custom".
        // pup: ONE rule for every panel - the server said you manage this one.
        // Opening a container is not enough to rearrange it for everybody:
        // isowner comes from the server for custom containers too (openInventory's
        // canManage), so a container whose resource has not granted it has no Sort button.
        const canArrange = !!(geninfo && geninfo.isowner != 0);
        if (canArrange && $("#secondInventoryHud #sortToggle").length === 0) {
            $("#secondInventoryHud .controls").append(
                `<button id='sortToggle' class='sort-mode-off' type='button'>${(LANGUAGE && LANGUAGE.sortshop) || "Sort"}</button>`
            );
            $("#sortToggle").on("click", () => {
                if (this.SORT_ON) {
                    this.SORT_DISABLE(true);
                } else {
                    this.SORT_ENABLE();
                }
            });
        } else if ($("#secondInventoryHud #sortToggle").length !== 0) {
            $("#secondInventoryHud #sortToggle").remove();
        }

        // pup: A to Z lives in the controls row beside Sort, not in the header
        // where it would sit on top of the container's name.
        // Same gate as Sort: you do not reorder a container you do not manage.
        if (canArrange && $("#secondInventoryHud #secondInventorySort").length === 0) {
            $("#secondInventoryHud .controls").append(
                `<button id='secondInventorySort' type='button' title='Sort everything A to Z' aria-label='Sort A to Z'>A-Z</button>`
            );
        } else if (!canArrange) {
            $("#secondInventoryHud #secondInventorySort").remove();
        }

        $("#secondarysearch").bind("input", function () {
            var searchFor = $("#secondarysearch").val().toLowerCase();
            $("#secondInventoryElement .item").each(function () {
                var label = $(this).data("label");
                if (label) {
                    label = label.toLowerCase();
                    if (label.indexOf(searchFor) < 0) {
                        $(this).hide();
                    } else {
                        $(this).show();
                    }
                }
            });
        });

        $("#secondInventoryHud").fadeIn(200, () => {
            this.SCHEDULE_GROUP_STRIP();
        });

        UTILS.UPDATE_HINT_VISIBILITY();
        this.SET_TITLE(title);

        if (capacity) {
            this.SET_CAPACITY(capacity, weight);
        } else {
            this.SET_CAPACITY("0");
        }
    },

    // ------------------------------------------------------------------
    // pup: shop ARRANGE mode. Press Sort -> the grid becomes draggable and the
    // button reads Save; press Save -> the visual order is posted and stored on
    // the shop, so every customer afterwards sees the owner's layout.
    // ------------------------------------------------------------------
    SORT_ON: false,

    // Only real items take part. Empty padding cells are plain .item with
    // data-group="0" and are added/removed by the category filter, so including
    // them would make positions jump around.
    SORT_SELECTOR: ".item.item-filled",

    // Each filled cell is ALSO a jQuery UI draggable with a clone helper that is
    // appended to <body> (INIT_CROSS_INV_DRAG, mainInvScript.js:2379). Leave that
    // live while the grid is sortable and one drag runs both widgets: the clone
    // renders next to the element sortable is moving, which reads as the item
    // duplicating. So it has to be switched off for the duration.
    // Per element, because .draggable("disable") on a collection THROWS on the
    // first cell that never had the widget - and the empty padding cells never
    // do (INIT_CROSS_INV_DRAG filters to cells holding item data) - which aborts
    // the whole call and leaves every real cell still enabled.
    SET_CELL_DRAG: function (on) {
        $("#secondInventoryElement").children(this.SORT_SELECTOR).each(function () {
            const $cell = $(this);
            if (!$cell.data("ui-draggable")) return;
            try { $cell.draggable(on ? "enable" : "disable"); } catch (e) { /* skip this cell */ }
        });
    },

    // DOM order of the filled cells. The category filter and the search box only
    // show/hide cells (mainInvScript.js:796-799), never reorder or remove them,
    // so hidden rows still hold their true position here.
    CAPTURE_ORDER: function () {
        const out = [];
        $("#secondInventoryElement").children(this.SORT_SELECTOR).each(function () {
            const it = $(this).data("item");
            if (!it) return;
            out.push({ id: it.id, t: it.type });
        });
        return out;
    },

    SORT_ENABLE: function () {
        const $grid = $("#secondInventoryElement");
        if (!$grid.length) return;

        // start from an unfiltered grid, or a drag lands next to a visible
        // neighbour while hidden rows keep their old slots and the result reads
        // as scrambled to the owner
        $("#secondarysearch").val("").trigger("input");
        const all = document.querySelector('.dropdownButton1[data-param="all"][data-type="itemtype"]');
        if (all) all.click();

        // off BEFORE sortable takes over, so the two widgets never share a drag
        this.SET_CELL_DRAG(false);
        $grid.sortable({
            items: this.SORT_SELECTOR,
            tolerance: "pointer",
            revert: 120,
            forcePlaceholderSize: true,
        });
        $grid.addClass("is-sorting");

        this.SORT_ON = true;
        $("#sortToggle")
            .removeClass("sort-mode-off").addClass("sort-mode-on")
            .text((LANGUAGE && LANGUAGE.saveshop) || "Save");
    },

    SORT_DISABLE: function (save) {
        const $grid = $("#secondInventoryElement");
        let order = null;
        if ($grid.length && $grid.hasClass("ui-sortable")) {
            if (save) order = this.CAPTURE_ORDER();
            $grid.sortable("destroy");
        }
        $grid.removeClass("is-sorting");

        // Sweep up anything a drag left behind. A placeholder survives destroy if
        // the widget is torn down mid-drag, and it carries the dragged cell's own
        // classes, so it would sit in the grid looking like a second item. The
        // helper is a clone appended to <body> and is orphaned the same way.
        $grid.children(".ui-sortable-placeholder").remove();
        $("body > .ui-draggable-dragging, body > .ui-sortable-helper").remove();
        $grid.children(".item").removeClass("ui-sortable-helper ui-draggable-dragging")
            .css({ position: "", left: "", top: "", width: "", height: "", zIndex: "" });

        // flag down before the cells go live again, so the droppable guard and
        // the cell state can never disagree
        this.SORT_ON = false;
        this.SET_CELL_DRAG(true);

        $("#sortToggle")
            .removeClass("sort-mode-on").addClass("sort-mode-off")
            .text((LANGUAGE && LANGUAGE.sortshop) || "Sort");

        if (order && order.length) {
            if (type === "clan") {
                $.post(`https://${GetParentResourceName()}/ChangeOrderClan`,
                    JSON.stringify({ clan: clanid, inventoryItems: order }));
            } else if (type === "hideout") {
                $.post(`https://${GetParentResourceName()}/ChangeOrderHideout`,
                    JSON.stringify({ hideout: hideoutId, inventoryItems: order }));
            } else if (type === "custom") {
                $.post(`https://${GetParentResourceName()}/changeOrderCustom`,
                    JSON.stringify({ customId: customId, inventoryItems: order }));
            } else {
                $.post(`https://${GetParentResourceName()}/changeOrderStore`,
                    JSON.stringify({ StoreId: StoreId, inventoryItems: order }));
            }
        }
    },

    IS_CATEGORY_STRIP: function (container) {
        return !!(container && container.id === "staticCarousel" && container.closest(".secondary-item-groups"));
    },

    SET_GROUP_NAV_TITLE: function (key) {
        const el = document.getElementById("itemGroupsNavTitleSecond");
        if (!el) return;
        el.textContent = UTILS.RESOLVE_ITEM_GROUP_TITLE_TEXT(key);
    },

    SCHEDULE_GROUP_STRIP: function () {
        const container = document.getElementById("staticCarousel");
        if (!container) {
            return;
        }

        container.style.scrollBehavior = "auto";
        container.style.width = "";
        container.style.minWidth = "";
        container.style.maxWidth = "";
        container.style.flexBasis = "";
        container.scrollLeft = 0;

        requestAnimationFrame(() => INVENTORY.MAIN.CLAMP_CAT_STRIP(container));
        setTimeout(() => {
            const c = document.getElementById("staticCarousel");
            if (c) {
                c.style.scrollBehavior = "auto";
                INVENTORY.MAIN.CLAMP_CAT_STRIP(c);
            }
        }, 450);
    },

    ITEM_GROUPS_SELECTION: function (direction) {
        const strip = document.getElementById("staticCarousel");
        if (!strip) return;

        const buttons = Array.from(strip.querySelectorAll('.dropdownButton1[data-type="itemtype"]'));
        if (!buttons.length) return;

        const dir = direction < 0 ? -1 : 1;
        let idx = buttons.findIndex((b) => b.classList && b.classList.contains("active"));
        if (idx < 0) idx = 0;

        let next = idx + dir;
        if (next < 0 || next >= buttons.length) {
            return;
        }

        const target = buttons[next];
        if (!target) return;

        target.click();

        try {
            target.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "center" });
        } catch (e) {
            /* ignore */
        }
    },
};
