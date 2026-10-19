-- ============================================================================
-- Widgets Example
-- Demonstrates all available UI widgets
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- Shared State (use table to avoid local variable limit)
-- ============================================================================

local state = {
    textValue = "",
    sliderValue = 50,
    progressValue = 0.3,
    isChecked = false,
    isToggled = true,
    dropdownValue = nil,
    rating = 3,
    stepperValue = 1,
    tabIndex = 1,
    dateValue = nil,
    timeValue = nil,
    colorValue = { r = 255, g = 100, b = 50, a = 255 },
}

-- Widgets that need to be updated (use table)
local updatableWidgets = {
    carousels = {},
    progressBars = {},
    drawers = {},
}

-- ============================================================================
-- Create Main Layout
-- ============================================================================

local root = UI.Panel {
    id = "root",
    width = "100%",
    height = "100%",
    padding = 20,
    flexDirection = "column",
    backgroundColor = UI.Theme.Color("background"),
}

-- Title
root:AddChild(UI.Label {
    text = "UrhoX UI Widget Gallery",
    fontSize = UI.Theme.FontSizeOf("headline"),
    fontWeight = "bold",
    color = UI.Theme.Color("text"),
    marginBottom = 20,
})

-- ScrollView with all widgets
local scrollView = UI.ScrollView {
    width = "100%",
    flexGrow = 1,
    flexBasis = 0,  -- Important: allows flexGrow to work without content affecting size
    scrollY = true,
    showScrollbar = true,
}
root:AddChild(scrollView)

-- Content container
local content = UI.Panel {
    width = "100%",
    flexDirection = "column",
    gap = 20,
}
scrollView:AddChild(content)

-- ============================================================================
-- Helper: Create Section Panel
-- ============================================================================

local function createSection(title)
    local section = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 10,
        padding = 16,
        backgroundColor = UI.Theme.Color("surface"),
        borderRadius = 8,
    }

    section:AddChild(UI.Label {
        text = title,
        fontSize = UI.Theme.FontSizeOf("bodyLarge"),
        fontWeight = "bold",
        color = UI.Theme.Color("text"),
    })

    content:AddChild(section)
    return section
end

-- ============================================================================
-- Section: Basic Widgets (Button, Label, Panel)
-- ============================================================================
do
    local section = createSection("Basic Widgets")

    local row = UI.Row { gap = 10, flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Button {
        text = "Primary",
        variant = "primary",
        onClick = function() print("Primary clicked") end,
    })

    row:AddChild(UI.Button {
        text = "Secondary",
        variant = "secondary",
    })

    row:AddChild(UI.Button {
        text = "Outlined",
        variant = "outlined",
    })

    row:AddChild(UI.Button {
        text = "Disabled",
        disabled = true,
    })

    -- Image background buttons
    section:AddChild(UI.Label {
        text = "Image Background Buttons:",
        fontSize = UI.Theme.FontSizeOf("body"),
        color = UI.Theme.Color("textSecondary"),
        marginTop = 12,
    })

    local imageRow = UI.Row { gap = 10, flexWrap = "wrap", alignItems = "center" }
    section:AddChild(imageRow)

    -- Button with color background (custom colors)
    imageRow:AddChild(UI.Button {
        text = "Custom Color",
        backgroundColor = {100, 149, 237, 255},  -- Cornflower blue
        hoverBackgroundColor = {120, 169, 255, 255},
        pressedBackgroundColor = {80, 129, 217, 255},
        onClick = function() print("Custom color button clicked") end,
    })

    -- Button with image background (cover mode)
    imageRow:AddChild(UI.Button {
        text = "",
        width = 64,
        height = 64,
        backgroundImage = "Textures/UrhoIcon.png",
        backgroundFit = "contain",
        borderRadius = 8,
        onClick = function() print("Icon button clicked") end,
    })

    -- Button with image background (nine-slice)
    imageRow:AddChild(UI.Button {
        text = "Nine-Slice",
        width = 150,
        height = 60,
        backgroundImage = "Urho2D/Stretchable.png",
        backgroundFit = "sliced",
        backgroundSlice = {20, 20, 20, 20},  -- Corner size (must be < height/2)
        onClick = function() print("Nine-slice button clicked") end,
    })

    -- Button with state-specific images
    imageRow:AddChild(UI.Button {
        text = "",
        width = 48,
        height = 48,
        backgroundImage = "Urho2D/GoldIcon/1.png",
        hoverBackgroundImage = "Urho2D/GoldIcon/3.png",
        pressedBackgroundImage = "Urho2D/GoldIcon/5.png",
        backgroundFit = "contain",
        borderRadius = 24,
        onClick = function() print("Gold icon button clicked") end,
    })

    -- Shadow examples
    section:AddChild(UI.Label {
        text = "Shadow Examples:",
        fontSize = UI.Theme.FontSizeOf("body"),
        color = UI.Theme.Color("textSecondary"),
        marginTop = 12,
    })

    local shadowRow = UI.Row { gap = 20, flexWrap = "wrap", alignItems = "center" }
    section:AddChild(shadowRow)

    -- Soft shadow (blur, no offset)
    shadowRow:AddChild(UI.Button {
        text = "Soft",
        shadowX = 0,
        shadowY = 4,
        shadowBlur = 12,
        shadowColor = {0, 0, 0, 40},
        onClick = function() print("Soft shadow clicked") end,
    })

    -- Hard shadow (no blur, offset)
    shadowRow:AddChild(UI.Button {
        text = "Hard",
        shadowX = 4,
        shadowY = 4,
        shadowBlur = 0,
        shadowColor = {0, 0, 0, 100},
        onClick = function() print("Hard shadow clicked") end,
    })

    -- Large blur shadow (elevation effect)
    shadowRow:AddChild(UI.Button {
        text = "Elevated",
        shadowX = 0,
        shadowY = 8,
        shadowBlur = 24,
        shadowColor = {0, 0, 0, 30},
        onClick = function() print("Elevated shadow clicked") end,
    })

    -- Colored shadow (pink)
    shadowRow:AddChild(UI.Button {
        text = "Pink",
        shadowX = 0,
        shadowY = 6,
        shadowBlur = 16,
        shadowColor = {236, 72, 153, 80},
        onClick = function() print("Pink shadow clicked") end,
    })

    -- Colored shadow (blue)
    shadowRow:AddChild(UI.Button {
        text = "Blue",
        shadowX = 0,
        shadowY = 6,
        shadowBlur = 16,
        shadowColor = {59, 130, 246, 80},
        onClick = function() print("Blue shadow clicked") end,
    })
