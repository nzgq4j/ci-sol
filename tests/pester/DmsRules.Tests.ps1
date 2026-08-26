#Requires -Version 7.2
<#
    Unit tests for the DMS rule engine.

    These tests are traceable to PRD requirement IDs. They run entirely offline: no tenant, no
    credentials, no PnP module. That is deliberate, because the rules they cover are the controls
    that must hold before anything reaches a tenant.
#>
# Pester evaluates -ForEach during DISCOVERY, before BeforeAll runs. Data-driven cases must
# therefore be loaded in BeforeDiscovery, not BeforeAll.
BeforeDiscovery {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    Import-Module (Join-Path $repo 'src/modules/DmsProvisioning/DmsProvisioning.psd1') -Force
    $discoveryConfig     = Get-DmsConfiguration -Environment dev
    $ValidTransitions    = @($discoveryConfig.Lifecycle.conformanceVectors.valid)
    $InvalidTransitions  = @($discoveryConfig.Lifecycle.conformanceVectors.invalid)
    $RoutingVectors      = @($discoveryConfig.Routing.conformanceVectors)
}

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    Import-Module (Join-Path $RepoRoot 'src/modules/DmsProvisioning/DmsProvisioning.psd1') -Force
    $script:Config    = Get-DmsConfiguration -Environment dev
    $script:Lifecycle = $Config.Lifecycle
    $script:Routing   = $Config.Routing
}

