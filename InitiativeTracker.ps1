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
$initiativeListPanel = $window.FindName("InitiativeListPanel")

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
    foreach ($col in $panel.Children) {
        foreach ($child in $col.Children) {
            if ($child -is [System.Windows.Controls.Grid]) {
                $grids += $child
            }
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
    foreach ($col in $panel.Children) {
        foreach ($child in $col.Children) {
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
}

# Player data structure definition
function New-Player {
    param(
        [string]$Name,
        [bool]$Playing = $false
    )
    return [PSCustomObject]@{
        Name = $Name
        Playing = $Playing
    }
}

# Create and return a new encounter panel
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
    $conditionsPanel = New-Object System.Windows.Controls.StackPanel
    $conditionsPanel.Orientation = "Vertical"
    $conditionsPanel.MinWidth = 50
    $appliedLabel = New-Object System.Windows.Controls.Label
    $appliedLabel.Content = $conditions
    $appliedLabel.FontSize = 14
    $appliedLabel.Foreground = "#AAA"
    $appliedLabel.Margin = [System.Windows.Thickness]::new(0,2,0,6)
    $appliedLabel.HorizontalAlignment = "Left"
    $appliedLabel.Visibility = [System.Windows.Visibility]::Visible
    $null = $conditionsPanel.Children.Add($appliedLabel)
    [System.Windows.Controls.Grid]::SetColumn($conditionsPanel, 3)

    $null = $newPanel.Children.Add($initiativePanel)
    $null = $newPanel.Children.Add($characterNameBox)
    $null = $newPanel.Children.Add($hpPanel)
    $null = $newPanel.Children.Add($conditionsPanel)

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
            # Remove from the correct column in the InitiativeListPanel
            foreach ($col in $initiativeListPanel.Children) {
                if ($col -is [System.Windows.Controls.StackPanel] -and $col.Children.Contains($parentPanel)) {
                    $col.Children.Remove($parentPanel)
                    break
                }
            }
            Set-AlternateShading $initiativeListPanel $script:highlightIndex
            Resize-WindowToFitContent
        }
    })
    $null = $contextMenu.Items.Add($removeMenuItem)

    # Add Edit Conditions menu item
    $editConditionsMenuItem = New-Object System.Windows.Controls.MenuItem
    $editConditionsMenuItem.Header = "Edit Conditions"
    $editConditionsMenuItem.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent.PlacementTarget
        # Hide the initiative panel while editing conditions
        $mainPanel.Visibility = "Collapsed"
        $editConditionsPanel = New-Object System.Windows.Controls.StackPanel
        $editConditionsPanel.Margin = [System.Windows.Thickness]::new(20)
        $editConditionsPanel.Background = "#222"
        $title = New-Object System.Windows.Controls.Label
        $title.Content = "Edit Conditions"
        $title.FontSize = 18
        $title.Foreground = "#EEE"
        $title.HorizontalAlignment = "Center"
        $null = $editConditionsPanel.Children.Add($title)
        $currentConditions = $parentPanel.Children[3].Children[0].Content -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        # Create a grid with 3 columns for checkboxes
        $checkboxGrid = New-Object System.Windows.Controls.Grid
        for ($i = 0; $i -lt 3; $i++) {
            $col = New-Object System.Windows.Controls.ColumnDefinition
            $col.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $checkboxGrid.ColumnDefinitions.Add($col)
        }
        $toggles = @()
        $conditionsPerCol = [math]::Ceiling($conditions.Count / 3)
        for ($colIdx = 0; $colIdx -lt 3; $colIdx++) {
            $stack = New-Object System.Windows.Controls.StackPanel
            $stack.Orientation = "Vertical"
            $stack.HorizontalAlignment = "Center"
            $startIdx = $colIdx * $conditionsPerCol
            $endIdx = [math]::Min($startIdx + $conditionsPerCol, $conditions.Count)
            for ($i = $startIdx; $i -lt $endIdx; $i++) {
                $cond = $conditions[$i]
                $cb = New-Object System.Windows.Controls.CheckBox
                $condName = $cond
                $condDesc = $null
                if ($cond -is [PSCustomObject] -or $cond -is [System.Collections.IDictionary]) {
                    if ($cond.PSObject.Properties["Name"]) {
                        $condName = $cond.Name
                    }
                    if ($cond.PSObject.Properties["Description"]) {
                        $condDesc = $cond.Description
                    }
                }
                $cb.Content = $condName
                if ($condDesc) { $cb.ToolTip = $condDesc }
                $cb.IsChecked = $currentConditions -contains $condName
                $cb.Margin = [System.Windows.Thickness]::new(0,2,0,2)
                $null = $stack.Children.Add($cb)
                $toggles += $cb
            }
            [System.Windows.Controls.Grid]::SetColumn($stack, $colIdx)
            $checkboxGrid.Children.Add($stack)
        }
        $editConditionsPanel.Children.Add($checkboxGrid)
        $editConditionsPanel.Tag = @{ Toggles = $toggles; ParentPanel = $parentPanel }
        $doneBtn = New-Object System.Windows.Controls.Button
        $doneBtn.Content = "Done"
        $doneBtn.Width = 80
        $doneBtn.Margin = [System.Windows.Thickness]::new(0,10,0,0)
        $doneBtn.HorizontalAlignment = "Center"
        $doneBtn.Add_Click({
            param($sourceObj, $e)
            $editConditionsPanel = $sourceObj.Parent
            $tag = $editConditionsPanel.Tag
            $toggles = $tag.Toggles
            $parentPanel = $tag.ParentPanel
            $selected = $toggles | Where-Object { $_.IsChecked } | ForEach-Object { $_.Content }
            if ($parentPanel -and $parentPanel.Children.Count -ge 4 -and $parentPanel.Children[3].Children.Count -ge 1) {
                # Use the appliedConditions label (already created as Children[0] in conditionsPanel)
                $appliedConditionsLabel = $parentPanel.Children[3].Children[0]
                $appliedConditionsLabel.Content = ($selected -join ', ')
                $parentPanel.Tag = $selected # Save conditions array in Tag property for this panel
            }
            if ($editConditionsPanel -and $editConditionsPanel.PSObject.Properties["Visibility"]) {
                $editConditionsPanel.Visibility = "Collapsed"
            } elseif ($editConditionsPanel -is [System.Windows.UIElement]) {
                $editConditionsPanel.SetValue([System.Windows.UIElement]::VisibilityProperty, [System.Windows.Visibility]::Collapsed)
            }
            
            # Show the main panel again
            if ($mainPanel -and $mainPanel.PSObject.Properties["Visibility"]) {
                $mainPanel.Visibility = "Visible"
            } elseif ($mainPanel -is [System.Windows.UIElement]) {
                $mainPanel.SetValue([System.Windows.UIElement]::VisibilityProperty, [System.Windows.Visibility]::Visible)
            }
            $nextRoundButton.Visibility = "Visible"
        })
        $null = $editConditionsPanel.Children.Add($doneBtn)
        $window.Content.Children.Add($editConditionsPanel)
    })
    $null = $contextMenu.Items.Add($editConditionsMenuItem)
    # Add Roll HD menu item
    $rollHdMenuItem = New-Object System.Windows.Controls.MenuItem
    $rollHdMenuItem.Header = "Roll Hit Dice"
    $rollHdMenuItem.Add_Click({
        param($sourceObj, $e)
        $parentPanel = $sourceObj.Parent.PlacementTarget
        # Find the column and index of the panel in initiativeListPanel
        $panelIndex = -1
        $colIndex = -1
        for ($c = 0; $c -lt $initiativeListPanel.Children.Count; $c++) {
            $col = $initiativeListPanel.Children[$c]
            if ($col -is [System.Windows.Controls.StackPanel]) {
                for ($i = 0; $i -lt $col.Children.Count; $i++) {
                    if ($col.Children[$i] -eq $parentPanel) {
                        $panelIndex = $i
                        $colIndex = $c
                        break
                    }
                }
            }
            if ($panelIndex -ne -1) { break }
        }
        # Create pop-out window
        $rollWindow = New-Object System.Windows.Window
        $rollWindow.Title = "Roll Hit Dice"
        $rollWindow.SizeToContent = "widthAndHeight"
        $rollWindow.WindowStartupLocation = "CenterScreen"
        $rollWindow.Background = [System.Windows.Media.Brushes]::Black
        $rollPanel = New-Object System.Windows.Controls.StackPanel
        $rollPanel.Margin = [System.Windows.Thickness]::new(20)
        $rollPanel.Background = "#222"
        # NumDice
        $numDiceLabel = New-Object System.Windows.Controls.Label
        $numDiceLabel.Content = "Number of Dice:"
        $numDiceLabel.Foreground = "#EEE"
        $numDiceBox = New-Object System.Windows.Controls.TextBox
        $numDiceBox.Width = 60
        $numDiceBox.Text = "1"
        $numDiceBox.Margin = [System.Windows.Thickness]::new(0,0,0,10)
        $numDiceBox.Background = "#333"
        $numDiceBox.Foreground = "#EEE"
        $numDiceBox.BorderBrush = "#555"
        $numDiceBox.Add_PreviewTextInput({
            param($src, $evt)
            if ($evt.Text -notmatch '^[0-9]$') {
                $evt.Handled = $true
            }
        })
        $numDiceBox.Add_TextChanged({
            param($src, $evt)
            $text = $src.Text -replace '[^0-9]', ''
            if ($src.Text -ne $text) {
                $src.Text = $text
                $src.SelectionStart = $src.Text.Length
            }
        })
        # DiceSides
        $diceSidesLabel = New-Object System.Windows.Controls.Label
        $diceSidesLabel.Content = "Dice Sides:"
        $diceSidesLabel.Foreground = "#EEE"
        $diceSidesCombo = New-Object System.Windows.Controls.ComboBox
        $diceSidesCombo.Width = 80
        $diceSidesCombo.Margin = [System.Windows.Thickness]::new(0,0,0,10)
        $diceSidesCombo.Background = "#333"
        $diceSidesCombo.Foreground = "#333"
        $diceSidesCombo.BorderBrush = "#555"
        $diceOptions = @(4, 6, 8, 10, 12, 20)
        foreach ($opt in $diceOptions) { $null = $diceSidesCombo.Items.Add($opt) }
        $diceSidesCombo.SelectedIndex = 1 # Default to d6
        # Modifier
        $modifierLabel = New-Object System.Windows.Controls.Label
        $modifierLabel.Content = "Modifier:"
        $modifierLabel.Foreground = "#EEE"
        $modifierBox = New-Object System.Windows.Controls.TextBox
        $modifierBox.Width = 60
        $modifierBox.Text = "0"
        $modifierBox.Margin = [System.Windows.Thickness]::new(0,0,0,10)
        $modifierBox.Background = "#333"
        $modifierBox.Foreground = "#EEE"
        $modifierBox.BorderBrush = "#555"
        # Roll Button
        $rollButton = New-Object System.Windows.Controls.Button
        $rollButton.Content = "Roll"
        $rollButton.Width = 80
        $rollButton.Margin = [System.Windows.Thickness]::new(0,10,0,0)
        $rollButton.HorizontalAlignment = "Center"
        $rollButton.Background = "#5555FF"
        $rollButton.Foreground = "#EEE"
        $rollButton.BorderBrush = "#222"
        $rollButton.Tag = @{ ColIndex = $colIndex; PanelIndex = $panelIndex }
        $rollButton.Add_Click({
            param($src, $evt)
            $numDice = 1
            $diceSides = 6
            $modifier = 0
            if ($numDiceBox.Text -match '^[0-9]+$') { $numDice = [int]$numDiceBox.Text }
            if ($diceSidesCombo.SelectedItem) { $diceSides = [int]$diceSidesCombo.SelectedItem }
            if ($modifierBox.Text -match '^-?[0-9]+$') { $modifier = [int]$modifierBox.Text }
            $rolls = @()
            for ($i = 0; $i -lt $numDice; $i++) {
                $rolls += (Get-Random -Minimum 1 -Maximum ($diceSides + 1))
            }
            $total = ($rolls | Measure-Object -Sum).Sum + $modifier
            $msg = "Rolls: " + ($rolls -join ', ') + "`nModifier: $modifier`nTotal: $total"
            [System.Windows.MessageBox]::Show($msg, "Roll Result")
            # Use the passed index to update the correct panel
            $tag = $src.Tag
            if ($tag -and $tag.ColIndex -ge 0 -and $tag.PanelIndex -ge 0) {
                $col = $initiativeListPanel.Children[$tag.ColIndex]
                $panel = $col.Children[$tag.PanelIndex]
                if ($panel -and $panel.Children.Count -ge 3) {
                    $hpPanel = $panel.Children[2]
                    if ($hpPanel.Children.Count -ge 3) {
                        $currentHpPanel = $hpPanel.Children[0]
                        $totalHpPanel = $hpPanel.Children[2]
                        if (($totalHpPanel.Children.Count -ge 2) -and ($currentHpPanel.Children.Count -ge 2)) {
                            $currentHpBox = $currentHpPanel.Children[1]
                            $totalHpBox = $totalHpPanel.Children[1]
                            $currentHpBox.Text = $total.ToString()
                            $totalHpBox.Text = $total.ToString()
                        }
                    }
                }
            }
            # Hide the rollWindow after updating
            $rollWindow.Hide()
        })
        $null = $rollPanel.Children.Add($numDiceLabel)
        $null = $rollPanel.Children.Add($numDiceBox)
        $null = $rollPanel.Children.Add($diceSidesLabel)
        $null = $rollPanel.Children.Add($diceSidesCombo)
        $null = $rollPanel.Children.Add($modifierLabel)
        $null = $rollPanel.Children.Add($modifierBox)
        $null = $rollPanel.Children.Add($rollButton)
        $rollWindow.Content = $rollPanel
        $rollWindow.ShowDialog() | Out-Null
    })
    $null = $contextMenu.Items.Add($rollHdMenuItem)
    $newPanel.ContextMenu = $contextMenu

    return $newPanel
}