end

-- ============================================================================
-- Section: Text Input
-- ============================================================================
do
    local section = createSection("Text Input")

    local row = UI.Row { gap = 10, flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.TextField {
        placeholder = "Enter text...",
        width = 200,
        onTextChange = function(_, text) state.textValue = text end,
    })

    row:AddChild(UI.TextField {
        placeholder = "Password",
        password = true,
        width = 200,
    })

    row:AddChild(UI.TextField {
        placeholder = "Disabled",
        disabled = true,
        width = 200,
    })
end

-- ============================================================================
-- Section: Toggle Controls
-- ============================================================================
do
    local section = createSection("Toggle Controls")

    local row = UI.Row { gap = 20, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Checkbox {
        label = "Checkbox",
        checked = state.isChecked,
        onChange = function(_, checked) state.isChecked = checked end,
    })

    row:AddChild(UI.Toggle {
        label = "Toggle Switch",
        checked = state.isToggled,
        onChange = function(_, checked) state.isToggled = checked end,
    })
end

-- ============================================================================
-- Section: Slider & Progress
-- ============================================================================
do
    local section = createSection("Slider & Progress")

    section:AddChild(UI.Slider {
        value = state.sliderValue,
        min = 0,
        max = 100,
        width = 300,
        onChange = function(_, value) state.sliderValue = value end,
    })

    local pb = UI.ProgressBar {
        value = state.progressValue,
        width = 300,
    }
    section:AddChild(pb)
    table.insert(updatableWidgets.progressBars, pb)
end

-- ============================================================================
-- Section: Dropdown
-- ============================================================================
do
    local section = createSection("Dropdown")

    section:AddChild(UI.Dropdown {
        placeholder = "Select option...",
        options = {
            { value = "opt1", label = "Option 1" },
            { value = "opt2", label = "Option 2" },
            { value = "opt3", label = "Option 3" },
        },
        width = 200,
        onChange = function(_, value) state.dropdownValue = value end,
    })
end

-- ============================================================================
-- Section: Badges & Chips
-- ============================================================================
do
    local section = createSection("Badges & Chips")

    local row = UI.Row { gap = 10, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Badge { content = "5", variant = "primary" })
    row:AddChild(UI.Badge { content = "New", variant = "success" })
    row:AddChild(UI.Badge { content = "!", variant = "error" })

    -- Badge with Yoga position="absolute" (regression test: position prop conflict)
    local absContainer = UI.Panel { width = 80, height = 40, position = "relative" }
    row:AddChild(absContainer)
    absContainer:AddChild(UI.Badge { content = "99", variant = "error", position = "absolute", left = 10, top = 5 })

    local chipRow = UI.Row { gap = 8, marginTop = 10, flexWrap = "wrap" }
    section:AddChild(chipRow)

    chipRow:AddChild(UI.Chip { label = "Tag 1" })
    chipRow:AddChild(UI.Chip { label = "Tag 2", variant = "primary" })
    chipRow:AddChild(UI.Chip { label = "Removable", removable = true })
