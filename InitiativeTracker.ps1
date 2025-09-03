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

function Add-EncounterPanel {
    param(
        [string]$initiative = "0",
        [string]$name = "Name",
        [string]$conditions = "",
        [string]$currentHp = "CurHP",
        [string]$totalHp = "TotHP"
    )
    $newPanel = New-Object System.Windows.Controls.Grid
    $newPanel.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $newPanel.HorizontalAlignment = "Stretch"
    $newPanel.Width = [double]::NaN
    $newPanel.ColumnDefinitions.Clear()
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Initiative
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Name
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # HP
    $newPanel.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) # Conditions
    $newPanel.ColumnDefinitions[0].Width = [System.Windows.GridLength]::Auto
    $newPanel.ColumnDefinitions[1].Width = [System.Windows.GridLength]::Auto
    $newPanel.ColumnDefinitions[2].Width = [System.Windows.GridLength]::Auto
    $newPanel.ColumnDefinitions[3].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)

    # Initiative column
    $initiativePanel = New-Object System.Windows.Controls.StackPanel
    $initiativePanel.Orientation = "Vertical"
    $initiativeLabel = New-Object System.Windows.Controls.Label
    $initiativeLabel.Content = "Initiative"
    $initiativeLabel.Background="#333"
    $initiativeLabel.Foreground="#EEE"
    $initiativeLabel.VerticalAlignment = "Center"
    $initiativeValue = New-Object System.Windows.Controls.TextBox
    $initiativeValue.Width = 50
    $initiativeValue.Margin = [System.Windows.Thickness]::new(0,0,0,0)
    $initiativeValue.Text = $initiative
    $initiativeValue.TextAlignment = "Center"
    $initiativeValue.Add_GotFocus({
        param($sourceObj, $e)
        $sourceObj.SelectAll()
    })
    $initiativeValue.Add_PreviewMouseLeftButtonDown({
        param($sourceObj, $e)
        if (-not $sourceObj.IsKeyboardFocusWithin) {
            $e.Handled = $true
            $sourceObj.Focus()
            $sourceObj.SelectAll()
        }
    })
    $null = $initiativePanel.Children.Add($initiativeLabel)
    $null = $initiativePanel.Children.Add($initiativeValue)
    [System.Windows.Controls.Grid]::SetColumn($initiativePanel, 0)

    # Name column
    $characterNameBox = New-Object System.Windows.Controls.TextBox
    $characterNameBox.Width = 150
    $characterNameBox.Background = $null
    $characterNameBox.Foreground = "#00ff00"
    $characterNameBox.FontSize = 24
    $characterNameBox.VerticalContentAlignment = "Center"
    $characterNameBox.Margin = [System.Windows.Thickness]::new(5,0,0,0)
    $characterNameBox.Text = $name
    $characterNameBox.Add_GotFocus({
        param($sourceObj, $e)
        $sourceObj.SelectAll()
    })
    $characterNameBox.Add_PreviewMouseLeftButtonDown({
        param($sourceObj, $e)
        if (-not $sourceObj.IsKeyboardFocusWithin) {
            $e.Handled = $true
            $sourceObj.Focus()
            $sourceObj.SelectAll()
        }
    })
    [System.Windows.Controls.Grid]::SetColumn($characterNameBox, 1)

    # HP column
    $hpPanel = New-Object System.Windows.Controls.StackPanel
    $hpPanel.Orientation = "Vertical"
    $hpPanel.Margin = [System.Windows.Thickness]::new(5,0,0,0)

    # Current HP with left-to-right: minus, textbox, plus
    $currentHpPanel = New-Object System.Windows.Controls.StackPanel
    $currentHpPanel.Orientation = "Horizontal"
    $downCurrentHp = New-Object System.Windows.Controls.Button
    $downCurrentHp.Content = "-"
    $downCurrentHp.Width = 20
    $downCurrentHp.Height = 20
    $downCurrentHp.Margin = [System.Windows.Thickness]::new(0,0,2,0)
    $downCurrentHp.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent
        $hpBox = $parentPanel.Children[1]
        $val = 0
        if ($hpBox.Text -match '^[0-9]+$') { $val = [int]$hpBox.Text }
        if ($val -gt 0) { $hpBox.Text = ($val - 1).ToString() }
    })
    $currentHpBox = New-Object System.Windows.Controls.TextBox
    $currentHpBox.Width = 40
    $currentHpBox.Text = $currentHp
    $currentHpBox.MaxLength = 5
    $currentHpBox.Add_GotFocus({
        param($sourceObj, $e)
        $sourceObj.SelectAll()
    })
    $currentHpBox.Add_PreviewMouseLeftButtonDown({
        param($sourceObj, $e)
        if (-not $sourceObj.IsKeyboardFocusWithin) {
            $e.Handled = $true
            $sourceObj.Focus()
            $sourceObj.SelectAll()
        }
    })
    $currentHpBox.Add_PreviewTextInput({
        param($sourceObj, $e)
        if ($e.Text -notmatch '^[0-9]$') {
            $e.Handled = $true
        }
    })
    $currentHpBox.Add_TextChanged({
        param($sourceObj, $e)
        $text = $sourceObj.Text -replace '[^0-9]', ''
        if ($sourceObj.Text -ne $text) {
            $sourceObj.Text = $text
            $sourceObj.SelectionStart = $sourceObj.Text.Length
        }
    })
    $upCurrentHp = New-Object System.Windows.Controls.Button
    $upCurrentHp.Content = "+"
    $upCurrentHp.Width = 20
    $upCurrentHp.Height = 20
    $upCurrentHp.Margin = [System.Windows.Thickness]::new(2,0,0,0)
    $upCurrentHp.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent
        $hpBox = $parentPanel.Children[1]
        $val = 0
        if ($hpBox.Text -match '^[0-9]+$') { $val = [int]$hpBox.Text }
        $hpBox.Text = ($val + 1).ToString()
    })
    $null = $currentHpPanel.Children.Add($downCurrentHp)
    $null = $currentHpPanel.Children.Add($currentHpBox)
    $null = $currentHpPanel.Children.Add($upCurrentHp)
    $null = $hpPanel.Children.Add($currentHpPanel)
    # Add horizontal line below CurrentHP
    $hpSeparator = New-Object System.Windows.Controls.Separator
    $hpSeparator.Margin = [System.Windows.Thickness]::new(0,2,0,2)
    $hpSeparator.Background = "#888"
    $null = $hpPanel.Children.Add($hpSeparator)
    # Total HP with left-to-right: minus, textbox, plus
    $totalHpPanel = New-Object System.Windows.Controls.StackPanel
    $totalHpPanel.Orientation = "Horizontal"
    $downTotalHp = New-Object System.Windows.Controls.Button
    $downTotalHp.Content = "-"
    $downTotalHp.Width = 20
    $downTotalHp.Height = 20
    $downTotalHp.Margin = [System.Windows.Thickness]::new(0,0,2,0)
    $downTotalHp.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent
        $hpBox = $parentPanel.Children[1]
        $val = 0
        if ($hpBox.Text -match '^[0-9]+$') { $val = [int]$hpBox.Text }
        if ($val -gt 0) { $hpBox.Text = ($val - 1).ToString() }
    })
    $totalHpBox = New-Object System.Windows.Controls.TextBox
    $totalHpBox.Width = 40
    $totalHpBox.Text = $totalHp
    $totalHpBox.MaxLength = 5
    $totalHpBox.Add_GotFocus({
        param($sourceObj, $e)
        $sourceObj.SelectAll()
    })
    $totalHpBox.Add_PreviewMouseLeftButtonDown({
        param($sourceObj, $e)
        if (-not $sourceObj.IsKeyboardFocusWithin) {
            $e.Handled = $true
            $sourceObj.Focus()
            $sourceObj.SelectAll()
        }
    })
    $totalHpBox.Add_PreviewTextInput({
        param($sourceObj, $e)
        if ($e.Text -notmatch '^[0-9]$') {
            $e.Handled = $true
        }
    })
    $totalHpBox.Add_TextChanged({
        param($sourceObj, $e)
        $text = $sourceObj.Text -replace '[^0-9]', ''
        if ($sourceObj.Text -ne $text) {
            $sourceObj.Text = $text
            $sourceObj.SelectionStart = $sourceObj.Text.Length
        }
    })
    $upTotalHp = New-Object System.Windows.Controls.Button
    $upTotalHp.Content = "+"
    $upTotalHp.Width = 20
    $upTotalHp.Height = 20
    $upTotalHp.Margin = [System.Windows.Thickness]::new(2,0,0,0)
    $upTotalHp.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent
        $hpBox = $parentPanel.Children[1]
        $val = 0
        if ($hpBox.Text -match '^[0-9]+$') { $val = [int]$hpBox.Text }
        $hpBox.Text = ($val + 1).ToString()
    })
    $null = $totalHpPanel.Children.Add($downTotalHp)
    $null = $totalHpPanel.Children.Add($totalHpBox)
    $null = $totalHpPanel.Children.Add($upTotalHp)
    $null = $hpPanel.Children.Add($totalHpPanel)
    [System.Windows.Controls.Grid]::SetColumn($hpPanel, 2)

    # Conditions column
    $col3Panel = New-Object System.Windows.Controls.StackPanel
    $col3Panel.Orientation = "Vertical"
    $conditionsLabel = New-Object System.Windows.Controls.Label
    $conditionsLabel.Content = "Conditions"
    $conditionsLabel.Background="#333"
    $conditionsLabel.Foreground="#EEE"
    $conditionsLabel.VerticalAlignment = "Center"
    $null = $col3Panel.Children.Add($conditionsLabel)
    [System.Windows.Controls.Grid]::SetColumn($col3Panel, 3)

    $null = $newPanel.Children.Add($initiativePanel)
    $null = $newPanel.Children.Add($characterNameBox)
    $null = $newPanel.Children.Add($hpPanel)
    $null = $newPanel.Children.Add($col3Panel)

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
    $null = $contextMenu.Items.Add($removeMenuItem)
    $newPanel.ContextMenu = $contextMenu

    return $newPanel
}