# After adding or removing panels, resize the window to fit all elements
function Resize-WindowToFitContent {
    $window.Dispatcher.Invoke([action]{
        $window.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $window.UpdateLayout()
        # Get screen working area
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        # Limit window height to screen height minus 100
        $maxHeight = $screen.Height - 100
        if ($window.ActualHeight -gt $maxHeight) {
            $window.Height = $maxHeight
            $window.SizeToContent = [System.Windows.SizeToContent]::Manual
        }
        # Limit window width to screen width minus 100
        $maxWidth = $screen.Width - 100
        if ($window.ActualWidth -gt $maxWidth) {
            $window.Width = $maxWidth
            $window.SizeToContent = [System.Windows.SizeToContent]::Manual
        }
    })
}

# Helper function to ensure MainPanel uses a horizontal StackPanel and adds columns as needed
function Add-PanelToMainPanel {
    param($panel)
    # Ensure initiativeListPanel is a horizontal StackPanel
    if ($initiativeListPanel.Orientation -ne "Horizontal") {
        $initiativeListPanel.Orientation = "Horizontal"
    }
    # If there are no columns yet, create the first column
    if ($initiativeListPanel.Children.Count -eq 0) {
        $firstCol = New-Object System.Windows.Controls.StackPanel
        $firstCol.Orientation = "Vertical"
        $initiativeListPanel.Children.Add($firstCol)
    }
    $totalPanels = 0
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            $totalPanels += $col.Children.Count
        }
    }
    $targetColIdx = [math]::Floor($totalPanels / 10)
    while ($initiativeListPanel.Children.Count -le $targetColIdx) {
        $newCol = New-Object System.Windows.Controls.StackPanel
        $newCol.Orientation = "Vertical"
        $initiativeListPanel.Children.Add($newCol)
    }
    $targetCol = $initiativeListPanel.Children[$targetColIdx]
    $targetCol.Children.Add($panel)
}