Describe 'Lifecycle transition engine (PRD F-005)' {

    Context 'Declared conformance vectors' {
        It 'permits <_.from> -> <_.to> as <_.actor>' -ForEach $ValidTransitions {
            $v = $_
            $r = Test-DmsLifecycleTransition -From $v.from -To $v.to -Actor $v.actor -Model $script:Lifecycle
            $r.IsPermitted | Should -BeTrue -Because $r.Reason
        }

        It 'rejects <_.from> -> <_.to> as <_.actor>' -ForEach $InvalidTransitions {
            $v = $_
            $r = Test-DmsLifecycleTransition -From $v.from -To $v.to -Actor $v.actor -Model $script:Lifecycle
            $r.IsPermitted | Should -BeFalse
            $r.Reason      | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Invariants that protect the effective revision (PRD F-012, F-013)' {
        It 'never allows a document to reach Effective without passing through Approved Pending Effective' {
            $toEffective = @($script:Lifecycle.transitions | Where-Object to -eq 'Effective')
            $toEffective | Should -Not -BeNullOrEmpty
            foreach ($t in $toEffective) {
                $t.from | Should -Be 'ApprovedPendingEffective' -Because 'approval alone must never activate a revision'
            }
        }

        It 'restricts the actors who may set Effective to automation and Document Control' {
            foreach ($t in @($script:Lifecycle.transitions | Where-Object to -eq 'Effective')) {
                foreach ($a in $t.allowedActors) {
                    $a | Should -BeIn @('SystemAutomation','DocumentController')
                }
            }
        }

        It 'does not allow an author to approve their own content' {
            $r = Test-DmsLifecycleTransition -From 'InReview' -To 'ApprovedPendingEffective' -Actor 'Author' -Model $script:Lifecycle
            $r.IsPermitted | Should -BeFalse
        }

        It 'does not allow rollback from Superseded to Effective' {
            $r = Test-DmsLifecycleTransition -From 'Superseded' -To 'Effective' -Actor 'DocumentController' -Model $script:Lifecycle
            $r.IsPermitted | Should -BeFalse
            $r.Reason      | Should -Match 'new approved revision'
        }

        It 'treats Obsolete as terminal' {
            foreach ($target in @('Authoring','Effective','Superseded','Withdrawn')) {
                (Test-DmsLifecycleTransition -From 'Obsolete' -To $target -Actor 'DocumentController' -Model $script:Lifecycle).IsPermitted |
                    Should -BeFalse
            }
        }

        It 'flags exactly one state as current-effective' {
            @($script:Lifecycle.states | Where-Object currentEffective).Count | Should -Be 1
        }
    }

    Context 'Preconditions' {
        It 'blocks submission when a precondition is unmet' {
            $r = Test-DmsLifecycleTransition -From 'Authoring' -To 'InReview' -Actor 'Author' -Model $script:Lifecycle `
                    -SatisfiedPreconditions @('MandatoryMetadataComplete')
            $r.IsPermitted        | Should -BeFalse
            $r.UnmetPreconditions | Should -Contain 'ChangeSummaryProvided'
        }

        It 'permits submission when all preconditions are satisfied' {
            $t = Get-DmsLifecycleTransition -From 'Authoring' -To 'InReview' -Model $script:Lifecycle
            $r = Test-DmsLifecycleTransition -From 'Authoring' -To 'InReview' -Actor 'Author' -Model $script:Lifecycle `
                    -SatisfiedPreconditions @($t.preconditions)
            $r.IsPermitted | Should -BeTrue
        }
    }

    Context 'Unknown input' {
        It 'rejects an unknown source state rather than defaulting' {
            (Test-DmsLifecycleTransition -From 'Banana' -To 'Effective' -Actor 'SystemAutomation' -Model $script:Lifecycle).IsPermitted | Should -BeFalse
        }
        It 'raises High severity when an invalid transition targets Effective' {
            (Test-DmsLifecycleTransition -From 'Authoring' -To 'Effective' -Actor 'DocumentController' -Model $script:Lifecycle).ExceptionSeverity | Should -Be 'High'
        }
    }
}

Describe 'Routing resolution (PRD F-009, SEC-003)' {

    It 'resolves <_.expect> for <_.input.documentType>/<_.input.businessFunction>/<_.input.sensitivity>' -ForEach $RoutingVectors {
        $vector = $_
        $r = Resolve-DmsRoutingRule -DocumentType $vector.input.documentType -BusinessFunction $vector.input.businessFunction `
                -Sensitivity $vector.input.sensitivity -Model $script:Routing
        $expected = switch ($vector.expect) { 'match' { 'Matched' } 'ambiguous' { 'Ambiguous' } 'nomatch' { 'NoMatch' } }
        $r.Status | Should -Be $expected
    }

    It 'refuses to guess when two rules tie on specificity' {
        $r = Resolve-DmsRoutingRule -DocumentType 'SOP' -BusinessFunction 'Operations' -Sensitivity 'Highly Confidential' -Model $script:Routing
        $r.Status        | Should -Be 'Ambiguous'
        $r.IsBlocking    | Should -BeTrue
        $r.ExceptionType | Should -Be 'MissingRoute'
        $r.Stages.Count  | Should -Be 0
    }

    It 'produces a blocking exception rather than a default route when nothing matches' {
        $r = Resolve-DmsRoutingRule -DocumentType 'Standard' -BusinessFunction 'Finance' -Sensitivity 'Internal' -Model $script:Routing
        $r.Status     | Should -Be 'NoMatch'
        $r.IsBlocking | Should -BeTrue
    }

    It 'prefers the more specific rule over a wildcard rule' {
        $r = Resolve-DmsRoutingRule -DocumentType 'SOP' -BusinessFunction 'Quality' -Sensitivity 'Highly Confidential' -Model $script:Routing
        $r.Status      | Should -Be 'Matched'
        $r.Specificity | Should -Be 2
    }

    It 'removes the sole author from assignees (separation of duties)' {
        $model = $script:Routing | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $rule  = $model.ruleSets | Where-Object name -eq 'Work Instruction - default'
        $rule.stages[0].assignees = @('alice@contoso.com','bob@contoso.com')
        $r = Resolve-DmsRoutingRule -DocumentType 'Work Instruction' -BusinessFunction 'Operations' -Sensitivity 'Internal' -Model $model -SoleAuthor 'alice@contoso.com'
        $r.Status              | Should -Be 'Matched'
        $r.Stages[0].Assignees | Should -Not -Contain 'alice@contoso.com'
        $r.Stages[0].Assignees | Should -Contain 'bob@contoso.com'
    }

    It 'blocks rather than approving with an empty stage when the author is the only assignee' {
        $model = $script:Routing | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $rule  = $model.ruleSets | Where-Object name -eq 'Work Instruction - default'
        $rule.stages[0].assignees = @('alice@contoso.com')
        $r = Resolve-DmsRoutingRule -DocumentType 'Work Instruction' -BusinessFunction 'Operations' -Sensitivity 'Internal' -Model $model -SoleAuthor 'alice@contoso.com'
        $r.Status     | Should -Be 'Blocked'
        $r.IsBlocking | Should -BeTrue
        $r.Reason     | Should -Match 'self-approval'
    }
}

Describe 'Approval integrity (PRD F-008, NFR-011, risk R-05)' {

    It 'proceeds when the ETag is unchanged' {
        (Test-DmsApprovalIntegrity -CapturedETag '"abc,1"' -CurrentETag '"abc,1"').IsIntact | Should -BeTrue
    }

    It 'blocks approval when content changed after submission' {
        $r = Test-DmsApprovalIntegrity -CapturedETag '"abc,1"' -CurrentETag '"abc,2"' -Stage BeforeApproval
        $r.IsIntact    | Should -BeFalse
        $r.Action      | Should -Be 'RestartApproval'
        $r.IsBlocking  | Should -BeTrue
    }

    It 'invalidates and returns to Rework when content changed before activation' {
        $r = Test-DmsApprovalIntegrity -CapturedETag '"abc,1"' -CurrentETag '"abc,2"' -Stage BeforeActivation
        $r.Action        | Should -Be 'InvalidateAndReturnToRework'
        $r.ExceptionType | Should -Be 'VersionIntegrity'
        $r.Severity      | Should -Be 'High'
    }

    It 'blocks when no ETag was captured at submission' {
        $r = Test-DmsApprovalIntegrity -CapturedETag '' -CurrentETag '"abc,1"'
        $r.IsIntact | Should -BeFalse
        $r.Action   | Should -Be 'Block'
    }

    It 'detects a version-label change even when the ETag appears unchanged' {
        $r = Test-DmsApprovalIntegrity -CapturedETag '"abc,1"' -CurrentETag '"abc,1"' -CapturedVersion '2.1' -CurrentVersion '2.2'
        $r.IsIntact | Should -BeFalse
    }
}

Describe 'Effective revision uniqueness (PRD F-013, MET-014)' {

    It 'accepts exactly one current revision per document' {
        $items = @(
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='2.0'; Applicability='All Locations'; CurrentEffective=$false }
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='3.0'; Applicability='All Locations'; CurrentEffective=$true  }
        )
        (Test-DmsEffectiveRevisionUniqueness -Revision $items).IsValid | Should -BeTrue
    }

    It 'detects more than one current revision as a High blocking violation' {
        $items = @(
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='2.0'; Applicability='All Locations'; CurrentEffective=$true }
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='3.0'; Applicability='All Locations'; CurrentEffective=$true }
        )
        $r = Test-DmsEffectiveRevisionUniqueness -Revision $items
        $r.IsValid                 | Should -BeFalse
        $r.Violations[0].Type      | Should -Be 'DuplicateCurrentRevision'
        $r.Violations[0].IsBlocking| Should -BeTrue
    }

    It 'allows different effective revisions in different applicability contexts' {
        $items = @(
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='3.0'; Applicability='Corporate';       CurrentEffective=$true }
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='2.0'; Applicability='Field Operations';CurrentEffective=$true }
        )
        (Test-DmsEffectiveRevisionUniqueness -Revision $items).IsValid | Should -BeTrue
    }

    It 'detects a missing current revision when the register expects one' {
        $items = @(
            [PSCustomObject]@{ DocumentId='QMS-SOP-0042'; BusinessRevision='3.0'; Applicability='All Locations'; CurrentEffective=$false }
        )
        $r = Test-DmsEffectiveRevisionUniqueness -Revision $items -ExpectCurrentFor @('QMS-SOP-0042')
        $r.IsValid            | Should -BeFalse
        $r.Violations[0].Type | Should -Be 'MissingCurrentRevision'
    }
}

Describe 'Document ID rules (PRD F-002)' {
    BeforeAll { $script:Pattern = '^[A-Z]{2,5}-[A-Z]{2,4}-[0-9]{3,5}$' }

    It 'accepts a well-formed unique identifier' {
        (Test-DmsDocumentId -DocumentId 'QMS-SOP-0042' -Pattern $Pattern).IsValid | Should -BeTrue
    }
    It 'rejects an identifier that does not match the namespace pattern' {
        (Test-DmsDocumentId -DocumentId 'sop 42' -Pattern $Pattern).IsValid | Should -BeFalse
    }
    It 'rejects an empty identifier' {
        (Test-DmsDocumentId -DocumentId '' -Pattern $Pattern).IsValid | Should -BeFalse
    }
    It 'detects a duplicate case-insensitively' {
        $r = Test-DmsDocumentId -DocumentId 'qms-sop-0042' -Pattern $Pattern -ExistingId @('QMS-SOP-0042')
        $r.IsDuplicate | Should -BeTrue
    }
    It 'rejects surrounding whitespace rather than trimming silently' {
        (Test-DmsDocumentId -DocumentId ' QMS-SOP-0042 ' -Pattern $Pattern).IsValid | Should -BeFalse
    }
}

Describe 'Review date calculation (PRD F-015)' {

    It 'calculates the first review date from the effective date' {
        $r = Get-DmsNextReviewDate -FromDate ([datetime]'2026-01-15') -FrequencyMonths 12 -Basis InitialActivation
        $r.IsPermitted             | Should -BeTrue
        $r.NextReviewDate.ToString('yyyy-MM-dd') | Should -Be '2027-01-15'
    }

    It 'REFUSES to roll the review date forward without an attributable decision' {
        $r = Get-DmsNextReviewDate -FromDate ([datetime]'2026-01-15') -FrequencyMonths 12 -Basis PeriodicReviewDecision
        $r.IsPermitted    | Should -BeFalse
        $r.NextReviewDate | Should -BeNullOrEmpty
        $r.Reason         | Should -Match 'attributable review decision'
    }

    It 'rolls forward when a decision reference is supplied' {
        $r = Get-DmsNextReviewDate -FromDate ([datetime]'2026-06-30') -FrequencyMonths 24 -Basis PeriodicReviewDecision -DecisionReference 'EVID-00123'
        $r.IsPermitted | Should -BeTrue
        $r.NextReviewDate.ToString('yyyy-MM-dd') | Should -Be '2028-06-30'
    }

    It 'produces reminders before due and an escalation after due' {
        $s = Get-DmsReviewReminderSchedule -NextReviewDate ([datetime]'2026-12-01') -ReminderOffsetsDays @(90,30,7) -EscalateAfterDaysOverdue 14
        @($s | Where-Object Type -eq 'Reminder').Count | Should -Be 3
        ($s | Where-Object Type -eq 'Escalation').FireDate.ToString('yyyy-MM-dd') | Should -Be '2026-12-15'
        ($s | Where-Object { $_.Type -eq 'Reminder' -and $_.OffsetDays -eq 90 }).FireDate.ToString('yyyy-MM-dd') | Should -Be '2026-09-02'
    }
}

Describe 'Business day arithmetic' {
    It 'skips the weekend' {
        (Get-DmsBusinessDayOffset -StartDate ([datetime]'2026-08-28') -BusinessDays 1).ToString('yyyy-MM-dd') | Should -Be '2026-08-31'
    }
    It 'adds five business days as one calendar week' {
        (Get-DmsBusinessDayOffset -StartDate ([datetime]'2026-08-28') -BusinessDays 5).ToString('yyyy-MM-dd') | Should -Be '2026-09-04'
    }
    It 'honours a supplied holiday' {
        (Get-DmsBusinessDayOffset -StartDate ([datetime]'2026-08-28') -BusinessDays 1 -Holiday @([datetime]'2026-08-31')).ToString('yyyy-MM-dd') | Should -Be '2026-09-01'
    }
    It 'returns the start date when zero days are added' {
        (Get-DmsBusinessDayOffset -StartDate ([datetime]'2026-08-28') -BusinessDays 0).ToString('yyyy-MM-dd') | Should -Be '2026-08-28'
    }
}

Describe 'Control completeness (PRD MET-001, OBJ-02)' {
    BeforeAll {
        $script:Complete = [PSCustomObject]@{
            DmsDocumentId='QMS-SOP-0042'; DmsDocumentType='SOP'; DmsBusinessFunction='Quality'
            DmsBusinessProcess='Document Control'; DmsDocumentOwner='alice@contoso.com'
            DmsBusinessRevision='3.0'; DmsEffectiveDate='2026-09-01'; DmsNextReviewDate='2027-09-01'
            DmsSensitivityClassification='Internal'; DmsApplicability=@('All Locations')
            DmsRetentionClass='Controlled Document - Superseded Revision'; DmsChangeSummary='Updated section 4.'
        }
    }
    It 'passes a fully controlled document' {
        (Test-DmsControlCompleteness -Document $Complete -HasApprovalEvidence $true -OwnerIsActive $true -RetentionClassApproved $true).IsComplete | Should -BeTrue
    }
    It 'fails when approval evidence is missing' {
        $r = Test-DmsControlCompleteness -Document $Complete -HasApprovalEvidence $false -OwnerIsActive $true -RetentionClassApproved $true
        $r.IsComplete | Should -BeFalse
        $r.Failures   | Should -Match 'approval evidence'
    }
    It 'fails when the retention class is not approved' {
        (Test-DmsControlCompleteness -Document $Complete -HasApprovalEvidence $true -OwnerIsActive $true -RetentionClassApproved $false).IsComplete | Should -BeFalse
    }
    It 'fails when the owner is no longer active' {
        (Test-DmsControlCompleteness -Document $Complete -HasApprovalEvidence $true -OwnerIsActive $false -RetentionClassApproved $true).IsComplete | Should -BeFalse
    }
    It 'reports each missing required field' {
        $d = $Complete.PSObject.Copy(); $d.DmsEffectiveDate = ''
        $r = Test-DmsControlCompleteness -Document $d -HasApprovalEvidence $true -OwnerIsActive $true -RetentionClassApproved $true
        $r.Failures | Should -Match 'DmsEffectiveDate'
    }
}

Describe 'Secret redaction (PRD SEC-004, section 17.3)' {
    It 'redacts a bearer token' {
        $r = Write-DmsLog -Action 'T' -Message 'Authorization: Bearer abc123XYZ_-token'
        $r.message | Should -Not -Match 'abc123XYZ'
        $r.message | Should -Match 'REDACTED'
    }
    It 'redacts a client secret in a key/value pair' {
        (Write-DmsLog -Action 'T' -Message 'clientSecret=Sup3rS3cret!').message | Should -Not -Match 'Sup3rS3cret'
    }
    It 'redacts a JWT' {
        (Write-DmsLog -Action 'T' -Message 'token eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc').message | Should -Match 'REDACTED-JWT'
    }
    It 'always emits the structured fields' {
        $r = Write-DmsLog -Action 'EnsureList' -Target 'Approval Evidence' -Result Created -Environment dev -CorrelationId 'abc-123'
        $r.action | Should -Be 'EnsureList'; $r.target | Should -Be 'Approval Evidence'
        $r.result | Should -Be 'Created';    $r.correlationId | Should -Be 'abc-123'
        $r.timestampUtc | Should -Not -BeNullOrEmpty
    }
}

Describe 'Production guard (production protection controls)' {
    BeforeAll {
        $script:GoodTenant = [PSCustomObject]@{ tenantName='contoso'; tenantId='11111111-2222-3333-4444-555555555555'; sharePointAdminUrl='https://contoso-admin.sharepoint.com'; contentTypeHubUrl='https://contoso.sharepoint.com/sites/cthub' }
        $script:ProdEnv    = [PSCustomObject]@{ dmsSiteUrl='https://contoso.sharepoint.com/sites/dms'; allowProductionChanges=$true }
    }
    It 'denies a production apply by default' {
        (Test-DmsProductionGuard -Environment prod -EnvironmentConfig ([PSCustomObject]@{ dmsSiteUrl='https://contoso.sharepoint.com/sites/dms'; allowProductionChanges=$false }) -TenantConfig $GoodTenant -Mode Apply).IsPermitted | Should -BeFalse
    }
    It 'reports every blocker at once rather than stopping at the first' {
        (Test-DmsProductionGuard -Environment prod -EnvironmentConfig ([PSCustomObject]@{ dmsSiteUrl='https://contoso.sharepoint.com/sites/dms'; allowProductionChanges=$false }) -TenantConfig $GoodTenant -Mode Apply).BlockerCount | Should -BeGreaterThan 3
    }
    It 'permits a production apply only when every condition is met' {
        (Test-DmsProductionGuard -Environment prod -EnvironmentConfig $ProdEnv -TenantConfig $GoodTenant -Mode Apply `
            -ProductionChangeAuthorised -PriorSuccessfulDeploymentEnvironment @('test') `
            -PreDeploymentTestsPassed $true -RollbackPlanReference 'docs/BACKUP_RECOVERY_PLAN.md#rollback' -ChangeDisplayed $true).IsPermitted | Should -BeTrue
    }
    It 'still refuses when no prior dev or test deployment exists' {
        (Test-DmsProductionGuard -Environment prod -EnvironmentConfig $ProdEnv -TenantConfig $GoodTenant -Mode Apply `
            -ProductionChangeAuthorised -PriorSuccessfulDeploymentEnvironment @() `
            -PreDeploymentTestsPassed $true -RollbackPlanReference 'x' -ChangeDisplayed $true).IsPermitted | Should -BeFalse
    }
    It 'refuses an Apply that would target an unresolved placeholder tenant' {
        (Test-DmsProductionGuard -Environment dev -EnvironmentConfig ([PSCustomObject]@{ dmsSiteUrl='REQUIRES_TENANT_DISCOVERY'; allowProductionChanges=$false }) -TenantConfig $GoodTenant -Mode Apply).IsPermitted | Should -BeFalse
    }
    It 'permits planning in any environment' {
        (Test-DmsProductionGuard -Environment prod -EnvironmentConfig $ProdEnv -TenantConfig $GoodTenant -Mode Plan).IsPermitted | Should -BeTrue
    }
}