# Add the click event handler
$insertButton.Add_Click({
    $newPanel = Add-EncounterPanel
    $insertIndex = $mainPanel.Children.Count - 1
    $mainPanel.Children.Insert($insertIndex, $newPanel)
    Set-AlternateShading $mainPanel $script:highlightIndex

    #only allow Initiative to be float values
    $initiativeValue = $newPanel.Children[0].Children[1]
    $initiativeValue.Add_PreviewTextInput({
        param($sourceObj, $e)
        # Only allow digits, a single period, and a single leading minus
        if ($e.Text -notmatch '^[0-9.-]$') {
            $e.Handled = $true
        } elseif ($e.Text -eq '-' -and ($sourceObj.SelectionStart -ne 0 -or $sourceObj.Text.Contains('-'))) {
            $e.Handled = $true
        } elseif ($e.Text -eq '.' -and $sourceObj.Text.Contains('.')) {
            $e.Handled = $true
        }
    })
    $initiativeValue.Add_TextChanged({
        param($sourceObj, $e)
        # Remove extra periods, non-digit characters, and ensure only one leading minus
        $text = $sourceObj.Text
        $firstPeriod = $text.IndexOf('.')
        if ($firstPeriod -ge 0) {
            $text = $text.Substring(0, $firstPeriod + 1) + ($text.Substring($firstPeriod + 1) -replace '\.', '')
        }
        $text = $text -replace '[^0-9.-]', ''
        if ($text.StartsWith('-')) {
            $text = '-' + ($text.Substring(1) -replace '-', '')
        } else {
            $text = $text -replace '-', ''
        }
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
        $initiativePanel = $_.Children[0]
        $initiativeValue = $initiativePanel.Children[1]
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
            # HP column: get TextBox from inside StackPanels (new layout)
            $currentHp = $child.Children[2].Children[0].Children[1].Text
            $totalHp = $child.Children[2].Children[2].Children[1].Text
            $conditions = $child.Children[3].Children[0].Text
            $encounter += [PSCustomObject]@{
                Initiative = $initiative
                Name = $name
                CurrentHP = $currentHp
                TotalHP = $totalHp
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
        $insertIndex = $mainPanel.Children.Count - 1
        foreach ($entry in $encounter) {
            $newPanel = Add-EncounterPanel $entry.Initiative $entry.Name $entry.Conditions $entry.CurrentHP $entry.TotalHP
            $mainPanel.Children.Insert($insertIndex, $newPanel)
            $insertIndex++
        }
        # Redraw current turn highlight
        Set-AlternateShading $mainPanel $script:highlightIndex
    }
})

# Show the window
$window.ShowDialog() | Out-Null
$window.Close()