# Add the click event handler
$insertButton.Add_Click({
    $newPanel = Add-EncounterPanel
    Add-PanelToMainPanel $newPanel
    Set-AlternateShading $initiativeListPanel $script:highlightIndex
    Resize-WindowToFitContent
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

# Update sort functions to work with InitiativeListPanel columns
$sortAscMenuItem.Add_Click({
    $panels = @()
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            foreach ($child in $col.Children) {
                if ($child -is [System.Windows.Controls.Grid]) {
                    $panels += $child
                }
            }
        }
    }
    $sortedPanels = $panels | Sort-Object {
        $initiativePanel = $_.Children[0]
        $initiativeValue = $initiativePanel.Children[1]
        [float]$initiativeValue.Text
    }
    # Remove all panels from columns
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            $col.Children.Clear()
        }
    }
    # Re-add sorted panels to columns of 10
    for ($i = 0; $i -lt $sortedPanels.Count; $i++) {
        $colIdx = [math]::Floor($i / 10)
        while ($initiativeListPanel.Children.Count -le $colIdx) {
            $newCol = New-Object System.Windows.Controls.StackPanel
            $newCol.Orientation = "Vertical"
            $initiativeListPanel.Children.Add($newCol)
        }
        $initiativeListPanel.Children[$colIdx].Children.Add($sortedPanels[$i])
    }
    Set-AlternateShading $initiativeListPanel $script:highlightIndex
})

