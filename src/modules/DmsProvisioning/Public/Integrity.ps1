Set-StrictMode -Version Latest

function Test-DmsDocumentId {
<#
.SYNOPSIS
    Validates a Document ID and detects duplicate active identifiers.
.DESCRIPTION
    Implements PRD F-002: a unique, persistent Document ID with duplicate activation blocked.
    The ID convention itself is a PRD open question (OQ-11); the provisional pattern is supplied by
    configuration rather than hard-coded, so answering OQ-11 is a configuration change.
.PARAMETER DocumentId
    Identifier to validate.
.PARAMETER Pattern
    Regular expression the identifier must match.
.PARAMETER ExistingId
    Identifiers already in use by OTHER documents. Used for duplicate detection.
.OUTPUTS
    PSCustomObject with IsValid, IsDuplicate and Reason.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$DocumentId,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Pattern,
        [Parameter()][string[]]$ExistingId = @()
    )

    if ([string]::IsNullOrWhiteSpace($DocumentId)) {
        return [PSCustomObject]@{ DocumentId=$DocumentId; IsValid=$false; IsDuplicate=$false; Reason='Document ID is empty.'; Requirements=@('F-002') }
    }
    if ($DocumentId -cne $DocumentId.Trim()) {
        return [PSCustomObject]@{ DocumentId=$DocumentId; IsValid=$false; IsDuplicate=$false; Reason='Document ID has leading or trailing whitespace.'; Requirements=@('F-002') }
    }
    if ($DocumentId -notmatch $Pattern) {
        return [PSCustomObject]@{ DocumentId=$DocumentId; IsValid=$false; IsDuplicate=$false; Reason="Document ID '$DocumentId' does not match the approved namespace pattern '$Pattern'."; Requirements=@('F-002') }
    }
    # Comparison is case-insensitive so that 'qms-sop-0042' cannot coexist with 'QMS-SOP-0042'.
    $dupe = @($ExistingId | Where-Object { $_ -ieq $DocumentId })
    if ($dupe.Count -gt 0) {
        return [PSCustomObject]@{ DocumentId=$DocumentId; IsValid=$false; IsDuplicate=$true; Reason="Document ID '$DocumentId' is already in use. PRD F-002 blocks duplicate active identifiers."; Requirements=@('F-002') }
    }
    return [PSCustomObject]@{ DocumentId=$DocumentId; IsValid=$true; IsDuplicate=$false; Reason='Valid and unique.'; Requirements=@('F-002') }
}

function Test-DmsApprovalIntegrity {
<#
.SYNOPSIS
    Verifies that an approval still applies to the content that was reviewed.
.DESCRIPTION
    Implements PRD F-008, F-012 and NFR-011, and mitigates PRD risk R-05. The ETag captured at
    submission is compared with the ETag now. A mismatch means the file changed after review, so the
    approval MUST NOT be applied to the changed content.

    The function is called twice in the lifecycle:
      * before recording final approval, and
      * again by the scheduled activation flow immediately before publishing.
    The second call is what prevents an edit made between approval and the effective date from being
    published under an approval that never covered it.
.PARAMETER CapturedETag
    ETag recorded at submission or approval.
.PARAMETER CurrentETag
    ETag read now.
.PARAMETER CapturedVersion
    Version label recorded at submission or approval.
.PARAMETER CurrentVersion
    Version label read now.
.PARAMETER Stage
    Where the check is running, for the returned reason text.
.OUTPUTS
    PSCustomObject with IsIntact, Action and Reason.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$CapturedETag,
        [Parameter(Mandatory)][AllowEmptyString()][string]$CurrentETag,
        [Parameter()][AllowEmptyString()][string]$CapturedVersion = '',
        [Parameter()][AllowEmptyString()][string]$CurrentVersion = '',
        [Parameter()][ValidateSet('BeforeApproval','BeforeActivation')][string]$Stage = 'BeforeApproval'
    )

    if ([string]::IsNullOrWhiteSpace($CapturedETag)) {
        return [PSCustomObject]@{
            IsIntact=$false; Action='Block'; Stage=$Stage
            Reason='No ETag was captured at submission, so version integrity cannot be proven. PRD F-008 requires capture before review begins.'
            ExceptionType='VersionIntegrity'; Severity='High'; IsBlocking=$true; Requirements=@('F-008','NFR-011')
        }
    }

    # ETag is the authoritative content-change signal; version label is corroborating evidence.
    $etagMatches    = ($CapturedETag -eq $CurrentETag)
    $versionSupplied= -not ([string]::IsNullOrWhiteSpace($CapturedVersion) -or [string]::IsNullOrWhiteSpace($CurrentVersion))
    $versionMatches = (-not $versionSupplied) -or ($CapturedVersion -eq $CurrentVersion)

    if ($etagMatches -and $versionMatches) {
        return [PSCustomObject]@{
            IsIntact=$true; Action='Proceed'; Stage=$Stage
            Reason='Content is unchanged since capture.'
            ExceptionType=$null; Severity=$null; IsBlocking=$false; Requirements=@('F-008','NFR-011')
        }
    }

    # PRD F-008 allows invalidation OR restart. Before activation the safe action is to invalidate
    # and return to Rework, because publishing unreviewed content is the failure R-05 describes.
    $action = if ($Stage -eq 'BeforeActivation') { 'InvalidateAndReturnToRework' } else { 'RestartApproval' }
    $detail = if (-not $etagMatches) { "ETag changed." } else { "Version label changed from '$CapturedVersion' to '$CurrentVersion'." }

    return [PSCustomObject]@{
        IsIntact=$false; Action=$action; Stage=$Stage
        Reason="$detail The approval does not apply to the current content and must not be published. PRD F-008, NFR-011, risk R-05."
        ExceptionType='VersionIntegrity'; Severity='High'; IsBlocking=$true; Requirements=@('F-008','F-012','NFR-011')
    }
}

