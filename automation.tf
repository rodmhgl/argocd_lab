#region automation account and permissions
resource "azurerm_automation_account" "aks_automation" {
  name                = "AKS-Lab-Automation"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "sub_contributor" {
  for_each = toset(var.managed_subscription_ids)

  principal_id         = azurerm_automation_account.aks_automation.identity[0].principal_id
  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Contributor"
}
#endregion

#region modules
resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.12.1"
  }
}

resource "azurerm_automation_module" "az_aks" {
  name                    = "Az.Aks"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Aks/5.3.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}
#endregion

#region startup runbook
resource "azurerm_automation_runbook" "start_aks_clusters" {
  name                    = "Start-AKS-Clusters"
  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  automation_account_name = azurerm_automation_account.aks_automation.name
  log_verbose             = true
  log_progress            = true
  description             = "Start AKS clusters based on tags across subscriptions"
  runbook_type            = "PowerShell"

  content = <<-EOT
    param(
      [Parameter(Mandatory = $false)]
      [string[]] $SubscriptionIds = @(${join(", ", formatlist("'%s'", var.managed_subscription_ids))}),
      
      [Parameter(Mandatory = $false)]
      [string] $TagName = "AutoPowerMgmt",
      
      [Parameter(Mandatory = $false)]
      [string] $TagValue = "Enabled",
      
      [Parameter(Mandatory = $false)]
      [string] $LogAnalyticsWorkspaceId = "${azurerm_log_analytics_workspace.this.workspace_id}"
    )

    Write-Output "Starting tagged AKS clusters across subscriptions"
    
    # Connect using managed identity
    try {
        Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "Successfully authenticated using managed identity"
    }
    catch {
        Write-Error ("Failed to authenticate: " + $_)
        throw $_
    }
    
    # Function to write logs to Log Analytics
    function Write-OperationalLog {
        param (
            [string]$Message,
            [string]$ClusterName = "",
            [string]$ResourceGroup = "",
            [string]$SubscriptionId = "",
            [string]$Status = "Info",
            [string]$WorkspaceId = $LogAnalyticsWorkspaceId
        )
        
        if ([string]::IsNullOrEmpty($WorkspaceId)) {
            Write-Output $Message
            return
        }
        
        try {
            $logEntry = @{
                OperationType = "AKS-PowerManagement"
                Action = "Start"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                ClusterName = $ClusterName
                ResourceGroup = $ResourceGroup
                SubscriptionId = $SubscriptionId
                Status = $Status
                Message = $Message
            }
            
            $logJson = ConvertTo-Json $logEntry
            
            # Use REST API to send log to Log Analytics
            $headers = @{
                "Authorization" = "Bearer $((Get-AzAccessToken).Token)"
                "Content-Type" = "application/json"
            }
            
            $uri = "$WorkspaceId/api/logs?api-version=2016-04-01"
            
            Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $logJson
        }
        catch {
            Write-Output ("Failed to write to Log Analytics: " + $_)
            Write-Output $Message
        }
    }
    
    # Process each subscription
    foreach ($subscriptionId in $SubscriptionIds) {
        try {
            Write-Output "Processing subscription: $subscriptionId"
            Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
            
            # Get all AKS clusters with the specified tag
            $clusters = Get-AzAksCluster | Where-Object { 
                $_.Tags -and $_.Tags.ContainsKey($TagName) -and $_.Tags[$TagName] -eq $TagValue 
            }
            
            Write-Output "Found $($clusters.Count) clusters to start in subscription $subscriptionId"
            
            # Start each tagged cluster
            foreach ($cluster in $clusters) {
                try {
                    Write-Output "Starting cluster: $($cluster.Name) in resource group: $($cluster.ResourceGroupName)"
                    Start-AzAksCluster -ResourceGroupName $cluster.ResourceGroupName -Name $cluster.Name -ErrorAction Stop
                    Write-OperationalLog -Message "Successfully initiated startup" -ClusterName $cluster.Name -ResourceGroup $cluster.ResourceGroupName -SubscriptionId $subscriptionId -Status "Success"
                }
                catch {
                    $errorMsg = "Failed to start cluster $($cluster.Name): " + $_
                    Write-Error $errorMsg
                    Write-OperationalLog -Message $errorMsg -ClusterName $cluster.Name -ResourceGroup $cluster.ResourceGroupName -SubscriptionId $subscriptionId -Status "Error"
                }
            }
        }
        catch {
            Write-Error ("Error processing subscription " + $subscriptionId + ": " + $_)
            Write-OperationalLog -Message ("Error processing subscription: " + $_) -SubscriptionId $subscriptionId -Status "Error"
        }
    }
    
    Write-Output "AKS cluster startup operations completed"
  EOT
}
#endregion

