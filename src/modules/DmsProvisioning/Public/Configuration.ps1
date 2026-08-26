Set-StrictMode -Version Latest

function Get-DmsConfiguration {
<#
.SYNOPSIS
    Loads the DMS configuration set from disk.
.DESCRIPTION
    Loads every configuration file into one object graph so that callers never read config files
    directly. Environment selection is explicit; there is no implicit "current" environment, which
    avoids the global mutable state the coding standards prohibit.

    If config/environments.json is absent, config/environments.example.json is used and the result is
    flagged IsExample. Deployment scripts refuse Apply mode against example configuration.
.PARAMETER ConfigPath
    Directory containing the configuration files. Defaults to the repository config folder.
.PARAMETER Environment
    Environment key to resolve.
.EXAMPLE
    $cfg = Get-DmsConfiguration -Environment dev
.OUTPUTS
    PSCustomObject with tenant, environment and all model sections.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()][string]$ConfigPath = (Join-Path (Get-DmsRepositoryRoot) 'config'),
        [Parameter()][ValidateSet('dev','test','prod')][string]$Environment = 'dev'
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Configuration directory not found: $ConfigPath"
    }

    $envFile   = Join-Path $ConfigPath 'environments.json'
    $isExample = $false
    if (-not (Test-Path -LiteralPath $envFile)) {
        $envFile   = Join-Path $ConfigPath 'environments.example.json'
        $isExample = $true
    }

    $environments = Read-DmsJsonFile -Path $envFile
    if (-not (Test-DmsProperty -InputObject $environments.environments -Name $Environment)) {
        throw "Environment '$Environment' is not defined in $envFile."
    }

    $retentionFile = Join-Path $ConfigPath 'retention-map.json'
    if (-not (Test-Path -LiteralPath $retentionFile)) {
        $retentionFile = Join-Path $ConfigPath 'retention-map.example.json'
    }

    return [PSCustomObject]@{
        ConfigPath      = $ConfigPath
        EnvironmentKey  = $Environment
        IsExample       = $isExample
        SourceFile      = $envFile
        Tenant          = $environments.tenant
        Environment     = $environments.environments.$Environment
        Provisional     = (Get-DmsPropertyOrDefault -InputObject $environments -Name 'provisional' -Default @())
        SiteColumns     = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'site-columns.json')
        ContentTypes    = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'content-types.json')
        Libraries       = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'libraries.json')
        Lists           = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'lists.json')
        Views           = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'views.json')
        Taxonomy        = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'taxonomy.json')
        Lifecycle       = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'lifecycle-states.json')
        Routing         = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'routing-rules.json')
        SecurityRoles   = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'security-roles.json')
        RetentionMap    = Read-DmsJsonFile -Path $retentionFile
        Metrics         = Read-DmsJsonFile -Path (Join-Path $ConfigPath 'metrics.json')
    }
}