end

-- ============================================================================
-- Section: Avatar
-- ============================================================================
do
    local section = createSection("Avatar")

    local row = UI.Row { gap = 15, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Avatar { initials = "JD", size = "sm" })
    row:AddChild(UI.Avatar { initials = "AB", size = "md" })
    row:AddChild(UI.Avatar { initials = "XY", size = "lg" })
end

-- ============================================================================
-- Section: Cards
-- ============================================================================
do
    local section = createSection("Cards")

    local row = UI.Row { gap = 15, flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Card {
        width = "30%",
        overflow = "hidden",
        children = {
            UI.Label { text = "Card Title", fontSize = UI.Theme.FontSizeOf("bodyLarge"), fontWeight = "bold" },
            UI.Label { text = "Card content goes here.", fontSize = UI.Theme.FontSizeOf("body") },
        },
    })

    row:AddChild(UI.Card {
        width = "30%",
        variant = "outlined",
        overflow = "hidden",
        children = {
            UI.Label { text = "Outlined Card", fontSize = UI.Theme.FontSizeOf("bodyLarge"), fontWeight = "bold" },
            UI.Label { text = "With border style.", fontSize = UI.Theme.FontSizeOf("body") },
        },
    })

    -- Card with header separator line (using SetHeader/AddBody API)
    local Card = require("urhox-libs/UI/Widgets/Card")
    local cardWithHeader = Card:new({
        width = "30%",
        variant = "elevated",
        overflow = "hidden",
    })
    cardWithHeader:SetHeader("Card with Header")
    cardWithHeader:AddBody(UI.Label { text = "This card has a header", fontSize = UI.Theme.FontSizeOf("body") })
    cardWithHeader:AddBody(UI.Label { text = "with separator line.", fontSize = UI.Theme.FontSizeOf("body") })
    row:AddChild(cardWithHeader)
end

-- ============================================================================
-- Section: Alerts
-- ============================================================================
do
    local section = createSection("Alerts")

    section:AddChild(UI.Alert {
        title = "Info",
        message = "This is an informational alert.",
        severity = "info",
    })

    section:AddChild(UI.Alert {
        title = "Success",
        message = "Operation completed successfully!",
        severity = "success",
    })

    section:AddChild(UI.Alert {
        title = "Warning",
        message = "Please review before proceeding.",
        severity = "warning",
    })

    section:AddChild(UI.Alert {
        title = "Error",
        message = "Something went wrong.",
        severity = "error",
    })
end

-- ============================================================================
-- Section: Tabs
-- ============================================================================
do
    local section = createSection("Tabs")

    local tabs = UI.Tabs {
        tabs = {
            { id = "tab1", label = "Tab 1" },
            { id = "tab2", label = "Tab 2" },
            { id = "tab3", label = "Tab 3" },
        },
        activeTab = "tab1",
        width = "100%",
        height = 150,
        onChange = function(_, tabId) print("Tab changed to: " .. tostring(tabId)) end,
    }

    -- Set content for each tab
    tabs:SetTabContent("tab1", UI.Label {
        text = "This is the content of Tab 1",
        color = UI.Theme.Color("text"),
        textAlign = "center",
        verticalAlign = "middle",
    })
    -- Tab2: Button wrapped in Panel for centering
    local tab2Panel = UI.Panel {
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
    }
    tab2Panel:AddChild(UI.Button {
        text = "Click me in Tab 2!",
        size = "sm",
        onClick = function() print("Button in Tab 2 clicked!") end,
    })
    tabs:SetTabContent("tab2", tab2Panel)
    tabs:SetTabContent("tab3", UI.Label {
        text = "You are viewing Tab 3",
        color = UI.Theme.Color("text"),
        textAlign = "center",
        verticalAlign = "middle",
    })

    section:AddChild(tabs)
end

-- ============================================================================
-- Section: Rating
-- ============================================================================
do
    local section = createSection("Rating")

    section:AddChild(UI.Rating {
        value = state.rating,
        max = 5,
        onChange = function(_, value) state.rating = value end,
    })
end

-- ============================================================================
-- Section: Stepper
-- ============================================================================
do
    local section = createSection("Stepper")

    section:AddChild(UI.Stepper {
        steps = {
            { id = 1, label = "Step 1", description = "First step" },
            { id = 2, label = "Step 2", description = "Second step" },
            { id = 3, label = "Step 3", description = "Final step" },
        },
        activeStep = state.stepperValue,
        clickable = true,
        onChange = function(_, step) state.stepperValue = step end,
    })
