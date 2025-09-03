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
        $name = $parentPanel.Children[1].Text
        $result = [System.Windows.MessageBox]::Show("Are you sure you want to delete '$name'?", "Confirm Deletion", "YesNo", "Warning")
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $mainPanel.Children.Remove($parentPanel)
            Set-AlternateShading $mainPanel $script:highlightIndex
        }
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
$sortAscMenuItem = $window.FindName("SortAscMenuItem")
$sortDescMenuItem = $window.FindName("SortDescMenuItem")

# Add click event to SortAscMenuItem to sort MainPanel children by initiativeValue (ascending)
$sortAscMenuItem.Add_Click({
    $panels = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $panels += $child
        }
    }
    $sortedPanels = $panels | Sort-Object {
        $initiativePanel = $_.Children[0]
        $initiativeValue = $initiativePanel.Children[1]
        -[float]$initiativeValue.Text
    }
    foreach ($panel in $panels) {
        $mainPanel.Children.Remove($panel)
    }
    $insertIndex = $mainPanel.Children.Count - 1
    foreach ($panel in $sortedPanels) {
        $mainPanel.Children.Insert($insertIndex, $panel)
    }
    Set-AlternateShading $mainPanel $script:highlightIndex
})

# Add click event to SortDescMenuItem to sort MainPanel children by initiativeValue (descending)
$sortDescMenuItem.Add_Click({
    $panels = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $panels += $child
        }
    }
    $sortedPanels = $panels | Sort-Object {
        $initiativePanel = $_.Children[0]
        $initiativeValue = $initiativePanel.Children[1]
        [float]$initiativeValue.Text
    }
    foreach ($panel in $panels) {
        $mainPanel.Children.Remove($panel)
    }
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
    $dialogResult = $saveFileDialog.ShowDialog()
    $filePath = $saveFileDialog.FileName
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($filePath)) {
        return
    }
    Set-Content -Path $filePath -Value $json
    [System.Windows.MessageBox]::Show("Encounter exported to $filePath")
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

# Players list storage and persistence
$playersFile = Join-Path $PSScriptRoot 'players\player_cache.json'
# Player data structure: @{ Name = ..., Playing = $false }
if (Test-Path $playersFile) {
    try {
        $loadedPlayers = Get-Content $playersFile -Raw | ConvertFrom-Json
        $script:players = New-Object System.Collections.ArrayList
        foreach ($p in $loadedPlayers) {
            if ($p -is [string]) {
                $null = $script:players.Add([PSCustomObject]@{ Name = $p; Playing = $false })
            } elseif ($p.PSObject.Properties["Name"] -and $p.PSObject.Properties["Playing"]) {
                $null = $script:players.Add([PSCustomObject]@{ Name = $p.Name; Playing = $p.Playing })
            } else {
                $null = $script:players.Add([PSCustomObject]@{ Name = $p; Playing = $false })
            }
        }
    } catch {}
} else {
    $script:players = New-Object System.Collections.ArrayList
}

function Save-PlayersList {
    $null = New-Item -ItemType Directory -Path (Split-Path $playersFile) -Force
    Set-Content -Path $playersFile -Value ($script:players.ToArray() | ConvertTo-Json -Depth 2)
}

# Get EditPlayers menu item
$editPlayersMenuItem = $window.FindName("EditPlayers")

