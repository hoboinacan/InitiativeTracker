Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Define the XAML for the window
[xml]$xaml = Get-Content .\ui\InitiativeTracker_Main.xml -Raw

# Read the XAML into a WPF object
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get the button control from the XAML
$insertButton = $window.FindName("InsertButton")
$mainPanel = $window.FindName("MainPanel")

# Load conditions from conditions.json
$conditionsPath = Join-Path $PSScriptRoot 'cfg\conditions.json'
$conditionsJson = Get-Content $conditionsPath -Raw
$conditions = ConvertFrom-Json $conditionsJson

# Track the current highlighted index
if (-not (Get-Variable -Name highlightIndex -Scope Script -ErrorAction SilentlyContinue)) {
    $script:highlightIndex = 0
}
function Update-HighlightIndex {
    param($panel)
    $grids = @()
    foreach ($child in $panel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $grids += $child
        }
    }
    if ($grids.Count -eq 0) { return $null }
    if (++$script:highlightIndex -ge $grids.Count) {
        $script:highlightIndex = 0
    }
    return $script:highlightIndex
}

function Set-AlternateShading {
    param($panel, $highlightedIndex = $null)
    $index = 0
    foreach ($child in $panel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            if ($null -ne $highlightedIndex -and $index -eq $highlightedIndex) {
                $child.Background = "#5555FF"
            } elseif ($index % 2 -eq 0) {
                $child.Background = "#222"
            } else {
                $child.Background = "#333"
            }
            $index++
        }
    }
}

# Add the click event handler
$insertButton.Add_Click({
    # Create a grid for the panel layout
    $newPanel = New-Object System.Windows.Controls.Grid
    $newPanel.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $newPanel.HorizontalAlignment = "Stretch"
    $newPanel.Width = [double]::NaN
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $newPanel.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
    $newPanel.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $newPanel.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
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
    # Second column: Character name textbox
    $characterNameBox = New-Object System.Windows.Controls.TextBox
    $characterNameBox.Width = 150
    $characterNameBox.Background = $null
    $characterNameBox.Foreground = "#00ff00"
    $characterNameBox.FontSize = 24
    $characterNameBox.VerticalContentAlignment = "Center"
    $characterNameBox.Margin = [System.Windows.Thickness]::new(5,0,0,0)
    [System.Windows.Controls.Grid]::SetColumn($characterNameBox, 1)
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
    $newPanel.Children.Add($characterNameBox)
    $newPanel.Children.Add($col3Panel)
    # Add right-click menu to remove panel
    $contextMenu = New-Object System.Windows.Controls.ContextMenu
    $removeMenuItem = New-Object System.Windows.Controls.MenuItem
    $removeMenuItem.Header = "Remove"
    $removeMenuItem.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent.PlacementTarget
        $mainPanel.Children.Remove($parentPanel)
        Set-AlternateShading $mainPanel $script:highlightIndex
    })
    $contextMenu.Items.Add($removeMenuItem)
    $newPanel.ContextMenu = $contextMenu
    # Insert the new panel at the end but before the button (if button is in MainPanel)
    $insertIndex = $mainPanel.Children.Count - 1
    $mainPanel.Children.Insert($insertIndex, $newPanel)
    Set-AlternateShading $mainPanel $script:highlightIndex

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
    Set-AlternateShading $mainPanel $script:highlightIndex
})

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
    Update-HighlightIndex $mainPanel
    Set-AlternateShading $mainPanel $script:highlightIndex
})

# Get the ExportMenuItem from XAML
$exportMenuItem = $window.FindName("ExportMenuItem")

