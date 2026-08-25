#Requires -Version 7.2
<#
    Provisioning, configuration and safety tests.

    These verify the deployment machinery itself: that Plan never mutates, that reruns are
    idempotent, that safety gates hold, and that the scripts do not reference cmdlets or parameters
    that do not exist.
#>
BeforeDiscovery {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $ConfigFiles = @(Get-ChildItem (Join-Path $repo 'config') -Filter '*.json' -File |
                     Where-Object { $_.Name -notlike '*.schema.json' } | ForEach-Object { $_.Name })
    $RequiredDocs = @(
        'ARCHITECTURE.md','ARCHITECTURE_DECISIONS.md','BUILD_STATUS.md','OPEN_DECISIONS.md',
        'REQUIREMENTS_TRACEABILITY.md','DATA_DICTIONARY.md','STATE_MODEL.md','SECURITY_MODEL.md',
        'PURVIEW_DESIGN.md','POWER_AUTOMATE_DESIGN.md','MIGRATION_PLAN.md','TEST_STRATEGY.md',
        'DEPLOYMENT_RUNBOOK.md','OPERATIONS_RUNBOOK.md','BACKUP_RECOVERY_PLAN.md','SUPPORT_MODEL.md'
    )
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    Import-Module (Join-Path $RepoRoot 'src/modules/DmsProvisioning/DmsProvisioning.psd1') -Force
    $script:Config = Get-DmsConfiguration -Environment dev
}