end

-- ============================================================================
-- Section: Breadcrumb
-- ============================================================================
do
    local section = createSection("Breadcrumb")

    section:AddChild(UI.Breadcrumb {
        items = {
            { label = "Home", onClick = function() print("Home") end },
            { label = "Products", onClick = function() print("Products") end },
            { label = "Category" },
        },
        width = "100%",
    })
end

-- ============================================================================
-- Section: Pagination
-- ============================================================================
do
    local section = createSection("Pagination")

    section:AddChild(UI.Pagination {
        currentPage = 1,
        totalPages = 10,
        onChange = function(_, page) print("Page: " .. page) end,
    })
end

-- ============================================================================
-- Section: Accordion
-- ============================================================================
do
    local section = createSection("Accordion")

    section:AddChild(UI.Accordion {
        items = {
            { id = "s1", title = "Section 1", content = "Content for section 1" },
            { id = "s2", title = "Section 2", content = "Content for section 2" },
            { id = "s3", title = "Section 3", content = "Content for section 3" },
        },
        width = "100%",
        height = 200,
    })
end

-- ============================================================================
-- Section: Timeline
-- ============================================================================
do
    local section = createSection("Timeline")

    section:AddChild(UI.Timeline {
        items = {
            { title = "Step 1", description = "First step completed", status = "completed" },
            { title = "Step 2", description = "In progress", status = "current" },
            { title = "Step 3", description = "Pending", status = "pending" },
        },
    })
end

-- ============================================================================
-- Section: Menu
-- ============================================================================
do
    local section = createSection("Menu")

    section:AddChild(UI.Menu {
        items = {
            { label = "Item 1", onClick = function() print("Item 1") end },
            { label = "Item 2", onClick = function() print("Item 2") end },
            { type = "divider" },
            { label = "Item 3", onClick = function() print("Item 3") end },
        },
    })
end

-- ============================================================================
-- Section: Tree
-- ============================================================================
do
    local section = createSection("Tree")

    section:AddChild(UI.Tree {
        nodes = {
            {
                label = "Root",
                expanded = true,
                children = {
                    { label = "Child 1" },
                    {
                        label = "Child 2",
                        children = {
                            { label = "Grandchild" },
                        },
                    },
                },
            },
        },
    })
end

-- ============================================================================
-- Section: Divider
-- ============================================================================
do
    local section = createSection("Divider")

    section:AddChild(UI.Label { text = "Above divider" })
    section:AddChild(UI.Divider {})
    section:AddChild(UI.Label { text = "Below divider" })
end

-- ============================================================================
-- Section: Skeleton
-- ============================================================================
do
    local section = createSection("Skeleton (Loading)")

    local row = UI.Row { gap = 10, flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Skeleton { variant = "circle", width = 48, height = 48 })
    row:AddChild(UI.Column {
        gap = 8,
        children = {
            UI.Skeleton { variant = "text", width = 150, height = 16 },
            UI.Skeleton { variant = "text", width = 100, height = 14 },
        },
    })
end

-- ============================================================================
-- Section: Tooltip
-- ============================================================================
do
    local section = createSection("Tooltip")

    section:AddChild(UI.Tooltip {
        content = "This is a tooltip!",
        children = {
            UI.Button { text = "Hover me" },
        },
    })
end

-- ============================================================================
-- Section: List
-- ============================================================================
do
    local section = createSection("List")

    -- Create list first
    local listWidget = UI.List {
        items = {
            { id = "inbox", primary = "Inbox", secondary = "3 unread messages" },
            { id = "sent", primary = "Sent", secondary = "Last sent yesterday" },
            { id = "drafts", primary = "Drafts", secondary = "2 drafts" },
            { id = "trash", primary = "Trash" },
        },
        selectable = false,
        showDividers = true,
        onSelect = function(list, selectedId)
            print("Selected:", selectedId)
        end,
    }

    -- Toggle for selectable control
    section:AddChild(UI.Toggle {
        label = "Selectable",
        value = false,
        marginBottom = 12,
        onChange = function(toggle, value)
            listWidget.selectable_ = value
            listWidget:ClearSelection()
        end,
    })
    section:AddChild(listWidget)
end

-- ============================================================================
-- Section: DatePicker
-- ============================================================================
do
    local section = createSection("DatePicker")

    section:AddChild(UI.DatePicker {
        placeholder = "Select date...",
        onChange = function(_, date) state.dateValue = date end,
    })
end

-- ============================================================================
-- Section: TimePicker
-- ============================================================================
do
    local section = createSection("TimePicker")

    section:AddChild(UI.TimePicker {
        placeholder = "Select time...",
        onChange = function(_, time) state.timeValue = time end,
    })
end