# Add click event to SortDescMenuItem to sort MainPanel children by initiativeValue (descending)
$sortDescMenuItem.Add_Click({
    $panels = @()
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            foreach ($child in $col.Children) {
                if ($child -is [System.Windows.Controls.Grid]) {
                    $panels += $child
                }
            }
        }
    }
    $sortedPanels = $panels | Sort-Object {
        $initiativePanel = $_.Children[0]
        $initiativeValue = $initiativePanel.Children[1]
        -[float]$initiativeValue.Text
    }
    # Remove all panels from columns
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            $col.Children.Clear()
        }
    }
    # Re-add sorted panels to columns of 10
    for ($i = 0; $i -lt $sortedPanels.Count; $i++) {
        $colIdx = [math]::Floor($i / 10)
        while ($initiativeListPanel.Children.Count -le $colIdx) {
            $newCol = New-Object System.Windows.Controls.StackPanel
            $newCol.Orientation = "Vertical"
            $initiativeListPanel.Children.Add($newCol)
        }
        $initiativeListPanel.Children[$colIdx].Children.Add($sortedPanels[$i])
    }
    Set-AlternateShading $initiativeListPanel $script:highlightIndex
})

# Add click event to NextRoundButton to highlight the next item in MainPanel
$nextRoundButton = $window.FindName("NextRoundButton")
$nextRoundButton.Add_Click({
    Update-HighlightIndex $initiativeListPanel
    Set-AlternateShading $initiativeListPanel $script:highlightIndex
})