Describe 'Configuration integrity (PRD NFR-019)' {

    It 'parses <_> as valid JSON' -ForEach $ConfigFiles {
        { Get-Content (Join-Path $RepoRoot 'config' $_) -Raw | ConvertFrom-Json -Depth 40 } | Should -Not -Throw
    }

    It 'passes the full validation gate with no failures' {
        $r = Test-DmsConfiguration -Configuration $Config
        $r.IsValid     | Should -BeTrue -Because ($r.Failures -join ' | ')
        $r.FailedCount | Should -Be 0
    }

    It 'declares a unique internal name for every site column' {
        $names = @($Config.SiteColumns.columns | ForEach-Object { $_.internalName })
        ($names | Sort-Object -Unique).Count | Should -Be $names.Count
    }

    It 'prefixes every site column with Dms so it cannot collide with a built-in field' {
        foreach ($c in $Config.SiteColumns.columns) { $c.internalName | Should -Match '^Dms' }
    }

    It 'keeps indexed columns within the platform budget for every library' {
        $budget = $Config.SiteColumns.indexingBudget.maxIndexedColumnsPerList
        foreach ($lib in $Config.Libraries.libraries) {
            $idx = @(Get-DmsPropertyOrDefault -InputObject $lib -Name 'indexedColumns' -Default @())
            $idx.Count | Should -BeLessOrEqual $budget -Because "library $($lib.key) would exceed the indexed-column limit"
        }
    }

    It 'derives every content type id from its declared parent' {
        foreach ($ct in $Config.ContentTypes.contentTypes) {
            $ct.id | Should -BeLike "$($ct.parentId)*"
        }
    }

    It 'gives every metric a formula, source, owner and target' {
        foreach ($m in $Config.Metrics.metrics) {
            $m.formula | Should -Not -BeNullOrEmpty
            $m.sources | Should -Not -BeNullOrEmpty
            $m.owner   | Should -Not -BeNullOrEmpty
            $m.target  | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Retention safety gate (PRD F-018, SEC-012, R-03, R-06)' {

    It 'invents no retention period' {
        foreach ($rc in $Config.RetentionMap.retentionClasses) {
            $rc.period | Should -Be 'REQUIRES_RECORDS_APPROVAL' -Because 'a legal retention period must never be invented by the implementation'
        }
    }

    It 'declares no regulatory record label' {
        foreach ($rc in $Config.RetentionMap.retentionClasses) {
            $rc.declareAsRegulatoryRecord | Should -BeFalse -Because 'regulatory records are irreversible and excluded from MVP'
        }
    }

    It 'defaults allowIrreversiblePurviewChanges to false in every environment' {
        $all = Get-Content (Join-Path $RepoRoot 'config/environments.example.json') -Raw | ConvertFrom-Json
        foreach ($e in @('dev','test','prod')) {
            $all.environments.$e.allowIrreversiblePurviewChanges | Should -BeFalse
        }
    }

    It 'defaults allowProductionChanges to false in every environment' {
        $all = Get-Content (Join-Path $RepoRoot 'config/environments.example.json') -Raw | ConvertFrom-Json
        foreach ($e in @('dev','test','prod')) {
            $all.environments.$e.allowProductionChanges | Should -BeFalse
        }
    }

    It 'blocks every unapproved retention class in the Purview plan' {
        $p = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsPurview.ps1') -Environment dev -Mode Plan 6>$null
        $p.blockedCount | Should -Be @($Config.RetentionMap.retentionClasses).Count
        $p.createCount  | Should -Be 0
    }
}

Describe 'Security model (PRD F-024, SEC-002, SEC-003)' {

    It 'grants write access to Approval Evidence to exactly one principal' {
        $writers = @()
        foreach ($role in $Config.SecurityRoles.roles) {
            foreach ($p in $role.permissions) {
                if ($p.scope -eq 'ApprovalEvidence' -and $p.level -notin @('None','Read','DMS Read Evidence')) { $writers += $role.key }
            }
        }
        $writers.Count | Should -Be 1
        $writers[0]    | Should -Be 'AutomationService'
    }

    It 'does not give readers any access to Approval Evidence or the Exception Register' {
        $readers = $Config.SecurityRoles.roles | Where-Object key -eq 'Readers'
        foreach ($scope in @('ApprovalEvidence','Exceptions')) {
            ($readers.permissions | Where-Object scope -eq $scope).level | Should -Be 'None'
        }
    }

    It 'never grants Full Control to a content role' {
        foreach ($key in @('Readers','Authors','Reviewers','Approvers','RecordsManagers','Auditors','AutomationService')) {
            $role = $Config.SecurityRoles.roles | Where-Object key -eq $key
            foreach ($p in $role.permissions) { $p.level | Should -Not -Be 'Full Control' }
        }
    }

    It 'gives auditors read-only access everywhere' {
        $auditors = $Config.SecurityRoles.roles | Where-Object key -eq 'Auditors'
        foreach ($p in $auditors.permissions) { $p.level | Should -BeIn @('Read','DMS Read Evidence','None') }
    }

    It 'removes delete rights from the author and business-user permission level' {
        $level = $Config.SecurityRoles.customPermissionLevels | Where-Object name -eq 'DMS Contribute No Delete'
        $level.removePermissions | Should -Contain 'DeleteListItems'
    }

    It 'states a negative assertion for every privileged role' {
        foreach ($key in @('Authors','Approvers','DocumentControllers','PlatformAdministrators','RecordsManagers')) {
            $role = $Config.SecurityRoles.roles | Where-Object key -eq $key
            $role.mustNotBeAbleTo | Should -Not -BeNullOrEmpty
        }
    }

    It 'covers anonymous and guest access in the negative test matrix' {
        $roles = @($Config.SecurityRoles.negativeTestMatrix.assertions | ForEach-Object { $_.role })
        $roles | Should -Contain 'Anonymous'
        $roles | Should -Contain 'Guest'
    }

    It 'disables external sharing in every environment by default (PRD F-025)' {
        $all = Get-Content (Join-Path $RepoRoot 'config/environments.example.json') -Raw | ConvertFrom-Json
        foreach ($e in @('dev','test','prod')) { $all.environments.$e.externalSharing | Should -Be 'Disabled' }
    }
}

Describe 'Plan and Apply behaviour' {

    It 'produces a plan without a tenant connection' {
        $p = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan 6>$null
        $p.totalCount | Should -BeGreaterThan 0
        $p.applied    | Should -BeFalse
    }

    It 'is deterministic: two plan runs produce identical action sets (idempotency, PRD NFR-006)' {
        $a = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan 6>$null
        $b = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan 6>$null
        $a.totalCount   | Should -Be $b.totalCount
        $a.createCount  | Should -Be $b.createCount
        $a.blockedCount | Should -Be $b.blockedCount
    }

    It 'refuses Apply without a connection and returns a prerequisite exit code' {
        $p = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Apply 6>$null 2>$null
        $p.exitCode | Should -Be 3
        $p.applied  | Should -BeFalse
    }

    It 'blocks decision-gated resources rather than provisioning them' {
        $p = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan 6>$null
        $blocked = @($p | Out-Null)
        $plan = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan 6>$null
        $plan.blockedCount | Should -BeGreaterThan 0
    }

    It 'refuses to create Entra groups automatically (PRD D-006, R-07)' {
        $p = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSecurity.ps1') -Environment dev -Mode Plan 6>$null
        $p.blockedCount | Should -BeGreaterThan 0
    }
}

Describe 'Cmdlet fabrication guard (coding standards)' {

    It 'uses only PnP cmdlets and parameters that exist in the indexed source' {
        $r = Test-DmsPnPCmdletUsage -Path @((Join-Path $RepoRoot 'src'))
        $r.IsValid | Should -BeTrue -Because ($r.Findings | ForEach-Object { $_.Detail } | Out-String)
    }

    It 'actually inspects a meaningful number of invocations' {
        (Test-DmsPnPCmdletUsage -Path @((Join-Path $RepoRoot 'src'))).CmdletUsages | Should -BeGreaterThan 10
    }

    It 'records the provenance of the cmdlet index' {
        $idx = Get-Content (Join-Path $RepoRoot 'tests/fixtures/pnp-cmdlet-index.json') -Raw | ConvertFrom-Json
        $idx._provenance.commit     | Should -Not -BeNullOrEmpty
        $idx._provenance.commitDate | Should -Not -BeNullOrEmpty
        $idx._provenance.source     | Should -Match 'github.com/pnp/powershell'
    }

    It 'would catch a fabricated cmdlet' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "dms-fake-$(New-Guid).ps1"
        try {
            'Get-PnPNonExistentThing -Identity "x"' | Set-Content -LiteralPath $tmp -Encoding utf8
            $r = Test-DmsPnPCmdletUsage -Path @($tmp)
            $r.IsValid          | Should -BeFalse
            $r.Findings[0].Cmdlet | Should -Be 'Get-PnPNonExistentThing'
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    It 'would catch a fabricated parameter on a real cmdlet' {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "dms-fake-$(New-Guid).ps1"
        try {
            'Get-PnPList -Identity "Docs" -NotARealParameter' | Set-Content -LiteralPath $tmp -Encoding utf8
            $r = Test-DmsPnPCmdletUsage -Path @($tmp)
            $r.IsValid | Should -BeFalse
            $r.Findings[0].Parameter | Should -Be 'NotARealParameter'
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Discovery is read-only (PRD Phase 1)' {

    It 'contains no mutating cmdlet' {
        $file = Join-Path $RepoRoot 'src/provisioning/Invoke-DmsDiscovery.ps1'
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
        $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        $mutating = @($commands | ForEach-Object { $_.GetCommandName() } |
                      Where-Object { $_ -match '^(Set|New|Add|Remove|Update|Publish|Grant|Revoke|Clear|Reset)-PnP' })
        $mutating | Should -BeNullOrEmpty -Because 'discovery must not change tenant state'
    }

    It 'has no Apply mode' {
        (Get-Content (Join-Path $RepoRoot 'src/provisioning/Invoke-DmsDiscovery.ps1') -Raw) | Should -Not -Match "ValidateSet\('Plan','Apply'\)"
    }
}

Describe 'Repository completeness' {

    It 'includes the required document <_>' -ForEach $RequiredDocs {
        Test-Path (Join-Path $RepoRoot 'docs' $_) | Should -BeTrue
    }

    It 'has a specification for every P0 flow' {
        foreach ($f in @('Flow1-Request-Triage','Flow2-Submit-Review-Approve','Flow3-Scheduled-Activation','Flow4-Periodic-Review','Flow5-Exception-Management')) {
            Test-Path (Join-Path $RepoRoot "src/power-platform/flow-specifications/$f.md") | Should -BeTrue
        }
    }

    It 'ships no fabricated Power Platform solution archive' {
        @(Get-ChildItem (Join-Path $RepoRoot 'src/power-platform') -Recurse -Filter '*.zip' -ErrorAction SilentlyContinue).Count |
            Should -Be 0 -Because 'a solution package is a build artefact exported from a real environment, never hand-written'
    }

    It 'contains no committed secret-looking value' {
        $suspicious = Get-ChildItem $RepoRoot -Recurse -File -Include '*.json','*.ps1','*.psm1','*.psd1','*.yml','*.md' |
            Where-Object { $_.FullName -notmatch '[\\/](\.git|artifacts|node_modules)[\\/]' } |
            Select-String -Pattern '(?i)(client_?secret|password)\s*[:=]\s*["'']?[A-Za-z0-9+/=_\-]{12,}' |
            Where-Object { $_.Line -notmatch 'REDACTED|REQUIRES_|example|placeholder|\$\(|\$\{|Protect-Dms|pattern|Pattern' }
        $suspicious | Should -BeNullOrEmpty
    }
}

Describe 'Migration inventory (PRD F-037, DATA-012, ADR-014)' {
    BeforeAll {
        $script:Src = Join-Path ([System.IO.Path]::GetTempPath()) "dms-mig-$(New-Guid)"
        New-Item -ItemType Directory -Path (Join-Path $Src 'Quality/01 Drafts') -Force | Out-Null
        'same' | Set-Content (Join-Path $Src 'Quality/SOP-13 QC Inspection v2.docx')
        'same' | Set-Content (Join-Path $Src 'Quality/01 Drafts/SOP-13 QC Inspection v2 - Copy.docx')
        'diff' | Set-Content (Join-Path $Src 'Quality/QCP Rev0 FINAL.docx')
        $script:Inv = & (Join-Path $RepoRoot 'src/migration/Get-DmsSourceInventory.ps1') -SourcePath $Src -ComputeHash 6>$null
    }
    AfterAll { Remove-Item -LiteralPath $Src -Recurse -Force -ErrorAction SilentlyContinue }

    It 'counts duplicate SETS, not files within a set' {
        # Regression: a single duplicate set was unwrapped from its array, so .Count returned the
        # GroupInfo's own Count (files in the group) instead of the number of groups.
        $Inv.duplicateSetCount  | Should -Be 1
        $Inv.duplicateFileCount | Should -Be 2
    }
    It 'inventories every file' { $Inv.fileCount | Should -Be 3 }
    It 'flags revision encoded in a filename rather than parsing it' { $Inv.revisionInNameCount | Should -BeGreaterThan 0 }
    It 'flags status encoded in a name or folder' { $Inv.statusInNameCount | Should -BeGreaterThan 0 }
    It 'reports itself as read-only' { $Inv.readOnly | Should -BeTrue }
    It 'leaves the source untouched' { (Get-ChildItem $Src -Recurse -File).Count | Should -Be 3 }
    It 'contains no mutating filesystem cmdlet' {
        $f = Join-Path $RepoRoot 'src/migration/Get-DmsSourceInventory.ps1'
        $tok=$null; $err=$null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$tok,[ref]$err)
        $cmds = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] },$true) | ForEach-Object { $_.GetCommandName() }
        @($cmds | Where-Object { $_ -in @('Remove-Item','Move-Item','Set-Content','Add-Content','Clear-Content') -and $_ -ne 'Set-Content' }) | Should -BeNullOrEmpty
    }
}