-- ============================================================================
-- Section: ColorPicker
-- ============================================================================
do
    local section = createSection("ColorPicker")

    section:AddChild(UI.ColorPicker {
        value = state.colorValue,
        onChange = function(_, color) state.colorValue = color end,
    })
end

-- ============================================================================
-- Section: Calendar
-- ============================================================================
do
    local section = createSection("Calendar")

    section:AddChild(UI.Calendar {
        onDateSelect = function(_, date)
            print("Selected: " .. date.year .. "-" .. date.month .. "-" .. date.day)
        end,
    })
end

-- ============================================================================
-- Section: Table
-- ============================================================================
do
    local section = createSection("Table")

    -- Create table first
    local tableWidget = UI.Table {
        columns = {
            { key = "name", label = "Name", width = 150 },
            { key = "age", label = "Age", width = 80 },
            { key = "city", label = "City", width = 120 },
        },
        data = {
            { name = "Alice", age = 25, city = "New York" },
            { name = "Bob", age = 30, city = "London" },
            { name = "Charlie", age = 35, city = "Tokyo" },
        },
        selectable = false,
        variant = "striped",
    }

    -- Toggle for selectable control
    section:AddChild(UI.Toggle {
        label = "Selectable",
        value = false,
        marginBottom = 12,
        onChange = function(toggle, value)
            tableWidget.selectable_ = value
            tableWidget:ClearSelection()
        end,
    })
    section:AddChild(tableWidget)
end

-- ============================================================================
-- Section: Carousel
-- ============================================================================
do
    local section = createSection("Carousel")

    local carousel = UI.Carousel {
        items = {
            { content = "Slide 1", backgroundColor = "#3498db" },
            { content = "Slide 2", backgroundColor = "#e74c3c" },
            { content = "Slide 3", backgroundColor = "#2ecc71" },
        },
        width = 400,
        height = 200,
        autoPlay = true,
    }
    section:AddChild(carousel)
    table.insert(updatableWidgets.carousels, carousel)
end

-- ============================================================================
-- Section: Drawer
-- ============================================================================
do
    local section = createSection("Drawer")

    local drawer = UI.Drawer {
        position = "left",
        size = 280,
        header = "Menu",
        showCloseButton = true,
        showOverlay = false,  -- No overlay (transparent), click anywhere to close
        content = function(nvg, x, y, w, h)
            nvgFontSize(nvg, UI.Theme.FontSizeOf("body"))
            nvgFontFace(nvg, UI.Theme.FontFamily())
            nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, UI.Theme.NvgColor("text"))
            nvgText(nvg, x + 16, y + 24, "Menu Item 1")
            nvgText(nvg, x + 16, y + 60, "Menu Item 2")
            nvgText(nvg, x + 16, y + 96, "Menu Item 3")
        end,
    }

    section:AddChild(UI.Button {
        text = "Open Drawer",
        onClick = function() drawer:Open() end,
    })

    root:AddChild(drawer)
    table.insert(updatableWidgets.drawers, drawer)
end

-- ============================================================================
-- Section: Popover
-- ============================================================================
do
    local section = createSection("Popover")

    section:AddChild(UI.Popover {
        content = "Popover content here!",
        placement = "bottom",
        trigger = "click",
        children = {
            UI.Button { text = "Click for Popover" },
        },
    })
end

-- ============================================================================
-- Section: FileUpload
-- ============================================================================
do
    local section = createSection("FileUpload")

    section:AddChild(UI.FileUpload {
        variant = "dropzone",
        multiple = true,
        onFileSelect = function(_, file)
            print("File selected: " .. file.name)
        end,
    })
end

