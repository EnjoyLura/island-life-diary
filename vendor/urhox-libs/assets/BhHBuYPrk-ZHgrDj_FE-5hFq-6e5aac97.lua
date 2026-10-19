-- ============================================================================
-- UIInspector - Component Property Schema
-- Each component declares its own prop metadata as an ordered array.
-- Inspector walks the component hierarchy to collect all available props.
-- Properties belong to components; lookups walk Widget → component inheritance.
-- ============================================================================

local Schema = {}

-- Built by Schema.apply()
Schema._propOrder = nil    -- key → number (definition order for sorting)
Schema._tabProps = nil     -- tab → { key = true, ... }
Schema._labelMap = nil     -- key → label (first-seen label for getPropLabel without widget)
Schema._resolved = nil     -- className → { key → def } (预算的完整属性表，含继承)

Schema.COMPONENTS = {
    Widget = {
        propDefs = {
            -- common
            { key = "id",              label = "ID",         type = "string",  tab = { "common" } },
            { key = "visible",         label = _tr("t_bSVSTh8rax2ye6mN"),       type = "boolean", tab = { "common" } },
            -- layout: size
            { key = "width",           label = _tr("t_56IPJjGaWZzjq8"),       type = "layout",  tab = { "common", "layout" } },
            { key = "height",          label = _tr("t_3iomUJfR3DOUtsUV"),       type = "layout",  tab = { "common", "layout" } },
            { key = "minWidth",        label = _tr("t_AIvkUtgSABfchKfC"),   type = "layout",  tab = { "layout" } },
            { key = "maxWidth",        label = _tr("t_KKRlB7srKDC3UOmR"),   type = "layout",  tab = { "layout" } },
            { key = "minHeight",       label = _tr("t_lQpUrbzYkvPVVyFe"),   type = "layout",  tab = { "layout" } },
            { key = "maxHeight",       label = _tr("t_IdaQPOLpI86Bdylz"),   type = "layout",  tab = { "layout" } },
            { key = "flex",            label = _tr("t_15oQRlY5z15cJOorbR"),     type = "number",  tab = { "layout" } },
            { key = "flexBasis",       label = _tr("t_1FrqtcS0l1FfmUAmld"), type = "layout", tab = { "layout" } },
            { key = "aspectRatio",     label = _tr("t_5ZrAQMFR59DOM3Kl"),     type = "number",  tab = { "common", "layout" } },
            -- layout: position
            { key = "position",        label = _tr("t_mmmApthDnIF5qpob"),   type = "enum",    tab = { "layout" }, options = {
                { value = "relative", label = _tr("t_2PkYHszu1uGbcTDk") },
                { value = "absolute", label = _tr("t_LamPSADYLOhFSIdy") },
            } },
            { key = "left",            label = _tr("t_3f9Cz1KX39jCUy0J"),     type = "layout",  tab = { "layout" } },
            { key = "top",             label = _tr("t_1CcdkFB031CVPNMqtl"),     type = "layout",  tab = { "layout" } },
            { key = "right",           label = _tr("t_2vCjTFVn2nv8lLu5"),     type = "layout",  tab = { "layout" } },
            { key = "bottom",          label = _tr("t_4RQyF1ug4s4kJR9U"),     type = "layout",  tab = { "layout" } },
            -- layout: margin
            { key = "margin",          label = _tr("t_fOluA1lLfasyAj3l"),     type = "spacing", tab = { "layout" } },
            { key = "marginTop",       label = _tr("t_IhlcXrMbICJPkCjj"),   type = "layout",  tab = { "layout" } },
            { key = "marginRight",     label = _tr("t_4xIZagjT4We46BdF"),   type = "layout",  tab = { "layout" } },
            { key = "marginBottom",    label = _tr("t_a6xa9CC3ZbTvifBN"),   type = "layout",  tab = { "layout" } },
            { key = "marginLeft",      label = _tr("t_EFv9Jhc6DkT6nlbE"),   type = "layout",  tab = { "layout" } },
            { key = "marginHorizontal", label = _tr("t_qtktieQBqhesM9GD"), type = "layout",  tab = { "layout" } },
            { key = "marginVertical",   label = _tr("t_wtS9rcAOx0gz3NMQ"), type = "layout",  tab = { "layout" } },
            -- layout: padding
            { key = "padding",         label = _tr("t_6aU7QSZB6TEs7X8t"),     type = "spacing", tab = { "layout" } },
            { key = "paddingTop",      label = _tr("t_DVq6CIscDOZW0mai"),   type = "layout",  tab = { "layout" } },
            { key = "paddingRight",    label = _tr("t_1GI1vqLP21GU7yGsQk"),   type = "layout",  tab = { "layout" } },
            { key = "paddingBottom",   label = _tr("t_1A3pCvgbM1AFvFQpGU"),   type = "layout",  tab = { "layout" } },
            { key = "paddingLeft",     label = _tr("t_VLFWGYnZVlsYv1ln"),   type = "layout",  tab = { "layout" } },
            { key = "paddingHorizontal", label = _tr("t_9kSKcySC9YLHkRtK"), type = "layout",  tab = { "layout" } },
            { key = "paddingVertical",   label = _tr("t_15ElJl6GQ157Vd8ake"), type = "layout",  tab = { "layout" } },
            -- layout: container (only shown for widgets with children)
            { key = "flexDirection",   label = _tr("t_OB1xeq3hNyu2HJOF"),   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "row", label = _tr("t_Mhw1Q8k8MpCJRHZq") },
                { value = "column", label = _tr("t_FHpnigbrFP3sM0YP") },
                { value = "row-reverse", label = _tr("t_mITxRU2CmPlrNfVW") },
                { value = "column-reverse", label = _tr("t_7Lc7zoRm6uyCqHAy") },
            } },
            { key = "justifyContent",  label = _tr("t_1GHM2Y3NI1GObR0WgA"),   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "flex-start", label = _tr("t_d2lLXPMocvVnzpAK") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "flex-end", label = _tr("t_7Lk07TsB6v90YY17") },
                { value = "space-between", label = _tr("t_c4bHtrQrbZAh0ns3") },
                { value = "space-around", label = _tr("t_A6ibMLfQAXKkNpeM") },
                { value = "space-evenly", label = _tr("t_lYFhWYyjm3impARn") },
            } },
            { key = "alignItems",      label = _tr("t_ClQfJbqNCsiiL2o1"), type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "stretch", label = _tr("t_dfKIJ3SpdY4kpquX") },
                { value = "flex-start", label = _tr("t_d2lLXPMocvVnzpAK") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "flex-end", label = _tr("t_7Lk07TsB6v90YY17") },
                { value = "baseline", label = _tr("t_AK9UskdnACrt2WqL") },
            } },
            { key = "alignSelf",       label = _tr("t_14HLGJrJx14mmINkbX"),   type = "enum",    tab = { "layout" }, options = {
                { value = "auto", label = _tr("t_XFjWVkpxXRr0hvkZ") },
                { value = "stretch", label = _tr("t_dfKIJ3SpdY4kpquX") },
                { value = "flex-start", label = _tr("t_d2lLXPMocvVnzpAK") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "flex-end", label = _tr("t_7Lk07TsB6v90YY17") },
                { value = "baseline", label = _tr("t_AK9UskdnACrt2WqL") },
            } },
            { key = "alignContent",    label = _tr("t_aQhbP8ReaXvX1coW"),   type = "enum",    tab = { "layout" }, container = true, options = {
                { value = "stretch", label = _tr("t_dfKIJ3SpdY4kpquX") },
                { value = "flex-start", label = _tr("t_d2lLXPMocvVnzpAK") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "flex-end", label = _tr("t_7Lk07TsB6v90YY17") },
                { value = "space-between", label = _tr("t_c4bHtrQrbZAh0ns3") },
                { value = "space-around", label = _tr("t_A6ibMLfQAXKkNpeM") },
            } },
            { key = "flexGrow",        label = _tr("t_1C8DPcpgX1Bw7gUkO7"), type = "number",  tab = { "layout" } },
            { key = "flexShrink",      label = _tr("t_13EyVBg9o13MFee5HK"), type = "number",  tab = { "layout" } },
            { key = "flexWrap",        label = _tr("t_Ce4yBYWjCqAG42wc"), type = "enum",   tab = { "layout" }, container = true, options = {
                { value = "nowrap", label = _tr("t_16LOccZA616SdRo3J3") },
                { value = "wrap", label = _tr("t_LAd99wMxKk06QiAj") },
                { value = "wrap-reverse", label = _tr("t_K1bHpPLtKSBOoxSA") },
            } },
            { key = "gap",             label = _tr("t_OqL9OPp9OPirDh4a"),       type = "number",  tab = { "layout" }, container = true },
            { key = "rowGap",          label = _tr("t_FVBUw2mpEzlMVI0y"),     type = "number",  tab = { "layout" }, container = true },
            { key = "columnGap",       label = _tr("t_10k2V2xaQ10rJVPuMT"),     type = "number",  tab = { "layout" }, container = true },
            -- appearance
            { key = "backgroundColor", label = _tr("t_1637Yhh0d15XfoMJAq"),     type = "color",   tab = { "common", "appearance" } },
            { key = "backgroundImage", label = _tr("t_pJrc0qJXppKzTkya"),     type = "path",    tab = { "appearance" } },
            { key = "backgroundFit",   label = _tr("t_1383eBGEb13KAXyOqk"),   type = "enum",    tab = { "appearance" }, options = {
                { value = "cover", label = _tr("t_hntocXSHiJLGsBXG") },
                { value = "contain", label = _tr("t_YToyM3ShYuQEsDE0") },
                { value = "fill", label = _tr("t_bdLcQbqVbpSgVwqK") },
                { value = "none", label = _tr("t_tqbzZA8ktxpvBgZV") },
            } },
            { key = "imageTint",       label = _tr("t_Vi24A0HVVHNqpqZO"),   type = "color",   tab = { "appearance" } },
            { key = "borderColor",     label = _tr("t_h41h2jwDgYa5mWCI"),   type = "color",   tab = { "common", "appearance" } },
            { key = "borderWidth",     label = _tr("t_9NB7BEN79sffF5gM"),   type = "number",  tab = { "common", "appearance" } },
            { key = "borderRadius",    label = _tr("t_P4ACZaXgPZeAIiwR"),       type = "number",  tab = { "common", "appearance" } },
            { key = "opacity",         label = _tr("t_oyhGZChuorRZwgCD"),     type = "number",  tab = { "common", "appearance" } },
            { key = "zIndex",          label = _tr("t_Ug9dSKE6VBcQap9p"), type = "number", tab = { "appearance" } },
            -- interaction
            { key = "overflow",        label = _tr("t_aaoS3qc2aOirwVh3"),       type = "enum",    tab = { "interaction" }, options = {
                { value = "visible", label = _tr("t_bSVSTh8rax2ye6mN") },
                { value = "hidden", label = _tr("t_FmvfiXCoFz2HLW9I") },
                { value = "scroll", label = _tr("t_1D7wiMvD01DFEKCwHt") },
            } },
            { key = "pointerEvents",   label = _tr("t_xUsM00Dkxgy6GAnD"),   type = "enum",    tab = { "interaction" }, options = {
                { value = "auto", label = _tr("t_XFjWVkpxXRr0hvkZ") },
                { value = "none", label = _tr("t_I8JyuG3MIdk8XdPL") },
                { value = "box-none", label = _tr("t_14GJAwlKe14gvlDOYd") },
            } },
            { key = "cursor",          label = _tr("t_WPrwEzsJVzGETKYe"), type = "enum", tab = { "interaction" }, options = {
                { value = "default", label = _tr("t_Ixd7ltTYJ4vIoSjL") },
                { value = "pointer", label = _tr("t_MslXsoF8MlTVvO5N") },
                { value = "move", label = _tr("t_ClgsEx63CsufqY1U") },
                { value = "text", label = _tr("t_vTYt25Uxvz3Gsc2m") },
                { value = "grab", label = _tr("t_DZ5G7HFgDMzWzS0N") },
                { value = "grabbing", label = _tr("t_XnvlI4JAYJN4OARX") },
                { value = "not-allowed", label = _tr("t_EsqGLuvfENMAg0t6") },
            } },
            { key = "scale",           label = _tr("t_vHkEW7jZv5e30Cgs"),       type = "number",  tab = { "interaction" } },
            { key = "rotate",          label = _tr("t_15v6q5Bji15UUfrIxN"),       type = "number",  tab = { "interaction" } },
            { key = "translateX",      label = _tr("t_3Yj1Obj23MebwtHn"),   type = "number",  tab = { "interaction" } },
            { key = "translateY",      label = _tr("t_6VL3OYxb6hSXWWoK"),   type = "number",  tab = { "interaction" } },
        },
    },

    Panel = {},
    Card = {},
    SafeAreaView = {},
    ScrollView = {
        propDefs = {
            { key = "scrollX",             label = _tr("t_zqmvEFQL10MDDx0rC"),   type = "boolean", tab = { "interaction" } },
            { key = "scrollY",             label = _tr("t_kkVHqTDzkF36FLuq"),   type = "boolean", tab = { "interaction" } },
            { key = "showScrollbar",       label = _tr("t_DmqCSwOKEDTN8e31"), type = "boolean", tab = { "interaction" } },
            { key = "scrollbarInteractive", label = _tr("t_R2wX4lItRAC5g37w"), type = "boolean", tab = { "interaction" } },
            { key = "allowOverflow",       label = _tr("t_1AdmWy4Qk2CdjwT"),   type = "boolean", tab = { "interaction" } },
        },
    },

    Label = {
        propDefs = {
            { key = "text",            label = _tr("t_lxz8qrMylSUkw8pP"),       type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = _tr("t_1E094PXoQ1Do20KG4z"),   type = "string",  tab = { "content" } },
            { key = "fontSize",        label = _tr("t_taa8D7zqu608lLFh"),       type = "number",  tab = { "common", "content" } },
            { key = "fontFamily",      label = _tr("t_aCTjNnX0Zh0N7f6j"),       type = "string",  tab = { "content" } },
            { key = "fontWeight",      label = _tr("t_cvrsDTlyd3A3Bc7B"),   type = "string",  tab = { "content" } },
            { key = "fontColor",       label = _tr("t_t9XChugntGmtKe3O"),   type = "color",   tab = { "common", "content" } },
            { key = "color",           label = _tr("t_1EhuapTES1ECT8eOeh"),       type = "color",   tab = { "common", "content" } },
            { key = "lineHeight",      label = _tr("t_ZJbODG0vZCMPsF7e"),       type = "number",  tab = { "content" } },
            { key = "letterSpacing",   label = _tr("t_qJhfvX50pt3TjnxF"),     type = "number",  tab = { "content" } },
            { key = "textAlign",       label = _tr("t_1ADRT3dZk1A69Z7QyJ"),   type = "enum",    tab = { "content" }, options = {
                { value = "left", label = _tr("t_yk2ceTL4yw8MuaiH") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "right", label = _tr("t_LVLo0uVnLcavRC1k") },
            } },
            { key = "verticalAlign",   label = _tr("t_B3JefFvWArDvXH5Z"),   type = "enum",    tab = { "content" }, options = {
                { value = "top", label = _tr("t_NFSU0RGWNg6PEeR1") },
                { value = "middle", label = _tr("t_ScY204uKS7714Dli") },
                { value = "bottom", label = _tr("t_oJ9WNmX4o732hm17") },
            } },
            { key = "whiteSpace",      label = _tr("t_gPhYl2s5fz45v55S"),   type = "enum",    tab = { "content" }, options = {
                { value = "nowrap", label = _tr("t_16LOccZA616SdRo3J3") },
                { value = "normal", label = _tr("t_NInrHpo3NQ3PtOgG") },
            } },
            { key = "textColor",       label = _tr("t_lGEVO5nzl8xKnF28"),   type = "color",   tab = { "common", "content" } },
            { key = "maxLines",        label = _tr("t_mKQzBELCmWVytAW5"),    type = "number",  tab = { "content" } },
            { key = "wordBreak",       label = _tr("t_1FBFsdB7w1Ez9zHoCF"), type = "enum", tab = { "content" }, options = {
                { value = "normal", label = _tr("t_W146dzJ8WDArQcWX") },
                { value = "break-word", label = _tr("t_O8WVTH6LO1G4IXBq") },
            } },
            { key = "textDecoration",  label = _tr("t_RPHZaAuGQyfQZ1Ad"), type = "enum", tab = { "content" }, options = {
                { value = "none", label = _tr("t_Fv4KRHJXG2JasJ4i") },
                { value = "underline", label = _tr("t_5kIrdba96AwleiGg") },
                { value = "line-through", label = _tr("t_szdiBipbtQEGQiDg") },
            } },
            { key = "textTransform",   label = _tr("t_1BlFOCTA21CGffmcDt"), type = "enum", tab = { "content" }, options = {
                { value = "none", label = _tr("t_Fv4KRHJXG2JasJ4i") },
                { value = "uppercase", label = _tr("t_9kaXVYMA9YVpxwVN") },
                { value = "lowercase", label = _tr("t_19IXTRWkd19nyCCkNw") },
                { value = "capitalize", label = _tr("t_9iaZsayp9WVR12b6") },
            } },
        },
    },
    RichText = {
        propDefs = {
            { key = "text", label = _tr("t_lxz8qrMylSUkw8pP"), type = "string", tab = { "common", "content" } },
        },
    },
    Button = {
        propDefs = {
            { key = "text",            label = _tr("t_lxz8qrMylSUkw8pP"),       type = "string",  tab = { "common", "content" } },
            { key = "fontSize",        label = _tr("t_taa8D7zqu608lLFh"),       type = "number",  tab = { "common", "content" } },
            { key = "fontFamily",      label = _tr("t_aCTjNnX0Zh0N7f6j"),       type = "string",  tab = { "content" } },
            { key = "fontWeight",      label = _tr("t_cvrsDTlyd3A3Bc7B"),   type = "string",  tab = { "content" } },
            { key = "textAlign",       label = _tr("t_1ADRT3dZk1A69Z7QyJ"),   type = "enum",    tab = { "content" }, options = {
                { value = "left", label = _tr("t_yk2ceTL4yw8MuaiH") },
                { value = "center", label = _tr("t_ScY204uKS7714Dli") },
                { value = "right", label = _tr("t_LVLo0uVnLcavRC1k") },
            } },
            { key = "verticalAlign",   label = _tr("t_B3JefFvWArDvXH5Z"),   type = "enum",    tab = { "content" }, options = {
                { value = "top", label = _tr("t_NFSU0RGWNg6PEeR1") },
                { value = "middle", label = _tr("t_ScY204uKS7714Dli") },
                { value = "bottom", label = _tr("t_oJ9WNmX4o732hm17") },
            } },
            { key = "variant",         label = _tr("t_SYqvs95zSMktRQLQ"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" },
                { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" },
                { value = "success", label = "success" },
                { value = "outline", label = "outline" },
                { value = "ghost", label = "ghost" },
            } },
            { key = "size",            label = _tr("t_VXQ2Gu76YBqyW"),       type = "enum",    tab = { "common", "appearance" }, options = {
                { value = "xs", label = "xs" }, { value = "sm", label = "sm" },
                { value = "md", label = "md" }, { value = "lg", label = "lg" }, { value = "xl", label = "xl" },
            } },
            { key = "disabled",        label = _tr("t_fTebBj9Nffl4w9Ru"),       type = "boolean", tab = { "common", "interaction" } },
            { key = "textColor",       label = _tr("t_lGEVO5nzl8xKnF28"),   type = "color",   tab = { "common", "content" } },
            { key = "icon",            label = _tr("t_OgCP0EGpOYxHePng"),   type = "path",    tab = { "content" } },
            { key = "iconSize",        label = _tr("t_pBhamtG3ogFpEjBQ"),   type = "number",  tab = { "content" } },
            { key = "hoverBackgroundColor",   label = _tr("t_eOlDQrSLeCgx8ixi"), type = "color", tab = { "interaction" } },
            { key = "pressedBackgroundColor", label = _tr("t_GUzeRhn1Gh43tOAG"), type = "color", tab = { "interaction" } },
            { key = "disabledBackgroundColor", label = _tr("t_KKwfRmSPK8q2btss"), type = "color", tab = { "interaction" } },
            { key = "hoverBorderColor", label = _tr("t_1ArNxvklr1Ak8PK7ZA"), type = "color", tab = { "interaction" } },
        },
    },
    TextField = {
        propDefs = {
            { key = "value",           label = _tr("t_UT6anUdrU2VbEWeW"),     type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = _tr("t_1E094PXoQ1Do20KG4z"),   type = "string",  tab = { "content" } },
            { key = "fontSize",        label = _tr("t_taa8D7zqu608lLFh"),       type = "number",  tab = { "common", "content" } },
            { key = "disabled",        label = _tr("t_fTebBj9Nffl4w9Ru"),       type = "boolean", tab = { "common", "interaction" } },
            { key = "readOnly",        label = _tr("t_SzE0IRw8TBMEyjaB"),       type = "boolean", tab = { "interaction" } },
            { key = "password",        label = _tr("t_1297qBaFv11x0vGAa4"),   type = "boolean", tab = { "interaction" } },
            { key = "maxLength",       label = _tr("t_QV2ToBIHQcGrkE9O"),   type = "number",  tab = { "interaction" } },
            { key = "placeholderColor", label = _tr("t_T1TmhGWST8j38IHj"), type = "color",  tab = { "interaction" } },
            { key = "selectionColor",  label = _tr("t_PgvCHpY8QCOZgKQp"),   type = "color",  tab = { "interaction" } },
            { key = "cursorColor",     label = _tr("t_11T2n6wjL11Lm3ltcy"),   type = "color",  tab = { "interaction" } },
        },
    },
    Dropdown = {
        propDefs = {
            { key = "value",           label = _tr("t_fjmwHVANfEMCJYQK"),     type = "string",  tab = { "common", "content" } },
            { key = "placeholder",     label = _tr("t_1E094PXoQ1Do20KG4z"),   type = "string",  tab = { "content" } },
            { key = "disabled",        label = _tr("t_fTebBj9Nffl4w9Ru"),       type = "boolean", tab = { "common", "interaction" } },
            { key = "maxVisibleItems", label = _tr("t_qNpitaXxdgUs78"), type = "number",  tab = { "interaction" } },
            { key = "itemHeight",      label = _tr("t_1GlDAcLQu1HGg6lg4d"),   type = "number",  tab = { "interaction" } },
            { key = "triggerBgColor",  label = _tr("t_hEC16TxUhepV5BZj"), type = "color", tab = { "interaction" } },
            { key = "arrowColor",      label = _tr("t_Uu5Oky7TV1JldHDc"),   type = "color",  tab = { "interaction" } },
            { key = "itemHoverBgColor", label = _tr("t_NAmcta8BNbOw8JgS"), type = "color", tab = { "interaction" } },
            { key = "itemHoverTextColor", label = _tr("t_17O6EyJBG17ok93nW5"), type = "color", tab = { "interaction" } },
            { key = "itemSelectedColor", label = _tr("t_DRnWigVJDKWWPoCI"), type = "color", tab = { "interaction" } },
            { key = "itemSelectedTextColor", label = _tr("t_1CJHPPVA51ColnKPQI"), type = "color", tab = { "interaction" } },
            { key = "popupBorderColor", label = _tr("t_TPRslKVYTq3RWHdr"), type = "color", tab = { "interaction" } },
        },
    },

    Checkbox = {
        propDefs = {
            { key = "label",    label = _tr("t_10CaeTtiH100UAnxSU"),     type = "string",  tab = { "common", "content" } },
            { key = "checked",  label = _tr("t_K8A1tJSDKYmT9CMo"),     type = "boolean", tab = { "common", "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),     type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize", label = _tr("t_taa8D7zqu608lLFh"),     type = "number",  tab = { "common", "content" } },
            { key = "fontColor", label = _tr("t_t9XChugntGmtKe3O"), type = "color",  tab = { "content" } },
        },
    },
    Toggle = {
        propDefs = {
            { key = "label",    label = _tr("t_10CaeTtiH100UAnxSU"),     type = "string",  tab = { "common", "content" } },
            { key = "checked",  label = _tr("t_K8A1tJSDKYmT9CMo"),     type = "boolean", tab = { "common", "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),     type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize", label = _tr("t_taa8D7zqu608lLFh"),     type = "number",  tab = { "common", "content" } },
            { key = "fontColor", label = _tr("t_t9XChugntGmtKe3O"), type = "color",  tab = { "content" } },
        },
    },
    Slider = {
        propDefs = {
            { key = "value",    label = _tr("t_jnApkXfNjuS9M4UQ"),   type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = _tr("t_151VBfWoK158kQy8zP"), type = "number",  tab = { "interaction" } },
            { key = "max",      label = _tr("t_kI3wptXuknXSFd77"), type = "number",  tab = { "interaction" } },
            { key = "step",     label = _tr("t_sV7tJSvXshCar5uK"),   type = "number",  tab = { "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),   type = "boolean", tab = { "common", "interaction" } },
        },
    },
    Stepper = {
        propDefs = {
            { key = "value",    label = _tr("t_jnApkXfNjuS9M4UQ"),   type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = _tr("t_151VBfWoK158kQy8zP"), type = "number",  tab = { "interaction" } },
            { key = "max",      label = _tr("t_kI3wptXuknXSFd77"), type = "number",  tab = { "interaction" } },
            { key = "step",     label = _tr("t_sV7tJSvXshCar5uK"),   type = "number",  tab = { "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),   type = "boolean", tab = { "common", "interaction" } },
        },
    },
    ProgressBar = {
        propDefs = {
            { key = "value",    label = _tr("t_i6csWjpxhzKYPIXG"),     type = "number",  tab = { "common", "interaction" } },
            { key = "min",      label = _tr("t_151VBfWoK158kQy8zP"), type = "number",  tab = { "interaction" } },
            { key = "max",      label = _tr("t_kI3wptXuknXSFd77"), type = "number",  tab = { "interaction" } },
            { key = "progress", label = _tr("t_10tVtS19i10hO5wuXh"),   type = "number",  tab = { "interaction" } },
        },
    },
    Rating = {
        propDefs = {
            { key = "value",    label = _tr("t_vbdYGbivvnizIlPe"),   type = "number",  tab = { "common", "interaction" } },
            { key = "max",      label = _tr("t_kI3wptXuknXSFd77"), type = "number",  tab = { "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),   type = "boolean", tab = { "common", "interaction" } },
        },
    },

    Alert = {
        propDefs = {
            { key = "title",   label = _tr("t_UZTh3I0cU401U7Yf"), type = "string", tab = { "common", "content" } },
            { key = "message", label = _tr("t_12ek5QbKb12XRtKMaN"), type = "string", tab = { "common", "content" } },
            { key = "variant", label = _tr("t_SYqvs95zSMktRQLQ"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" }, { value = "success", label = "success" },
            } },
            { key = "icon",    label = _tr("t_OgCP0EGpOYxHePng"), type = "path", tab = { "content" } },
        },
    },
    Badge = {
        propDefs = {
            { key = "text",      label = _tr("t_lxz8qrMylSUkw8pP"), type = "string", tab = { "common", "content" } },
            { key = "label",     label = _tr("t_10CaeTtiH100UAnxSU"), type = "string", tab = { "common", "content" } },
            { key = "variant",   label = _tr("t_SYqvs95zSMktRQLQ"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "danger", label = "danger" }, { value = "success", label = "success" },
            } },
            { key = "size",      label = _tr("t_VXQ2Gu76YBqyW"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "xs", label = "xs" }, { value = "sm", label = "sm" },
                { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
            { key = "fontSize",  label = _tr("t_taa8D7zqu608lLFh"), type = "number", tab = { "common", "content" } },
            { key = "fontColor", label = _tr("t_t9XChugntGmtKe3O"), type = "color", tab = { "content" } },
        },
    },
    Chip = {
        propDefs = {
            { key = "text",      label = _tr("t_lxz8qrMylSUkw8pP"), type = "string", tab = { "common", "content" } },
            { key = "label",     label = _tr("t_10CaeTtiH100UAnxSU"), type = "string", tab = { "common", "content" } },
            { key = "variant",   label = _tr("t_SYqvs95zSMktRQLQ"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "primary", label = "primary" }, { value = "secondary", label = "secondary" },
                { value = "outline", label = "outline" },
            } },
            { key = "size",      label = _tr("t_VXQ2Gu76YBqyW"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "sm", label = "sm" }, { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
            { key = "disabled",  label = _tr("t_fTebBj9Nffl4w9Ru"), type = "boolean", tab = { "common", "interaction" } },
            { key = "fontSize",  label = _tr("t_taa8D7zqu608lLFh"), type = "number", tab = { "common", "content" } },
            { key = "fontColor", label = _tr("t_t9XChugntGmtKe3O"), type = "color", tab = { "content" } },
        },
    },
    Toast = {
        propDefs = {
            { key = "title",   label = _tr("t_UZTh3I0cU401U7Yf"), type = "string", tab = { "common", "content" } },
            { key = "message", label = _tr("t_12ek5QbKb12XRtKMaN"), type = "string", tab = { "common", "content" } },
            { key = "variant", label = _tr("t_SYqvs95zSMktRQLQ"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "info", label = "info" }, { value = "success", label = "success" },
                { value = "warning", label = "warning" }, { value = "error", label = "error" },
            } },
            { key = "icon",    label = _tr("t_OgCP0EGpOYxHePng"), type = "path", tab = { "content" } },
        },
    },
    Tooltip = {
        propDefs = {
            { key = "title",   label = _tr("t_UZTh3I0cU401U7Yf"), type = "string", tab = { "common", "content" } },
            { key = "message", label = _tr("t_12ek5QbKb12XRtKMaN"), type = "string", tab = { "common", "content" } },
        },
    },
    Modal = {
        propDefs = {
            { key = "title",   label = _tr("t_UZTh3I0cU401U7Yf"), type = "string", tab = { "common", "content" } },
            { key = "message", label = _tr("t_12ek5QbKb12XRtKMaN"), type = "string", tab = { "common", "content" } },
        },
    },
    Popover = {
        propDefs = {
            { key = "title",   label = _tr("t_UZTh3I0cU401U7Yf"), type = "string", tab = { "common", "content" } },
            { key = "message", label = _tr("t_12ek5QbKb12XRtKMaN"), type = "string", tab = { "common", "content" } },
        },
    },
    Avatar = {
        propDefs = {
            { key = "icon", label = _tr("t_OgCP0EGpOYxHePng"), type = "path", tab = { "content" } },
            { key = "size", label = _tr("t_VXQ2Gu76YBqyW"), type = "enum", tab = { "common", "appearance" }, options = {
                { value = "sm", label = "sm" }, { value = "md", label = "md" }, { value = "lg", label = "lg" },
            } },
        },
    },
    Pagination = {
        propDefs = {
            { key = "current",  label = _tr("t_IOGg0TQuIVVd94T1"), type = "number", tab = { "common", "interaction" } },
            { key = "total",    label = _tr("t_DRs63f37DKbMiJpa"), type = "number", tab = { "common", "interaction" } },
            { key = "disabled", label = _tr("t_fTebBj9Nffl4w9Ru"),   type = "boolean", tab = { "common", "interaction" } },
        },
    },
}

-- ============================================================================
-- Internal Helpers
-- ============================================================================

local function isColorPropName(key)
    return type(key) == "string" and key:sub(-5):lower() == "color"
end

local function optionSignature(options)
    if not options then return "" end
    local parts = {}
    for _, option in ipairs(options) do
        parts[#parts + 1] = tostring(option.value)
    end
    return table.concat(parts, "|")
end

local function propDefSignature(def)
    if not def then return nil end
    return table.concat({
        tostring(def.type or "string"),
        tostring(def.editor or ""),
        optionSignature(def.options),
    }, "#")
end

local function valueMatchesDef(key, value, def)
    if value == nil or not def then return true end
    local valueType = type(value)
    local defType = def.type
    if defType == "layout" then
        return valueType == "number" or valueType == "string"
    elseif defType == "spacing" then
        return valueType == "number" or valueType == "string" or valueType == "table"
    elseif defType == "color" then
        return valueType == "table" or valueType == "string"
    elseif defType == "number" then
        return valueType == "number"
    elseif defType == "boolean" then
        return valueType == "boolean"
    elseif defType == "string" or defType == "path" or defType == "enum" then
        return valueType == "string"
    end
    return true
end

local function inferRuntimePropDef(key, value)
    local valueType = type(value)
    if valueType == "number" then
        return { label = key, type = "number", generic = true }
    elseif valueType == "boolean" then
        return { label = key, type = "boolean", generic = true }
    elseif valueType == "string" then
        return { label = key, type = isColorPropName(key) and "color" or "string", generic = true }
    elseif valueType == "table" and isColorPropName(key) and #value >= 3 then
        return { label = key, type = "color", generic = true }
    end
    return nil
end

-- ============================================================================
-- Public API
-- ============================================================================

function Schema.apply()
    Schema._propOrder = {}
    Schema._tabProps = {}
    Schema._labelMap = {}

    local orderCounter = 0

    -- Widget first (base props), then all other components sorted alphabetically
    local componentOrder = { "Widget" }
    local others = {}
    for name in pairs(Schema.COMPONENTS) do
        if name ~= "Widget" then
            others[#others + 1] = name
        end
    end
    table.sort(others)
    for _, name in ipairs(others) do
        componentOrder[#componentOrder + 1] = name
    end

    for _, componentName in ipairs(componentOrder) do
        local component = Schema.COMPONENTS[componentName]
        for _, entry in ipairs(component.propDefs or {}) do
            local key = entry.key
            if key then
                -- Assign ordering (first seen wins)
                if not Schema._propOrder[key] then
                    orderCounter = orderCounter + 1
                    Schema._propOrder[key] = orderCounter
                end

                -- Label map (first seen wins, for getPropLabel without widget)
                if not Schema._labelMap[key] and entry.label then
                    Schema._labelMap[key] = entry.label
                end

                -- Tab index
                for _, tab in ipairs(entry.tab or {}) do
                    Schema._tabProps[tab] = Schema._tabProps[tab] or {}
                    Schema._tabProps[tab][key] = true
                end
            end
        end
    end

    -- 预算每个组件的完整属性表（Widget 基础 + 组件自有，子覆盖父）
    Schema._resolved = {}
    local function buildEntryDef(entry)
        local def = {}
        for k, v in pairs(entry) do
            if k ~= "key" then def[k] = v end
        end
        return def
    end
    local widgetDefs = {}
    for _, entry in ipairs((Schema.COMPONENTS.Widget or {}).propDefs or {}) do
        if entry.key then
            widgetDefs[entry.key] = buildEntryDef(entry)
        end
    end
    Schema._resolved.Widget = widgetDefs
    for _, componentName in ipairs(others) do
        local merged = {}
        for k, v in pairs(widgetDefs) do merged[k] = v end
        for _, entry in ipairs((Schema.COMPONENTS[componentName] or {}).propDefs or {}) do
            if entry.key then
                merged[entry.key] = buildEntryDef(entry)
            end
        end
        Schema._resolved[componentName] = merged
    end
end

function Schema.getPropDef(key)
    local resolved = Schema._resolved and Schema._resolved.Widget
    return resolved and resolved[key] or nil
end

function Schema.getPropOrder(key)
    return Schema._propOrder and Schema._propOrder[key] or nil
end

function Schema.getPropLabel(key)
    if Schema._labelMap and Schema._labelMap[key] then
        return Schema._labelMap[key]
    end
    return key
end

function Schema.getWidgetPropDef(key, widget)
    local className = widget and widget._className or "Widget"
    local resolved = Schema._resolved and Schema._resolved[className]
    if not resolved then
        resolved = Schema._resolved and Schema._resolved.Widget
    end
    if resolved and resolved[key] then
        return resolved[key]
    end
    return widget and widget.props and inferRuntimePropDef(key, widget.props[key]) or nil
end

function Schema.getWidgetPropKeyMap(widget)
    local keys = {}
    local className = widget and widget._className or "Widget"
    local resolved = Schema._resolved and Schema._resolved[className]
    if not resolved then
        resolved = Schema._resolved and Schema._resolved.Widget
    end
    if not resolved then return keys end

    local hasChildren = widget and widget.children and #widget.children > 0
    for key, def in pairs(resolved) do
        if not def.container or hasChildren then
            keys[key] = true
        end
    end
    return keys
end

function Schema.getEditableProps(widgets, sortFn)
    if not widgets or #widgets == 0 then return {} end

    local result = Schema.getWidgetPropKeyMap(widgets[1])
    for i = 2, #widgets do
        local other = Schema.getWidgetPropKeyMap(widgets[i])
        for key in pairs(result) do
            if not other[key] then
                result[key] = nil
            end
        end
    end

    local keys = {}
    for key in pairs(result) do
        local _, conflict = Schema.getPropDefForWidgets(key, widgets)
        if not conflict then
            keys[#keys + 1] = key
        end
    end
    if sortFn then sortFn(keys) else table.sort(keys) end
    return keys
end

function Schema.getPropDefForWidgets(key, widgets)
    local chosen = nil
    local signature = nil
    for _, widget in ipairs(widgets or {}) do
        local def = Schema.getWidgetPropDef(key, widget)
        local value = widget and widget.props and widget.props[key] or nil
        if def then
            local currentSignature = propDefSignature(def)
            if signature and currentSignature ~= signature then
                return nil, true
            end
            signature = signature or currentSignature
            chosen = def
        elseif value ~= nil then
            return nil, true
        elseif chosen then
            return nil, true
        end

        if value ~= nil and def and not valueMatchesDef(key, value, def) then
            return nil, true
        end
    end

    return chosen, false
end

return Schema