# Add click event to ExportMenuItem to export encounter data to JSON file
$exportMenuItem.Add_Click({
    $encounter = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $initiative = $child.Children[0].Children[1].Text
            $name = $child.Children[1].Text
            $conditions = $child.Children[2].Text
            $encounter += [PSCustomObject]@{
                Initiative = $initiative
                Name = $name
                Conditions = $conditions
            }
        }
    }
    $exportData = [PSCustomObject]@{
        HighlightIndex = $script:highlightIndex
        Encounter = $encounter
    }
    $json = $exportData | ConvertTo-Json -Depth 3
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "JSON files (*.json)|*.json"
    $saveFileDialog.InitialDirectory = "$PSScriptRoot/encounters"
    $saveFileDialog.Title = "Export Encounter"
    $saveFileDialog.FileName = "encounter_export.json"
    [void]$saveFileDialog.ShowDialog()
    $filePath = $saveFileDialog.FileName
    if (![string]::IsNullOrWhiteSpace($filePath)) {
        Set-Content -Path $filePath -Value $json
        [System.Windows.MessageBox]::Show("Encounter exported to $filePath")
    }
})

# Get the ImportMenuItem from XAML
$importMenuItem = $window.FindName("ImportMenuItem")

# Add click event to ImportMenuItem to import encounter data from a JSON file
$importMenuItem.Add_Click({
    # Prompt user to select a JSON file
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "JSON files (*.json)|*.json"
    $openFileDialog.InitialDirectory = "$PSScriptRoot/encounters"
    $openFileDialog.Title = "Import Encounter"
    [void]$openFileDialog.ShowDialog()
    $filePath = $openFileDialog.FileName

    if (![string]::IsNullOrWhiteSpace($filePath) -and (Test-Path $filePath)) {
        # Read and parse the JSON file
        $json = Get-Content $filePath -Raw
        $importData = ConvertFrom-Json $json
        $encounter = $importData.Encounter
        $script:highlightIndex = $importData.HighlightIndex

        # Remove existing panels except InsertButton
        $panelsToRemove = @()
        foreach ($child in $mainPanel.Children) {
            if ($child -is [System.Windows.Controls.Grid]) {
                $panelsToRemove += $child
            }
        }
        foreach ($panel in $panelsToRemove) {
            $mainPanel.Children.Remove($panel)
        }

        # Add imported panels
        foreach ($entry in $encounter) {
            $newPanel = New-Object System.Windows.Controls.Grid
            $newPanel.Margin = [System.Windows.Thickness]::new(0,0,0,10)
            $newPanel.HorizontalAlignment = "Stretch"
            $newPanel.Width = [double]::NaN
            $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
            $newPanel.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
            $newPanel.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $newPanel.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star
)

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
            $initiativeValue.Text = "$($entry.Initiative)"
            $initiativeValue.TextAlignment = "Center"
            $col1Panel.Children.Add($initiativeValue)
            [System.Windows.Controls.Grid]::SetColumn($col1Panel, 0)

            # Second column: Character name textbox
            $characterNameBox = New-Object System.Windows.Controls.TextBox
            $characterNameBox.Width = 150
            $characterNameBox.Background = $null
            $characterNameBox.Foreground = "#00ff00"
            $characterNameBox.FontSize = 24
            $characterNameBox.VerticalContentAlignment = "Center"
            $characterNameBox.Margin = [System.Windows.Thickness]::new(5,0,0,0)
            $characterNameBox.Text = "$($entry.Name)"
            [System.Windows.Controls.Grid]::SetColumn($characterNameBox, 1)

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
            $newPanel.Children.Add($characterNameBox)
            $newPanel.Children.Add($col3Panel)
            # Add right-click menu to remove panel
            $contextMenu = New-Object System.Windows.Controls.ContextMenu
            $removeMenuItem = New-Object System.Windows.Controls.MenuItem
            $removeMenuItem.Header = "Remove"
            $removeMenuItem.Add_Click({
                param($sourceObj, $e)
                $parentPanel = $sourceObj.Parent.PlacementTarget
                $mainPanel.Children.Remove($parentPanel)
                Set-AlternateShading $mainPanel $script:highlightIndex
            })
            $contextMenu.Items.Add($removeMenuItem)
            $newPanel.ContextMenu = $contextMenu
            # Insert the new panel at the end but before the button (if button is in MainPanel)
            $insertIndex = $mainPanel.Children.Count - 1
            $mainPanel.Children.Insert($insertIndex, $newPanel)
        }
        Set-AlternateShading $mainPanel $script:highlightIndex
    }
})

# Show the window
$window.ShowDialog() | Out-Null
$window.Close()