-- ============================================================================
-- Section: RichText
-- ============================================================================
do
    local section = createSection("RichText")

    section:AddChild(UI.RichText {
        content = [[
# Heading 1
## Heading 2

This is **bold** and *italic* text.

- List item 1
- List item 2

> A blockquote

`inline code`

[Link](https://example.com)
]],
    })
end

-- ============================================================================
-- Section: Modal
-- ============================================================================
do
    local section = createSection("Modal")

    -- 1. Basic modal with multi-line content (tests Yoga contentContainer_ height calculation)
    local basicModal = UI.Modal {
        title = "Basic Modal",
        children = {
            UI.Label { text = "This is the first line of content." },
            UI.Label { text = "This is the second line, testing multi-child Yoga layout." },
            UI.Label { text = "Third line to verify gap spacing between children." },
        },
    }

    -- 2. Modal with footer buttons (tests footer Yoga subtree + hit testing)
    local footerModal = UI.Modal {
        title = "Modal with Footer",
        children = {
            UI.Label { text = "This modal has footer buttons." },
            UI.Label { text = "Click the buttons below to test hit testing on footer." },
        },
    }
    local footerPanel = UI.Panel {
        flexDirection = "row",
        justifyContent = "flex-end",
        gap = 10,
        width = "100%",
    }
    footerPanel:AddChild(UI.Button {
        text = "Cancel",
        variant = "secondary",
        onClick = function() footerModal:Close() end,
    })
    footerPanel:AddChild(UI.Button {
        text = "Confirm",
        variant = "primary",
        onClick = function() footerModal:Close() end,
    })
    footerModal:SetFooter(footerPanel)

    -- 3. Modal with interactive content (tests GetHitTestChildren on content children)
    local interactiveModal = UI.Modal {
        title = "Interactive Content",
        size = "lg",
    }
    interactiveModal:AddContent(UI.Label { text = "Interactive controls inside modal body:" })
    interactiveModal:AddContent(UI.TextField {
        placeholder = "Type here to test input focus...",
        width = "100%",
    })
    interactiveModal:AddContent(UI.Panel {
        flexDirection = "row",
        gap = 8,
        children = {
            UI.Button { text = "Action A", variant = "primary" },
            UI.Button { text = "Action B", variant = "secondary" },
        },
    })

    -- 4. Modal with Dropdown (tests overlay-in-overlay: Dropdown opens on top of Modal)
    local dropdownModal = UI.Modal {
        title = "Modal with Dropdown",
        size = "md",
    }
    dropdownModal:AddContent(UI.Label { text = "Select a fruit from the dropdown:" })
    dropdownModal:AddContent(UI.Dropdown {
        placeholder = "Choose fruit...",
        options = {
            { value = "apple", label = "Apple" },
            { value = "banana", label = "Banana" },
            { value = "cherry", label = "Cherry" },
            { value = "grape", label = "Grape" },
            { value = "mango", label = "Mango" },
        },
        width = 200,
        onChange = function(_, value) print("Dropdown in modal: " .. tostring(value)) end,
    })
    dropdownModal:AddContent(UI.Label {
        text = "The dropdown list should appear above the modal overlay.",
        color = UI.Theme.Color("textSecondary"),
    })

    -- 5. Modal with ScrollView (tests scrollable content in Yoga subtree)
    local scrollModal = UI.Modal {
        title = "Modal with ScrollView",
        size = "md",
    }
    local scrollContent = UI.ScrollView {
        width = "100%",
        height = 200,
        scrollY = true,
        showScrollbar = true,
    }
    local scrollInner = UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 6,
    }
    for i = 1, 20 do
        scrollInner:AddChild(UI.Label {
            text = "Scrollable item #" .. i,
        })
    end
    scrollContent:AddChild(scrollInner)
    scrollModal:AddContent(UI.Label { text = "Scroll through the list below:" })
    scrollModal:AddContent(scrollContent)

    -- 6. Modal with Tabs (tests Tabs widget inside Yoga subtree)
    local tabsModal = UI.Modal {
        title = "Modal with Tabs",
        size = "lg",
    }
    local modalTabs = UI.Tabs {
        tabs = {
            { id = "info", label = "Info" },
            { id = "settings", label = "Settings" },
            { id = "about", label = "About" },
        },
        activeTab = "info",
        width = "100%",
        height = 180,
    }
    modalTabs:SetTabContent("info", UI.Panel {
        width = "100%",
        height = "100%",
        padding = 12,
        flexDirection = "column",
        gap = 6,
        children = {
            UI.Label { text = "Info tab content inside a modal." },
            UI.Label { text = "Switch tabs to verify tab rendering works." },
        },
    })
    modalTabs:SetTabContent("settings", UI.Panel {
        width = "100%",
        height = "100%",
        padding = 12,
        flexDirection = "column",
        gap = 8,
        children = {
            UI.Label { text = "Settings tab:" },
            UI.Toggle { label = "Enable notifications", checked = true },
            UI.Toggle { label = "Dark mode", checked = false },
        },
    })
    modalTabs:SetTabContent("about", UI.Label {
        text = "About: UrhoX UI Modal + Tabs integration test.",
        textAlign = "center",
        verticalAlign = "middle",
    })
    tabsModal:AddContent(modalTabs)

    -- 7. Confirm dialog (tests Modal.Confirm static helper)
    local confirmResult = UI.Label {
        text = "Confirm result: (none)",
        color = UI.Theme.Color("textSecondary"),
    }

    -- 8. Alert dialog (tests Modal.Alert static helper)
    local alertResult = UI.Label {
        text = "Alert result: (none)",
        color = UI.Theme.Color("textSecondary"),
    }

    -- 9. Modal with flexGrow ScrollView + inline action bar
    --    (regression test: YGUndefined caused ScrollView to expand fully,
    --     pushing action bar out of the visible area)
    local flexGrowModal = UI.Modal {
        title = "flexGrow ScrollView + Action Bar",
        size = "md",
        closeOnOverlay = true, closeOnEscape = true, showCloseButton = true,
    }
    do
        local listContent = UI.Panel { width = "100%", gap = 4 }
        for i = 1, 50 do
            listContent:AddChild(UI.Panel {
                width = "100%", height = 48,
                flexDirection = "row", alignItems = "center",
                padding = 8, gap = 10,
                backgroundColor = { 40, 45, 55, 255 },
                borderRadius = 6,
                children = {
                    UI.Label { text = "Item #" .. i, fontSize = 13 },
                },
            })
        end
        local scrollView = UI.ScrollView {
            width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0,
            children = { listContent },
        }
        local actionBar = UI.Panel {
            width = "100%", flexDirection = "row",
            justifyContent = "flex-end", gap = 8,
            flexShrink = 0, padding = 8,
            backgroundColor = { 35, 38, 48, 255 }, borderRadius = 8,
            children = {
                UI.Button { text = "Cancel", onClick = function() flexGrowModal:Close() end },
                UI.Button { text = "Confirm", variant = "solid", onClick = function() flexGrowModal:Close() end },
            },
        }
        flexGrowModal:AddContent(UI.Panel {
            width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0, gap = 8,
            children = {
                UI.Label { text = "ScrollView should scroll; action bar should stay visible at bottom.", fontSize = 12, fontColor = UI.Theme.Color("textSecondary") },
                scrollView,
                actionBar,
            },
        })
    end

    -- 10. Modal with ScrollView bounce-back test
    --     (regression test: YGUndefined made viewport = content height,
    --      scrollRange ≈ 0, so scrolling bounced back immediately)
    local bounceModal = UI.Modal {
        title = "ScrollView Bounce-back Test",
        size = "sm",
        closeOnOverlay = true, closeOnEscape = true, showCloseButton = true,
    }
    do
        local listContent = UI.Panel { width = "100%", gap = 4 }
        for i = 1, 30 do
            listContent:AddChild(UI.Panel {
                width = "100%", height = 48,
                flexDirection = "row", alignItems = "center",
                padding = 8, gap = 10,
                backgroundColor = { 40, 45, 55, 255 },
                borderRadius = 6,
                children = {
                    UI.Label { text = "Item #" .. i, fontSize = 13 },
                },
            })
        end
        listContent:AddChild(UI.Panel {
            width = "100%", height = 60,
            backgroundColor = { 255, 80, 80, 255 }, borderRadius = 8,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label { text = "END — you should be able to see this", fontSize = 13, fontColor = { 255, 255, 255, 255 }, textAlign = "center" },
            },
        })
        bounceModal:AddContent(UI.Panel {
            width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0, gap = 8,
            children = {
                UI.Label { text = "Scroll down to find the red marker at the bottom.", fontSize = 12, fontColor = UI.Theme.Color("textSecondary") },
                UI.ScrollView {
                    width = "100%", height = "100%",
                    children = { listContent },
                },
            },
        })
    end

    -- Buttons row 1
    local buttonsRow1 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    buttonsRow1:AddChild(UI.Button {
        text = "Basic",
        onClick = function() basicModal:Open() end,
    })
    buttonsRow1:AddChild(UI.Button {
        text = "With Footer",
        onClick = function() footerModal:Open() end,
    })
    buttonsRow1:AddChild(UI.Button {
        text = "Interactive",
        onClick = function() interactiveModal:Open() end,
    })
    buttonsRow1:AddChild(UI.Button {
        text = "Dropdown",
        onClick = function() dropdownModal:Open() end,
    })

    -- Buttons row 2
    local buttonsRow2 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    buttonsRow2:AddChild(UI.Button {
        text = "ScrollView",
        onClick = function() scrollModal:Open() end,
    })
    buttonsRow2:AddChild(UI.Button {
        text = "Tabs",
        onClick = function() tabsModal:Open() end,
    })
    buttonsRow2:AddChild(UI.Button {
        text = "Confirm",
        onClick = function()
            local m = UI.Modal.Confirm {
                title = "Delete Item?",
                message = "This action cannot be undone. Are you sure?",
                confirmText = "Delete",
                cancelText = "Keep",
                onConfirm = function()
                    confirmResult:SetText("Confirm result: Confirmed!")
                end,
                onCancel = function()
                    confirmResult:SetText("Confirm result: Cancelled")
                end,
            }
            root:AddChild(m)
        end,
    })
    buttonsRow2:AddChild(UI.Button {
        text = "Alert",
        onClick = function()
            local m = UI.Modal.Alert {
                title = "Notice",
                message = "Operation completed successfully.",
                onClose = function()
                    alertResult:SetText("Alert result: Dismissed")
                end,
            }
            root:AddChild(m)
        end,
    })

    -- Buttons row 3: regression tests
    local buttonsRow3 = UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    buttonsRow3:AddChild(UI.Button {
        text = "flexGrow + ActionBar",
        onClick = function() flexGrowModal:Open() end,
    })
    buttonsRow3:AddChild(UI.Button {
        text = "Bounce-back Test",
        onClick = function() bounceModal:Open() end,
    })

    section:AddChild(buttonsRow1)
    section:AddChild(buttonsRow2)
    section:AddChild(buttonsRow3)
    section:AddChild(confirmResult)
    section:AddChild(alertResult)

    root:AddChild(basicModal)
    root:AddChild(footerModal)
    root:AddChild(interactiveModal)
    root:AddChild(dropdownModal)
    root:AddChild(scrollModal)
    root:AddChild(tabsModal)
    root:AddChild(flexGrowModal)
    root:AddChild(bounceModal)