# Get the ExportMenuItem from XAML
$exportMenuItem = $window.FindName("ExportMenuItem")

# Update export to work with InitiativeListPanel columns
$exportMenuItem.Add_Click({
    $encounter = @()
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            foreach ($child in $col.Children) {
                if ($child -is [System.Windows.Controls.Grid]) {
                    $initiative = $child.Children[0].Children[1].Text
                    $name = $child.Children[1].Text
                    $currentHp = $child.Children[2].Children[0].Children[1].Text
                    $totalHp = $child.Children[2].Children[2].Children[1].Text
                    $appliedLabel = $child.Children[3].Children[0]
                    $conditions = $appliedLabel.Content
                    $encounter += [PSCustomObject]@{
                        Initiative = $initiative
                        Name = $name
                        CurrentHP = $currentHp
                        TotalHP = $totalHp
                        Conditions = $conditions
                    }
                }
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
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "JSON files (*.json)|*.json"
    $openFileDialog.InitialDirectory = "$PSScriptRoot/encounters"
    $openFileDialog.Title = "Import Encounter"
    [void]$openFileDialog.ShowDialog()
    $filePath = $openFileDialog.FileName
    if (![string]::IsNullOrWhiteSpace($filePath) -and (Test-Path $filePath)) {
        $json = Get-Content $filePath -Raw
        $importData = ConvertFrom-Json $json
        $encounter = $importData.Encounter
        $script:highlightIndex = $importData.HighlightIndex
        # Remove all panels from columns
        foreach ($col in $initiativeListPanel.Children) {
            if ($col -is [System.Windows.Controls.StackPanel]) {
                $col.Children.Clear()
            }
        }
        # Re-add imported panels to columns of 10
        for ($i = 0; $i -lt $encounter.Count; $i++) {
            $entry = $encounter[$i]
            $newPanel = Add-EncounterPanel $entry.Initiative $entry.Name $entry.Conditions $entry.CurrentHP $entry.TotalHP
            $colIdx = [math]::Floor($i / 10)
            while ($initiativeListPanel.Children.Count -le $colIdx) {
                $newCol = New-Object System.Windows.Controls.StackPanel
                $newCol.Orientation = "Vertical"
                $initiativeListPanel.Children.Add($newCol)
            }
            $initiativeListPanel.Children[$colIdx].Children.Add($newPanel)
        }
        Set-AlternateShading $initiativeListPanel $script:highlightIndex
        Resize-WindowToFitContent
    }
})

# Players list storage and persistence
$playersFile = Join-Path $PSScriptRoot 'players\player_cache.json'
if (Test-Path $playersFile) {
    try {
        $loadedPlayers = Get-Content $playersFile -Raw | ConvertFrom-Json
        $script:players = New-Object System.Collections.ArrayList
        foreach ($p in $loadedPlayers) {
            $conditionsArr = @()
            if ($p.PSObject.Properties["Conditions"]) {
                $conditionsArr = $p.Conditions
            }
            if ($p -is [string]) {
                $null = $script:players.Add((New-Player -Name $p))
            } elseif ($p.PSObject.Properties["Name"] -and $p.PSObject.Properties["Playing"]) {
                $null = $script:players.Add((New-Player -Name $p.Name -Playing $p.Playing -Conditions $conditionsArr))
            } else {
                $null = $script:players.Add((New-Player -Name $p))
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
    $playerListView.MinHeight = 170
    $playerListView.MaxHeight = 400
    $playerListView.Margin = [System.Windows.Thickness]::new(0,10,0,10)
    $playerListView.ItemsSource = $script:players
    $playerListView.VerticalAlignment = "Top"
    $playerListView.SetValue([System.Windows.Controls.ListView]::HeightProperty, [double]::NaN)
    Resize-WindowToFitContent
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
            $null = $script:players.Add((New-Player -Name $name))
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

# Add click event to AddPlayers to add entries to InitiativeListPanel for each player in the players list
$addPlayersMenuItem.Add_Click({
    # Remove panels for players whose Playing value is false
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            $toRemove = @()
            foreach ($panel in $col.Children) {
                if ($panel -is [System.Windows.Controls.Grid]) {
                    $nameBox = $panel.Children[1]
                    $player = $script:players | Where-Object { $_.Name -eq $nameBox.Text }
                    if ($player -and -not $player.Playing) {
                        $toRemove += $panel
                    }
                }
            }
            foreach ($panel in $toRemove) {
                $col.Children.Remove($panel)
            }
        }
    }
    # Add panels for players whose Playing value is true and not already present
    $existingNames = @()
    foreach ($col in $initiativeListPanel.Children) {
        if ($col -is [System.Windows.Controls.StackPanel]) {
            foreach ($panel in $col.Children) {
                if ($panel -is [System.Windows.Controls.Grid]) {
                    $nameBox = $panel.Children[1]
                    $existingNames += $nameBox.Text
                }
            }
        }
    }
    foreach ($player in $script:players) {
        if (-not $player.Playing) { continue }
        if ($existingNames -contains $player.Name) { continue }
        $newPanel = Add-EncounterPanel "0" $player.Name "" "" ""
        Add-PanelToMainPanel $newPanel
    }
    Set-AlternateShading $initiativeListPanel $script:highlightIndex
    Resize-WindowToFitContent
})

# Show the window
$window.ShowDialog() | Out-Null
$window.Close()