function Test-DmsControlCompleteness {
<#
.SYNOPSIS
    Evaluates the MET-001 control-completeness rule for a revision.
.DESCRIPTION
    Implements PRD MET-001 and objective OBJ-02: 100% of newly effective documents must carry the
    required control metadata and approval evidence. This is the gate the activation flow runs
    before publishing, and the reconciliation job runs daily.
.PARAMETER Document
    Object exposing the controlled metadata fields.
.PARAMETER HasApprovalEvidence
    Whether durable approval evidence exists for this exact revision.
.PARAMETER OwnerIsActive
    Whether the document owner resolves to an active identity.
.PARAMETER RetentionClassApproved
    Whether the mapped retention class is approved rather than provisional.
.OUTPUTS
    PSCustomObject with IsComplete and Failure detail.
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]$Document,
        [Parameter()][bool]$HasApprovalEvidence = $false,
        [Parameter()][bool]$OwnerIsActive = $true,
        [Parameter()][bool]$RetentionClassApproved = $false
    )

    $failures = [System.Collections.Generic.List[string]]::new()

    $requiredFields = @(
        'DmsDocumentId','DmsDocumentType','DmsBusinessFunction','DmsBusinessProcess',
        'DmsDocumentOwner','DmsBusinessRevision','DmsEffectiveDate','DmsNextReviewDate',
        'DmsSensitivityClassification','DmsApplicability','DmsRetentionClass','DmsChangeSummary'
    )
    foreach ($f in $requiredFields) {
        $v = Get-DmsPropertyOrDefault -InputObject $Document -Name $f -Default $null
        $isEmpty = ($null -eq $v) -or ($v -is [string] -and [string]::IsNullOrWhiteSpace($v)) -or ($v -is [array] -and $v.Count -eq 0)
        if ($isEmpty) { $failures.Add("Missing required field '$f'.") | Out-Null }
    }

    if (-not $HasApprovalEvidence)    { $failures.Add('No durable approval evidence exists for this revision. PRD F-010.') | Out-Null }
    if (-not $OwnerIsActive)          { $failures.Add('Document owner does not resolve to an active identity. PRD MET-005.') | Out-Null }
    if (-not $RetentionClassApproved) { $failures.Add('Retention class is not approved. PRD F-018 blocks production use of an unapproved class.') | Out-Null }

    return [PSCustomObject]@{
        DocumentId   = (Get-DmsPropertyOrDefault -InputObject $Document -Name 'DmsDocumentId' -Default '(unknown)')
        IsComplete   = ($failures.Count -eq 0)
        FailureCount = $failures.Count
        Failures     = $failures.ToArray()
        Requirements = @('MET-001','OBJ-02','F-010','F-018')
    }
}
