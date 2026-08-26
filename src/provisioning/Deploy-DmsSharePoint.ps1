#Requires -Version 7.2
<#
.SYNOPSIS
    Provisions the DMS SharePoint information architecture idempotently.
.DESCRIPTION
    Builds and optionally applies the SharePoint layer: site columns, content types, libraries,
    lists, views and library configuration, from config/*.json.

    Separation of planning, validation and mutation is deliberate (PRD coding standards):
      * every Test-* function reads state and returns a decision,
      * every plan action carries the scriptblock that would perform the change,
      * Apply executes only the actions the plan classified Create or Update.

    Idempotency (PRD NFR-006): a resource that already matches is classified Compliant and skipped,
    so reruns are safe. A difference that cannot be changed safely is classified Blocked and
    reported rather than forced.

    This script does not connect on its own. Connect first with Connect-PnPOnline and pass the
    connection, so credential handling stays outside the repository (PRD SEC-004).
.PARAMETER Environment
    Target environment key.
.PARAMETER Mode
    Plan renders intended changes without applying them. Apply executes them.
.PARAMETER Connection
    An existing PnP connection. When omitted the script runs in offline planning mode and reports
    desired state only, clearly labelled, because actual state cannot be read.
.PARAMETER ConfigPath
    Configuration directory.
.PARAMETER LogPath
    Optional JSON Lines log file.
.EXAMPLE
    ./Deploy-DmsSharePoint.ps1 -Environment dev -Mode Plan
.EXAMPLE
    $c = Connect-PnPOnline -Url https://contoso.sharepoint.com/sites/dms-dev -Interactive -ReturnConnection
    ./Deploy-DmsSharePoint.ps1 -Environment dev -Mode Apply -Connection $c
.OUTPUTS
    PSCustomObject deployment summary.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)][ValidateSet('Plan','Apply')][string]$Mode,
    [Parameter()]$Connection = $null,
    [Parameter()][string]$ConfigPath,
    [Parameter()][string]$LogPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path $PSScriptRoot '..' 'modules' 'DmsProvisioning' 'DmsProvisioning.psd1'
Import-Module $moduleRoot -Force

if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '..' '..' 'config' }
$config = Get-DmsConfiguration -ConfigPath $ConfigPath -Environment $Environment
$plan   = New-DmsPlan -Environment $Environment -Mode $Mode
$isOnline = ($null -ne $Connection)
$taxonomyGroupName = (Read-DmsJsonFile -Path (Join-Path $ConfigPath 'taxonomy.json')).termGroup

Write-DmsLog -Action 'DeploySharePoint' -Target $Environment -Result 'Info' -Environment $Environment `
    -CorrelationId $plan.correlationId -LogPath $LogPath `
    -Message "Mode=$Mode Online=$isOnline Site=$($config.Environment.dmsSiteUrl)" | Out-Null

if (-not $isOnline) {
    Write-DmsLog -Action 'DeploySharePoint' -Target 'Connection' -Result 'Skipped' -Level Warning `
        -Environment $Environment -CorrelationId $plan.correlationId -LogPath $LogPath `
        -Message 'No PnP connection supplied. Producing a DESIRED-STATE plan only; actual tenant state was not read, so no resource can be reported as Compliant.' | Out-Null
}

# ---------------------------------------------------------------------------- helpers

function Get-ExistingField {
    param([string]$InternalName)
    if (-not $isOnline) { return $null }
    try { return (Get-PnPField -Identity $InternalName -Connection $Connection -ErrorAction Stop) }
    catch { return $null }
}

function Get-ExistingList {
    param([string]$Title)
    if (-not $isOnline) { return $null }
    try { return (Get-PnPList -Identity $Title -Connection $Connection -ErrorAction Stop) }
    catch { return $null }
}

function Get-ExistingContentType {
    param([string]$Name)
    if (-not $isOnline) { return $null }
    try { return (Get-PnPContentType -Identity $Name -Connection $Connection -ErrorAction Stop) }
    catch { return $null }
}

# Maps the configuration field type to the SharePoint field type accepted by Add-PnPField.
function ConvertTo-SharePointFieldType {
    param([string]$ConfigType)
    switch ($ConfigType) {
        'Text'                     { 'Text' }
        'Note'                     { 'Note' }
        'Number'                   { 'Number' }
        'Boolean'                  { 'Boolean' }
        'DateTime'                 { 'DateTime' }
        'Choice'                   { 'Choice' }
        'MultiChoice'              { 'MultiChoice' }
        'User'                     { 'User' }
        'UserMulti'                { 'UserMulti' }
        'Lookup'                   { 'Lookup' }
        'URL'                      { 'URL' }
        'Calculated'               { 'Calculated' }
        # Taxonomy fields cannot be created with Add-PnPField -Type; they need the taxonomy-aware path.
        'TaxonomyFieldType'        { 'TaxonomyFieldType' }
        'TaxonomyFieldTypeMulti'   { 'TaxonomyFieldTypeMulti' }
        default                    { throw "Unsupported configured field type '$ConfigType'." }
    }
}

# ---------------------------------------------------------------------------- 1. site columns

# Everything a create needs is resolved HERE, before the closure is built. A deferred scriptblock
# created with GetNewClosure() runs in its own module scope, which cannot see functions defined in
# this script's scope when the script is invoked from the orchestrator. Resolving the field spec up
# front removes that dependency entirely, and makes the plan carry exactly what Apply will execute.
function Resolve-DmsFieldSpec {
    param($Column, [string]$FieldGroup, [string]$TaxonomyGroup)

    $spType   = ConvertTo-SharePointFieldType -ConfigType $Column.type
    $required = [bool](Get-DmsPropertyOrDefault -InputObject $Column -Name 'required' -Default $false)
    $indexed  = [bool](Get-DmsPropertyOrDefault -InputObject $Column -Name 'indexed'  -Default $false)

    if ($spType -like 'TaxonomyField*') {
        $p = @{
            DisplayName  = $Column.displayName
            InternalName = $Column.internalName
            TermSetPath  = ('{0}|{1}' -f $TaxonomyGroup, $Column.termSet)
            Group        = $FieldGroup
        }
        if ([bool](Get-DmsPropertyOrDefault -InputObject $Column -Name 'allowMultipleValues' -Default $false)) { $p['MultiValue'] = $true }
        if ($required) { $p['Required'] = $true }
        return [PSCustomObject]@{ Kind='Taxonomy'; Type=$spType; Params=$p; Xml=$null; Indexed=$indexed; InternalName=$Column.internalName }
    }

    if ($spType -eq 'UserMulti') {
        # The CSOM FieldType enum has User but no UserMulti, so Add-PnPField cannot create a
        # multi-value person field. UserMulti is a valid SharePoint *schema* type, so the field is
        # created from field XML instead.
        $mode = Get-DmsPropertyOrDefault -InputObject $Column -Name 'selectionMode' -Default 'PeopleOnly'
        $xml  = '<Field Type="UserMulti" DisplayName="{0}" Name="{1}" StaticName="{1}" ID="{2}" Group="{3}" Mult="TRUE" UserSelectionMode="{4}" List="UserInfo"{5} />' -f `
                    [System.Security.SecurityElement]::Escape($Column.displayName),
                    $Column.internalName,
                    ('{' + [guid]::NewGuid().ToString() + '}'),
                    [System.Security.SecurityElement]::Escape($FieldGroup),
                    $mode,
                    $(if ($required) { ' Required="TRUE"' } else { '' })
        return [PSCustomObject]@{ Kind='Xml'; Type=$spType; Params=$null; Xml=$xml; Indexed=$indexed; InternalName=$Column.internalName }
    }

    $p = @{
        DisplayName  = $Column.displayName
        InternalName = $Column.internalName
        Type         = $spType
        Group        = $FieldGroup
    }
    if ($Column.type -in @('Choice','MultiChoice')) { $p['Choices'] = @($Column.choices) }
    if ($required) { $p['Required'] = $true }
    return [PSCustomObject]@{ Kind='Standard'; Type=$spType; Params=$p; Xml=$null; Indexed=$indexed; InternalName=$Column.internalName }
}

foreach ($col in $config.SiteColumns.columns) {
    $spec     = Resolve-DmsFieldSpec -Column $col -FieldGroup $config.SiteColumns.fieldGroup -TaxonomyGroup $taxonomyGroupName
    $existing = Get-ExistingField -InternalName $col.internalName

    if ($null -eq $existing) {
        $capturedSpec = $spec
        $capturedConn = $Connection
        Add-DmsPlanAction -Plan $plan -ResourceType 'SiteColumn' -Target $col.internalName -Change 'Create' `
            -Reason $(if ($isOnline) { 'Field does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements $col.requirements -Detail @{ type = $spec.Type; kind = $spec.Kind; indexed = $spec.Indexed } `
            -ApplyScript {
                switch ($capturedSpec.Kind) {
                    'Taxonomy' {
                        $tp = $capturedSpec.Params.Clone(); $tp['Connection'] = $capturedConn
                        Invoke-DmsWithRetry -OperationName "Add-PnPTaxonomyField $($capturedSpec.InternalName)" -ScriptBlock { Add-PnPTaxonomyField @tp } | Out-Null
                    }
                    'Xml' {
                        $x = $capturedSpec.Xml; $c = $capturedConn
                        Invoke-DmsWithRetry -OperationName "Add-PnPFieldFromXml $($capturedSpec.InternalName)" -ScriptBlock { Add-PnPFieldFromXml -FieldXml $x -Connection $c } | Out-Null
                    }
                    default {
                        $fp = $capturedSpec.Params.Clone(); $fp['Connection'] = $capturedConn
                        Invoke-DmsWithRetry -OperationName "Add-PnPField $($capturedSpec.InternalName)" -ScriptBlock { Add-PnPField @fp } | Out-Null
                    }
                }
                if ($capturedSpec.Indexed) {
                    $n = $capturedSpec.InternalName; $c2 = $capturedConn
                    Invoke-DmsWithRetry -OperationName "Index $n" -ScriptBlock {
                        Set-PnPField -Identity $n -Values @{ Indexed = $true } -Connection $c2
                    } | Out-Null
                }
            }.GetNewClosure() | Out-Null
    } else {
        $actualType = "$($existing.TypeAsString)"
        if ($actualType -ne $spec.Type) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'SiteColumn' -Target $col.internalName -Change 'Blocked' `
                -Reason "Field exists with type '$actualType' but configuration requires '$($spec.Type)'. Changing a field type can destroy data, so it is not attempted. Resolve manually or rename the configured column." `
                -Requirements $col.requirements | Out-Null
        } elseif ("$($existing.Title)" -ne "$($col.displayName)") {
            $n = $col.internalName; $t = $col.displayName; $c3 = $Connection
            Add-DmsPlanAction -Plan $plan -ResourceType 'SiteColumn' -Target $col.internalName -Change 'Update' `
                -Reason "Display name differs (actual '$($existing.Title)', desired '$($col.displayName)'). Safe to update; the internal name is unchanged." `
                -Requirements $col.requirements `
                -ApplyScript {
                    Invoke-DmsWithRetry -OperationName "Set-PnPField $n" -ScriptBlock {
                        Set-PnPField -Identity $n -Values @{ Title = $t } -Connection $c3
                    } | Out-Null
                }.GetNewClosure() | Out-Null
        } else {
            Add-DmsPlanAction -Plan $plan -ResourceType 'SiteColumn' -Target $col.internalName -Change 'Compliant' `
                -Reason 'Matches configuration.' -Requirements $col.requirements | Out-Null
        }
    }
}


# ---------------------------------------------------------------------------- 2. content types

foreach ($ct in @($config.ContentTypes.contentTypes | Where-Object { (Get-DmsPropertyOrDefault -InputObject $_ -Name 'status' -Default '') -ne 'Deferred' })) {
    $existing = Get-ExistingContentType -Name $ct.name
    $required = @(Get-DmsPropertyOrDefault -InputObject $ct -Name 'requiredFields' -Default @())
    $optional = @(Get-DmsPropertyOrDefault -InputObject $ct -Name 'optionalFields' -Default @())

    # Field binding is done per field with its own error handling. Binding them in one unbroken
    # sequence meant a single unavailable column aborted every remaining binding, which is how a
    # content type ended up existing with most of its optional fields missing.
    $bindFields = {
        param($CtName, $RequiredFields, $OptionalFields, $Conn)
        $failures = [System.Collections.Generic.List[string]]::new()
        foreach ($f in $RequiredFields) {
            try   { Add-PnPFieldToContentType -Field $f -ContentType $CtName -Required -Connection $Conn | Out-Null }
            catch { $failures.Add("$f (required): $($_.Exception.Message)") | Out-Null }
        }
        foreach ($f in $OptionalFields) {
            try   { Add-PnPFieldToContentType -Field $f -ContentType $CtName -Connection $Conn | Out-Null }
            catch { $failures.Add("$f (optional): $($_.Exception.Message)") | Out-Null }
        }
        if ($failures.Count -gt 0) { throw "Content type '$CtName' created, but $($failures.Count) field binding(s) failed: $($failures -join ' | ')" }
    }

    if ($null -eq $existing) {
        $capturedCt   = $ct
        $capturedReq  = $required
        $capturedOpt  = $optional
        $capturedGrp  = $config.ContentTypes.group
        $capturedConn = $Connection
        $capturedBind = $bindFields
        Add-DmsPlanAction -Plan $plan -ResourceType 'ContentType' -Target $ct.name -Change 'Create' `
            -Reason $(if ($isOnline) { 'Content type does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements (Get-DmsPropertyOrDefault -InputObject $ct -Name 'requirements' -Default @()) `
            -Detail @{ id = $ct.id; parentId = $ct.parentId; fieldCount = ($required.Count + $optional.Count) } `
            -ApplyScript {
                $ctParams = @{
                    Name          = $capturedCt.name
                    ContentTypeId = $capturedCt.id
                    Description   = $capturedCt.description
                    Group         = $capturedGrp
                    Connection    = $capturedConn
                }
                Invoke-DmsWithRetry -OperationName "Add-PnPContentType $($capturedCt.name)" -ScriptBlock { Add-PnPContentType @ctParams } | Out-Null
                & $capturedBind $capturedCt.name $capturedReq $capturedOpt $capturedConn
            }.GetNewClosure() | Out-Null
    } else {
        $actualId = "$($existing.Id.StringValue)"
        if ($actualId -ne $ct.id) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'ContentType' -Target $ct.name -Change 'Blocked' `
                -Reason "Content type exists with id '$actualId' but configuration declares '$($ct.id)'. Content type IDs are immutable contracts; this indicates a name collision or a regenerated id. Resolve manually." `
                -Requirements @('F-001') | Out-Null
        } else {
            # Existence alone is not compliance. A content type created by a partially failed run can
            # exist with fields missing, and reporting it Compliant would leave those fields unbound
            # for good, because the next run would skip it too.
            $missing = @()
            if ($isOnline -and ($required.Count + $optional.Count) -gt 0) {
                try {
                    $bound = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                    foreach ($fl in @((Get-PnPContentType -Identity $ct.name -Connection $Connection).Fields)) { [void]$bound.Add("$($fl.InternalName)") }
                    if ($bound.Count -gt 0) { $missing = @(($required + $optional) | Where-Object { -not $bound.Contains($_) }) }
                } catch { $missing = @() }
            }

            if ($missing.Count -gt 0) {
                $capturedCt2  = $ct
                $capturedMissReq = @($required | Where-Object { $_ -in $missing })
                $capturedMissOpt = @($optional | Where-Object { $_ -in $missing })
                $capturedConn2   = $Connection
                $capturedBind2   = $bindFields
                Add-DmsPlanAction -Plan $plan -ResourceType 'ContentType' -Target $ct.name -Change 'Update' `
                    -Reason "Content type exists but $($missing.Count) configured field(s) are not bound: $($missing -join ', '). Binding the missing fields is safe and additive." `
                    -Requirements @('F-001') -Detail @{ missingFields = $missing } `
                    -ApplyScript {
                        & $capturedBind2 $capturedCt2.name $capturedMissReq $capturedMissOpt $capturedConn2
                    }.GetNewClosure() | Out-Null
            } else {
                Add-DmsPlanAction -Plan $plan -ResourceType 'ContentType' -Target $ct.name -Change 'Compliant' `
                    -Reason 'Exists with the expected content type id and all configured fields bound.' -Requirements @('F-001') | Out-Null
            }
        }
    }
}


# ---------------------------------------------------------------------------- 3. libraries

$featureFlags = Get-DmsPropertyOrDefault -InputObject $config.Environment -Name 'features' -Default $null

foreach ($lib in $config.Libraries.libraries) {
    $gate = Get-DmsPropertyOrDefault -InputObject $lib -Name 'provisionWhen' -Default ''
    if ($gate) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'Library' -Target $lib.title -Change 'Blocked' `
            -Reason "Gated by '$gate'$(if (Get-DmsPropertyOrDefault -InputObject $lib -Name 'blockedBy' -Default ''){ " and decision $((Get-DmsPropertyOrDefault -InputObject $lib -Name 'blockedBy' -Default ''))" }). Not provisioned until the feature flag is enabled." `
            -Requirements (Get-DmsPropertyOrDefault -InputObject $lib -Name 'requirements' -Default @()) | Out-Null
        continue
    }

    $existing = Get-ExistingList -Title $lib.title
    $captured = $lib

    $applySettings = {
        $v = $captured.versioning
        $ca = $captured.contentApproval
        $setParams = @{
            Identity              = $captured.title
            EnableVersioning      = [bool]$v.enableVersioning
            EnableMinorVersions   = [bool]$v.enableMinorVersions
            EnableModeration      = [bool]$ca.enableModeration
            EnableContentTypes    = [bool]$captured.contentTypesEnabled
            EnableFolderCreation  = [bool]$captured.folderCreation.enableFolderCreation
            ForceCheckout         = [bool]$captured.checkOut.forceCheckout
            DisableGridEditing    = [bool]$captured.gridEditing.disableGridEditing
            DraftVersionVisibility= $ca.draftVisibility
            Connection            = $Connection
        }
        if (Test-DmsProperty -InputObject $v -Name 'majorVersionLimit')          { $setParams['MajorVersions'] = [int]$v.majorVersionLimit }
        if (Test-DmsProperty -InputObject $v -Name 'majorWithMinorVersionsLimit'){ $setParams['MinorVersions'] = [int]$v.majorWithMinorVersionsLimit }

        Invoke-DmsWithRetry -OperationName "Set-PnPList $($captured.title)" -ScriptBlock { Set-PnPList @setParams } | Out-Null

        foreach ($ctName in @($captured.contentTypes)) {
            Invoke-DmsWithRetry -OperationName "Bind CT $ctName" -ScriptBlock {
                Add-PnPContentTypeToList -List $captured.title -ContentType $ctName -Connection $Connection
            } | Out-Null
        }
        foreach ($idx in @(Get-DmsPropertyOrDefault -InputObject $captured -Name 'indexedColumns' -Default @())) {
            Invoke-DmsWithRetry -OperationName "Index $idx on $($captured.title)" -ScriptBlock {
                Set-PnPField -List $captured.title -Identity $idx -Values @{ Indexed = $true } -Connection $Connection
            } | Out-Null
        }
    }.GetNewClosure()

    if ($null -eq $existing) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'Library' -Target $lib.title -Change 'Create' `
            -Reason $(if ($isOnline) { 'Library does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements $lib.requirements `
            -Detail @{ operatingMode = $lib.operatingMode; draftVisibility = $lib.contentApproval.draftVisibility; forceCheckout = $lib.checkOut.forceCheckout } `
            -ApplyScript {
                Invoke-DmsWithRetry -OperationName "New-PnPList $($captured.title)" -ScriptBlock {
                    New-PnPList -Title $captured.title -Template DocumentLibrary -Url $captured.urlPath -EnableContentTypes:([bool]$captured.contentTypesEnabled) -Connection $Connection
                } | Out-Null
                & $applySettings
            }.GetNewClosure() | Out-Null
    } else {
        # Compare the settings that carry control meaning. Anything different is a safe update.
        $diffs = @()
        if ([bool]$existing.EnableVersioning    -ne [bool]$lib.versioning.enableVersioning)    { $diffs += 'EnableVersioning' }
        if ([bool]$existing.EnableMinorVersions -ne [bool]$lib.versioning.enableMinorVersions) { $diffs += 'EnableMinorVersions' }
        if ([bool]$existing.EnableModeration    -ne [bool]$lib.contentApproval.enableModeration){ $diffs += 'EnableModeration' }
        if ([bool]$existing.ForceCheckout       -ne [bool]$lib.checkOut.forceCheckout)          { $diffs += 'ForceCheckout' }
        if ("$($existing.DraftVersionVisibility)" -ne "$($lib.contentApproval.draftVisibility)"){ $diffs += 'DraftVersionVisibility' }

        if ($diffs.Count -gt 0) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'Library' -Target $lib.title -Change 'Update' `
                -Reason "Configuration drift in: $($diffs -join ', '). These are safe, reversible settings." `
                -Requirements $lib.requirements -Detail @{ driftedSettings = $diffs } -ApplyScript $applySettings | Out-Null
        } else {
            Add-DmsPlanAction -Plan $plan -ResourceType 'Library' -Target $lib.title -Change 'Compliant' `
                -Reason 'Versioning, moderation, draft visibility and check-out match configuration.' -Requirements $lib.requirements | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------- 4. lists

foreach ($list in $config.Lists.lists) {
    $gate = Get-DmsPropertyOrDefault -InputObject $list -Name 'provisionWhen' -Default ''
    if ($gate) {
        Add-DmsPlanAction -Plan $plan -ResourceType 'List' -Target $list.title -Change 'Blocked' `
            -Reason "Gated by '$gate'. Not provisioned until the feature flag is enabled." `
            -Requirements $list.requirements | Out-Null
        continue
    }

    $existing = Get-ExistingList -Title $list.title

    # Field specs are resolved BEFORE the closure, so the deferred scriptblock never calls a
    # function defined in this script's scope. It could not see one when this script is invoked
    # from the orchestrator, which is what made every list creation fail.
    $fieldSpecs = [System.Collections.Generic.List[object]]::new()
    foreach ($f in @($list.fields)) {
        if ($f.internalName -eq 'Title') { continue }
        if ([bool](Get-DmsPropertyOrDefault -InputObject $f -Name 'reuseSiteColumn' -Default $false)) {
            $fieldSpecs.Add([PSCustomObject]@{ Kind='SiteColumn'; InternalName=$f.internalName; Params=$null; Xml=$null }) | Out-Null
        } else {
            $spec = Resolve-DmsFieldSpec -Column $f -FieldGroup $config.SiteColumns.fieldGroup -TaxonomyGroup $taxonomyGroupName
            $fieldSpecs.Add($spec) | Out-Null
        }
    }

    if ($null -eq $existing) {
        $capturedList = $list
        $capturedSpecs= $fieldSpecs.ToArray()
        $capturedIdx  = @(Get-DmsPropertyOrDefault -InputObject $list -Name 'indexedColumns' -Default @())
        $capturedConn = $Connection
        Add-DmsPlanAction -Plan $plan -ResourceType 'List' -Target $list.title -Change 'Create' `
            -Reason $(if ($isOnline) { 'List does not exist.' } else { 'Desired state (actual state not read).' }) `
            -Requirements $list.requirements -Detail @{ fieldCount = $fieldSpecs.Count } `
            -ApplyScript {
                Invoke-DmsWithRetry -OperationName "New-PnPList $($capturedList.title)" -ScriptBlock {
                    New-PnPList -Title $capturedList.title -Template GenericList -Url $capturedList.urlPath -Connection $capturedConn
                } | Out-Null

                # Each field is added independently so one failure cannot abort the rest of the list.
                $fieldFailures = [System.Collections.Generic.List[string]]::new()
                foreach ($s in $capturedSpecs) {
                    try {
                        switch ($s.Kind) {
                            'SiteColumn' { $n=$s.InternalName; Add-PnPField -List $capturedList.title -Field $n -Connection $capturedConn | Out-Null }
                            'Xml'        { $x=$s.Xml;          Add-PnPFieldFromXml -List $capturedList.title -FieldXml $x -Connection $capturedConn | Out-Null }
                            'Taxonomy'   { $tp=$s.Params.Clone(); $tp['List']=$capturedList.title; $tp['Connection']=$capturedConn; Add-PnPTaxonomyField @tp | Out-Null }
                            default      { $fp=$s.Params.Clone(); $fp['List']=$capturedList.title; $fp['Connection']=$capturedConn; Add-PnPField @fp | Out-Null }
                        }
                    } catch { $fieldFailures.Add("$($s.InternalName): $($_.Exception.Message)") | Out-Null }
                }
                foreach ($idx in $capturedIdx) {
                    try { Set-PnPField -List $capturedList.title -Identity $idx -Values @{ Indexed = $true } -Connection $capturedConn | Out-Null }
                    catch { $fieldFailures.Add("index $idx : $($_.Exception.Message)") | Out-Null }
                }
                if ($fieldFailures.Count -gt 0) {
                    throw "List '$($capturedList.title)' created, but $($fieldFailures.Count) field operation(s) failed: $($fieldFailures -join ' | ')"
                }
            }.GetNewClosure() | Out-Null
    } else {
        Add-DmsPlanAction -Plan $plan -ResourceType 'List' -Target $list.title -Change 'Compliant' `
            -Reason 'List exists. Field-level drift is reported by Test-DmsConfiguration and the drift report.' `
            -Requirements $list.requirements | Out-Null
    }
}


# ---------------------------------------------------------------------------- 5. views

$provisionedContainers = @($config.Libraries.libraries | Where-Object { -not (Get-DmsPropertyOrDefault -InputObject $_ -Name 'provisionWhen' -Default '') } | ForEach-Object { $_.key }) +
                         @($config.Lists.lists       | Where-Object { -not (Get-DmsPropertyOrDefault -InputObject $_ -Name 'provisionWhen' -Default '') } | ForEach-Object { $_.key })

foreach ($view in $config.Views.views) {
    foreach ($targetKey in @($view.targetLists)) {
        if ($targetKey -notin $provisionedContainers) { continue }

        $container = @($config.Libraries.libraries | Where-Object key -eq $targetKey) + @($config.Lists.lists | Where-Object key -eq $targetKey) | Select-Object -First 1
        $listTitle = $container.title
        $captured  = $view
        $capturedList = $listTitle

        $existingView = $null
        if ($isOnline) {
            try { $existingView = Get-PnPView -List $listTitle -Identity $view.title -Connection $Connection -ErrorAction Stop } catch { $existingView = $null }
        }

        if ($null -eq $existingView) {
            Add-DmsPlanAction -Plan $plan -ResourceType 'View' -Target "$listTitle / $($view.title)" -Change 'Create' `
                -Reason $(if ($isOnline) { 'View does not exist.' } else { 'Desired state (actual state not read).' }) `
                -Requirements $view.requirements `
                -ApplyScript {
                    $vp = @{
                        List       = $capturedList
                        Title      = $captured.title
                        Fields     = @($captured.viewFields)
                        Query      = (Get-DmsPropertyOrDefault -InputObject $captured -Name 'camlQuery' -Default '')
                        RowLimit   = [uint32](Get-DmsPropertyOrDefault -InputObject $captured -Name 'rowLimit' -Default 30)
                        Connection = $Connection
                    }
                    if ([bool](Get-DmsPropertyOrDefault -InputObject $captured -Name 'paged'     -Default $false)) { $vp['Paged'] = $true }
                    if ([bool](Get-DmsPropertyOrDefault -InputObject $captured -Name 'isDefault' -Default $false)) { $vp['SetAsDefault'] = $true }
                    Invoke-DmsWithRetry -OperationName "Add-PnPView $($captured.title)" -ScriptBlock { Add-PnPView @vp } | Out-Null
                }.GetNewClosure() | Out-Null
        } else {
            Add-DmsPlanAction -Plan $plan -ResourceType 'View' -Target "$listTitle / $($view.title)" -Change 'Compliant' `
                -Reason 'View exists.' -Requirements $view.requirements | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------- render and apply

$summary = Format-DmsPlan -Plan $plan

if ($Mode -eq 'Apply') {
    if (-not $isOnline) {
        Write-DmsLog -Action 'DeploySharePoint' -Target $Environment -Result 'Blocked' -Level Error `
            -Environment $Environment -CorrelationId $plan.correlationId -LogPath $LogPath `
            -Message 'Apply requires a PnP connection. Connect with Connect-PnPOnline and pass -Connection.' | Out-Null
        $summary | Add-Member -NotePropertyName applied -NotePropertyValue $false -Force
        $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue 3 -Force
        return $summary
    }

    $applied = 0; $failed = 0
    foreach ($action in @($plan.actions | Where-Object { $_.change -in @('Create','Update') })) {
        if ($null -eq $action.applyScript) { continue }
        if ($PSCmdlet.ShouldProcess("$($action.resourceType) $($action.target)", $action.change)) {
            try {
                & $action.applyScript
                $action.executed = $true
                $action.outcome  = 'Succeeded'
                $applied++
                Write-DmsLog -Action "Apply$($action.resourceType)" -Target $action.target -Result $(if ($action.change -eq 'Create') { 'Created' } else { 'Updated' }) `
                    -Environment $Environment -CorrelationId $plan.correlationId -LogPath $LogPath | Out-Null
            } catch {
                $action.outcome = 'Failed'
                $failed++
                Write-DmsLog -Action "Apply$($action.resourceType)" -Target $action.target -Result 'Failed' -Level Error `
                    -Environment $Environment -CorrelationId $plan.correlationId -LogPath $LogPath -Message $_.Exception.Message | Out-Null
            }
        }
    }
    $summary | Add-Member -NotePropertyName appliedCount -NotePropertyValue $applied -Force
    $summary | Add-Member -NotePropertyName failedCount  -NotePropertyValue $failed  -Force
    $summary | Add-Member -NotePropertyName applied      -NotePropertyValue $true    -Force
    $summary | Add-Member -NotePropertyName exitCode     -NotePropertyValue $(if ($failed -gt 0) { 1 } else { 0 }) -Force
} else {
    $summary | Add-Member -NotePropertyName applied  -NotePropertyValue $false -Force
    $summary | Add-Member -NotePropertyName exitCode -NotePropertyValue $(if ($summary.hasBlocking) { 2 } else { 0 }) -Force
}

return $summary