function Test-DmsConfiguration {
<#
.SYNOPSIS
    Validates the DMS configuration set: schema conformance, referential integrity and rule conformance.
.DESCRIPTION
    This is the offline gate that runs before any deployment and in CI. It performs three classes of
    check that a JSON Schema alone cannot:

      1. Schema conformance    - each file against its JSON Schema via Test-Json.
      2. Referential integrity - cross-file references actually resolve (library content types exist,
                                 view fields exist as site columns or list fields, indexed columns
                                 exist and stay within the platform budget, permission levels exist).
      3. Rule conformance      - the lifecycle and routing engines are executed against the
                                 conformance vectors declared in configuration, so a config change
                                 that breaks a documented behaviour fails here rather than in a tenant.

    It also enforces the retention production gate: a retention class still marked
    REQUIRES_RECORDS_APPROVAL is reported, because PRD F-018 forbids production record capture
    against an unapproved class.
.PARAMETER Configuration
    Configuration object from Get-DmsConfiguration. Loaded automatically when omitted.
.PARAMETER ConfigPath
    Configuration directory, used when Configuration is not supplied.
.EXAMPLE
    Test-DmsConfiguration -Verbose
.OUTPUTS
    PSCustomObject with IsValid, Checks, Failures and Warnings.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]$Configuration,
        [Parameter()][string]$ConfigPath = (Join-Path (Get-DmsRepositoryRoot) 'config')
    )

    if ($null -eq $Configuration) {
        $Configuration = Get-DmsConfiguration -ConfigPath $ConfigPath
    }
    $cfgDir = $Configuration.ConfigPath

    $checks   = [System.Collections.Generic.List[object]]::new()
    $failures = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    function Add-Check {
        param([string]$Name, [bool]$Passed, [string]$Detail = '', [string]$Requirement = '')
        $checks.Add([PSCustomObject]@{ Name=$Name; Passed=$Passed; Detail=$Detail; Requirement=$Requirement }) | Out-Null
        if (-not $Passed) { $failures.Add("$Name : $Detail") | Out-Null }
    }

    # ---------------------------------------------------------------- 1. Schema conformance
    $schemaMap = @{
        'environments.example.json' = 'environments.schema.json'
        'lifecycle-states.json'     = 'lifecycle-states.schema.json'
        'site-columns.json'         = 'site-columns.schema.json'
        'content-types.json'        = 'content-types.schema.json'
        'routing-rules.json'        = 'routing-rules.schema.json'
        'retention-map.example.json'= 'retention-map.schema.json'
    }
    if (Test-Path -LiteralPath (Join-Path $cfgDir 'environments.json')) {
        $schemaMap['environments.json'] = 'environments.schema.json'
        $schemaMap.Remove('environments.example.json')
    }
    if (Test-Path -LiteralPath (Join-Path $cfgDir 'retention-map.json')) {
        $schemaMap['retention-map.json'] = 'retention-map.schema.json'
        $schemaMap.Remove('retention-map.example.json')
    }

    foreach ($file in ($schemaMap.Keys | Sort-Object)) {
        $dataPath   = Join-Path $cfgDir $file
        $schemaPath = Join-Path $cfgDir $schemaMap[$file]
        if (-not (Test-Path -LiteralPath $dataPath))   { Add-Check "Schema:$file" $false "Data file missing: $dataPath"; continue }
        if (-not (Test-Path -LiteralPath $schemaPath)) { Add-Check "Schema:$file" $false "Schema file missing: $schemaPath"; continue }
        $json   = Get-Content -LiteralPath $dataPath   -Raw -Encoding utf8
        $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding utf8
        $err = $null
        $ok = Test-Json -Json $json -Schema $schema -ErrorAction SilentlyContinue -ErrorVariable err
        $detail = if ($ok) { 'Conforms.' } else { "Does not conform: $(($err | Select-Object -First 1))" }
        Add-Check "Schema:$file" ([bool]$ok) $detail 'NFR-019'
    }

    # ---------------------------------------------------------------- 2. Referential integrity
    $siteColumnNames = @($Configuration.SiteColumns.columns | ForEach-Object { $_.internalName })
    $contentTypeNames= @($Configuration.ContentTypes.contentTypes | ForEach-Object { $_.name })

    # 2a. Content type field references resolve to declared site columns.
    foreach ($ct in $Configuration.ContentTypes.contentTypes) {
        foreach ($prop in @('requiredFields','optionalFields')) {
            $fields = Get-DmsPropertyOrDefault -InputObject $ct -Name $prop -Default @()
            $missing = @($fields | Where-Object { $_ -notin $siteColumnNames })
            if ($missing.Count -gt 0) {
                Add-Check "ContentTypeFields:$($ct.name).$prop" $false "References undeclared site columns: $($missing -join ', ')" 'F-001'
            }
        }
    }
    Add-Check 'ContentTypeFields' (-not ($failures -match 'ContentTypeFields:')) 'All content type field references resolve.' 'F-001'

    # 2b. Library content types exist.
    foreach ($lib in $Configuration.Libraries.libraries) {
        $missing = @($lib.contentTypes | Where-Object { $_ -notin $contentTypeNames })
        if ($missing.Count -gt 0) { Add-Check "LibraryContentTypes:$($lib.key)" $false "Unknown content types: $($missing -join ', ')" 'F-001' }
    }

    # 2c. Indexed columns exist and respect the platform budget.
    $budget = $Configuration.SiteColumns.indexingBudget.maxIndexedColumnsPerList
    foreach ($lib in $Configuration.Libraries.libraries) {
        $idx = @(Get-DmsPropertyOrDefault -InputObject $lib -Name 'indexedColumns' -Default @())
        $unknown = @($idx | Where-Object { $_ -notin $siteColumnNames })
        if ($unknown.Count -gt 0) { Add-Check "LibraryIndex:$($lib.key)" $false "Indexes undeclared columns: $($unknown -join ', ')" 'NFR-004' }
        if ($idx.Count -gt $budget) { Add-Check "LibraryIndexBudget:$($lib.key)" $false "Declares $($idx.Count) indexed columns; platform budget is $budget." 'NFR-004' }
    }

    # 2d. View fields resolve to site columns, list-local fields, or known built-ins.
    $builtIn = @('LinkFilename','Title','Modified','Created','Editor','Author','FileLeafRef','ID','DocIcon')
    $listFieldsByKey = @{}
    foreach ($l in $Configuration.Lists.lists) {
        $listFieldsByKey[$l.key] = @($l.fields | ForEach-Object { $_.internalName })
    }
    foreach ($view in $Configuration.Views.views) {
        $allowed = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($n in $siteColumnNames) { [void]$allowed.Add($n) }
        foreach ($n in $builtIn)         { [void]$allowed.Add($n) }
        foreach ($t in @($view.targetLists)) {
            if ($listFieldsByKey.ContainsKey($t)) { foreach ($n in $listFieldsByKey[$t]) { [void]$allowed.Add($n) } }
        }
        $unknown = @($view.viewFields | Where-Object { -not $allowed.Contains($_) })
        if ($unknown.Count -gt 0) { Add-Check "ViewFields:$($view.key)" $false "Unresolvable fields: $($unknown -join ', ')" 'F-026' }
    }

    # 2e. Default reader views over LIFECYCLE-MANAGED content must exclude non-effective revisions
    #     (PRD F-014). The invariant applies only where a current-effective concept exists: content
    #     types descending from Controlled Document. External Documents and Operational Records have
    #     no lifecycle status, so requiring the filter there would be meaningless.
    $controlledBase = ($Configuration.ContentTypes.contentTypes | Where-Object { $_.name -eq 'Controlled Document' } | Select-Object -First 1).id
    $lifecycleManagedCts = @($Configuration.ContentTypes.contentTypes |
        Where-Object { $_.id.StartsWith($controlledBase) } | ForEach-Object { $_.name })
    $lifecycleManagedContainers = @($Configuration.Libraries.libraries |
        Where-Object { @($_.contentTypes | Where-Object { $_ -in $lifecycleManagedCts }).Count -gt 0 } |
        ForEach-Object { $_.key })
    $lifecycleManagedContainers += 'DocumentRegister'

    foreach ($view in @($Configuration.Views.views | Where-Object { $_.isDefault -and $_.audience -match '(?i)reader' })) {
        $targetsLifecycleContent = @($view.targetLists | Where-Object { $_ -in $lifecycleManagedContainers }).Count -gt 0
        if (-not $targetsLifecycleContent) { continue }
        $caml = Get-DmsPropertyOrDefault -InputObject $view -Name 'camlQuery' -Default ''
        $filtersCurrent = $caml -match "DmsCurrentEffective"
        Add-Check "DefaultReaderViewExcludesNonEffective:$($view.key)" $filtersCurrent `
            $(if ($filtersCurrent) { 'Filters on DmsCurrentEffective.' } else { 'A default reader view over lifecycle-managed content does not filter on DmsCurrentEffective; superseded or withdrawn revisions could be presented as current.' }) 'F-014'
    }

    # 2f. Security role permission levels resolve.
    $levelNames = @($Configuration.SecurityRoles.customPermissionLevels | ForEach-Object { $_.name }) + @('Read','Edit','Contribute','Full Control','None')
    foreach ($role in $Configuration.SecurityRoles.roles) {
        $unknown = @($role.permissions | Where-Object { $_.level -notin $levelNames } | ForEach-Object { $_.level })
        if ($unknown.Count -gt 0) { Add-Check "RolePermissionLevel:$($role.key)" $false "Unknown permission levels: $($unknown -join ', ')" 'SEC-002' }
    }

    # 2g. Exactly one principal may write Approval Evidence (PRD F-010).
    $evidenceWriters = @()
    foreach ($role in $Configuration.SecurityRoles.roles) {
        foreach ($p in $role.permissions) {
            if ($p.scope -eq 'ApprovalEvidence' -and $p.level -notin @('None','Read','DMS Read Evidence')) {
                $evidenceWriters += $role.key
            }
        }
    }
    Add-Check 'ApprovalEvidenceSingleWriter' ($evidenceWriters.Count -eq 1 -and $evidenceWriters[0] -eq 'AutomationService') `
        "Principals with write access to Approval Evidence: $(if($evidenceWriters){$evidenceWriters -join ', '}else{'none'}). Exactly one (AutomationService) is required." 'F-010'

    # ---------------------------------------------------------------- 3. Rule conformance
    $lifecycle = $Configuration.Lifecycle

    # 3a. Every transition references declared states.
    $stateKeys = @($lifecycle.states | ForEach-Object { $_.key })
    $dangling = @($lifecycle.transitions | Where-Object { $_.from -notin $stateKeys -or $_.to -notin $stateKeys })
    Add-Check 'LifecycleTransitionsResolve' ($dangling.Count -eq 0) `
        $(if ($dangling.Count -eq 0) { 'All transitions reference declared states.' } else { "Dangling transitions: $(($dangling | ForEach-Object { $_.id }) -join ', ')" }) 'F-005'

    # 3b. Exactly one state may be flagged current-effective.
    $effectiveStates = @($lifecycle.states | Where-Object { $_.currentEffective })
    Add-Check 'SingleCurrentEffectiveState' ($effectiveStates.Count -eq 1) `
        "States flagged currentEffective: $(($effectiveStates | ForEach-Object { $_.key }) -join ', '). Exactly one is required." 'F-013'

    # 3c. Only SystemAutomation or Document Control may set Effective.
    $toEffective = @($lifecycle.transitions | Where-Object { $_.to -eq 'Effective' })
    $badActors = @($toEffective | Where-Object { @($_.allowedActors | Where-Object { $_ -notin @('SystemAutomation','DocumentController') }).Count -gt 0 })
    Add-Check 'EffectiveTransitionActorsRestricted' ($badActors.Count -eq 0) `
        $(if ($badActors.Count -eq 0) { 'Only SystemAutomation and DocumentController may set Effective.' } else { "Over-permissive transitions: $(($badActors | ForEach-Object { $_.id }) -join ', ')" }) 'F-005,F-012'

    # 3d. Execute the declared lifecycle conformance vectors through the real engine.
    $lcPass = 0; $lcFail = [System.Collections.Generic.List[string]]::new()
    foreach ($v in $lifecycle.conformanceVectors.valid) {
        $r = Test-DmsLifecycleTransition -From $v.from -To $v.to -Actor $v.actor -Model $lifecycle
        if ($r.IsPermitted) { $lcPass++ } else { $lcFail.Add("expected PERMIT $($v.from)->$($v.to) as $($v.actor): $($r.Reason)") | Out-Null }
    }
    foreach ($v in $lifecycle.conformanceVectors.invalid) {
        $r = Test-DmsLifecycleTransition -From $v.from -To $v.to -Actor $v.actor -Model $lifecycle
        if (-not $r.IsPermitted) { $lcPass++ } else { $lcFail.Add("expected REJECT $($v.from)->$($v.to) as $($v.actor) but it was permitted") | Out-Null }
    }
    Add-Check 'LifecycleConformanceVectors' ($lcFail.Count -eq 0) "$lcPass vector(s) passed. $(if($lcFail.Count){'Failures: ' + ($lcFail -join ' | ')})" 'F-005'

    # 3e. Execute the declared routing conformance vectors through the real engine.
    $rtPass = 0; $rtFail = [System.Collections.Generic.List[string]]::new()
    foreach ($v in $Configuration.Routing.conformanceVectors) {
        $r = Resolve-DmsRoutingRule -DocumentType $v.input.documentType -BusinessFunction $v.input.businessFunction -Sensitivity $v.input.sensitivity -Model $Configuration.Routing
        $expected = switch ($v.expect) { 'match' { 'Matched' } 'ambiguous' { 'Ambiguous' } 'nomatch' { 'NoMatch' } }
        if ($r.Status -eq $expected) {
            if ($v.expect -eq 'match' -and (Test-DmsProperty -InputObject $v -Name 'expectedRule') -and $r.RuleName -ne $v.expectedRule) {
                $rtFail.Add("expected rule '$($v.expectedRule)' but resolved '$($r.RuleName)'") | Out-Null
            } else { $rtPass++ }
        } else {
            $rtFail.Add("expected $expected but got $($r.Status) for $($v.input.documentType)/$($v.input.businessFunction)/$($v.input.sensitivity)") | Out-Null
        }
    }
    Add-Check 'RoutingConformanceVectors' ($rtFail.Count -eq 0) "$rtPass vector(s) passed. $(if($rtFail.Count){'Failures: ' + ($rtFail -join ' | ')})" 'F-009'

    # ---------------------------------------------------------------- 4. Safety gates
    $unapproved = @($Configuration.RetentionMap.retentionClasses | Where-Object {
        $_.retentionAuthority -eq 'REQUIRES_RECORDS_APPROVAL' -or $_.period -eq 'REQUIRES_RECORDS_APPROVAL' -or $_.status -ne 'Approved'
    })
    if ($unapproved.Count -gt 0) {
        $warnings.Add("Retention: $($unapproved.Count) of $(@($Configuration.RetentionMap.retentionClasses).Count) class(es) are not approved (OQ-03). Production record capture is blocked until Records Management approves them. PRD F-018, R-03.") | Out-Null
    }

    $regulatory = @($Configuration.RetentionMap.retentionClasses | Where-Object { $_.declareAsRegulatoryRecord })
    Add-Check 'NoRegulatoryRecordWithoutAuthorisation' ($regulatory.Count -eq 0) `
        $(if ($regulatory.Count -eq 0) { 'No regulatory-record label is configured.' } else { "Regulatory-record labels configured without the authorisation gate: $(($regulatory | ForEach-Object { $_.recordClass }) -join ', '). These are irreversible." }) 'SEC-012'

    foreach ($e in @('dev','test','prod')) {
        $envCfg = $null
        $all = Read-DmsJsonFile -Path $Configuration.SourceFile
        if (Test-DmsProperty -InputObject $all.environments -Name $e) { $envCfg = $all.environments.$e }
        if ($null -ne $envCfg) {
            $sharing = Get-DmsPropertyOrDefault -InputObject $envCfg -Name 'externalSharing' -Default 'Disabled'
            if ($sharing -ne 'Disabled') {
                $warnings.Add("External sharing for '$e' is '$sharing'. PRD F-025 and SEC-005 require Disabled on controlled sites unless an approved exception exists.") | Out-Null
            }
        }
    }

    if ($Configuration.IsExample) {
        $warnings.Add('Using example configuration (config/environments.json not found). Apply mode is refused against example configuration.') | Out-Null
    }
    $provisionalCount = @($Configuration.Provisional).Count
    if ($provisionalCount -gt 0) {
        $warnings.Add("$provisionalCount provisional setting(s) depend on unanswered PRD open questions. See docs/OPEN_DECISIONS.md.") | Out-Null
    }

    return [PSCustomObject]@{
        IsValid      = ($failures.Count -eq 0)
        CheckCount   = $checks.Count
        PassedCount  = @($checks | Where-Object Passed).Count
        FailedCount  = $failures.Count
        WarningCount = $warnings.Count
        Checks       = $checks.ToArray()
        Failures     = $failures.ToArray()
        Warnings     = $warnings.ToArray()
    }
}