end

-- ============================================================================

-- ============================================================================
-- Section: Spine Animation
-- ============================================================================
if cache:Exists("LuaScripts/Tests/assets/test_spine/spineboy/spineboy-pro.skel") then
    local section = createSection("Spine Animation")

    local row = UI.Row { gap = 16, alignItems = "center", flexWrap = "wrap" }
    section:AddChild(row)

    local spineWidget
    local ik = { crosshair = nil, lastScreenX = -1, lastScreenY = -1 }
    local spineCard = UI.Panel {
        width = 300, height = 300,
        overflow = "hidden",
        backgroundColor = UI.Theme.Color("background"),
        borderRadius = 8,
        pointerEvents = "box-only",
        onPointerMove = function(event, widget)
            ik.lastScreenX = event.x
            ik.lastScreenY = event.y
        end,
        onPointerDown = function()
            if spineWidget then
                spineWidget:SetAnimation(2, "shoot", false)
            end
        end,
    }
    spineWidget = UI.Spine {
        src = "LuaScripts/Tests/assets/test_spine/spineboy/spineboy-pro.skel",
        animation = "idle",
        loop = true,
        width = "100%",
        height = "100%",
        pointerEvents = "none",
    }
    -- Track 1: aim overlay (always active)
    spineWidget:SetAnimation(1, "aim", true)
    ik.crosshair = spineWidget:FindBone("crosshair")
    local origUpdate = spineWidget.Update
    spineWidget.Update = function(self, dt)
        origUpdate(self, dt)
        if ik.crosshair and ik.lastScreenX >= 0 then
            local sx, sy = self:ScreenToSkeleton(ik.lastScreenX, ik.lastScreenY)
            ik.crosshair:SetX(sx)
            ik.crosshair:SetY(sy)
            self:UpdateWorldTransform()
        end
    end
    spineCard:AddChild(spineWidget)
    row:AddChild(spineCard)

    local controls = UI.Panel { flexDirection = "column", gap = 8 }
    row:AddChild(controls)

    -- Track 0: base animation buttons
    local anims = { "idle", "walk", "run", "jump", "hoverboard" }
    for _, name in ipairs(anims) do
        controls:AddChild(UI.Button {
            text = name,
            size = "sm",
            variant = "outlined",
            onClick = function()
                spineWidget:SetAnimation(0, name, true)
            end,
        })
    end
