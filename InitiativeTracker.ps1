Add-Type -AssemblyName PresentationFramework

# Define the XAML for the window
[xml]$xaml = Get-Content .\ui\InitiativeTracker_Main.xml -Raw

# Read the XAML into a WPF object
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get the button control from the XAML
$button = $window.FindName("InsertButton")
$mainPanel = $window.FindName("MainPanel")

# Load conditions from conditions.json
$conditionsPath = Join-Path $PSScriptRoot 'cfg\conditions.json'
$conditionsJson = Get-Content $conditionsPath -Raw
$conditions = ConvertFrom-Json $conditionsJson

# Add the click event handler
$button.Add_Click({
    # Create a grid for the panel layout
    $newPanel = New-Object System.Windows.Controls.Grid
    $newPanel.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    # First column: Initiative value with label above
    $col1Panel = New-Object System.Windows.Controls.StackPanel
    $col1Panel.Orientation = "Vertical"
    $initiativeLabel = New-Object System.Windows.Controls.Label
    $initiativeLabel.Content = "Initiative"
    $initiativeLabel.Background="#333"
    $initiativeLabel.Foreground="#EEE"
    $initiativeLabel.VerticalAlignment = "Center"
    $col1Panel.Children.Add($initiativeLabel)
    $initiativeValue = New-Object System.Windows.Controls.TextBox
    $initiativeValue.Width = 50
    $initiativeValue.Margin = [System.Windows.Thickness]::new(0,5,0,0)
    $initiativeValue.Text = "0"
    $initiativeValue.TextAlignment = "Center"
    $col1Panel.Children.Add($initiativeValue)
    [System.Windows.Controls.Grid]::SetColumn($col1Panel, 0)
    # Second column: textbox2
    $textBox2 = New-Object System.Windows.Controls.TextBox
    $textBox2.Width = 150
    $textBox2.Margin = [System.Windows.Thickness]::new(5,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($textBox2, 1)
    # Third column: label "Conditions" at the top
    $col3Panel = New-Object System.Windows.Controls.StackPanel
    $col3Panel.Orientation = "Vertical"
    $conditionsLabel = New-Object System.Windows.Controls.Label
    $conditionsLabel.Content = "Conditions"
    $conditionsLabel.Background="#333"
    $conditionsLabel.Foreground="#EEE"
    $conditionsLabel.VerticalAlignment = "Center"
    $col3Panel.Children.Add($conditionsLabel)
    [System.Windows.Controls.Grid]::SetColumn($col3Panel, 2)
    $newPanel.Children.Add($col1Panel)
    $newPanel.Children.Add($textBox2)
    $newPanel.Children.Add($col3Panel)
    # Add right-click menu to remove panel
    $contextMenu = New-Object System.Windows.Controls.ContextMenu
    $removeMenuItem = New-Object System.Windows.Controls.MenuItem
    $removeMenuItem.Header = "Remove"
    $removeMenuItem.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent.PlacementTarget
        $mainPanel.Children.Remove($parentPanel)
    })
    $contextMenu.Items.Add($removeMenuItem)
    $newPanel.ContextMenu = $contextMenu
    # Insert the new panel at the end but before the button (if button is in MainPanel)
    $insertIndex = $mainPanel.Children.Count - 1
    $mainPanel.Children.Insert($insertIndex, $newPanel)

    #only allow Initiative to be float values
    $initiativeValue.Add_PreviewTextInput({
        param($sourceObj, $e)
        # Only allow digits and a single period
        if ($e.Text -notmatch '^[0-9.]$') {
            $e.Handled = $true
        } elseif ($e.Text -eq '.' -and $sourceObj.Text.Contains('.')) {
            $e.Handled = $true
        }
    })
    $initiativeValue.Add_TextChanged({
        param($sourceObj, $e)
        # Remove extra periods and non-digit characters
        $text = $sourceObj.Text
        $firstPeriod = $text.IndexOf('.')
        if ($firstPeriod -ge 0) {
            $text = $text.Substring(0, $firstPeriod + 1) + ($text.Substring($firstPeriod + 1) -replace '\.', '')
        }
        $text = $text -replace '[^0-9.]', ''
        if ($sourceObj.Text -ne $text) {
            $sourceObj.Text = $text
            $sourceObj.SelectionStart = $sourceObj.Text.Length
        }
    })
})

# Get the SortMenuItem from XAML
$sortMenuItem = $window.FindName("SortMenuItem")

# Add click event to SortMenuItem to sort MainPanel children by initiativeValue (descending)
$sortMenuItem.Add_Click({
    # Get all panels except the InsertButton
    $panels = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $panels += $child
        }
    }
    # Sort panels by initiativeValue (ascending because insertion will reverse order)
    $sortedPanels = $panels | Sort-Object {
        $col1Panel = $_.Children[0]
        $initiativeValue = $col1Panel.Children[1]
        [float]$initiativeValue.Text
    }
    # Remove all panels from MainPanel
    foreach ($panel in $panels) {
        $mainPanel.Children.Remove($panel)
    }
    # Re-insert sorted panels before the InsertButton
    $insertIndex = $mainPanel.Children.Count - 1
    foreach ($panel in $sortedPanels) {
        $mainPanel.Children.Insert($insertIndex, $panel)
    }
})

# Track the current highlighted index
if (-not (Get-Variable -Name currentIndex -Scope Script -ErrorAction SilentlyContinue)) {
    $script:currentIndex = 0
}

# Add click event to NextRoundButton to highlight the next item in MainPanel
$nextRoundButton = $window.FindName("NextRoundButton")
$nextRoundButton.Add_Click({
    # Get all panels except the InsertButton
    $panels = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $panels += $child
        }
    }
    if ($panels.Count -eq 0) { return }
    # Remove highlight from all panels
    foreach ($panel in $panels) {
        $panel.Background = $null
    }
    # Highlight the next panel
    $panelToHighlight = $panels[$script:currentIndex % $panels.Count]
    $panelToHighlight.Background = "#5555FF"
    $script:currentIndex++
})

# Show the window
$window.ShowDialog() | Out-Null
$window.Close()