#region shutdown runbook
resource "azurerm_automation_runbook" "stop_aks_clusters" {
  name                    = "Stop-AKS-Clusters"
  resource_group_name     = azurerm_resource_group.this.name
  location                = azurerm_resource_group.this.location
  automation_account_name = azurerm_automation_account.aks_automation.name
  log_verbose             = true
  log_progress            = true
  description             = "Stop AKS clusters based on tags across subscriptions"
  runbook_type            = "PowerShell"

  content = <<-EOT
    param(
      [Parameter(Mandatory = $false)]
      [string[]] $SubscriptionIds = @(${join(", ", formatlist("'%s'", var.managed_subscription_ids))}),
      
      [Parameter(Mandatory = $false)]
      [string] $TagName = "AutoPowerMgmt",
      
      [Parameter(Mandatory = $false)]
      [string] $TagValue = "Enabled",
      
      [Parameter(Mandatory = $false)]
      [string] $LogAnalyticsWorkspaceId = "${azurerm_log_analytics_workspace.this.workspace_id}"
    )

    Write-Output "Stopping tagged AKS clusters across subscriptions"
    
    # Connect using managed identity
    try {
        Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "Successfully authenticated using managed identity"
    }
    catch {
        Write-Error ("Failed to authenticate: " + $_)
        throw $_
    }
    
    # Function to write logs to Log Analytics
    function Write-OperationalLog {
        param (
            [string]$Message,
            [string]$ClusterName = "",
            [string]$ResourceGroup = "",
            [string]$SubscriptionId = "",
            [string]$Status = "Info",
            [string]$WorkspaceId = $LogAnalyticsWorkspaceId
        )
        
        if ([string]::IsNullOrEmpty($WorkspaceId)) {
            Write-Output $Message
            return
        }
        
        try {
            $logEntry = @{
                OperationType = "AKS-PowerManagement"
                Action = "Stop"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                ClusterName = $ClusterName
                ResourceGroup = $ResourceGroup
                SubscriptionId = $SubscriptionId
                Status = $Status
                Message = $Message
            }
            
            $logJson = ConvertTo-Json $logEntry
            
            # Use REST API to send log to Log Analytics
            $headers = @{
                "Authorization" = "Bearer $((Get-AzAccessToken).Token)"
                "Content-Type" = "application/json"
            }
            
            $uri = "$WorkspaceId/api/logs?api-version=2016-04-01"
            
            Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $logJson
        }
        catch {
            Write-Output ("Failed to write to Log Analytics: " + $_)
            Write-Output $Message
        }
    }
    
    # Process each subscription
    foreach ($subscriptionId in $SubscriptionIds) {
        try {
            Write-Output "Processing subscription: $subscriptionId"
            Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
            
            # Get all AKS clusters with the specified tag
            $clusters = Get-AzAksCluster | Where-Object { 
                $_.Tags -and $_.Tags.ContainsKey($TagName) -and $_.Tags[$TagName] -eq $TagValue 
            }
            
            Write-Output "Found $($clusters.Count) clusters to stop in subscription $subscriptionId"
            
            # Stop each tagged cluster
            foreach ($cluster in $clusters) {
                try {
                    Write-Output "Stopping cluster: $($cluster.Name) in resource group: $($cluster.ResourceGroupName)"
                    Stop-AzAksCluster -ResourceGroupName $cluster.ResourceGroupName -Name $cluster.Name -ErrorAction Stop
                    Write-OperationalLog -Message "Successfully initiated shutdown" -ClusterName $cluster.Name -ResourceGroup $cluster.ResourceGroupName -SubscriptionId $subscriptionId -Status "Success"
                }
                catch {
                    $errorMsg = "Failed to stop cluster $($cluster.Name): " + $_
                    Write-Error $errorMsg
                    Write-OperationalLog -Message $errorMsg -ClusterName $cluster.Name -ResourceGroup $cluster.ResourceGroupName -SubscriptionId $subscriptionId -Status "Error"
                }
            }
        }
        catch {
            Write-Error ("Error processing subscription " + $subscriptionId + ": " + $_)
            Write-OperationalLog -Message ("Error processing subscription: " + $_) -SubscriptionId $subscriptionId -Status "Error"
        }
    }
    
    Write-Output "AKS cluster shutdown operations completed"
  EOT
}
#endregion

#region scheduling
resource "azurerm_automation_schedule" "morning_startup" {
  name                    = "Morning-Startup-Schedule"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Chicago"
  description             = "Schedule for starting AKS clusters"
}

resource "azurerm_automation_schedule" "evening_shutdown" {
  name                    = "Evening-Shutdown-Schedule"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Chicago"
  description             = "Schedule for stopping AKS clusters"
}

resource "azurerm_automation_job_schedule" "morning_startup_job" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name
  schedule_name           = azurerm_automation_schedule.morning_startup.name
  runbook_name            = azurerm_automation_runbook.start_aks_clusters.name
}

resource "azurerm_automation_job_schedule" "evening_shutdown_job" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.aks_automation.name
  schedule_name           = azurerm_automation_schedule.evening_shutdown.name
  runbook_name            = azurerm_automation_runbook.stop_aks_clusters.name
}
#endregion

#region monitoring and alerting
resource "azurerm_monitor_diagnostic_setting" "automation_logs" {
  name                       = "automation-logs"
  target_resource_id         = azurerm_automation_account.aks_automation.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "JobLogs"
  }

  enabled_log {
    category = "JobStreams"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_action_group" "aks_ops" {
  name                = "aks-ops-team"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "aksops"

  email_receiver {
    name          = "ops-team"
    email_address = "admin@kube-playground.io" # Replace with your email
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "failed_job_alert" {
  name                = "aks-automation-failed-job"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  action {
    action_group = [azurerm_monitor_action_group.aks_ops.id]
  }

  data_source_id = azurerm_log_analytics_workspace.this.id
  description    = "Alert when an AKS automation job fails"
  enabled        = true

  query       = <<-QUERY
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.AUTOMATION" 
    | where Category == "JobLogs" 
    | where ResultType == "Failed"
    | where RunbookName_s in ("Start-All-AKS-Clusters", "Stop-All-AKS-Clusters")
  QUERY
  severity    = 1
  frequency   = 5
  time_window = 5

  trigger {
    operator  = "GreaterThan"
    threshold = 0
  }
}
#endregion