end

-- ============================================================================
-- Section: Toast
-- ============================================================================
do
    local section = createSection("Toast")

    local row = UI.Row { gap = 10, flexWrap = "wrap" }
    section:AddChild(row)

    row:AddChild(UI.Button {
        text = "Show Info Toast",
        onClick = function()
            UI.Toast.Show({ message = "Info message", variant = "info" })
        end,
    })

    row:AddChild(UI.Button {
        text = "Show Success Toast",
        onClick = function()
            UI.Toast.Show({ message = "Success!", variant = "success" })
        end,
    })
end

-- ============================================================================
-- Set Root and Prepare
-- ============================================================================

UI.SetRoot(root)

-- ============================================================================
-- Export
-- ============================================================================

-- ============================================================================
-- Example-specific Update (for demo animations)
-- UI.Update() and UI.Render() are handled by autoEvents
-- ============================================================================

local eventNode = Node()
local eventHandler = eventNode:CreateScriptObject("LuaScriptObject")
eventHandler:SubscribeToEvent("Update", function(self, eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- Update progress bars (demo animation)
    for _, pb in ipairs(updatableWidgets.progressBars) do
        local val = pb:GetValue() + dt * 0.1
        if val > 1 then val = 0 end
        pb:SetValue(val)
    end
end)
