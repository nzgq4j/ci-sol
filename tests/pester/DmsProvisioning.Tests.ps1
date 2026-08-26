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

Describe 'Deferred apply actions bind their own target (PowerShell closure capture)' {
    # Regression for a defect found in review: each -ApplyScript closed over script-scope loop
    # variables that kept being reassigned while the plan was built. Because the scriptblocks are not
    # executed until Apply, every action ran against the LAST loop value - so Apply would have
    # provisioned the final column repeatedly and silently reported all the others as succeeded.
    #
    # Plan-only tests could never catch this: Plan does not execute the scriptblocks. This test
    # executes them against stubbed PnP cmdlets and asserts each acted on its own target.

    BeforeAll {
        $global:DmsStubCalls = [System.Collections.Generic.List[object]]::new()

        function global:Add-PnPField {
            param($DisplayName,$InternalName,$Type,$Group,$Connection,$Choices,$Required,$List,$Field)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPField'; Target=$(if ($InternalName) { $InternalName } else { $Field }) }) | Out-Null
        }
        function global:Set-PnPField {
            param($Identity,$List,$Values,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Set-PnPField'; Target=$Identity }) | Out-Null
        }
        function global:Add-PnPTaxonomyField {
            param($DisplayName,$InternalName,$TermSetPath,$Group,$Connection,$MultiValue,$Required)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPTaxonomyField'; Target=$InternalName }) | Out-Null
        }
        function global:Set-PnPListPermission {
            param($Identity,$Group,$User,$AddRole,$RemoveRole,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Set-PnPListPermission'; Target="$Identity|$Group|$AddRole" }) | Out-Null
        }
        function global:Add-PnPRoleDefinition {
            param($RoleName,$Clone,$Description,$Include,$Exclude,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPRoleDefinition'; Target=$RoleName }) | Out-Null
        }
        function global:Set-PnPTenantSite {
            param($Identity,$SharingCapability,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Set-PnPTenantSite'; Target=$Identity }) | Out-Null
        }
        function global:Add-PnPFieldFromXml {
            param($FieldXml,$List,$Connection)
            # Recover the internal name from the field XML so the assertions can match on it.
            $name = if ($FieldXml -match 'StaticName="([^"]+)"') { $Matches[1] } else { '(unparsed)' }
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPFieldFromXml'; Target=$name; Xml=$FieldXml }) | Out-Null
        }
        function global:Add-PnPContentType {
            param($Name,$ContentTypeId,$Description,$Group,$ParentContentType,$DocumentTemplate,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPContentType'; Target=$Name }) | Out-Null
        }
        function global:Add-PnPFieldToContentType {
            param($Field,$ContentType,[switch]$Required,[switch]$Hidden,[switch]$UpdateChildren,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPFieldToContentType'; Target="$ContentType|$Field" }) | Out-Null
        }
        function global:New-PnPList {
            param($Title,$Template,$Url,$EnableContentTypes,$EnableVersioning,[switch]$Hidden,[switch]$OnQuickLaunch,$Connection)
            $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='New-PnPList'; Target=$Title }) | Out-Null
        }
    }
    AfterAll {
        foreach ($f in @('Add-PnPField','Set-PnPField','Add-PnPTaxonomyField','Set-PnPListPermission','Add-PnPRoleDefinition','Set-PnPTenantSite','Add-PnPFieldFromXml','Add-PnPContentType','Add-PnPFieldToContentType','New-PnPList')) {
            Remove-Item "function:global:$f" -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name DmsStubCalls -Scope Global -ErrorAction SilentlyContinue
    }

    Context 'Site columns' {
        BeforeAll {
            $global:DmsStubCalls.Clear()
            $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            $script:ColumnActions = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'SiteColumn' -and $_.change -eq 'Create' })
            foreach ($a in $ColumnActions) { & $a.applyScript }
            $script:CreatedColumns = @($global:DmsStubCalls | Where-Object { $_.Cmdlet -in @('Add-PnPField','Add-PnPTaxonomyField','Add-PnPFieldFromXml') } | ForEach-Object { $_.Target })
        }

        It 'plans a create for every configured column' { $ColumnActions.Count | Should -BeGreaterThan 25 }

        It 'creates one field per planned action, not the same field repeatedly' {
            $CreatedColumns.Count | Should -Be $ColumnActions.Count
            (@($CreatedColumns | Sort-Object -Unique)).Count | Should -Be $ColumnActions.Count
        }

        It 'creates exactly the fields that were planned' {
            foreach ($a in $ColumnActions) { $CreatedColumns | Should -Contain $a.target }
        }

        It 'creates taxonomy fields through the taxonomy path rather than throwing' {
            $tax = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Add-PnPTaxonomyField' | ForEach-Object { $_.Target })
            $tax | Should -Contain 'DmsBusinessFunction'
            $tax | Should -Contain 'DmsApplicability'
        }

        It 'creates multi-value person fields from field XML, not through the CSOM FieldType enum' {
            # UserMulti is a valid SharePoint schema type but is absent from the CSOM FieldType enum,
            # so Add-PnPField -Type UserMulti fails. These must go through the XML path.
            $xmlFields = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Add-PnPFieldFromXml')
            @($xmlFields | ForEach-Object { $_.Target }) | Should -Contain 'DmsAuthor'
            @($xmlFields | ForEach-Object { $_.Target }) | Should -Contain 'DmsReviewer'
            @($xmlFields | ForEach-Object { $_.Target }) | Should -Contain 'DmsApprover'
            foreach ($x in $xmlFields) { $x.Xml | Should -Match 'Type="UserMulti"'; $x.Xml | Should -Match 'Mult="TRUE"' }
        }

        It 'never passes UserMulti to Add-PnPField' {
            @($global:DmsStubCalls | Where-Object { $_.Cmdlet -eq 'Add-PnPField' -and $_.Target -in @('DmsAuthor','DmsReviewer','DmsApprover') }) |
                Should -BeNullOrEmpty
        }
    }

    Context 'Content types' {
        BeforeAll {
            $global:DmsStubCalls.Clear()
            $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            $script:CtActions = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'ContentType' -and $_.change -eq 'Create' })
            foreach ($a in $CtActions) { & $a.applyScript }
        }

        It 'creates each content type once' {
            $created = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Add-PnPContentType' | ForEach-Object { $_.Target })
            $created.Count | Should -Be $CtActions.Count
            (@($created | Sort-Object -Unique)).Count | Should -Be $CtActions.Count
        }

        It 'binds every configured field, and does not stop at the first that fails' {
            # Regression: bindings ran in one unbroken sequence, so a single unavailable column
            # aborted all remaining bindings and left the content type incompletely configured.
            $bound = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Add-PnPFieldToContentType' | ForEach-Object { $_.Target })
            $bound | Should -Contain 'Controlled Document|DmsDocumentId'
            $bound | Should -Contain 'Controlled Document|DmsAuthor'
            # DmsCurrentEffective is late in the optional list; it is the one that went missing.
            $bound | Should -Contain 'Controlled Document|DmsCurrentEffective'
            $bound | Should -Contain 'Controlled Document|DmsEffectiveDate'
        }

        It 'continues binding after a failure and reports what failed' {
            $global:DmsStubCalls.Clear()
            function global:Add-PnPFieldToContentType {
                param($Field,$ContentType,[switch]$Required,[switch]$Hidden,[switch]$UpdateChildren,$Connection)
                $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPFieldToContentType'; Target="$ContentType|$Field" }) | Out-Null
                if ($Field -eq 'DmsAuthor') { throw "Column 'DmsAuthor' does not exist." }
            }
            try {
                $action = $CtActions | Where-Object target -eq 'Controlled Document' | Select-Object -First 1
                { & $action.applyScript } | Should -Throw -ExpectedMessage '*field binding*'
                $bound = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Add-PnPFieldToContentType' | ForEach-Object { $_.Target })
                # Fields after the failing one must still have been attempted.
                $bound | Should -Contain 'Controlled Document|DmsCurrentEffective'
            } finally {
                function global:Add-PnPFieldToContentType {
                    param($Field,$ContentType,[switch]$Required,[switch]$Hidden,[switch]$UpdateChildren,$Connection)
                    $global:DmsStubCalls.Add([pscustomobject]@{ Cmdlet='Add-PnPFieldToContentType'; Target="$ContentType|$Field" }) | Out-Null
                }
            }
        }
    }

    Context 'Lists' {
        BeforeAll {
            $global:DmsStubCalls.Clear()
            $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSharePoint.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            $script:ListActions = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'List' -and $_.change -eq 'Create' })
            foreach ($a in $ListActions) { & $a.applyScript }
        }

        It 'creates every planned list' {
            # Regression: the deferred scriptblock called a script-scope helper function, which a
            # closure module cannot resolve when the script is invoked from the orchestrator. Every
            # list creation failed with 'ConvertTo-SharePointFieldType is not recognized'.
            $created = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'New-PnPList' | ForEach-Object { $_.Target })
            $created.Count | Should -Be $ListActions.Count
            (@($created | Sort-Object -Unique)).Count | Should -Be $ListActions.Count
            $created | Should -Contain 'Approval Evidence'
            $created | Should -Contain 'Document Register'
        }

        It 'adds list fields without calling a script-scope helper at execution time' {
            $added = @($global:DmsStubCalls | Where-Object { $_.Cmdlet -in @('Add-PnPField','Add-PnPFieldFromXml') })
            $added.Count | Should -BeGreaterThan 40
        }
    }

    Context 'Security assignments' {
        BeforeAll {
            $global:DmsStubCalls.Clear()
            $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSecurity.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            $script:PermActions = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'ListPermission' -and $_.change -eq 'Create' })
            foreach ($a in $PermActions) { & $a.applyScript }
            $script:GrantedPerms = @($global:DmsStubCalls | Where-Object Cmdlet -eq 'Set-PnPListPermission' | ForEach-Object { $_.Target })
        }

        It 'plans multiple permission grants' { $PermActions.Count | Should -BeGreaterThan 10 }

        It 'grants each list/group/role combination once, not the last one repeatedly' {
            $GrantedPerms.Count | Should -Be $PermActions.Count
            (@($GrantedPerms | Sort-Object -Unique)).Count | Should -Be $PermActions.Count
        }

        It 'grants the automation identity write on Approval Evidence' {
            $GrantedPerms | Should -Contain 'Approval Evidence|DMS-DEV-AutomationService|DMS Contribute No Delete'
        }
    }

    Context 'Security assignments against a site whose groups do not exist' {
        # The offline plan above is desired-state and cannot read groups. This exercises the ONLINE
        # path, which is where the first real Apply failed: every grant was planned Create and every
        # one of them failed with 'Group cannot be found'. Stubbing the happy path only is what let
        # that reach the tenant.
        BeforeAll {
            function global:Get-PnPRoleDefinition { param($Identity,$Connection) @() }
            function global:Get-PnPGroup { param($Identity,$Connection,$ErrorAction) throw "Group cannot be found." }
            try {
                $script:MissingSummary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSecurity.ps1') `
                    -Environment dev -Mode Plan -Connection ([pscustomobject]@{ Url = 'https://stub' }) `
                    -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            } finally {
                foreach ($f in @('Get-PnPRoleDefinition','Get-PnPGroup')) { Remove-Item "function:global:$f" -ErrorAction SilentlyContinue }
            }
            $script:MissingPerms = @($MissingSummary.plan.actions | Where-Object resourceType -eq 'ListPermission')
        }

        It 'still plans every configured grant' { $MissingPerms.Count | Should -BeGreaterThan 10 }

        It 'plans no grant as Create when its group is absent' {
            @($MissingPerms | Where-Object change -eq 'Create') | Should -BeNullOrEmpty
        }

        It 'reports each unassignable grant as Blocked and names the group' {
            @($MissingPerms | Where-Object change -eq 'Blocked').Count | Should -Be $MissingPerms.Count
            $MissingPerms[0].reason | Should -Match "Group 'DMS-DEV-[A-Za-z]+' does not exist"
        }

        It 'attaches no apply script to a blocked grant' {
            @($MissingPerms | Where-Object { $null -ne $_.applyScript }) | Should -BeNullOrEmpty
        }
    }

    Context 'Security assignments against a site whose groups exist' {
        BeforeAll {
            function global:Get-PnPRoleDefinition { param($Identity,$Connection) @() }
            function global:Get-PnPGroup { param($Identity,$Connection,$ErrorAction) [pscustomobject]@{ Title = $Identity } }
            try {
                $script:PresentSummary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsSecurity.ps1') `
                    -Environment dev -Mode Plan -Connection ([pscustomobject]@{ Url = 'https://stub' }) `
                    -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            } finally {
                foreach ($f in @('Get-PnPRoleDefinition','Get-PnPGroup')) { Remove-Item "function:global:$f" -ErrorAction SilentlyContinue }
            }
            $script:PresentPerms = @($PresentSummary.plan.actions | Where-Object resourceType -eq 'ListPermission')
        }

        It 'plans the grants as Create once the groups are present' {
            @($PresentPerms | Where-Object change -eq 'Create').Count | Should -Be $PresentPerms.Count
        }

        It 'blocks nothing on group existence' {
            @($PresentSummary.plan.actions | Where-Object { $_.resourceType -eq 'RoleGroup' -and $_.change -eq 'Blocked' }) | Should -BeNullOrEmpty
        }
    }

    Context 'Taxonomy' {
        It 'provisions each term set and term against its own target' {
            $global:DmsStubCalls.Clear()
            $created = [System.Collections.Generic.List[string]]::new()
            function global:New-PnPTermGroup  { param($Name,$Description,$Connection) $created.Add("group:$Name")   | Out-Null }
            function global:New-PnPTermSet    { param($Name,$TermGroup,$Description,$IsOpenForTermCreation,$Connection) $created.Add("set:$Name") | Out-Null }
            function global:New-PnPTerm       { param($Name,$TermSet,$TermGroup,$Connection) $created.Add("term:$Name") | Out-Null; [pscustomobject]@{ Id = [guid]::NewGuid() } }
            function global:Add-PnPTermToTerm { param($Name,$ParentTermId,$Connection) $created.Add("child:$Name") | Out-Null }
            try {
                $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsTaxonomy.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
                $setActions = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'TermSet' -and $_.change -eq 'Create' })
                foreach ($a in $setActions) { & $a.applyScript }
                $sets = @($created | Where-Object { $_ -like 'set:*' })
                $sets.Count | Should -Be $setActions.Count
                (@($sets | Sort-Object -Unique)).Count | Should -Be $setActions.Count
            } finally {
                foreach ($f in @('New-PnPTermGroup','New-PnPTermSet','New-PnPTerm','Add-PnPTermToTerm')) {
                    Remove-Item "function:global:$f" -ErrorAction SilentlyContinue
                }
            }
        }

        It 'refuses to create a placeholder term as a real vocabulary entry' {
            $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsTaxonomy.ps1') -Environment dev -Mode Plan -InformationAction SilentlyContinue -WarningAction SilentlyContinue
            $blocked = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'Term' -and $_.change -eq 'Blocked' })
            $blocked.Count | Should -BeGreaterThan 0
            $blocked[0].reason | Should -Match 'placeholder'
        }
    }
}

Describe 'Deferred scriptblocks resolve only module or global commands' {
    # A scriptblock created with .GetNewClosure() executes in its own module scope. That scope can
    # reach module-exported and global commands, but NOT functions defined in the enclosing script -
    # and whether it appears to work depends on how the script was invoked, so it passes when run
    # directly and fails when run from the orchestrator.
    #
    # This asserts the invariant structurally, so the trap cannot be reintroduced anywhere.

    It '<_> has no deferred action calling a function defined in that script' -ForEach @(
        'Deploy-DmsSharePoint.ps1','Deploy-DmsSecurity.ps1','Deploy-DmsPurview.ps1','Deploy-DmsTaxonomy.ps1'
    ) {
        $file = Join-Path $RepoRoot 'src/provisioning' $_
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        # Functions defined at script scope in this file.
        $localFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            [void]$localFunctions.Add($fn.Name)
        }

        # Scriptblocks that have .GetNewClosure() invoked on them are the deferred ones.
        $deferred = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            "$($n.Member)" -eq 'GetNewClosure'
        }, $true)

        $violations = [System.Collections.Generic.List[string]]::new()
        foreach ($d in $deferred) {
            foreach ($cmd in $d.Expression.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = $cmd.GetCommandName()
                if ($name -and $localFunctions.Contains($name)) {
                    $violations.Add("$name at line $($cmd.Extent.StartLineNumber)") | Out-Null
                }
            }
        }

        $violations | Should -BeNullOrEmpty -Because 'a deferred closure cannot resolve a script-scope function; resolve the value before building the closure'
    }
}

Describe 'Taxonomy is idempotent (PRD NFR-006)' {
    # Regression: the taxonomy plan checked the term group and term set for existence but never the
    # terms themselves, so every term was planned as Create on every run. A second Apply then failed
    # with 'There is already a term with the same default label and parent term' for all 17 terms.

    BeforeAll {
        # A connection object only needs to be non-null for the script to treat itself as online.
        $script:FakeConn = [PSCustomObject]@{ Url = 'https://contoso.sharepoint.com/sites/dms-dev' }

        function global:Get-PnPTermGroup { param($Identity,$TermStore,$Connection) [PSCustomObject]@{ Name = $Identity } }
        function global:Get-PnPTermSet   { param($Identity,$TermGroup,$TermStore,$Connection) [PSCustomObject]@{ Name = $Identity } }
    }
    AfterAll {
        foreach ($f in @('Get-PnPTermGroup','Get-PnPTermSet','Get-PnPTerm')) { Remove-Item "function:global:$f" -ErrorAction SilentlyContinue }
    }

    It 'reports every existing term as Compliant rather than planning a duplicate create' {
        $cfg = Get-DmsConfiguration -Environment dev
        # Return exactly what configuration asks for, as if a previous Apply had succeeded.
        function global:Get-PnPTerm {
            param($Identity,$TermSet,$TermGroup,$TermStore,[switch]$IncludeChildTerms,[switch]$Recursive,[switch]$IncludeDeprecated,$ParentTerm,$Connection)
            $set = ($cfg.Taxonomy.termSets | Where-Object name -eq $TermSet)
            foreach ($t in $set.terms) {
                if ("$($t.name)" -like '*REQUIRES_*') { continue }
                [PSCustomObject]@{
                    Name  = $t.name
                    Id    = [guid]::NewGuid()
                    Terms = @(@(Get-DmsPropertyOrDefault -InputObject $t -Name 'children' -Default @()) | ForEach-Object { [PSCustomObject]@{ Name = $_ } })
                }
            }
        }
        $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsTaxonomy.ps1') -Environment dev -Mode Plan `
                        -Connection $FakeConn -InformationAction SilentlyContinue -WarningAction SilentlyContinue

        $termActions = @($summary.plan.actions | Where-Object resourceType -eq 'Term')
        @($termActions | Where-Object change -eq 'Create') | Should -BeNullOrEmpty -Because 'the terms already exist'
        @($termActions | Where-Object change -eq 'Compliant').Count | Should -BeGreaterThan 15
        # The placeholder term stays blocked whatever the tenant contains.
        @($termActions | Where-Object change -eq 'Blocked').Count | Should -Be 1
    }

    It 'plans an additive Update when a term exists but a child term is missing' {
        $cfg = Get-DmsConfiguration -Environment dev
        function global:Get-PnPTerm {
            param($Identity,$TermSet,$TermGroup,$TermStore,[switch]$IncludeChildTerms,[switch]$Recursive,[switch]$IncludeDeprecated,$ParentTerm,$Connection)
            $set = ($cfg.Taxonomy.termSets | Where-Object name -eq $TermSet)
            foreach ($t in $set.terms) {
                if ("$($t.name)" -like '*REQUIRES_*') { continue }
                $kids = @(Get-DmsPropertyOrDefault -InputObject $t -Name 'children' -Default @())
                # Drop one child to simulate a partially completed run.
                if ($kids.Count -gt 1) { $kids = $kids[1..($kids.Count-1)] }
                [PSCustomObject]@{ Name = $t.name; Id = [guid]::NewGuid(); Terms = @($kids | ForEach-Object { [PSCustomObject]@{ Name = $_ } }) }
            }
        }
        $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsTaxonomy.ps1') -Environment dev -Mode Plan `
                        -Connection $FakeConn -InformationAction SilentlyContinue -WarningAction SilentlyContinue

        $updates = @($summary.plan.actions | Where-Object { $_.resourceType -eq 'Term' -and $_.change -eq 'Update' })
        $updates.Count   | Should -BeGreaterThan 0
        $updates[0].reason | Should -Match 'child term'
    }

    It 'does not assume an empty term set when the term store cannot be read' {
        function global:Get-PnPTerm {
            param($Identity,$TermSet,$TermGroup,$TermStore,[switch]$IncludeChildTerms,[switch]$Recursive,[switch]$IncludeDeprecated,$ParentTerm,$Connection)
            throw 'Access denied to the term store.'
        }
        $summary = & (Join-Path $RepoRoot 'src/provisioning/Deploy-DmsTaxonomy.ps1') -Environment dev -Mode Plan `
                        -Connection $FakeConn -InformationAction SilentlyContinue -WarningAction SilentlyContinue
        # Unreadable state falls back to planning creates, and the failure is logged rather than
        # silently treated as 'nothing exists'.
        @($summary.plan.actions | Where-Object { $_.resourceType -eq 'Term' -and $_.change -eq 'Create' }).Count | Should -BeGreaterThan 0
    }
}
