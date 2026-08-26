@{
    RootModule           = 'DmsProvisioning.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'f2a7c9d4-5b81-4e63-9a0f-7c3d8e1b6a24'
    Author               = 'DMS Platform Team'
    CompanyName          = 'REQUIRES_STAKEHOLDER_DECISION'
    Copyright            = 'Internal use'
    Description          = 'Provisioning, validation and lifecycle-rule engine for the Microsoft 365 SharePoint Document Management System. Pure rule functions have no tenant dependency and are unit testable offline; tenant-facing functions are separated and guarded.'
    PowerShellVersion    = '7.2'

    # PRD ADM-007: PnP PowerShell is a community-led managed dependency. It is declared here with a
    # pinned minimum version rather than assumed. Support ownership is defined in docs/SUPPORT_MODEL.md.
    # It is intentionally NOT a hard RequiredModules entry so that offline validation, schema checks
    # and the entire rule engine run in environments where PnP is not installed.
    RequiredModules      = @()

    FunctionsToExport    = @(
        'Get-DmsConfiguration',
        'Test-DmsConfiguration',
        'Test-DmsLifecycleTransition',
        'Get-DmsLifecycleTransition',
        'Resolve-DmsRoutingRule',
        'Get-DmsNextReviewDate',
        'Get-DmsReviewReminderSchedule',
        'Test-DmsDocumentId',
        'New-DmsCorrelationId',
        'Test-DmsEffectiveRevisionUniqueness',
        'Test-DmsControlCompleteness',
        'Test-DmsApprovalIntegrity',
        'Get-DmsBusinessDayOffset',
        'Write-DmsLog',
        'New-DmsPlan',
        'Add-DmsPlanAction',
        'Format-DmsPlan',
        'Test-DmsProductionGuard',
        'Invoke-DmsWithRetry',
        'Test-DmsPnPCmdletUsage',
        'Get-DmsRequiredApiPermission',
        'Test-DmsProperty',
        'Get-DmsPropertyOrDefault',
        'Get-DmsRepositoryRoot',
        'Protect-DmsSensitiveText',
        'Read-DmsJsonFile'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('SharePoint','DMS','Purview','PowerPlatform','Provisioning')
            ProjectUri   = ''
            ReleaseNotes = 'Initial implementation scaffold traced to SharePoint_DMS_PRD.md.'
        }
        DependencyRegister = @{
            # PRD ADM-007 dependency register with pinned versions.
            'PnP.PowerShell'                       = @{ MinimumVersion = '2.12.0'; Support = 'Community-led (PnP). Organisational support owner defined in docs/SUPPORT_MODEL.md.'; Purpose = 'SharePoint provisioning and configuration.' }
            'Microsoft.Online.SharePoint.PowerShell'= @{ MinimumVersion = '16.0.24810.12000'; Support = 'Microsoft'; Purpose = 'Tenant-level SharePoint administration.' }
            'ExchangeOnlineManagement'             = @{ MinimumVersion = '3.4.0'; Support = 'Microsoft'; Purpose = 'Security and Compliance PowerShell for Purview retention configuration.' }
            'Microsoft.Graph.Authentication'       = @{ MinimumVersion = '2.19.0'; Support = 'Microsoft'; Purpose = 'Graph access for Entra group and identity discovery.' }
            'Pester'                               = @{ MinimumVersion = '5.5.0'; Support = 'Community'; Purpose = 'Test framework.' }
        }
    }
}