# Add click event to EditPlayers to show player management UI
$editPlayersMenuItem.Add_Click({
    # Hide main UI controls
    $mainPanel.Visibility = "Collapsed"
    $nextRoundButton.Visibility = "Collapsed"

    # Create player edit panel
    $playerPanel = New-Object System.Windows.Controls.StackPanel
    $playerPanel.Name = "PlayerPanel"
    $playerPanel.Margin = [System.Windows.Thickness]::new(20)
    $playerPanel.Background = "#222"

    $title = New-Object System.Windows.Controls.Label
    $title.Content = "Edit Players"
    $title.FontSize = 20
    $title.Foreground = "#EEE"
    $title.HorizontalAlignment = "Center"
    $null = $playerPanel.Children.Add($title)

    $playerListView = New-Object System.Windows.Controls.ListView
    $playerListView.Width = 250
    $playerListView.Height = 170
    $playerListView.Margin = [System.Windows.Thickness]::new(0,10,0,10)
    $playerListView.ItemsSource = $script:players
    $gridView = New-Object System.Windows.Controls.GridView
    $playerListView.View = $gridView
    $nameColumn = New-Object System.Windows.Controls.GridViewColumn
    $nameColumn.Header = "Player Name"
    $nameColumn.DisplayMemberBinding = (New-Object System.Windows.Data.Binding "Name")
    $nameColumn.Width = 180
    $gridView.Columns.Add($nameColumn)
    $playingColumn = New-Object System.Windows.Controls.GridViewColumn
    $playingColumn.Header = "Playing"
    $playingTemplate = New-Object System.Windows.DataTemplate
    $factory = New-Object System.Windows.FrameworkElementFactory ([System.Windows.Controls.CheckBox])
    $factory.SetBinding([System.Windows.Controls.CheckBox]::IsCheckedProperty, (New-Object System.Windows.Data.Binding "Playing"))
    $factory.AddHandler([System.Windows.Controls.CheckBox]::CheckedEvent, [System.Windows.RoutedEventHandler]{ Save-PlayersList })
    $factory.AddHandler([System.Windows.Controls.CheckBox]::UncheckedEvent, [System.Windows.RoutedEventHandler]{ Save-PlayersList })
    $playingTemplate.VisualTree = $factory
    $playingColumn.CellTemplate = $playingTemplate
    $gridView.Columns.Add($playingColumn)
    $null = $playerPanel.Children.Add($playerListView)

    $inputPanel = New-Object System.Windows.Controls.StackPanel
    $inputPanel.Orientation = "Horizontal"
    $inputPanel.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $inputPanel.HorizontalAlignment = "Center"
    $playerNameBox = New-Object System.Windows.Controls.TextBox
    $playerNameBox.Width = 120
    $playerNameBox.Margin = [System.Windows.Thickness]::new(0,0,10,0)
    $addPlayerButton = New-Object System.Windows.Controls.Button
    $addPlayerButton.Content = "Add"
    $addPlayerButton.Width = 50
    $addPlayerButton.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent
        $nameBox = $parentPanel.Children[0]
        $name = $nameBox.Text.Trim()
        $playerPanel = $parentPanel.Parent
        $playerListView = $playerPanel.Children[1]
        if ($name -and (-not ($script:players | Where-Object { $_.Name -eq $name }))) {
            $null = $script:players.Add([PSCustomObject]@{ Name = $name; Playing = $false })
            $playerListView.ItemsSource = $null
            $playerListView.ItemsSource = $script:players
            $nameBox.Text = ""
            Save-PlayersList
        }
    })
    $null = $inputPanel.Children.Add($playerNameBox)
    $null = $inputPanel.Children.Add($addPlayerButton)
    $null = $playerPanel.Children.Add($inputPanel)

    $removePlayerButton = New-Object System.Windows.Controls.Button
    $removePlayerButton.Content = "Remove Selected"
    $removePlayerButton.Width = 120
    $removePlayerButton.Margin = [System.Windows.Thickness]::new(0,0,0,10)
    $removePlayerButton.Add_Click({
        param($sourceObj, $e)
        $playerPanel = $sourceObj.Parent
        $playerListView = $playerPanel.Children[1]
        $selected = $playerListView.SelectedItems
        if ($selected -and $selected.Count -gt 0) {
            # Copy to array to avoid modifying collection while iterating
            $toRemove = @($selected)
            foreach ($s in $toRemove) {
                $script:players.Remove($s)
            }
            $playerListView.ItemsSource = $null
            $playerListView.ItemsSource = $script:players
            Save-PlayersList
        }
    })
    $null = $playerPanel.Children.Add($removePlayerButton)

    $doneButton = New-Object System.Windows.Controls.Button
    $doneButton.Content = "Done"
    $doneButton.Width = 80
    $doneButton.Margin = [System.Windows.Thickness]::new(0,10,0,0)
    $doneButton.Add_Click({
        param($sourceObj, $e)
        $playerPanel = $sourceObj.Parent
        $playerPanel.Visibility = "Collapsed"
        $mainPanel.Visibility = "Visible"
        $nextRoundButton.Visibility = "Visible"
    })
    $null = $playerPanel.Children.Add($doneButton)

    $playerNameBox.Add_KeyDown({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent.Parent
        $addPlayerButton = $parentPanel.Children[2].Children[1]
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $addPlayerButton.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        }
    })

    $window.Content.Children.Add($playerPanel)
})

# Get AddPlayers menu item
$addPlayersMenuItem = $window.FindName("AddPlayers")

# Add click event to AddPlayers to add entries to MainPanel for each player in the players list
$addPlayersMenuItem.Add_Click({
    # Remove panels for players whose Playing value is false
    $toRemove = @()
    foreach ($child in $mainPanel.Children) {
        if ($child -is [System.Windows.Controls.Grid]) {
            $nameBox = $child.Children[1]
            $player = $script:players | Where-Object { $_.Name -eq $nameBox.Text }
            if ($player -and -not $player.Playing) {
                $toRemove += $child
            }
        }
    }
    foreach ($panel in $toRemove) {
        $mainPanel.Children.Remove($panel)
    }
    foreach ($player in $script:players) {
        if (-not $player.Playing) { continue }
        # Check if player already exists in MainPanel
        $exists = $false
        foreach ($child in $mainPanel.Children) {
            if ($child -is [System.Windows.Controls.Grid]) {
                $nameBox = $child.Children[1]
                if ($nameBox.Text -eq $player.Name) {
                    $exists = $true
                    break
                }
            }
        }
        if (-not $exists) {
            $newPanel = Add-EncounterPanel "0" $player.Name "" "" ""
            $insertIndex = $mainPanel.Children.Count - 1
            $mainPanel.Children.Insert($insertIndex, $newPanel)
        }
    }
    Set-AlternateShading $mainPanel $script:highlightIndex
})

# Show the window
$window.ShowDialog() | Out-Null
$window.Close()